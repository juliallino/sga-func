"""Run controller tests on a dedicated temporary PostgreSQL cluster.

Usage, from the project root: python3 Test/run-crud-tests.py
No external database URL is used. The temporary cluster is retained for inspection.
"""
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
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

# IHP 1.6 distributions may put the GHCi config under lib/IHP while
# IHPSchema.sql lives at the data root. Resolve both without a /tmp shim.
ihp_root = Path(ihp)
resource_roots = [ihp_root, ihp_root / 'lib/IHP', ihp_root.parent, ihp_root.parent.parent]
def resource(name):
    for candidate in resource_roots:
        if (candidate / name).is_file():
            return candidate / name
    raise SystemExit(f'Missing {name} under IHP_LIB={ihp}; activate the IHP environment.')

ihp_schema = resource('IHPSchema.sql')
ihp_ghci = resource('applicationGhciConfig')
# The migration checker reads IHPSchema.sql from the data root.
ihp = str(ihp_schema.parent)

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
    for sql in [ihp_schema, root / 'Application/Schema.sql']:
        run([tool('psql'), '-X', env['DATABASE_URL'], '-v', 'ON_ERROR_STOP=1', '-f', str(sql)])
    run([sys.executable, str(root / 'Test/check-migrations.py')])
    flags = []
    for line in ihp_ghci.read_text().splitlines():
        if line.startswith(':set -X') or line.startswith(':set -W'):
            flags.extend(line[5:].split())
    for suite in ['Test/Integration.hs', 'Test/CRUD.hs', 'Test/Auth.hs']:
        run([tool('runghc'), '-ignore-dot-ghci', '-i.', '-ibuild', '-iConfig', *flags, suite])
finally:
    if started:
        run([tool('pg_ctl'), '-D', str(data), '-m', 'fast', '-w', 'stop'])
    print(f'Temporary files retained at: {work}', flush=True)
