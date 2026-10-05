# Câmera, galeria e validação iOS

REL-03 em andamento em 03/10/2026. O projeto mantém nome, bundle identifier, configuração Firebase e deployment target iOS 13.0. Não houve build Apple neste ambiente Windows, sem Xcode/simulador/dispositivo iOS; o item permanece aberto.

## Ajustes locais

`ios/Runner/Info.plist` declara em português:

- `NSCameraUsageDescription`: uso da câmera para foto de perfil.
- `NSPhotoLibraryUsageDescription`: escolha de foto de perfil na biblioteca.

Não há captura de vídeo/áudio nem escrita na galeria nesse fluxo. `pickImage` usa `requestFullMetadata: false`, pois o avatar não precisa de metadados completos, e preserva limite 200 × 200/qualidade 75. O seletor da plataforma decide o acesso efetivamente exigido; a descrição de biblioteca cobre também o caminho legado no deployment target atual. Referência do plugin: [Image Picker](https://pub.dev/packages/image_picker).

Cancelamento retorna sem persistir ou anunciar sucesso. Negação/restrição de câmera/fotos recebe mensagem específica e libera uma nova tentativa. Não são registrados imagem, caminho local, mensagem bruta nem metadados pessoais. A escrita do avatar continua em Base64 no documento do próprio perfil; esta tarefa não migra armazenamento.

## Verificação realizada e pendente

O XML foi lido localmente sem resolver DTD externo; ambas as descrições existem e não estão vazias. Oito regressões de widgets simulam cancelamento de câmera/galeria, negação, negação sem novo prompt e acesso restrito: nenhuma escrita ocorre, erro bruto não aparece e o seletor pode ser reaberto. As regressões anteriores continuam cobrindo confirmação da escrita, falha e retorno após descarte. São testes do cliente com seletor substituto, sem comprovar permissões nativas.

Em macOS com Xcode e SDK registrado em `tool/flutter-sdk.json`:

```sh
dart tool/check_sdk.dart
flutter pub get --enforce-lockfile
flutter build ios --simulator --debug --no-pub --dart-define=USE_FIREBASE_EMULATORS=true
flutter run --dart-define=USE_FIREBASE_EMULATORS=true
```

Auth/Firestore devem usar emuladores isolados conforme [DEVELOPMENT.md](DEVELOPMENT.md); em dispositivo físico, configure host alcançável da máquina de desenvolvimento. Use contas e imagens fictícias. Não use produção para os testes.

| Cenário Apple | Evidência necessária | Estado |
| --- | --- | --- |
| Build simulador debug | Versões macOS/Xcode/SDK, comando, saída/código de término. | Pendente em ambiente Apple. |
| Galeria: escolher/cancelar/limitar/negar | Texto de solicitação, avatar anterior preservado no cancelamento/negação, confirmação após escrita. | Pendente no seletor nativo. |
| Câmera: permitir/negar/negar novamente/restringir/cancelar | Mensagem útil sem travar, sem escrita prematura; uso real em dispositivo físico. | Pendente; simulador não comprova câmera. |
| Retorno após sair da tela | Sem uso de contexto descartado ou anúncio de sucesso. | Coberto por fakes; validação nativa pendente. |
| Capas/fonts offline | Cards/detalhes com fallback e tipografia empacotada, sem rede. | Testes locais passam; execução iOS pendente em API-05. |

Registrar resultados reais aqui ao executar, inclusive falhas e correções necessárias. Build debug não comprova assinatura, distribuição ou publicação. A configuração de entrega continua nas tarefas REL-02/REL-04/REL-06.
