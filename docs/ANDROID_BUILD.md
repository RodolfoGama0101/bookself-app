# Verificação do build Android

Data: 03/10/2026. REL-01: reprodução atual concluída; diagnóstico da falha histórica inconclusivo. Builds debug locais, sem execução do app, alteração de dados ou publicação.

## Resultado atual

Os dois comandos abaixo passaram com as dependências do `pubspec.lock`:

```sh
flutter build apk --debug --no-pub --dart-define=USE_FIREBASE_EMULATORS=true
flutter build apk --debug --no-pub
```

O primeiro usa Firebase demo no código Dart; o segundo confirma compilação com a configuração padrão preservada. Compilar não executa autenticação nem lê/escreve documentos. Nenhuma mudança de Gradle, IDs, configuração Firebase gerada ou dependências foi necessária para esses resultados.

| Item | Ambiente observado |
| --- | --- |
| Flutter / Dart | 3.44.0 / 3.12.0, revisão em `tool/flutter-sdk.json` |
| Android Gradle Plugin / wrapper | 9.0.1 / Gradle 9.1.0 |
| Google Services plugin / Kotlin declarado | 4.3.15 / 2.3.20 |
| Compilador Java do Android Studio | OpenJDK 25.0.3; bytecode Java/Kotlin configurado para 17 |
| SDK instalado | Plataformas 34, 35, 36 e 37.2; build-tools 36.0.0, 36.1.0 e 37.0.0 |
| Destino | `build/app/outputs/flutter-apk/app-debug.apk`, ignorado pelo Git |

O build demo levou aproximadamente 116 s; o padrão, 13 s com cache. Tempos não são metas de desempenho. SHA-256 observado no APK demo antes do segundo comando: `7863947bc5f68bfd3e93a7ab542122aea2e6ccc131342585551c4b73186649f7`. O comando seguinte substitui o mesmo arquivo; esse hash identifica somente o artefato demo daquela execução.

Após as alterações de catálogo, capas e fontes de API-01/API-05/REL-03, novo `flutter build apk --debug --no-pub --dart-define=USE_FIREBASE_EMULATORS=true` passou na mesma data, aproximadamente 12 s com cache. APK demo observado: SHA-256 `201d86a0a551f7443d4b00ede6a697b55576c9703449b5b399fad81d53e7fa8b`. O catálogo não recebeu define de chave nesse build; não houve instalação/execução. Avisos de KGP/acesso nativo persistem. Esse resultado substitui o artefato local anterior, sem reconstruir novamente a variante padrão nesta rodada.

## Comparação com o log anterior

O `build.log` local registra `:app:compileDebugJavaWithJavac FAILED`, compilação usando outro caminho de JDK e saída 1. O trecho disponível não contém o diagnóstico do compilador nem stacktrace que explique a falha. A compilação atual passou essa etapa; a falha não foi reproduzida.

Não é possível comprovar a causa histórica nem atribuir a solução a uma alteração específica. REL-01 permanece aberta sob seu critério original de causa/solução comprovadas. Não editar artefatos gerados nem mudar dependências apenas para tentar explicar o log. Se reaparecer, capturar stdout e stderr completos com o SDK fixado e registrar o primeiro diagnóstico, por exemplo em PowerShell:

```powershell
flutter build apk --debug --no-pub --verbose *> android-build.local.log
```

Logs são locais/ignorados e precisam de revisão antes de compartilhamento; não incluir credenciais ou dados pessoais. O comando apenas compila. Para executar testes com escritas, usar o modo demo conforme [DEVELOPMENT.md](DEVELOPMENT.md).

## Avisos e limites

- Flutter avisou que `image_picker_android` ainda aplica Kotlin Gradle Plugin; futuras versões exigirão compatibilidade com Kotlin integrado. A configuração atual e os plugins não foram atualizados sem necessidade; revisar esse aviso ao planejar um upgrade.
- Java/Gradle emitiram aviso de acesso nativo restrito. O SDK informou diferença de versões do formato XML; plugins Java emitiram notas de APIs obsoletas/operações unchecked. Esses avisos de build são separados da análise Dart, que permanece limpa.
- `flutter doctor -v` informou situação desconhecida das licenças Android. Os builds debug passaram com os componentes já instalados; nenhuma licença foi aceita automaticamente. Uma máquina nova precisa validar seu próprio SDK/licenças.
- Nenhum dispositivo Android foi iniciado, nenhum APK instalado e nenhuma jornada validada. Câmera, autenticação, conectividade e cache continuam em REL-04/API-05.
- Release ainda usa assinatura debug; não houve build de distribuição, keystore ou publicação. REL-02 continua pendente. Cleartext/permissões existentes não foram alterados e precisam de revisão antes da distribuição.
- iOS depende de ambiente Apple; estes resultados não validam iOS.

Consulte [BACKLOG.md](../BACKLOG.md) para dependências e [decisão de SDK/CI](decisions/004-sdk-e-ci.md) para a reprodução do ambiente.
