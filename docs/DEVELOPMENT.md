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

O workflow `.github/workflows/ci.yml`, adaptado da develop, executa em push, pull request, merge queue e acionamento manual. O job **Flutter — análise e testes** instala a revisão fixada do SDK, confere o lockfile e executa análise e testes sem credenciais de produção. Falhas retornam erro no job. A execução no GitHub e a configuração efetiva que impede integração com checks falhando precisam ser verificadas separadamente; a existência do workflow não comprova proteção de branch.

Esta branch ainda não contém os emuladores nem o job de regras da develop. Execução limpa independente, testes de Auth/Firestore e proteção de branch continuam acompanhados pela [MAIN-01](https://github.com/RodolfoGama0101/bookself-app/issues/90) e pela [QA-05](https://github.com/RodolfoGama0101/bookself-app/issues/75).
