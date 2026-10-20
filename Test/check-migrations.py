"""Check additive migrations only, inside run-crud-tests.py's isolated cluster."""
import os
from pathlib import Path
import subprocess
from urllib.parse import parse_qs, urlsplit

root = Path(__file__).resolve().parent.parent
url = urlsplit(os.environ.get('DATABASE_URL', ''))
query = parse_qs(url.query)
host = query.get('host', [''])[0]
port = query.get('port', [''])[0]
if (os.environ.get('SGA_ISOLATED_CRUD_TEST') != '1'
        or url.path != '/sga_crud_test'
        or not host.startswith('/tmp/sga-crud-test-') or port != '55439'):
    raise SystemExit('Refusing non-isolated migration test database')

schema_url = os.environ['DATABASE_URL']
migration_url = f'postgresql:///sga_migration_test?{url.query}'
env = dict(os.environ, DATABASE_URL=migration_url, MINIMUM_REVISION='1792029677')

def run(args, **kwargs):
    return subprocess.run(args, env=env, text=True, check=True, **kwargs)

def sql(statement, database=migration_url):
    return run(['psql', '-X', database, '-v', 'ON_ERROR_STOP=1', '-Atc', statement],
               capture_output=True).stdout.strip()

def load(path):
    run(['psql', '-X', migration_url, '-v', 'ON_ERROR_STOP=1', '-f', str(path)],
        capture_output=True)

run(['createdb', '-h', host, '-p', port, 'sga_migration_test'])
load(Path(os.environ['IHP_LIB']) / 'IHPSchema.sql')
load(root / 'Test/Fixtures/PrePortalSchema.sql')
sql("""
    INSERT INTO students (id,name,email,enrollment_number)
    VALUES ('00000000-0000-0000-0000-000000000101','Legado teste','legacy@example.test','LEGACY-001');
    INSERT INTO courses (id,name,code,workload)
    VALUES ('00000000-0000-0000-0000-000000000102','Curso legado teste','LEGACY',60);
    INSERT INTO enrollments (id,student_id,course_id,enrollment_date,status)
    VALUES ('00000000-0000-0000-0000-000000000103','00000000-0000-0000-0000-000000000101',
        '00000000-0000-0000-0000-000000000102','2020-02-03','suspended');
    INSERT INTO grades (id,enrollment_id,assessment_name,score,weight)
    VALUES ('00000000-0000-0000-0000-000000000104','00000000-0000-0000-0000-000000000103','P1',8,2);
""")
fingerprint = """
    SELECT 'students',md5(jsonb_agg(to_jsonb(t)-'user_id' ORDER BY id)::text) FROM students t
    UNION ALL SELECT 'courses',md5(jsonb_agg(to_jsonb(t) ORDER BY id)::text) FROM courses t
    UNION ALL SELECT 'enrollments',md5(jsonb_agg(to_jsonb(t) ORDER BY id)::text) FROM enrollments t
    UNION ALL SELECT 'grades',md5(jsonb_agg(to_jsonb(t) ORDER BY id)::text) FROM grades t;
"""
before = sql(fingerprint)
run(['migrate'], capture_output=True)
if sql(fingerprint) != before:
    raise SystemExit('Migration changed pre-existing IDs, values or relationships')
expected = ','.join(p.name.split('.')[0] for p in sorted((root / 'Application/Migration').glob('*.sql'))
                    if p.stem.isdigit() and int(p.stem) > 1792029677)
if sql("SELECT string_agg(revision::text,',' ORDER BY revision) FROM schema_migrations") != expected:
    raise SystemExit('Unexpected revisions applied')

# Compare schema-created and migration-created objects, ignoring column order
# (ADD COLUMN naturally appends user_id) and IHP's revision tracking table.
metadata = """
    SELECT table_name,column_name,data_type,udt_name,is_nullable,COALESCE(column_default,''),numeric_precision,numeric_scale
    FROM information_schema.columns WHERE table_schema='public'
      AND table_name <> 'schema_migrations' ORDER BY table_name,column_name;
"""
constraints = """
    SELECT conrelid::regclass::text,conname,pg_get_constraintdef(oid),convalidated
    FROM pg_constraint WHERE connamespace='public'::regnamespace
      AND conrelid <> 'schema_migrations'::regclass ORDER BY 1,2;
"""
if sql(metadata) != sql(metadata, schema_url):
    raise SystemExit('Schema and migrated columns differ')
# to_regclass avoids requiring a tracking table in a schema-created database.
constraints = constraints.replace("conrelid <> 'schema_migrations'::regclass",
                                   "conrelid::regclass::text <> 'schema_migrations'")
if sql(constraints) != sql(constraints, schema_url):
    raise SystemExit('Schema and migrated constraints differ')
enums = "SELECT typname,enumlabel,enumsortorder FROM pg_enum JOIN pg_type ON pg_type.oid=enumtypid WHERE typnamespace='public'::regnamespace ORDER BY typname,enumsortorder"
indexes = "SELECT tablename,indexname,indexdef FROM pg_indexes WHERE schemaname='public' AND tablename <> 'schema_migrations' ORDER BY 1,2"
if sql(enums) != sql(enums, schema_url):
    raise SystemExit('Schema and migrated enums differ')
if sql(indexes) != sql(indexes, schema_url):
    raise SystemExit('Schema and migrated indexes differ')
run(['migrate'], capture_output=True)
if sql(fingerprint) != before:
    raise SystemExit('Second migration execution changed data')
print('Migrations: IDs, values, dates, status and grade links preserved; schema parity confirmed; second execution is a no-op.', flush=True)
print('Migration test database retained inside isolated cluster: sga_migration_test', flush=True)
