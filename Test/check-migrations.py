"""Verify the subject migration after the existing IHP 1.6 baseline, isolated only."""
import os,subprocess
from pathlib import Path
from urllib.parse import urlsplit,parse_qs
root=Path(__file__).resolve().parent.parent
url=urlsplit(os.environ.get('DATABASE_URL',''));query=parse_qs(url.query)
host=query.get('host',[''])[0];port=query.get('port',[''])[0]
if os.environ.get('SGA_ISOLATED_CRUD_TEST')!='1' or url.path!='/sga_crud_test' or not host.startswith('/tmp/sga-crud-test-') or port!='55439':
    raise SystemExit('Refusing a non-isolated migration database')
fresh_url=os.environ['DATABASE_URL'];migration_url=f'postgresql:///sga_migration_test?{url.query}'
env=dict(os.environ,DATABASE_URL=migration_url,MINIMUM_REVISION='1792459225')
def run(args,check=True): return subprocess.run(args,env=env,text=True,check=check,capture_output=True)
def sql(statement,target=migration_url): return run(['psql','-XAt',target,'-v','ON_ERROR_STOP=1','-c',statement]).stdout.strip()
run(['createdb','-h',host,'-p',port,'sga_migration_test'])
for path in [Path(os.environ['IHP_LIB'])/'IHPSchema.sql',root/'Test/Fixtures/PreSubjectSchema.sql']:
    run(['psql','-X',migration_url,'-v','ON_ERROR_STOP=1','-f',str(path)])
sql("INSERT INTO students(id,name,email,enrollment_number) VALUES ('00000000-0000-0000-0000-000000000101','Fixture legado','legacy-migration@example.test','LEGACY-M'); INSERT INTO courses(id,name,code,workload) VALUES ('00000000-0000-0000-0000-000000000102','Curso fixture','LEGACY-M',60); INSERT INTO enrollments(id,student_id,course_id) VALUES ('00000000-0000-0000-0000-000000000103','00000000-0000-0000-0000-000000000101','00000000-0000-0000-0000-000000000102'); INSERT INTO grades(id,enrollment_id,assessment_name,score,weight) VALUES ('00000000-0000-0000-0000-000000000104','00000000-0000-0000-0000-000000000103','Fixture',8,2)")
before=sql("SELECT md5(jsonb_agg(to_jsonb(t))::text) FROM enrollments t")
refused=run(['migrate'],check=False)
assert refused.returncode!=0,'Migration must refuse nonempty legacy enrollments'
assert sql("SELECT md5(jsonb_agg(to_jsonb(t))::text) FROM enrollments t")==before
assert sql('SELECT count(*) FROM grades')=='1'
# Explicit fixture IDs only; this is a disposable test, not the live cleanup.
sql("DELETE FROM grades WHERE id='00000000-0000-0000-0000-000000000104'; DELETE FROM enrollments WHERE id='00000000-0000-0000-0000-000000000103'")
course_before=sql("SELECT md5(jsonb_agg(to_jsonb(t))::text) FROM courses t")
run(['migrate'])
assert sql("SELECT md5(jsonb_agg(to_jsonb(t))::text) FROM courses t")==course_before
assert sql("SELECT string_agg(revision::text,',' ORDER BY revision) FROM schema_migrations")=='1793548800,1793923200'
metadata="SELECT table_name,column_name,data_type,udt_name,is_nullable,COALESCE(column_default,'') FROM information_schema.columns WHERE table_schema='public' AND table_name<>'schema_migrations' ORDER BY table_name,column_name"
constraints="SELECT conrelid::regclass::text,conname,pg_get_constraintdef(oid),convalidated FROM pg_constraint WHERE connamespace='public'::regnamespace AND conrelid::regclass::text<>'schema_migrations' ORDER BY 1,2"
indexes="SELECT tablename,indexname,indexdef FROM pg_indexes WHERE schemaname='public' AND tablename<>'schema_migrations' ORDER BY 1,2"
for check in [metadata,constraints,indexes]:
    assert sql(check)==sql(check,fresh_url),'Fresh and migrated schemas differ'
run(['migrate'])
assert sql("SELECT md5(jsonb_agg(to_jsonb(t))::text) FROM courses t")==course_before
print('PASS: legacy rows refused without mutation; new migration after baseline; fresh/migrated schema parity; second run no-op.')
