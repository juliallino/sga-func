# Demonstração AES isolada — SGA

Esta cópia contém a integração Reader previamente aprovada e a integração AES. Não ativar sobre o Development principal sem autorização separada para a migração.

No ambiente IHP 1.6 do projeto, com IHP_LIB apontando aos recursos instalados:

```bash
python3 Test/run-confidential-note-tests.py
python3 Test/run-confidential-note-demo.py
```

O primeiro comando gera modelos, compila e executa testes em PostgreSQL temporário. Não herda DATABASE_URL nem chaves de campos do ambiente. O segundo abre uma demonstração local em http://127.0.0.1:8107/Login e solicita uma senha fictícia no terminal, sem exibi-la. Usa somente um cluster /tmp/sga-aes-demo-* e três contas fictícias: admin-aes@example.test, teacher-aes@example.test e student-aes@example.test. Não reutiliza contas nem dados reais.

Como Admin: Estudantes → detalhe → Observação confidencial → preencher uma frase fictícia → salvar → editar → remover. Como Teacher/Student: usar diretamente a URL da observação exibida no navegador Admin; deve retornar 403.

A observação só aparece no corpo do textarea da resposta Admin autorizada, com escape HSX. Não aparece em atributos HTML, listagens ou perfis acadêmicos. Mensagens de erro são constantes.

Ctrl+C finaliza servidor e cluster desta demonstração. Para reabrir, usar `python3 Test/run-confidential-note-demo.py --state /tmp/sga-aes-demo-NOME-MOSTRADO`. O arquivo secrets.json nesse diretório restrito conserva a mesma chave e a senha fictícia; não publicar/copiar seu conteúdo nem incluí-lo em pacotes. Não gerar chave nova ao reabrir. Este recurso foi testado com parada e reinício reais.

Para mostrar o banco, conectar apenas ao socket do diretório da demonstração, banco sga_aes_demo, porta 55441. SELECT seguro de metadados:

```sql
SELECT confidential_note_encrypted IS NOT NULL AS possui_observacao,
       left(confidential_note_encrypted, 6) = 'SGAF1.' AS formato_cifrado,
       octet_length(confidential_note_encrypted) AS bytes_armazenados
FROM students WHERE enrollment_number = 'AES-DEMO';
```

Não projetar o envelope completo nem chaves. O teste automatizado também verifica ausência do texto fictício, payload diferente de texto claro, recuperação, edição, remoção, adulteração, chave errada, rotação e guardas em controller/DAL.

Configuração manual persistente: SGA_FIELD_ENCRYPTION_ACTIVE_KEY_ID contém o identificador ativo; SGA_FIELD_ENCRYPTION_KEYS contém JSON de IDs para Base64 de 32 bytes. Provisionar em arquivo/ambiente restrito fora do Git, separado da chave de sessão. Não registrar valores. Para rotacionar, manter chaves antigas no conjunto e mudar o identificador ativo; migração em lote de conteúdo exige autorização separada.

Os comandos deste roteiro não executam migrações, seeds ou testes de escrita no banco principal. Nenhum pacote contém chaves, contas reais, dump do banco ou arquivos .env.
