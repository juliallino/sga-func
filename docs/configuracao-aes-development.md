# Configuração AES no Development

Observações administrativas são opcionais e ficam em `students.confidential_note_encrypted`. Admin gerencia o conteúdo pelo detalhe do estudante; Teacher e Student não recebem acesso. A cifra é AES-256-GCM, com nonce aleatório novo por operação e contexto autenticado por registro/campo/chave.

## Segredos persistentes

Configure no ambiente do processo:

- `IHP_ENV=Development`.
- `SGA_FIELD_ENCRYPTION_ACTIVE_KEY_ID`: identificador da chave ativa (ASCII, letras/dígitos/`_`/`-`, 1–64 caracteres).
- `SGA_FIELD_ENCRYPTION_KEYS`: objeto JSON que associa identificadores a chaves de 32 bytes aleatórios codificadas em Base64.

Gere a chave uma única vez usando fonte criptograficamente segura. Preserve-a em armazenamento privado fora do repositório, com diretório `0700` e arquivo `0600`; a configuração local `.env`, ignorada pelo Git, pode carregar esse arquivo sem conter o material criptográfico. O `.envrc` existente carrega `.env` depois do ambiente Nix. Use `direnv exec . bash ./start` para iniciar com a configuração local carregada. Não exiba nem versione valores, não os passe como argumentos e não reutilize a chave de sessão IHP.

No Development desta instalação já existe uma chave provisionada. **Não gerar outra nem sobrescrever a existente** para reiniciar. O processo deve receber os mesmos valores em cada inicialização. A ausência ou inconsistência da configuração impede recuperar observações; ela não deve ser resolvida criando chave nova quando já há conteúdo cifrado.

O esquema `SGAF1.<identificador>.<payload Base64>` inclui versão e ID não secretos. O payload contém versão interna, nonce, tag e ciphertext; a chave fica fora do banco. A aplicação valida o conjunto de chaves e autentica conteúdo/contexto antes de renderizar texto.

## Migração e ativação

A migração aditiva é `Application/Migration/1793923200.sql`; adiciona somente a coluna TEXT nullable, sem default, índice ou FK nova. Sua aplicação ao Development atual foi autorizada e registrada na tabela de migrações. Não reaplicar nem executar outras migrações por inferência desta autorização. Nunca executar o histórico inteiro sobre banco legado ou Production sem revisão.

Em outra instalação, preparar backup e restauração de verificação, conferir o destino e aprovar a migração antes de iniciar modelos regenerados contra o banco. Não copiar chaves ou banco desta instalação para Git. Configurar e implantar código/schema de modo coordenado.

## Rotação e recuperação

Para rotação planejada, adicionar chave com ID novo, manter antigas para leitura e selecionar a nova como ativa para gravação. O serviço não converte registros antigos automaticamente. Conversão em lote, troca/remoção de chaves e migrações de dados precisam de procedimento separado e backup recuperável. Backups do banco e cópias protegidas das chaves devem sobreviver à aplicação e permanecer separados.

## Testes e demonstração

```bash
python3 Test/run-confidential-note-tests.py
python3 Test/run-confidential-note-demo.py
```

Esses comandos usam PostgreSQL temporário, sem modificar o Development principal. O demonstrador cria apenas contas fictícias e pede uma senha de demonstração sem exibi-la. Veja `docs/execucao-aes-isolada.md`. Não use estudantes reais para testar gravação, edição ou remoção de observações.
