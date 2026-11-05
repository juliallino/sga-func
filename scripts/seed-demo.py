#!/usr/bin/env python3
"""Prepare a dedicated Development demonstration database. Never target app/Production."""
import argparse
import getpass
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from urllib.parse import parse_qs, urlsplit

ROOT = Path(__file__).resolve().parent.parent
PASSWORD_VARIABLES = ('SGA_DEMO_ADMIN_PASSWORD', 'SGA_DEMO_TEACHER_PASSWORD', 'SGA_DEMO_STUDENT_PASSWORD')


def tool(name):
    path = shutil.which(name) or str(ROOT / '.devenv/profile/bin' / name)
    if not Path(path).is_file():
        raise RuntimeError(f'Ferramenta ausente: {name}; carregue o ambiente IHP/Nix.')
    return path


def resource(name):
    value = os.environ.get('IHP_LIB')
    if not value:
        raise RuntimeError('Carregue o ambiente IHP/Nix (IHP_LIB ausente).')
    ihp = Path(value)
    for folder in (ihp, ihp / 'lib/IHP', ihp.parent, ihp.parent.parent):
        if (folder / name).is_file():
            return folder / name
    raise RuntimeError(f'Recurso IHP ausente: {name}.')


def validate_target(url):
    if os.environ.get('IHP_ENV') != 'Development':
        raise RuntimeError('Defina IHP_ENV=Development; Production e modo implícito são recusados.')
    parsed = urlsplit(url)
    query = parse_qs(parsed.query, keep_blank_values=True)
    database = parsed.path.removeprefix('/')
    host = query.get('host', [''])[0]
    if (parsed.scheme not in ('postgres', 'postgresql') or parsed.hostname or parsed.password
            or parsed.fragment or not re.fullmatch(r'sga_demo(?:_[a-zA-Z0-9_]+)?', database)
            or set(query) - {'host', 'port'} or any(len(v) != 1 for v in query.values())
            or not Path(host).is_absolute() or not Path(host).is_dir()
            or ('port' in query and not re.fullmatch(r'[0-9]{1,5}', query['port'][0]))):
        raise RuntimeError('Use banco sga_demo ou sga_demo_*, socket Unix local e URL sem senha; app é recusado.')
    return parsed, database


def run(command, env, **kwargs):
    # Child output may contain SQL parameters. Do not print it on failure.
    result = subprocess.run(command, env=env, cwd=ROOT, text=True, capture_output=True, **kwargs)
    if result.returncode:
        raise RuntimeError('Etapa falhou: ' + Path(command[0]).name + '; consultas e credenciais omitidas.')
    return result


def connection_url(parsed):
    # urllib.urlunsplit drops the empty authority in PostgreSQL socket URLs.
    return parsed.scheme + '://' + parsed.netloc + parsed.path + ('?' + parsed.query if parsed.query else '')


def initialize(parsed, database, env):
    maintenance = connection_url(parsed._replace(path='/postgres'))
    # createdb fails if the database exists, so schema import can never overwrite it.
    run([tool('createdb'), '--maintenance-db=' + maintenance, database], env)
    run([tool('psql'), '-X', connection_url(parsed), '-v', 'ON_ERROR_STOP=1', '--single-transaction',
         '-f', str(resource('IHPSchema.sql')), '-f', str(ROOT / 'Application/Schema.sql')], env)
    print('Banco novo criado e schema atual importado; nenhuma migração histórica foi executada.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--database-url', required=True)
    parser.add_argument('--confirm', required=True, choices=['development-demo'])
    parser.add_argument('--init-db', action='store_true', help='Create a NEW dedicated database and apply the current schema')
    parser.add_argument('--schema-only', action='store_true', help='With --init-db, prepare schema without running the seed')
    args = parser.parse_args()
    if args.schema_only and not args.init_db:
        parser.error('--schema-only exige --init-db')
    parsed, database = validate_target(args.database_url)
    env = dict(os.environ, DATABASE_URL=args.database_url, IHP_ENV='Development', DEBUG='0', SGA_DEMO_CONFIRM=args.confirm)
    # Do not create even an empty DB if a noninteractive seed lacks credentials.
    if not args.schema_only:
        for name in PASSWORD_VARIABLES:
            value = env.get(name)
            if not value:
                if not sys.stdin.isatty():
                    raise RuntimeError(f'Configure {name} localmente; não há senha padrão.')
                value = getpass.getpass(f'{name} (mínimo 12 caracteres; entrada oculta): ')
            if len(value) < 12:
                raise RuntimeError(f'{name} precisa de pelo menos 12 caracteres.')
            env[name] = value
    if args.init_db:
        initialize(parsed, database, env)
    if args.schema_only:
        return
    # Confirm target identity through a read-only query, before running Haskell.
    identity = run([tool('psql'), '-XAt', args.database_url, '-v', 'ON_ERROR_STOP=1',
                    '-c', 'SELECT current_database(), inet_server_addr() IS NULL'], env).stdout.strip()
    if identity != database + '|t':
        raise RuntimeError('Identidade do banco divergente; seed não executado.')
    flags = []
    for line in resource('applicationGhciConfig').read_text().splitlines():
        if line.startswith(':set -X') or line.startswith(':set -W'):
            flags.extend(line[5:].split())
    run([tool('runghc'), '-ignore-dot-ghci', '-i.', '-ibuild', '-iConfig', *flags,
         'Application/Script/SeedDemo.hs'], env)
    print('Demonstração pronta: 1 Admin, 5 Teacher, 10 Student; 50 matrículas e 120 avaliações iniciais.')
    print('Contas existentes e senhas preservadas. Nenhuma mensagem enviada.')


if __name__ == '__main__':
    try:
        main()
    except RuntimeError as error:
        print('Preparação interrompida: ' + str(error), file=sys.stderr)
        sys.exit(1)
    except (OSError, ValueError):
        print('Preparação interrompida: ferramentas ou configuração inválidas; detalhes omitidos.', file=sys.stderr)
        sys.exit(1)
