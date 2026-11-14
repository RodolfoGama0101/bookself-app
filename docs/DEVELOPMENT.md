# Ambiente de desenvolvimento

## SDK reproduzível

A referência desta branch é Flutter 3.44.0, Dart 3.12.0, canal stable e revisão do framework registrada em `tool/flutter-sdk.json`. Instale o SDK pelas [instruções oficiais do Flutter](https://docs.flutter.dev/get-started/install), selecione a revisão registrada e coloque o diretório `bin` no PATH. Na raiz do projeto, confira e instale as dependências sem atualizar o lockfile:

```sh
dart tool/check_sdk.dart
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub
```

O verificador compara versão, canal e revisão do Flutter acessível pelo PATH. A versão de Node planejada para as ferramentas é registrada em `.node-version`; esta branch ainda não contém a configuração de emuladores nem o CI da develop. Não use dados de produção em testes. A análise da main possui apontamentos informativos preexistentes, descritos no README.

Esta etapa prepara o SDK; execução limpa independente, emuladores, CI e proteção de branch continuam acompanhados pela [MAIN-01](https://github.com/RodolfoGama0101/bookself-app/issues/90).
