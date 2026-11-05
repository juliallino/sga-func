"""Check the permission-row lock used by grade writes, isolated cluster only."""
import os,subprocess,uuid,selectors
from urllib.parse import urlsplit,parse_qs
url=os.environ.get('DATABASE_URL','');parsed=urlsplit(url);q=parse_qs(parsed.query)
if os.environ.get('SGA_ISOLATED_CRUD_TEST')!='1' or parsed.path!='/sga_crud_test' or not q.get('host',[''])[0].startswith('/tmp/sga-crud-test-'):
    raise SystemExit('Isolated authorization-lock test required')
base=['psql','-XAt',url,'-v','ON_ERROR_STOP=1']
def sql(statement,check=True): return subprocess.run(base+['-c',statement],capture_output=True,text=True,check=check)
course,subject,teacher,permission=[str(uuid.uuid4()) for _ in range(4)]
sql(f"INSERT INTO courses(id,name,code,workload) VALUES ('{course}','Lock fixture','{course}',60); INSERT INTO subjects(id,course_id,name,code,workload) VALUES ('{subject}','{course}','Lock fixture','{subject}',60); INSERT INTO teachers(id,name,email,registration_number) VALUES ('{teacher}','Lock fixture','{teacher}@example.test','{teacher}'); INSERT INTO teacher_subjects(id,teacher_id,subject_id) VALUES ('{permission}','{teacher}','{subject}')")
connection=subprocess.Popen(base,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,bufsize=1)
try:
    connection.stdin.write(f"BEGIN; SELECT id FROM teacher_subjects WHERE teacher_id='{teacher}' AND subject_id='{subject}' FOR SHARE;\n\\echo LOCK_READY\n")
    connection.stdin.flush()
    selector=selectors.DefaultSelector();selector.register(connection.stdout,selectors.EVENT_READ)
    output=b''
    while b'LOCK_READY' not in output:
        if not selector.select(timeout=10): raise RuntimeError('Permission lock test timed out')
        chunk=os.read(connection.stdout.fileno(),4096)
        if not chunk: raise RuntimeError('Lock session ended early')
        output+=chunk
    blocked=sql(f"SET lock_timeout='100ms'; DELETE FROM teacher_subjects WHERE id='{permission}'",check=False)
    assert blocked.returncode!=0 and 'lock timeout' in blocked.stderr
    connection.stdin.write('ROLLBACK;\n\\q\n');connection.stdin.flush();connection.wait(timeout=10)
    sql(f"DELETE FROM teacher_subjects WHERE id='{permission}'")
    assert sql(f"SELECT count(*) FROM teacher_subjects WHERE teacher_id='{teacher}' AND subject_id='{subject}'").stdout.strip()=='0'
    print('PASS: concurrent revocation waits for grade authorization lock; revocation succeeds after transaction ends.')
finally:
    if connection.poll() is None: connection.terminate();connection.wait(timeout=10)
    sql(f"DELETE FROM teacher_subjects WHERE id='{permission}'; DELETE FROM subjects WHERE id='{subject}'; DELETE FROM teachers WHERE id='{teacher}'; DELETE FROM courses WHERE id='{course}'")
