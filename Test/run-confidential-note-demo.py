"""Interactive local demonstration. All records and secrets stay under /tmp.
Requires the IHP development shell. Ctrl+C stops only this demonstration cluster.
Use --state /tmp/sga-aes-demo-... to reopen its records with the same saved keys.
"""
import argparse,base64,getpass,json,os,secrets,subprocess,tempfile
from pathlib import Path
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--state',type=Path)
args=parser.parse_args()
root=Path(__file__).resolve().parent.parent
os.chdir(root)
state=args.state or Path(tempfile.mkdtemp(prefix='sga-aes-demo-'))
state=state.resolve()
if not str(state).startswith('/tmp/sga-aes-demo-') or state.parent!=Path('/tmp'):
 raise SystemExit('Only a dedicated /tmp/sga-aes-demo-* state directory is permitted')
if not state.is_dir() or state.stat().st_uid!=os.getuid() or state.stat().st_mode & 0o077:
 raise SystemExit('State directory must belong to the current user and be mode 0700')
env=dict(os.environ);env.pop('DATABASE_URL',None)
for name in ['SGA_FIELD_ENCRYPTION_KEY','SGA_FIELD_ENCRYPTION_KEYS','SGA_FIELD_ENCRYPTION_ACTIVE_KEY_ID']:
 env.pop(name,None)
config_path=state/'secrets.json'
new=not (state/'data').exists()
if new:
 if config_path.exists():raise SystemExit('Partial state detected; inspect it instead of replacing its keys')
 password=getpass.getpass('Escolha uma senha fictícia para as três contas de demonstração (mínimo 8 caracteres): ')
 if len(password)<8:raise SystemExit('Senha curta')
 config={'password':password,'keys':{'demo1':base64.b64encode(secrets.token_bytes(32)).decode()}}
 with os.fdopen(os.open(config_path,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600),'w') as f:json.dump(config,f)
else:
 if not config_path.is_file() or config_path.stat().st_mode & 0o077:raise SystemExit('Restricted persistent configuration required')
 config=json.loads(config_path.read_text())
env.update(SGA_FIELD_ENCRYPTION_ACTIVE_KEY_ID='demo1',SGA_FIELD_ENCRYPTION_KEYS=json.dumps(config['keys']),SGA_AES_DEMO_PASSWORD=config['password'],IHP_ENV='Development',DEBUG='0')
env['DATABASE_URL']=f'postgresql:///sga_aes_demo?host={state}&port=55441'
ihp=Path(env['IHP_LIB'])
flags=[]
path=next(p for p in [ihp/'applicationGhciConfig',ihp/'lib/IHP/applicationGhciConfig'] if p.is_file())
for line in path.read_text().splitlines():
 if line.startswith(':set -X') or line.startswith(':set -W'):flags.extend(line[5:].split())
def run(cmd,**kw):return subprocess.run(cmd,env=env,check=True,**kw)
started=False
try:
 if new:run(['initdb','-D',str(state/'data'),'-A','trust','--no-locale','--encoding=UTF8'],stdout=subprocess.DEVNULL)
 run(['pg_ctl','-D',str(state/'data'),'-l',str(state/'postgres.log'),'-o',f"-k {state} -p 55441 -h ''",'-w','start'],stdout=subprocess.DEVNULL);started=True
 if new:
  run(['createdb','-h',str(state),'-p','55441','sga_aes_demo'])
  schema=next(p for p in [ihp/'IHPSchema.sql',ihp.parent/'IHPSchema.sql'] if p.is_file())
  for path in [schema,root/'Application/Schema.sql']:
   run(['psql','-X',env['DATABASE_URL'],'-v','ON_ERROR_STOP=1','-f',str(path)],stdout=subprocess.DEVNULL)
 print('Estado isolado:',state,flush=True)
 print('Contas fictícias: admin-aes@example.test, teacher-aes@example.test, student-aes@example.test',flush=True)
 print('A senha escolhida não será exibida. Para reabrir: --state',state,flush=True)
 run(['runghc','-ignore-dot-ghci','-i.','-ibuild','-iConfig',*flags,'Test/ConfidentialNoteDemo.hs'])
except KeyboardInterrupt:pass
finally:
 if started:run(['pg_ctl','-D',str(state/'data'),'-m','fast','-w','stop'],stdout=subprocess.DEVNULL)
