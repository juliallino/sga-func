"""Run controller tests on a dedicated temporary PostgreSQL cluster.

Usage, from the project root: python3 Test/run-crud-tests.py
No external database URL is used. The temporary cluster is retained for inspection.
"""
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
os.chdir(root)
bin_dir = root / '.devenv/profile/bin'

def tool(name):
    executable = shutil.which(name)
    if executable:
        return executable
    fallback = bin_dir / name
    if fallback.is_file():
        return str(fallback)
    raise SystemExit(f'Missing {name}: activate the IHP development environment first.')

ihp = os.environ.get('IHP_LIB')
if not ihp:
    for rc in (root / '.direnv').glob('*.rc'):
        match = re.search(r"^IHP_LIB='([^']+)'", rc.read_text(), re.M)
        if match:
            ihp = match.group(1)
            break
if not ihp:
    raise SystemExit('Activate the IHP development environment first.')

work = Path(tempfile.mkdtemp(prefix='sga-crud-test-'))
data = work / 'data'
env = dict(os.environ, PATH=str(bin_dir) + ':' + os.environ['PATH'], IHP_LIB=ihp)
env['DATABASE_URL'] = f'postgresql:///sga_crud_test?host={work}&port=55439'
env['SGA_ISOLATED_CRUD_TEST'] = '1'

def run(args):
    subprocess.run(args, env=env, check=True)

print(f'Isolated test cluster: {work}', flush=True)
run([tool('initdb'), '-D', str(data), '-A', 'trust', '--no-locale', '--encoding=UTF8'])
started = False
try:
    run([tool('pg_ctl'), '-D', str(data), '-l', str(work / 'postgres.log'), '-o', f"-k {work} -p 55439 -h ''", '-w', 'start'])
    started = True
    run([tool('createdb'), '-h', str(work), '-p', '55439', 'sga_crud_test'])
    for sql in [Path(ihp) / 'IHPSchema.sql', root / 'Application/Schema.sql']:
        run([tool('psql'), '-X', env['DATABASE_URL'], '-v', 'ON_ERROR_STOP=1', '-f', str(sql)])
    flags = []
    for line in (Path(ihp) / 'applicationGhciConfig').read_text().splitlines():
        if line.startswith(':set -X') or line.startswith(':set -W'):
            flags.extend(line[5:].split())
    run([tool('runghc'), '-ignore-dot-ghci', '-i.', '-ibuild', '-iConfig', *flags, 'Test/CRUD.hs'])
finally:
    if started:
        run([tool('pg_ctl'), '-D', str(data), '-m', 'fast', '-w', 'stop'])
    print(f'Temporary files retained at: {work}', flush=True)
