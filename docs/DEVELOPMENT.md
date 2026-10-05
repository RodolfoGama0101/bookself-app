# Desenvolvimento com emuladores

Revisão: 03/10/2026. Ambiente local para Auth/Firestore, separado do projeto distribuído. A implantação de regras é uma etapa distinta; os comandos abaixo não executam deploy.

## Pré-requisitos

- Flutter **3.44.0**, Dart **3.12.0**, canal stable; revisão exata em `tool/flutter-sdk.json`. O mínimo de `pubspec.yaml` continua válido, mas desenvolvimento/CI usam essa versão fixada.
- Node.js >=20 e Java >=21 disponíveis no PATH. Ambiente validado: Node 24.15.0, npm 12.0.2 e Java 25.0.2.
- Dependências Flutter instaladas com `flutter pub get --enforce-lockfile`.
- Internet na primeira instalação das ferramentas npm e download do emulador; a execução posterior usa o cache. Firebase CLI 15.24.0, Firebase JS 12.19.0 e Rules Unit Testing 5.0.2 estão fixados no lockfile.

Não é necessário fazer login no Firebase para os comandos de emuladores. Use contas fictícias e senhas descartáveis. Não importe backup ou credenciais de produção.

## Selecionar o SDK reproduzível

Use o SDK já instalado se `dart tool/check_sdk.dart` confirmar versão, canal e revisão. Para uma instalação separada, clone o SDK oficial em um diretório novo fora deste repositório, sem sobrescrever outro checkout. Exemplo a partir da raiz do app:

```sh
git clone --depth 1 --branch 3.44.0 https://github.com/flutter/flutter.git ../flutter-sdk-3.44.0
git -C ../flutter-sdk-3.44.0 rev-parse HEAD
git -C ../flutter-sdk-3.44.0 checkout -B stable 559ffa3f75e7402d65a8def9c28389a9b2e6fe42
```

A revisão deve ser `559ffa3f75e7402d65a8def9c28389a9b2e6fe42`. Adicione o caminho absoluto de `../flutter-sdk-3.44.0/bin` ao PATH da sessão e, na raiz deste projeto, execute:

```sh
dart tool/check_sdk.dart
flutter pub get --enforce-lockfile
```

O verificador é executado diretamente, sem `dart run`/resolução automática de dependências. SDK divergente encerra com código 1. O SDK fica fora dos arquivos versionados do app; não é obrigatório instalar FVM ou outro gerenciador. Não troque versão nem execute `pub upgrade` como efeito colateral de configurar a máquina. Mudanças intencionais de SDK/dependências exigem revisão dos lockfiles e nova validação. A tag/revisão pública foi conferida com `git ls-remote` em 03/10/2026.

