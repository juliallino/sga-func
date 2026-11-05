"""Run AES and academic regression without connecting to the main database.
Activate the IHP development shell; set IHP_LIB to the installed IHP resources.
"""
from pathlib import Path
import os,subprocess,sys
root=Path(__file__).resolve().parent.parent
os.chdir(root)
env=dict(os.environ);env.pop('DATABASE_URL',None)
# Prevent the test process from inheriting real field encryption secrets.
for name in ['SGA_FIELD_ENCRYPTION_KEY','SGA_FIELD_ENCRYPTION_KEYS','SGA_FIELD_ENCRYPTION_ACTIVE_KEY_ID']:
 env.pop(name,None)
ihp=Path(env['IHP_LIB'])
config=next(p for p in [ihp/'applicationGhciConfig',ihp/'lib/IHP/applicationGhciConfig'] if p.is_file())
flags=[]
for line in config.read_text().splitlines():
 if line.startswith(':set -X') or line.startswith(':set -W'):flags.extend(line[5:].split())
def run(cmd):subprocess.run(cmd,env=env,check=True,stdin=subprocess.DEVNULL)
run(['build-generated-code'])
run(['ghc','-fno-code','-i.','-ibuild','-iConfig','-outputdir','/tmp/sga-aes-ghc',*flags,'Main.hs'])
run(['runghc','-ignore-dot-ghci','-XBlockArguments','-i.','Test/Main.hs'])
run([sys.executable,'Test/run-crud-tests.py','--skip-migrations'])
