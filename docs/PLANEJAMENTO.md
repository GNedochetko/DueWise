# Planejamento do DueWise

## Decisões confirmadas

- Depuração exclusivamente em celular Android físico por USB; não iniciar emuladores.
- Aplicativo exclusivamente Android, em português do Brasil, com datas brasileiras e relógio de 24 horas.
- Visual sério e profissional; tema apenas claro; azul principal e superfícies claras.
- Cantos discretamente arredondados, espaço entre elementos e ícones vinculados a ações concretas.
- Sem slogans, ilustrações decorativas espalhadas, sombras fortes ou detalhes excessivos.
- Monge barbudo no ícone de instalação e na abertura; DW estilizado na marca interna.
- Início com resumo de hoje, próximos prazos e atrasadas.
- Barra inferior com Início, Calendário e Perfil.
- Disciplinas terão cadastro próprio com nome e cor.
- Tipos de atividade: prova, trabalho, apresentação, evento e visita técnica.
- Prioridades: baixa, média e alta; média como valor inicial proposto.
- Situação: pendente ou concluída; atraso calculado pela data e horário.
- Cadastro com nome completo, e-mail, senha e confirmação. Curso e instituição são opcionais no perfil.
- Firebase Authentication realiza o cadastro e login e mantém a sessão no Android. Após criar a conta, a sessão autenticada abre a área principal. Não há bloqueio adicional por verificação de e-mail nesta etapa.
- Senha do cadastro com pelo menos oito caracteres. No login, aceitar a senha existente e deixar o Firebase validar as credenciais.

## Primeira etapa

1. Estruturar aplicativo, tema, marca e navegação.
2. Implementar login, cadastro, recuperação, sessão e logout.
3. Disponibilizar perfil acadêmico editável no Firestore.
4. Preparar modelos de domínio para o CRUD.
5. Documentar criação do projeto Firebase, regras e execução.
6. Verificar análise estática, testes de interface e geração de APK.

A primeira etapa não implementa o CRUD das atividades nem a sincronização offline. As telas iniciais não contêm atividades de demonstração.

## Dados planejados

### Disciplina

`id`, `userId`, `name`, `color`.

### Atividade

`id`, `userId`, `title`, `disciplineId`, `type`, `description`, `dueAt`, `priority`, `completed`, `location`, `latitude`, `longitude`, `createdAt`, `updatedAt`.

`dueAt` representa o momento da prova, evento ou entrega. O armazenamento deverá normalizar instantes e a apresentação usar horário local. Os modelos desta etapa ainda não definem serialização SQLite/Firestore.

### Perfil

Documento `users/{uid}`: `name`, `email`, `course`, `institution`, `updatedAt`.
O nome inicial vem do Firebase Authentication; depois de salvar o perfil, o documento Firestore fornece o nome apresentado no aplicativo. O e-mail é sempre obtido da conta autenticada, sem campo de edição.

Coleções futuras: `users/{uid}/disciplines/{id}` e `users/{uid}/activities/{id}`.

## Próximas etapas

1. CRUD de disciplinas e atividades com SQLite e persistência após reabertura.
2. Firestore de atividades e fila de sincronização, identificadores estáveis, reenvio e exclusões pendentes.
3. Ligar resumo e calendário aos registros persistidos.
4. GPS associado aos registros e persistência das coordenadas.
5. Foto de perfil local e consulta de CEP para endereços, como proposta inicial ainda ajustável.
6. Testes integrados, documentação final, APK e preparação da defesa.

## Decisão a esclarecer sobre offline

O enunciado pede limpeza dos registros SQLite após confirmação do envio. Planejar a fila de operações pendentes com essa regra e esclarecer com o professor a expectativa de acesso offline ao histórico sincronizado antes de adicionar um cache permanente. A exclusão offline de registros remotos exige uma operação pendente de exclusão; somente apagar a linha local não basta.

## Escolhas técnicas

- Interface e formulários com widgets Flutter, `setState` e `StreamBuilder`.
- Interfaces de repositório permitem testar sem conta Firebase; a execução normal injeta serviços Firebase reais.
- Serviços sem conhecimento de widgets e widgets sem chamadas diretas ao Firebase.
- `AuthGate` mantém a área interna acessível apenas com usuário autenticado.
- O estado de sessão vem do SDK Firebase, sem gravar senha no dispositivo.
- Perfil salvo em caminho por UID; as regras verificam o proprietário e os campos permitidos.
- Bibliotecas de SQLite, GPS e imagens serão adicionadas quando as funcionalidades forem implementadas.
