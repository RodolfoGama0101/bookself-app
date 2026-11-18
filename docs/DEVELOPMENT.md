# Ambiente de desenvolvimento

## SDK reproduzível

A referência desta branch é Flutter 3.44.0, Dart 3.12.0, canal stable e revisão do framework registrada em `tool/flutter-sdk.json`. Instale o SDK pelas [instruções oficiais do Flutter](https://docs.flutter.dev/get-started/install), selecione a revisão registrada e coloque o diretório `bin` no PATH. Na raiz do projeto, confira e instale as dependências sem atualizar o lockfile:

```sh
dart tool/check_sdk.dart
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub
```

O verificador compara versão, canal e revisão do Flutter acessível pelo PATH. A versão de Node planejada para as ferramentas é registrada em `.node-version`. Não use dados de produção em testes.

## Integração contínua

O workflow `.github/workflows/ci.yml`, adaptado da develop, executa em push, pull request, merge queue e acionamento manual. O job **Flutter — análise e testes** instala a revisão fixada do SDK, confere o lockfile e executa análise, testes, build web demo e testes simulados do bootstrap sem credenciais de produção. Falhas retornam erro no job. A execução no GitHub e a configuração efetiva que impede integração com checks falhando precisam ser verificadas separadamente; a existência do workflow não comprova proteção de branch.

O job separado **Firebase — Auth e Firestore demo** instala as ferramentas pelo lockfile e executa a jornada automatizada nos emuladores do projeto fictício. Usa apenas regras permissivas de ensaio: não valida regras de produção nem concorrência ou isolamento entre usuários. A execução remota deste job e a proteção efetiva da branch precisam ser verificadas. Execução limpa independente, testes de autorização e proteção continuam acompanhados pela [MAIN-01](https://github.com/RodolfoGama0101/bookself-app/issues/90) e pela [QA-05](https://github.com/RodolfoGama0101/bookself-app/issues/75).

## Firebase local de ensaio

O modo demo é opt-in e usa o projeto fictício `demo-bookself`, sem carregar a configuração distribuída do Firebase. Ele requer Node da versão indicada em `.node-version` e Java compatível com o Firebase Emulator Suite. Em um terminal, na raiz:

```sh
cd tool/firebase
npm ci
npm run emulators
```

Em outro terminal, execute o aplicativo:

```sh
flutter run -d chrome --dart-define=USE_FIREBASE_EMULATORS=true
```

O host padrão é `127.0.0.1`, com Auth na porta 9099 e Firestore na 8080. Para o emulador Android use também `--dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2`; no simulador iOS use o padrão. As portas podem ser alteradas por `FIREBASE_AUTH_EMULATOR_PORT` e `FIRESTORE_EMULATOR_PORT`, devendo corresponder à configuração dos emuladores. Apenas hosts locais e portas válidas são aceitos. A inicialização com erro interrompe a abertura dos serviços, sem recorrer ao projeto distribuído.

`firebase.emulators.json` aponta para `tool/firebase/demo.rules`: estas regras de ensaio permitem acesso de qualquer usuário autenticado a todos os documentos. **Não são regras de segurança e não devem ser implantadas**. Use apenas contas e dados fictícios; o ambiente não comprova isolamento, acesso do parceiro ou segurança de produção. Não há persistência do Firestore no modo demo; reiniciar os emuladores sem exportação descarta seus dados.

Para o teste isolado de Auth/Firestore, com os emuladores parados, execute `npm test` em `tool/firebase`; `npm run test:web-bootstrap` verifica a ordem de configuração web sem rede. `BOOKSELF_TEST_AUTH_PORT` e `BOOKSELF_TEST_FIRESTORE_PORT` permitem portas alternativas para o teste, não alteram o aplicativo. A validação no navegador e nos dispositivos deve ser registrada separadamente dos testes automatizados.

Em 18/11/2026, no Windows, a análise ficou limpa, oito testes Flutter e seis testes simulados do bootstrap passaram; o build web demo também passou. Após uma primeira tentativa interrompida durante o download, `npm test` passou com o emulador Firestore 1.21.0 e o projeto `demo-bookself`, usando `BOOKSELF_TEST_AUTH_PORT=19099` e `BOOKSELF_TEST_FIRESTORE_PORT=18080`. O teste integrado cobre cadastro, gravação, saída, negação anônima e novo login; o binário oficial temporário foi conferido pelo tamanho e hash esperados pelo CLI. Cadastro, login e recarga no navegador, assim como Android e iOS, continuam sem validação nesta branch.
