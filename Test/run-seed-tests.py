"""Portable demo tests. Every write uses a private PostgreSQL cluster in /tmp."""
import csv
import importlib.util
import json
import os
from pathlib import Path
import secrets
import subprocess
import sys
import tempfile
from urllib.parse import quote

ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
os.chdir(ROOT)
spec = importlib.util.spec_from_file_location('demo', ROOT / 'scripts/seed-demo.py')
demo = importlib.util.module_from_spec(spec)
spec.loader.exec_module(demo)
work = Path(tempfile.mkdtemp(prefix='sga-seed-test-'))
os.chmod(work, 0o700)
port = '55440'
env = dict(os.environ, PATH=str(ROOT / '.devenv/profile/bin') + ':' + os.environ['PATH'],
           IHP_ENV='Development', DEBUG='0', SGA_ISOLATED_SEED_TEST='1')
# No test credential is a literal or persisted to a file.
for name in demo.PASSWORD_VARIABLES:
    env[name] = secrets.token_urlsafe(24)
passwords = [env[name] for name in demo.PASSWORD_VARIABLES]


def run(command, *, check=True, custom_env=None, private_result=False):
    result = subprocess.run(command, env=custom_env or env, cwd=ROOT, text=True, capture_output=True, stdin=subprocess.DEVNULL)
    # SQL errors and authentication failures must never print a password/hash.
    combined = result.stdout + result.stderr
    if not private_result and (any(p in combined for p in passwords) or 'sha256|' in combined):
        raise RuntimeError('Sensitive output refused (content omitted).')
    if check and result.returncode:
        raise RuntimeError('Isolated test step failed: ' + ' '.join(command[:2]) + (' (private SQL output omitted)' if private_result else '\n' + combined[-2500:]))
    return result


def url(database):
    return f'postgresql:///{database}?host={quote(str(work))}&port={port}'


def sql(statement, database='sga_demo_seed'):
    return run([demo.tool('psql'), '-XAt', url(database), '-v', 'ON_ERROR_STOP=1', '-c', statement], private_result=True).stdout.strip()


def seed(database='sga_demo_seed', *options, custom_env=None, check=True):
    return run([sys.executable, str(ROOT / 'scripts/seed-demo.py'), '--database-url', url(database),
                '--confirm', 'development-demo', *options], custom_env=custom_env, check=check)


TABLES = ['users', 'students', 'teachers', 'courses', 'subjects', 'teacher_subjects', 'enrollments', 'grades']


def fingerprint(database='sga_demo_seed'):
    return sql("SELECT md5(string_agg(v,'|' ORDER BY v)) FROM (" + ' UNION ALL '.join(
        f"SELECT '{table}:'||to_jsonb(t)::text v FROM {table} t" for table in TABLES) + ') data', database)


started = False
try:
    run([demo.tool('initdb'), '-D', str(work / 'data'), '-A', 'trust', '--no-locale', '--encoding=UTF8'])
    run([demo.tool('pg_ctl'), '-D', str(work / 'data'), '-l', str(work / 'postgres.log'),
         '-o', f"-k {work} -p {port} -h ''", '-w', 'start'])
    started = True
    seed('sga_demo_seed', '--init-db', '--schema-only')
    # --init-db must never import a schema over an existing database.
    before = fingerprint()
    assert seed('sga_demo_seed', '--init-db', '--schema-only', check=False).returncode != 0
    assert fingerprint() == before
    seed()
    flags = []
    for line in demo.resource('applicationGhciConfig').read_text().splitlines():
        if line.startswith(':set -X') or line.startswith(':set -W'):
            flags.extend(line[5:].split())
    test_env = dict(env, DATABASE_URL=url('sga_demo_seed'))
    result = run([demo.tool('runghc'), '-ignore-dot-ghci', '-i.', '-ibuild', '-iConfig', *flags,
                  'Test/SeedSecurity.hs'], custom_env=test_env)
    print(result.stdout, flush=True)
    before = fingerprint()
    seed()
    assert fingerprint() == before
    print('PASS: second seed is byte-for-byte idempotent.', flush=True)
    # Editing a grade or changing local configuration must not reset existing data/passwords.
    sql('UPDATE grades SET score=9.99 WHERE id=(SELECT id FROM grades ORDER BY id LIMIT 1)')
    before = fingerprint()
    changed_env = dict(env)
    for name in demo.PASSWORD_VARIABLES:
        changed_env[name] = secrets.token_urlsafe(24)
        passwords.append(changed_env[name])
    seed(custom_env=changed_env)
    assert fingerprint() == before
    print('PASS: edited grade and all original passwords preserved.', flush=True)
    # A collision occurs after creating some course/teacher rows: all must roll back.
    seed('sga_demo_collision', '--init-db', '--schema-only')
    # Reuse a hash from this isolated database only; no inventory or real account is read.
    hash_value = sql("SELECT password_hash FROM users WHERE role='RoleAdmin'")
    collision_email = list(csv.DictReader((ROOT / 'docs/database/reorganizacao-demo-novos-estudantes.csv').open()))[0]['development_email']
    def literal(value):
        return "'" + value.replace("'", "''") + "'"
    sql("INSERT INTO users(name,email,password_hash,role) VALUES ('Conta externa preservada'," +
        literal(collision_email) + ',' + literal(hash_value) + ",'RoleTeacher')", 'sga_demo_collision')
    before_collision = fingerprint('sga_demo_collision')
    assert seed('sga_demo_collision', check=False).returncode != 0
    assert fingerprint('sga_demo_collision') == before_collision
    print('PASS: identity collision rolls back all changes; unrelated account preserved.', flush=True)
    production = dict(env, IHP_ENV='Production')
    before = fingerprint()
    assert seed(custom_env=production, check=False).returncode != 0
    assert fingerprint() == before
    direct = dict(test_env, IHP_ENV='Production', SGA_DEMO_CONFIRM='development-demo')
    assert run([demo.tool('runghc'), '-ignore-dot-ghci', '-i.', '-ibuild', '-iConfig', *flags,
                'Application/Script/SeedDemo.hs'], custom_env=direct, check=False).returncode != 0
    assert fingerprint() == before
    assert seed('app', check=False).returncode != 0
    # Also exercise the Haskell guard independently of the wrapper, on a second disposable DB.
    run([demo.tool('createdb'), '-h', str(work), '-p', port, 'app'])
    direct = dict(test_env, DATABASE_URL=url('app'), SGA_DEMO_CONFIRM='development-demo')
    assert run([demo.tool('runghc'), '-ignore-dot-ghci', '-i.', '-ibuild', '-iConfig', *flags,
                'Application/Script/SeedDemo.hs'], custom_env=direct, check=False).returncode != 0
    assert sql("SELECT count(*) FROM pg_tables WHERE schemaname='public'", 'app') == '0'
    missing = {k: v for k, v in env.items() if k not in demo.PASSWORD_VARIABLES}
    assert seed(custom_env=missing, check=False).returncode != 0
    assert fingerprint() == before
    print('PASS: Production, protected app database, missing credentials and schema overwrite refused.', flush=True)
    print('PASS: independent UUIDs generated; no private inventory, seed or migration touched the main database.', flush=True)
finally:
    if started:
        run([demo.tool('pg_ctl'), '-D', str(work / 'data'), '-m', 'fast', '-w', 'stop'])
    print('Isolated seed artifacts:', work, flush=True)