Em 05/10/2026, a [execução no GitHub](https://github.com/RodolfoGama0101/bookself-app/actions/runs/37344069051) confirmou uma falha de seleção do canal: clonar a tag deixa HEAD destacado, e `check_sdk.dart` exige stable. O workflow e o exemplo acima agora criam a branch local stable na revisão já conferida, antes da primeira chamada ao SDK. Não relaxam a verificação nem alteram o commit fixado. O check Firebase dessa execução passou; a [nova execução no commit 6b9c67e](https://github.com/RodolfoGama0101/bookself-app/actions/runs/37344664198) aprovou os dois jobs, incluindo SDK, lockfile, análise, testes Flutter, build web demo e testes Firebase/bootstrap.

Node 24.15.0 fica registrado em `.node-version`. `pubspec.lock` e `tool/firebase/package-lock.json` são versionados; caches, artefatos de build, configurações locais, `node_modules` e arquivos de assinatura permanecem ignorados. Não editar `firebase_options.dart` ou registrantes gerados à mão. A dependência `flutter_localizations` já adicionada em CORE-11 permanece a única alteração anterior no lockfile Flutter; esta revisão não atualizou pacotes.

## Instalar e validar

Na raiz do repositório, em PowerShell, CMD ou outro terminal:

```sh
npm --prefix tool/firebase ci --no-audit --no-fund
npm --prefix tool/firebase test
dart tool/check_sdk.dart
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub
```

`npm test` usa `firebase.emulators.json`, projeto fixo **demo-bookself**, somente Auth/Firestore em `127.0.0.1:9099` e `127.0.0.1:8080`. Firebase usa projetos `demo-` sem recursos reais; serviços não emulados não devem ser usados como alternativa. Os testes também exigem hosts locais e o ID demo recebido do CLI antes de inicializar clientes ou limpar dados. [Documentação oficial dos projetos demo](https://firebase.google.com/docs/emulator-suite/connect_firestore).

Os testes iniciam/encerram os emuladores, carregam `firestore.rules`, usam dados fictícios e limpam somente o Firestore do projeto demo. Verificam sessão Auth real no emulador e autorização/concorrência em Firestore. São separados dos testes Dart com fakes. As negações esperadas não imprimem payloads dos SDKs; falhas de asserção mantêm diagnósticos do teste.

No Windows, o wrapper consulta o runtime Java selecionado e antepõe seu executável real ao PATH somente dos processos deste teste. Isso evita o launcher Oracle `javapath`, que cria outro filho e impede associá-lo diretamente ao CLI para limpeza. Propriedades Java não são impressas. O wrapper verifica se sobrou um Java filho do CLI deste teste, com projeto demo, host local e caminho destas regras, e encerra somente esse processo. Não muda o PATH da máquina nem encerra emuladores iniciados por outro terminal. Falha ou interrupção do CLI retorna código diferente de zero. Portas ocupadas impedem a execução: encerre a sua sessão anterior ou escolha outras portas na configuração e nos clientes; não encerre um processo desconhecido.

Para executar **somente os testes** enquanto outra sessão ocupa as portas padrão, use portas locais livres sem alterar a configuração versionada. Em PowerShell:

```powershell
$env:BOOKSELF_TEST_AUTH_PORT = '19099'
$env:BOOKSELF_TEST_FIRESTORE_PORT = '18080'
try {
  npm --prefix tool/firebase test
} finally {
  Remove-Item Env:BOOKSELF_TEST_AUTH_PORT
  Remove-Item Env:BOOKSELF_TEST_FIRESTORE_PORT
}
```

O runner valida portas entre 1 e 65535, distintas, gera uma configuração temporária com caminhos absolutos das mesmas regras/índices e a remove ao terminar. Hosts continuam `127.0.0.1`, projeto continua `demo-bookself`. Essas variáveis não mudam o destino de uma sessão Flutter ou do comando de emuladores manual. Em 03/10/2026, a porta 8080 estava ocupada por outro processo demo; ele foi preservado. Após corrigir o launcher Java, os 24 testes passaram e as portas 18080/19099 foram confirmadas livres ao final. Portas iguais e fora dos limites também foram rejeitadas antes de iniciar o CLI.

## Integração contínua

`.github/workflows/ci.yml` executa em push, pull request, fila de integração (`merge_group`) e disparo manual, com dois checks de nomes estáveis:

- **Flutter — análise e testes:** SDK oficial fixado/conferido, instalação exigindo lockfile, análise, testes e build web demo.
- **Firebase — regras e concorrência:** Node 24.15.0, Temurin 25.0.2, ferramentas npm pelo lockfile e emuladores Auth/Firestore demo.

Jobs usam Ubuntu 24.04, timeouts e `contents: read`, sem credenciais persistidas no checkout, login Firebase, secrets de produção, deploy, migração ou assinatura. As ações oficiais estão fixadas por SHA: [checkout v6.0.2](https://github.com/actions/checkout/releases/tag/v6.0.2), [setup-node v6.4.0](https://github.com/actions/setup-node/releases/tag/v6.4.0) e [setup-java v5.5.0](https://github.com/actions/setup-java/releases/tag/v5.5.0). Não há filtros por caminho que deixem um check obrigatório permanentemente sem execução.

**QA-05 permanece em andamento:** o YAML foi validado por actionlint 1.7.12 (checksum oficial conferido) e a execução remota foi observada em 05/10/2026 durante a publicação do APK. A falha inicial do canal Flutter foi corrigida no commit `6b9c67e`; a [execução seguinte](https://github.com/RodolfoGama0101/bookself-app/actions/runs/37344664198) aprovou os dois checks. Exigir os dois checks na proteção da branch de integração e comprovar que uma falha impede merge continua pendente. Essa proteção remota não foi alterada. [Documentação oficial de checks obrigatórios](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches#require-status-checks-before-merging).

Comandos dos jobs foram verificados localmente no Windows; isso não comprova execução no runner Ubuntu. Build Android e avisos/limites estão em [ANDROID_BUILD.md](ANDROID_BUILD.md). Registro de alternativas/motivos: [decisões técnicas](decisions/README.md).

## Cobertura de regressões e validação Dart

Revisão de QA-01, BIBLE-02 e QA-04 em 03/10/2026: **244 testes Dart passaram** e `flutter analyze --no-pub` encerrou com código zero, sem apontamentos. Os 47 infos do baseline original foram eliminados incrementalmente; os 37 restantes eram usos de APIs obsoletas. Não foram adicionadas supressões para o app.

Atualização de SEC-03/API-01/API-05/REL-03 na mesma data: **275 testes Flutter e 25 integrações Auth/Firestore passaram**, análise limpa e builds web/Android debug demo aprovados, sem chave de catálogo. As portas alternativas 18080/19099 ficaram livres ao terminar. O login web demo foi inspecionado no navegador integrado e não apresentou erros de console observados; não houve login ou dados enviados. Agent-browser foi bloqueado pela política de Controle de Aplicativo Windows. Capas/CORS, jornada completa, permissões nativas e ambiente Apple permanecem pendentes; a auditoria remota da chave foi rejeitada pela revisão automática, registrada em [CONFIGURATION.md](CONFIGURATION.md).

```sh
flutter analyze --no-pub
flutter test --no-pub
```

| Critério | Evidência na suíte |
| --- | --- |
| Limpar data de conclusão e opcionais sem perder autoria/identidade | `test/book_model_test.dart`, `test/user_model_test.dart`: omissão preserva, `null` explícito limpa, serialização mantém essa diferença e estados de leitura preservam inclusão. |
| Sessão/perfil coerentes durante restauração, ausência, falha e recuperação | `test/auth_service_test.dart`, `test/user_profile_service_test.dart`, `test/session_gate_test.dart`: perfil confirmado, cadastro parcial, conflito de criação e bloqueio de repetição. |
| Logout, troca de conta e descarte isolam resultados anteriores | `test/auth_service_test.dart`, `test/partner_service_test.dart`, `test/bible_screen_test.dart`: cancelamento de streams e retorno antigo sem atualizar a nova sessão. |
| Escrita rejeitada ou pendente não anuncia sucesso | `test/async_ui_test.dart`, `test/bible_service_test.dart`, `test/bible_screen_test.dart`, `test/completion_dates_test.dart`: futures controladas, confirmação atrasada, rejeição, repetição e preservação do estado. |
| Estrutura e limites bíblicos | `test/widget_test.dart`: 39/27 livros, 929/260 capítulos (1.189 no total), ordem, nomes/IDs únicos. `test/bible_service_test.dart`: primeiro/último capítulo dos 66 livros, limites inválidos, identidade/livro inválido, lotes idempotentes e isolamento do parceiro. |
| Compatibilidade das APIs visuais atuais | Regressões existentes de tema, busca, datas, progresso, perfil e detalhes passaram após `withValues(alpha:)` e `initialValue`; paleta, fundos explícitos e seleções foram preservados. |
| Busca paginada e resultados antigos | `test/catalog_pagination_test.dart`, `test/search_pagination_ui_test.dart`: timeout, parâmetros, configuração ausente, itens parciais, quota, paginação/duplicatas/retry, consultas concorrentes e manual em tela pequena. |
| Capas e fontes sem rede | `test/book_cover_test.dart`, `test/bundled_fonts_test.dart`: URL ausente/inválida, HTTPS direto, carregamento/falha com fallback e oito fontes reais empacotadas nos temas; sem mock de fontes no teste específico. |
| Cancelamento e permissão de foto | `test/photo_permissions_test.dart`: câmera/galeria canceladas, negação/restrição, nenhuma escrita prematura, mensagens específicas e reabertura; seletor substituto, não valida permissão nativa. |

Os testes Dart usam fakes e fontes locais; não acessam o projeto remoto. Validação de autorização/concorrência no servidor é separada, pelos emuladores descritos acima. Testes de widgets verificam interação e layouts pequenos/ampliados; execução e inspeção visual em navegador/dispositivo continuam pendentes. Consulte [ARCHITECTURE.md](ARCHITECTURE.md#persistência-do-progresso-bíblico) para os contratos de persistência.

## Abrir o app localmente

Em um terminal:

```sh
npm --prefix tool/firebase run emulators
```

Mantenha esse terminal aberto. Em outro terminal, na raiz:

```sh
flutter run -d chrome --dart-define=USE_FIREBASE_EMULATORS=true
```

O app cria a instância Firebase nomeada `demo-bookself`, com opções fictícias, e conecta Auth e Firestore antes de criar os serviços. Todos os serviços selecionam essa mesma instância. Isso evita reutilizar o Firebase padrão criado pela configuração nativa Android/iOS. O cache persistente do Firestore fica desabilitado nesse modo. Uma falha de configuração/conexão não troca automaticamente para o projeto real.

No web demo, o bootstrap conecta Auth antes de `Firebase.initializeApp` aguardar a sessão persistida. Sem essa antecipação, FlutterFire 6.2.1 podia consultar Auth remoto com as opções fictícias durante a recarga. O helper usa a versão JavaScript suportada por `firebase_core_web`, agora dependência direta sem upgrade. `web/firebase_emulator.js` é carregado antes do Flutter, mas só importa/inicializa SDKs quando o opt-in Dart o chama. Core/Auth/Firestore são os três módulos atuais; ao adicionar outro serviço Firebase ou atualizar os plugins, revise os módulos e as dependências de `initializeAuth` e repita login/recarga/logout no navegador. A conexão precisa ser síncrona após `initializeAuth`, conforme a [referência oficial](https://firebase.google.com/docs/reference/js/auth#connectauthemulator).

Os testes do bootstrap não usam rede ou emuladores e também estão no job Firebase da CI:

```sh
npm --prefix tool/firebase run test:web-bootstrap
```

Seis testes verificam carregamento inerte, rejeição de projeto/URLs remotos e versões incompatíveis, conexão antes da restauração e nova tentativa sem trocar o destino. O runner usa módulos sintéticos do Node, com aviso de API experimental; a jornada Chrome real continua sendo uma verificação separada em [WEB_VALIDATION.md](WEB_VALIDATION.md).

Cadastre duas contas fictícias pela interface; cada cadastro cria seu perfil. O código exibido no perfil ainda é o UID. O vínculo direto atual exige as duas contas livres; convites/aceite são uma evolução pendente. A busca Google Books e as capas continuam externas; o catálogo exige define explícito conforme [CONFIGURATION.md](CONFIGURATION.md). Cadastro manual permite testar as escritas sem catálogo externo. CI/build demo sem define não consultam o Google Books; usar chave junto do modo demo faz chamadas externas. Não use contas reais no emulador.

| Cliente | Host e comando | Limite de validação |
| --- | --- | --- |
| Web no mesmo computador | `127.0.0.1`, comando Chrome acima. | Compilação e configuração verificadas; jornada Flutter no navegador deve ser validada antes da distribuição. |
| Emulador Android | `flutter run -d <id-do-emulador> --dart-define=USE_FIREBASE_EMULATORS=true --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2` | Alias acessa o computador anfitrião. Execução Android não validada nesta entrega. |
| Simulador iOS no Mac | `flutter run -d <id-do-simulador> --dart-define=USE_FIREBASE_EMULATORS=true --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1` | Execute os emuladores Firebase no mesmo Mac. Execução iOS depende de ambiente Apple e permanece pendente. |

Os adaptadores FlutterFire também mapeiam loopback para `10.0.2.2` no Android; informar o alias deixa a intenção explícita. Hosts aceitos: `127.0.0.1`, `localhost` e `10.0.2.2`. Dispositivos físicos via LAN e hosts remotos não estão habilitados. Windows/macOS/Linux como apps Flutter nativos continuam sem configuração de produção e não foram validados.

Para portas alternativas, altere `firebase.emulators.json` e passe também `--dart-define=FIREBASE_AUTH_EMULATOR_PORT=<porta>` e `--dart-define=FIRESTORE_EMULATOR_PORT=<porta>` ao Flutter. Portas devem ser válidas e distintas.

Sem `USE_FIREBASE_EMULATORS=true`, o comportamento anterior permanece: o app usa `lib/firebase_options.dart` e o projeto já distribuído. Reinicie completamente ao trocar o modo; não reutilize hot reload/hot restart para alterar destinos. A preferência de tema continua local ao app, independente do projeto Firebase.

## Dados, regras e diagnóstico

Não há exportação/importação automática. Encerrar/reiniciar os emuladores inicia uma sessão descartável. Não execute `npm test` enquanto estiver usando manualmente os mesmos emuladores: o runner exige suas portas e os testes limpam dados fictícios.

`firebase.json` foi preservado; a configuração isolada fica em `firebase.emulators.json`. Regras locais não foram publicadas. `firestore.indexes.json` tem zero índices compostos, como as consultas atuais exigem; auditoria remota confirmou zero índices/overrides em 03/10/2026. Novas consultas precisam de revisão em DATA-04.

Se o catálogo bíblico mudar, execute `node tool/firebase/generate-rule-catalog.cjs` e revise `firestore.rules`. O gerador atualiza somente nomes/IDs/limites bíblicos e validação de autores; os testes verificam os limites dos 66 livros. Não modifica o banco.

`node_modules/`, logs e dados locais de emuladores são ignorados pelo Git. A análise Dart exclui especificamente `tool/firebase/node_modules/**`, pois o CLI contém templates Dart de outros projetos; código do app e testes continuam analisados sem supressões globais.

Consulte [SECURITY.md](SECURITY.md) para o resultado da auditoria, controles e condições de implantação, e [BACKLOG.md](../BACKLOG.md) para pendências.

Fontes oficiais: [instalação/configuração](https://firebase.google.com/docs/emulator-suite/install_and_configure), [Auth](https://firebase.google.com/docs/emulator-suite/connect_auth), [Firestore](https://firebase.google.com/docs/emulator-suite/connect_firestore), [testes de regras](https://firebase.google.com/docs/rules/emulator-setup).
