# Configurar o Firebase do DueWise

Este guia conecta o código a um projeto Firebase real. Você fará o login Google no seu próprio navegador; não precisa compartilhar credenciais no chat.

## 1. Conferir o ambiente

Abra o terminal na raiz do DueWise:

```bash
flutter --version
flutter doctor
flutter pub get
```

A base usa Flutter 3.44.8 / Dart 3.12.2 e Android mínimo API 24. A compilação Gradle está limitada a dois workers, com limite de heap de 3 GB para o processo Gradle, para reduzir o consumo de recursos. Resolva os avisos relacionados ao Android antes de executar no celular.

## 2. Criar o projeto

1. Acesse o [Firebase Console](https://console.firebase.google.com/).
2. Escolha criar/adicionar projeto e use o nome **DueWise**.
3. Confira e anote o **ID do projeto**, que pode ser diferente do nome. Nos comandos abaixo, substitua `SEU_PROJECT_ID` por esse ID.
4. Google Analytics pode ficar desativado nesta etapa.
5. Aguarde a criação e abra o painel do projeto.

## 3. Habilitar autenticação

1. Abra **Authentication** e inicie a configuração.
2. Em métodos de login/provedores, selecione **E-mail/senha**.
3. Ative a opção de e-mail e senha e salve. Link de login por e-mail não é necessário.
4. Se configurar uma política de senhas no console, mantenha-a compatível com o mínimo de oito caracteres do aplicativo.
5. Na área de modelos de e-mail, revise o remetente, o nome DueWise e o modelo de redefinição de senha. O app solicita o idioma `pt-BR` ao SDK.

O cadastro cria uma conta no Authentication e o Firebase abre a sessão automaticamente. Recuperação usa o envio de e-mail do próprio Firebase.

## 4. Criar o Firestore

1. Abra **Firestore Database** e crie um banco Cloud Firestore padrão, com ID `(default)`.
2. Se houver escolha de edição, selecione a edição Standard para esta configuração.
3. Escolha a região apropriada para seus usuários.
4. Inicie com regras de produção; publicaremos regras que permitem acesso somente ao proprietário.

O Firestore já será usado para salvar nome, curso e instituição no perfil. O Authentication funciona separadamente, mas o perfil depende deste banco e das regras publicadas.

## 5. Instalar e autenticar as ferramentas

Se o comando `firebase` ainda não existir, instale a CLI seguindo as [instruções oficiais](https://firebase.google.com/docs/cli#install_the_firebase_cli). Com Node.js/npm compatíveis, uma opção é:

```bash
npm install -g firebase-tools
```

Depois:

```bash
firebase login
firebase projects:list
dart pub global activate flutterfire_cli
```

O segundo comando deve listar o projeto criado. Se não listar, confira a conta Google selecionada.

No Linux, caso `flutterfire` não seja encontrado após a instalação:

```bash
export PATH="$PATH:$HOME/.pub-cache/bin"
```

Para deixar o caminho permanente, adicione essa linha ao arquivo de configuração do seu shell. Alternativamente, execute `dart pub global run flutterfire_cli:flutterfire` no lugar de `flutterfire`.

## 6. Vincular o aplicativo Android

Na raiz do DueWise:

```bash
flutterfire configure --project=SEU_PROJECT_ID --platforms=android --android-package-name=br.com.gnedochetko.duewise
```

- Se houver confirmação para substituir `lib/firebase_options.dart`, aceite. O arquivo existente é apenas um ponto de configuração pendente.
- Mantenha somente Android selecionado.
- O identificador Android é **br.com.gnedochetko.duewise**, igual ao `applicationId` do projeto.
- Caso a ferramenta solicite o nome do app Android, use **DueWise Android**.
- Deixe a CLI criar ou selecionar o aplicativo Android correspondente e gerar os arquivos de configuração.

Ao terminar, confira se `lib/firebase_options.dart` contém `FirebaseOptions` reais para Android e não mais o `UnsupportedError` inicial. Se foi gerado `android/app/google-services.json`, mantenha-o no caminho criado.

O código já inicializa o Firebase em `main.dart`; não é necessário reescrever o arquivo nem copiar configurações de outro projeto.

## 7. Publicar as regras do Firestore

O projeto já contém `firebase.json`, `firestore.rules` e `firestore.indexes.json`. Execute:

```bash
firebase deploy --only firestore:rules --project SEU_PROJECT_ID
```

Alternativa: copie todo o conteúdo de `firestore.rules` para a aba **Regras** do Firestore no console e publique.

As regras permitem ler e salvar o próprio perfil em `users/{uid}` e isolam as futuras atividades e disciplinas pelo mesmo UID. Não substitua por uma regra pública de leitura/escrita.

## 8. Executar e testar

Use somente o celular físico para evitar o consumo de recursos de um emulador:

1. No Android, habilite as opções do desenvolvedor (normalmente tocando sete vezes em **Número da versão** nas informações do aparelho).
2. Nas opções do desenvolvedor, ative **Depuração USB**.
3. Conecte o aparelho ao computador com um cabo que permita transferência de dados.
4. Desbloqueie o celular e autorize a chave de depuração do computador quando aparecer a solicitação.
5. Execute os comandos abaixo e use o ID do celular listado. Se aparecer como não autorizado, confira a solicitação na tela do aparelho.

Então:

```bash
flutter devices
flutter run -d ID_DO_DISPOSITIVO
```

Verifique este roteiro:

1. Toque em **Cadastre-se**, preencha nome, e-mail e uma senha com oito ou mais caracteres; repita a senha.
2. Confirme o acesso ao início e a existência da conta em **Authentication → Usuários** no console.
3. Abra **Perfil**, preencha curso e instituição e toque em **Salvar perfil**.
4. Confira o documento `users/{uid}` no Firestore.
5. Feche completamente o aplicativo e abra de novo: a sessão deve continuar aberta.
6. Saia pelo perfil e entre novamente com as credenciais criadas.
7. Experimente senha incorreta e confira a mensagem de erro.
8. Em **Esqueci minha senha**, solicite o e-mail, confira a caixa de entrada/spam, redefina a senha e entre com a nova senha.
9. Crie outra conta e confirme que seu perfil não contém os dados da primeira.

## Resolver problemas

| Sintoma | O que conferir |
| --- | --- |
| Configuração inicial pendente | Execute novamente a etapa 6 e faça uma nova execução do app. |
| Acesso por e-mail indisponível | Ative E-mail/senha na etapa 3. |
| Não carrega ou salva perfil | Confira criação do banco `(default)`, regras publicadas, conexão e projeto selecionado. |
| CLI não encontra o projeto | Confira a conta de `firebase login` e o ID exato. |
| Erro de pacote Android | Use `br.com.gnedochetko.duewise` no Firebase e no Gradle. |
| E-mail de recuperação não chega | Confira endereço, spam e configurações do modelo no console. A mensagem do app não revela se a conta existe. |
| App continua com configuração antiga | Pare a execução e rode `flutter run` novamente; configuração nativa requer recompilação. |

## Arquivos e referências

`firebase_options.dart` contém identificadores de configuração do cliente, não uma chave administrativa. O acesso aos dados é protegido pelas regras. Nunca adicione ao repositório chave de conta de serviço, chave privada ou token de login da CLI.

- [Configuração oficial Flutter/Firebase](https://firebase.google.com/docs/flutter/setup)
- [Autenticação por senha](https://firebase.google.com/docs/auth/flutter/password-auth)
- [Gerenciamento de usuários e redefinição de senha](https://firebase.google.com/docs/auth/flutter/manage-users)
- [Condições das regras do Firestore](https://firebase.google.com/docs/firestore/security/rules-conditions)
