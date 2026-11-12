# DueWise

- Aplicativo Flutter exclusivamente Android, em português do Brasil.
- Não iniciar emuladores ou AVDs: o usuário informou que travam seu computador. A depuração deve ocorrer em celular físico por USB.
- Identidade visual séria e discreta: tema somente claro, azul principal, superfícies claras, sem slogans ou decoração excessiva.
- Usar o monge no ícone/splash e o monograma DW nas telas internas.
- Manter a separação entre telas, modelos, contratos de repositório e serviços Firebase.
- Autenticação de produção deve usar Firebase Authentication; implementações simuladas são exclusivas dos testes.
- Consultar docs/PLANEJAMENTO.md para o escopo e docs/CONFIGURACAO_FIREBASE.md para a configuração.
- Repositório de destino: https://github.com/GNedochetko/DueWise.git, branch main.
- Verificações: flutter analyze, flutter test e, quando houver alteração nativa ou necessidade de validar integração, flutter build apk --debug.
