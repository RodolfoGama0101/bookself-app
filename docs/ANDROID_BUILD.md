# Verificação do build Android

## MusicBrainz local — API-04 / MUSIC-01 — 14/10/2026

No AVD Android API 34 já instalado, `integration_test/musicbrainz_demo_test.dart`
aprovou uma jornada em **23 s**: conta fictícia, busca pública pelo intermediário
local, seleção/detalhes e salvamento de faixa e álbum pela interface, releitura
confirmada no Firestore demo. Tipo/MBID/artistas/edição preservados, sem capa,
favorito ou escuta automática. Primeiro ensaio ajustou a rolagem do teste;
repetição passou sem intervenção. Build/instalação debug aprovados, sem mudanças
de SDK, permissões, identidade técnica ou dependências.

[Comandos e limites](MUSIC.md#musicbrainz-local--14102026). Log ignorado em
`build/validation/android-2026-10-14/musicbrainz-api34.log`. Nenhum dado real,
regra remota, migração ou publicação alterado. Web/iOS, offline e hospedagem
pública continuam pendentes; API-04/MUSIC-01 seguem em andamento no Linear.

## Execução no Pixel 9 — CORE-14 / REL-04 — 14/10/2026

Utilizados Flutter 3.44.0/Dart 3.12.0 na revisão fixada, SDK Android e AVD **Pixel_9** já instalados. Dispositivo `emulator-5554`, imagem x86_64 Android API 37 com páginas de 16 KB. Nenhum SDK, imagem ou AVD novo foi instalado. Auth/Firestore locais em 9099/8080, projeto fictício `demo-bookself`; sem chave de catálogo.

Reprodução em dois terminais na raiz, preservando outras sessões e conferindo portas livres:

```sh
npm --prefix tool/firebase run emulators
```

```sh
flutter emulators --launch Pixel_9
flutter run -d emulator-5554 --no-pub --dart-define=USE_FIREBASE_EMULATORS=true --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2
```

Confirme o ID por `flutter devices`, pois ele pode variar. Use somente contas fictícias. Mantenha o terminal Firebase aberto durante o uso; encerre com Ctrl+C quando terminar. Os dados demo são descartáveis. `d` no terminal Flutter desconecta o depurador mantendo o app aberto; `q` encerra o app. Encerre o Pixel 9 pela própria janela quando não precisar dele. Não execute testes que limpem esse mesmo ambiente enquanto estiver usando o app.

**Falha reproduzida e corrigida em CORE-14:** a tela de cadastro criou a conta Auth local, mas a gravação de perfil falhou. A primeira chamada nativa `clearPersistence` materializava as configurações padrão de host/SSL antes de `useFirestoreEmulator`; o SDK tentava o endpoint remoto do projeto fictício e recebia `PERMISSION_DENIED`. A configuração do destino foi antecipada para antes da limpeza. Persistência continua desabilitada e a limpeza continua anterior aos serviços; modo padrão e regras preservados. A implementação instalada de FlutterFire usa `late final pigeonApp`, confirmando que a primeira operação captura as configurações.

Após reinstalar o debug corrigido, a conta fictícia foi restaurada, o formulário de conclusão salvou o perfil e o Início abriu com estatísticas vazias. Encerramento completo e reabertura também restauraram o Início autenticado. Capturas locais em `build/validation/android-2026-10-14/`, ignoradas pelo Git, registram login, falha anterior e Início. Formatação aprovada, análise sem apontamentos e **506 testes Flutter aprovados após a correção**. Build debug instalado com sucesso. Avisos preexistentes de Java/Kotlin, SDK XML e opt-out Impeller continuam; não foram ocultados.

REL-04/QA-03 continuam abertos: este ensaio não cobre bibliotecas completas, casal/desvínculo, imagens/rede/offline, permissões, TalkBack, desempenho release ou iOS. Nenhuma migração, implantação de regras/índices, assinatura definitiva ou publicação foi realizada. A versão instalada no Pixel 9 é debug demo; não equivale ao APK remoto de distribuição.

## Jornada pessoal automatizada — QA-03 / REL-04 — 14/10/2026

`integration_test/android_demo_test.dart` executado no mesmo Pixel 9/API 37, usando os serviços Auth/Firestore demo já iniciados. **Uma jornada nativa aprovada em 29 s**, após compilação/instalação. Criou sua própria conta fictícia e confirmou pelo servidor:

- cadastro com perfil completo;
- livro manual sem capa/API e mudança de Quero Ler para Lendo;
- filme manual e marcação Assistido;
- faixa manual, favorito e escuta pessoal com data;
- série manual, episódio disponível marcado e pausa conservando o visto;
- capítulo 1 de Gênesis marcado independentemente das bibliotecas.

A jornada usa a interface para escrever e clientes Firebase nativos autenticados para conferir persistência. Foi ajustada às abas de leitura e aos gestos da rolagem aninhada; falhas iniciais de seletores/rolagem eram do teste e não foram tratadas como defeitos do produto. **506 testes Flutter existentes aprovados** com a nova dependência de desenvolvimento `integration_test`, sem atualizar pacotes existentes. [Comando, proteção contra produção e retorno ao app manual](DEVELOPMENT.md#jornada-automatizada-android--qa-03).

Na execução pessoal inicial, álbum e casal Android ainda estavam pendentes; o avanço seguinte está registrado abaixo. Catálogo real, rede/offline/imagens, leitores de tela, outras configurações Android e iOS continuam pendentes. Não comprova restauração após reinício por mídia nem autoriza distribuição. QA-03/REL-04 permanecem em andamento.

## Jornada de duas contas — QA-03 / REL-04 — 14/10/2026

A mesma integração foi ampliada e executada no AVD existente **CodexRemindersApi34**, Android API 34/x86_64, 1.080 × 2.400, densidade 420. A primeira execução completa passou em **3 min 36 s**, incluindo uma intervenção para trazer a atividade ao primeiro plano: o launcher estava ativo enquanto o teste aguardava frames. **Repetição final aprovada em 1 min 38 s, sem intervenção durante a jornada**, com boot completo confirmado antes de iniciar. `wait-for-device` sozinho não comprova boot completo; o roteiro agora exige `sys.boot_completed = 1` e atividade em primeiro plano. A automação espera o fim de animações/carregamentos e conserva uma proteção para não fechar a rota raiz. Formatação e análise final sem apontamentos; os 506 testes Flutter existentes passaram após adicionar a dependência do SDK, antes da ampliação exclusiva do teste nativo.

Além da jornada pessoal acima, foram verificados pela interface e pelo servidor local:

- criação do convite por A, consulta e aceite explícito por B;
- consulta de livros compartilhados negada antes do vínculo e permitida durante ele; perfil privado de A negado mesmo com vínculo;
- álbum manual e favorito pessoal de B;
- lista criada por B, seleção de álbum e proposta manual de uma sessão de filme;
- entrada de A, consulta da lista e confirmação da revisão, com duas respostas válidas no servidor;
- biblioteca/favoritos musicais de B negados a A;
- desvínculo pela interface de A; filme, faixa e episódio pessoal de A preservados;
- nova entrada de B: consulta compartilhada de A revogada, álbum/favorito próprios e histórico conjunto preservados.

Não foram criadas contas ou vínculos por seed administrativo. Leituras usam `Source.server`; o teste exige `permission-denied` nas negações, não aceita um erro genérico de rede como prova de isolamento. Sem valores de credenciais, códigos de convite ou identificadores de contas nas evidências versionadas. Os documentos já existentes no ambiente demo não foram apagados.

A jornada ampliada no Pixel 9/API 37 foi interrompida durante transições e não recebeu resultado integral. A causa dessas interrupções não foi comprovada; não atribuir uma correção de produto à troca de emulador ou aos ajustes da automação. A aprovação pessoal anterior no Pixel 9 permanece limitada àquele escopo. Comparação de episódios/sessão episódica, correção/reconfirmação concorrente por mídia, novo parceiro, rede/offline/imagens, TalkBack e iOS continuam fora desta execução nativa; QA-03/REL-04 continuam abertos. Nenhuma implantação, migração ou publicação.

## Assinatura de distribuição — REL-02 — 09/10/2026

O build `release` agora usa configuração própria e falha sem os quatro campos
locais; não há fallback para debug. O alias `androiddebugkey` também é recusado.
Debug continua independente de credenciais. Verificado neste host: build debug
aprovado; release sem configuração recusada antes da compilação, com mensagem
em português. Nenhuma chave de distribuição foi criada e nenhum APK publicado.
REL-02 permanece em andamento até um build com a chave definitiva e conferência
do certificado. REL-01 mantém seu diagnóstico histórico inconclusivo.

1. Crie ou recupere a chave de distribuição sob responsabilidade do mantenedor,
   seguindo a [documentação Android de assinatura](https://developer.android.com/studio/publish/app-signing).
   Mantenha a keystore fora do checkout, em armazenamento privado com backup
   criptografado independente e acesso restrito. Não reutilize a chave debug.
2. Copie `android/key.properties.example` para `android/key.properties`, ignorado
   pelo Git. Preencha `storeFile` (caminho absoluto com `/`), `storePassword`,
   `keyAlias` e `keyPassword` somente no arquivo local. Não passe senhas na linha
   de comando nem imprima esse arquivo em logs. Em `.properties`, caracteres
   especiais seguem o escape de Java Properties, inclusive barras invertidas.
3. Execute `flutter build apk --release --no-pub` ou
   `flutter build appbundle --release --no-pub`. Confira APK com
   `apksigner verify --verbose --print-certs <apk>` e compare o certificado com
   o inventário privado do mantenedor. Um alias diferente sozinho não comprova
   que o certificado é de distribuição: a conferência continua obrigatória.
4. Registre no inventário privado o certificado público, alias, responsável,
   localização dos backups e procedimento de restauração. Guarde as senhas em
   gerenciador de segredos separado; ensaie recuperação antes da distribuição.
   Se usar Play App Signing, diferencie chave de upload e chave de assinatura.

APKs de testes anteriores usaram certificado debug. Uma assinatura nova pode
impedir atualização direta desses APKs: não oriente desinstalação sem verificar
sincronização/recuperação dos dados. IDs Android/Firebase foram preservados.
Publicação, cadastro em loja e custódia definitiva da chave são etapas separadas.
Arquivos `.jks`, `.keystore` e configuração local são ignorados pelo Git.

## APK 1.3.0+4 para testes — 09/10/2026

APK com o redesign de UI-06, gerado a pedido do usuário por `flutter build apk --release --no-pub` em aproximadamente 124 s. SDK fixado e dependências existentes; sem defines de catálogo, emuladores ou funcionalidades experimentais. Firebase e identidade técnica preservados; nenhuma implantação remota.

| Verificação | Resultado |
| --- | --- |
| Pacote / versão | `com.couple.bookself.bookself_app`, `versionName` 1.3.0, `versionCode` 4 |
| Android / arquiteturas | Mínimo API 24; alvo API 36; `armeabi-v7a`, `arm64-v8a`, `x86_64` |
| Assinatura | `apksigner verify --verbose --print-certs` aprovado, esquema v2; Android Debug existente |
| Certificado SHA-256 | `700cd9b4af4e88360159c03b5177464c6dcc6fc271dc8851e8823b1074c4ea36` (igual a 1.1.0/1.2.0) |
| APK universal | `bookself-app-1.3.0.apk`, 60.424.028 bytes, aproximadamente 57,6 MiB |
| APK SHA-256 | `27bf0f83478ea2bbe02867f2975e2264a2c6e387cfb9f2b3befbcbf45d17f5cb` |

APK e `.sha256` em `build/release/`, ignorados pelo Git. `aapt dump badging` confirmou os metadados; verificação de assinatura com `java` funcional do host. Avisos existentes de KGP/Java/formato XML do SDK persistem, sem impedir o build. Lockfile sem mudança de conteúdo. Redesign já validado com análise limpa, 430 testes Flutter, build web demo e inspeção integrada em navegador. Nenhuma alteração Dart adicional nesta preparação.

A [pré-release v1.3.0](https://github.com/RodolfoGama0101/bookself-app/releases/tag/v1.3.0) foi publicada em 09/10/2026 às 14:23:32 UTC; tag no commit `a1ec225`, enviado à `develop`. Consulta pública confirmou publicação, estado de pré-release e ambos os assets. APK e checksum baixados de volta correspondem ao original; digest remoto também confere. [CI remoto](https://github.com/RodolfoGama0101/bookself-app/actions/runs/37943746070) em execução no momento desta conferência. Sem merge em `main`, loja, migração ou deploy Firebase. [Notas e limites](releases/v1.3.0.md). APK padrão sem filmes/novo espaço de listas/experiências/interesses habilitados; sem segredo de catálogo. Nenhum dispositivo Android executado; REL-02/REL-04/SEC-03/SEC-06 permanecem pendentes.

## APK 1.2.0+3 para testes — 08/10/2026

A pedido do usuário, `pubspec.yaml` passou a 1.2.0+3. `flutter build apk --release --no-pub` aprovado em aproximadamente 93 s com o SDK fixado e dependências existentes, sem defines de catálogo/emuladores/ativação experimental. Firebase padrão e identidade técnica preservados; nenhuma configuração/regra remota alterada. O lockfile não teve mudança de conteúdo.

| Verificação | Resultado |
| --- | --- |
| Pacote / versão | `com.couple.bookself.bookself_app`, `versionName` 1.2.0, `versionCode` 3 |
| Android / arquiteturas | Mínimo API 24; alvo API 36; `armeabi-v7a`, `arm64-v8a`, `x86_64` |
| Assinatura | `apksigner verify --verbose --print-certs` aprovado, esquema v2; Android Debug existente |
| Certificado SHA-256 | `700cd9b4af4e88360159c03b5177464c6dcc6fc271dc8851e8823b1074c4ea36` (igual a 1.1.0) |
| APK universal | `bookself-app-1.2.0.apk`, 60.292.840 bytes, aproximadamente 57,5 MiB |
| APK SHA-256 | `adf9b7c31a3087b04cb2e3ad9a12787d84087b05c4d26e10644cd3bd51a26b93` |

APK e checksum em `build/release/`, ignorados pelo Git. Avisos existentes de KGP, Java nativo e formato XML do SDK persistem; não impediram o build. `aapt dump badging` confirmou os metadados. A verificação de assinatura usou o runtime funcional selecionado pelo `java` do host: o launcher direto do JBR do Android Studio falhou ao abrir `jvm.cfg`; isso não foi atribuído ao código do aplicativo.

O APK padrão mantém filmes e o novo espaço de listas/experiências/interesses desativados: dependem de flags e regras/índices de SEC-06. Não inclui segredo de catálogo. A entrega de código foi validada com 426 testes Flutter, 86 Node/demo, análise limpa e build web; 37 testes pertinentes passaram novamente após os últimos ajustes. Nenhum dispositivo Android executado; REL-02/REL-04/SEC-03/SEC-06 permanecem pendentes. [Notas desta pré-release](releases/v1.2.0.md).

A [pré-release v1.2.0](https://github.com/RodolfoGama0101/bookself-app/releases/tag/v1.2.0) foi publicada em 08/10/2026 às 19:28:50 UTC, tag no commit `b7a97b9`, enviado à `develop`. Consulta pública confirmou estado publicado/pré-release e os dois assets. APK e `.sha256` baixados de volta foram comparados ao original, com hashes idênticos; digest remoto do APK também corresponde. O [CI remoto](https://github.com/RodolfoGama0101/bookself-app/actions/runs/37832214507) foi disparado; no momento da verificação estava em execução. Não houve merge em `main`, loja, migração ou deploy Firebase.

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

## APK 1.1.0+2 para testes — 05/10/2026

A pedido do usuário, a versão foi atualizada no commit `7b4595c` e compilada com:

```sh
flutter build apk --release --no-pub
```

Build aprovado em aproximadamente 116 s, com Flutter/Dart fixados e o lockfile atual. Sem define Google Books ou emuladores: usa o Firebase padrão preservado e cadastro manual; não inclui a chave local de catálogo. Compilar não executou o app nem alterou dados/regras remotos. Nenhuma keystore ou senha foi criada ou copiada para o repositório.

| Verificação | Resultado |
| --- | --- |
| Pacote / versão | `com.couple.bookself.bookself_app`, `versionName` 1.1.0, `versionCode` 2 |
| Android / arquiteturas | Mínimo API 24; alvo API 36; `armeabi-v7a`, `arm64-v8a`, `x86_64` |
| Assinatura | `apksigner verify --verbose --print-certs` aprovado, esquema v2; certificado Android Debug já existente |
| Certificado SHA-256 | `700cd9b4af4e88360159c03b5177464c6dcc6fc271dc8851e8823b1074c4ea36` |
| APK universal | `bookself-app-1.1.0.apk`, 58.276.508 bytes, aproximadamente 55,6 MiB |
| APK SHA-256 | `b66a46820bd26468535b7075852aa0f1afa54ac64d3a5ee51bbbab4ba9f2fcd9` |
| Análise / regressões | `flutter analyze --no-pub` limpo; 283 testes Flutter e seis testes Node do bootstrap web passaram |

O arquivo gerado e sua cópia para upload estão em `build/`, ignorados; o `.sha256` acompanha o APK como asset da release GitHub. `.gitignore` também exclui o cache gerado `android/.kotlin/`. Logs locais permanecem ignorados. Notas em [releases/v1.1.0.md](releases/v1.1.0.md).

Esta publicação é uma **pré-release para testes**, compilada em modo release com assinatura debug. REL-02 permanece aberta para assinatura de distribuição e recuperação da chave. Avisos de KGP, acesso nativo Java, formato XML do SDK e APIs Java obsoletas/unchecked persistem. O APK não foi instalado ou executado em dispositivo; REL-04 e a implantação adiada SEC-06 continuam pendentes. Não houve nova marca, categorias, migração, loja ou deploy Firebase.

A [pré-release v1.1.0](https://github.com/RodolfoGama0101/bookself-app/releases/tag/v1.1.0) foi publicada em 05/10/2026 às 16:53:43 UTC, com tag no commit `2d92c23` (mesmo código do build, com documentação acrescentada). Código enviado à `develop`; `main` preservada. O APK e seu checksum foram baixados de volta do GitHub e comparados ao arquivo local; SHA-256 idêntico e digest remoto conferido. Consulta pública confirmou release publicada, classificada como pré-release, com os dois assets e URLs definitivos. O APK permanece fora do histórico Git.
