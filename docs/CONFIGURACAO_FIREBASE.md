# Configurar o Firebase no Android

Se o projeto Firebase do DueWise já estiver disponível para você, use o ID desse projeto. Para configurar uma instalação independente, crie um projeto no [Firebase Console](https://console.firebase.google.com/).

1. Em **Authentication → Método de login**, habilite **E-mail/senha**. Em **Firestore Database**, crie o banco `(default)` em modo de produção e escolha a região.
2. Com Flutter, Dart e Node.js instalados, prepare as ferramentas e entre com a conta que tem acesso ao projeto.

   ```bash
   npm install -g firebase-tools
   dart pub global activate flutterfire_cli
   firebase login
   firebase projects:list
   ```

3. Na raiz do DueWise, substitua `SEU_PROJECT_ID` pelo ID listado e vincule o aplicativo Android. O comando atualiza `lib/firebase_options.dart`. Confira também `android/app/google-services.json`. Se o arquivo estiver ausente, baixe-o em **Configurações do projeto → Seus aplicativos → Android** e coloque-o em `android/app/`.

   ```bash
   flutter pub get
   dart pub global run flutterfire_cli:flutterfire configure --project=SEU_PROJECT_ID --platforms=android --android-package-name=br.com.gnedochetko.duewise
   ```

4. Publique as regras de acesso do repositório no projeto escolhido. Elas restringem perfil, atividades e disciplinas ao usuário autenticado que criou os registros.

   ```bash
   firebase deploy --only firestore:rules --project SEU_PROJECT_ID
   ```

5. Ative a depuração USB nas opções do desenvolvedor do celular e autorize o computador ao conectar o cabo. Siga os comandos de [execução do aplicativo](../README.md#executar-no-android). Crie uma conta e uma atividade. Confira o usuário em **Authentication** e a atividade em `users/{uid}/activities` no Firestore.
