"""Validate only the additive AES migration, on the runner's isolated cluster."""
import os,subprocess
from pathlib import Path
from urllib.parse import urlsplit,parse_qs
root=Path(__file__).resolve().parent.parent
url=urlsplit(os.environ.get('DATABASE_URL',''));q=parse_qs(url.query)
host=q.get('host',[''])[0];port=q.get('port',[''])[0]
if os.environ.get('SGA_ISOLATED_CRUD_TEST')!='1' or url.path!='/sga_crud_test' or not host.startswith('/tmp/sga-crud-test-') or port!='55439':
 raise SystemExit('Isolated migration database required')
target='postgresql:///sga_note_migration?'+url.query
base=['psql','-XAt',target,'-v','ON_ERROR_STOP=1']
def sql(statement):
 return subprocess.check_output(base+['-c',statement],text=True).strip()
subprocess.run(['createdb','-h',host,'-p',port,'sga_note_migration'],check=True)
subprocess.run(base+['-f',str(Path(os.environ['IHP_LIB'])/'IHPSchema.sql')],check=True,stdout=subprocess.DEVNULL)
schema=(root/'Application/Schema.sql').read_text().replace('    confidential_note_encrypted TEXT,\n','')
subprocess.run(base,input=schema,text=True,check=True,stdout=subprocess.DEVNULL)
sql("INSERT INTO students(name,email,enrollment_number) VALUES ('Fixture migração AES','aes-migration@example.test','AES-MIGRATION')")
tables=['students','users','teachers','courses','subjects','teacher_subjects','enrollments','grades']
statement="SELECT md5(string_agg(v,'|' ORDER BY v)) FROM ("+' UNION ALL '.join("SELECT '"+t+":'||(to_jsonb(t)-'confidential_note_encrypted')::text v FROM "+t+' t' for t in tables)+') x'
before=sql(statement)
subprocess.run(base+['--single-transaction','-f',str(root/'Application/Migration/1793923200.sql')],check=True,stdout=subprocess.DEVNULL)
assert sql(statement)==before
assert sql("SELECT count(*) FROM students WHERE confidential_note_encrypted IS NULL")=='1'
assert sql("SELECT is_nullable||':'||data_type||':'||COALESCE(column_default,'none') FROM information_schema.columns WHERE table_name='students' AND column_name='confidential_note_encrypted'")=='YES:text:none'
print('PASS: AES migration is additive; all existing columns/rows preserved; new TEXT column nullable, no default.')
