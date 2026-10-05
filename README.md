# Bookself App

Aplicativo de organização de leituras para uso individual e em casal, desenvolvido em Flutter com Firebase. Cada pessoa mantém sua estante, acompanha capítulos bíblicos lidos e pode consultar a estante e o progresso do parceiro vinculado.

O produto está em fase de MVP. A evolução planejada inclui filmes, séries e músicas. **Entrelace** é a proposta inicial de novo nome; a escolha e a aplicação da marca ainda estão pendentes. O aplicativo continua se chamando Bookself App no código.

## Documentação

| Arquivo | Conteúdo |
| --- | --- |
| [BACKLOG.md](BACKLOG.md) | Fonte central de tarefas, prioridades, dependências e critérios de conclusão. |
| [AGENTS.md](AGENTS.md) | Orientações para trabalhar neste repositório. |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Arquitetura atual, limitações e proposta de evolução. |
| [docs/WEB_VALIDATION.md](docs/WEB_VALIDATION.md) | Jornada Flutter web em ambiente demo, evidências e cenários pendentes. |
| [docs/PRODUCT.md](docs/PRODUCT.md) | Expansão, experiência do casal e nomes candidatos. |
| [docs/INTEGRATIONS.md](docs/INTEGRATIONS.md) | Integrações atuais e candidatas, com fontes oficiais. |
| [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) | Configuração isolada de Auth/Firestore, comandos e clientes por plataforma. |
| [docs/SECURITY.md](docs/SECURITY.md) | Auditoria remota, regras candidatas, concorrência de vínculo e implantação pendente. |
| [docs/decisions/README.md](docs/decisions/README.md) | Alternativas, escolhas técnicas implementadas e pendências. |
| [docs/ANDROID_BUILD.md](docs/ANDROID_BUILD.md) | Builds Android atuais, log histórico e limites de distribuição. |
| [docs/CONFIGURATION.md](docs/CONFIGURATION.md) | Inventário sem valores, configuração Google Books por ambiente e auditoria pendente. |
| [docs/IOS_VALIDATION.md](docs/IOS_VALIDATION.md) | Permissões de foto e verificação Apple ainda pendente. |

## Funcionalidades implementadas

- Cadastro, login, recuperação de senha e saída com Firebase Authentication.
- Login e cadastro preservam a senha digitada, inclusive espaços; a validação local exige pelo menos seis caracteres nos dois formulários.
- Erros de autenticação, dados e rede têm mensagens em português; diagnósticos do app registram somente operação, categoria e códigos permitidos.
- Restauração de sessão com estados de carregamento/erro e conclusão de perfil após cadastro parcial, preservando perfis existentes.
- Busca paginada de livros no Google Books, com timeout, tratamento de resposta parcial e descarte de buscas antigas; referência do catálogo preservada em registros novos. Cadastro manual disponível sem chave ou rede.
- Fontes Outfit/Playfair Display empacotadas para carregamento sem rede; capas em HTTPS com fallback, sem proxy externo.
- Estante com os estados “Quero Ler”, “Lendo” e “Lido”, data de conclusão e histórico por mês e ano.
- Limpeza da data de conclusão ao mudar um livro de “Lido” para “Lendo” ou “Quero Ler”.
- Livros lidos sem data aparecem em uma seção própria da estante, inclusive na consulta do parceiro. O dono pode informar ou corrigir a conclusão nos detalhes sem trocar o status; novas datas vão até hoje, em português e formato dia/mês/ano.
- Vínculo de duas contas por código, consulta da estante do parceiro e feed de atividades recentes de livros. O cliente aguarda o lote, bloqueia ações repetidas e não consulta o perfil do destinatário antes de vincular. Validação de concorrência/reciprocidade está pronta nas regras locais e precisa ser implantada no servidor. O Início atualiza feed e estatísticas automaticamente pelo stream; não oferece gesto de atualização manual.
- Acompanhamento de capítulos lidos nos 66 livros da Bíblia, com comparação do progresso do casal. Marcação individual/em lote aguarda confirmação, bloqueia ações repetidas e permite nova tentativa após falha.
- Edição de nome e foto de perfil; escolha de tema Claro, Escuro ou Sistema, salva localmente e restaurada ao abrir o app.
- Fechamento seguro de busca, perfil, detalhes e diálogos durante requisições, com resultado de exclusão na estante.

A seção da Bíblia registra progresso: **não contém textos ou versículos para leitura**. Filmes, séries e músicas ainda não estão implementados. O vínculo atual é direto por código, sem etapa de aceite.

Sem preferência salva, o tema inicial continua escuro. “Sistema” acompanha o brilho do dispositivo; Claro/Escuro explícitos permanecem fixos. A preferência é do app no dispositivo/navegador, vale também no login e permanece após logout; outros dispositivos têm escolhas independentes. Limpar os dados locais remove a preferência. A tela de carregamento da inicialização mantém a aparência escura; a interface principal abre após a leitura da escolha salva.

## Tecnologias e plataformas

Flutter/Dart, localização do SDK Flutter, Provider, Firebase Core, Firebase Authentication, Cloud Firestore, HTTP, Google Fonts, Image Picker, Intl e Shared Preferences. Os requisitos declarados em `pubspec.yaml` são Flutter `>=3.44.0` e Dart `^3.12.0`.

Há projetos para Android, iOS e web, com opções Firebase para essas plataformas. Isso não significa que todas tenham sido validadas em execução. Windows, macOS e Linux não possuem configuração Firebase nesta versão.

## Configuração e execução

1. Selecione Flutter 3.44.0/Dart 3.12.0, na revisão registrada em `tool/flutter-sdk.json`. Instalação e conferência do SDK estão em [DEVELOPMENT.md](docs/DEVELOPMENT.md#selecionar-o-sdk-reproduzível).
2. Na raiz do repositório, instale as dependências:

   ```sh
   dart tool/check_sdk.dart
   flutter pub get --enforce-lockfile
   ```

3. Configure um ambiente Firebase de desenvolvimento com Authentication por e-mail/senha e Firestore. O repositório já possui configuração de um projeto Firebase; confirme o ambiente antes de usá-la. Para apontar para outro projeto, use o FlutterFire CLI:

   ```sh
   flutterfire configure
   ```

   O Firebase é necessário ao fluxo atual. Durante a inicialização, o app mostra carregamento; se ela falhar, mostra uma tela com “Tentar novamente”. Os serviços de autenticação e dados só ficam disponíveis após a inicialização válida. Isso não oferece um modo funcional sem Firebase nem comprova conectividade/autorização dos serviços remotos. Regras candidatas e emuladores estão versionados; a auditoria de 03/10/2026 confirmou que as regras remotas permitem leitura/escrita de qualquer documento para qualquer conta autenticada. A proteção nova foi validada localmente e **ainda não foi implantada**. Consulte [autorização](docs/SECURITY.md) antes de distribuir o app.

4. Para busca de livros, copie `config/google-books.example.json` para `config/google-books.local.json`, preencha a chave de desenvolvimento e passe `--dart-define-from-file=config/google-books.local.json` ao executar/compilar. O arquivo local é ignorado pelo Git; sem define, o cadastro manual permanece disponível e a busca informa indisponibilidade. A revisão real de restrições/quotas ainda está pendente em SEC-03; consulte [CONFIGURATION.md](docs/CONFIGURATION.md).
5. Com um emulador ou dispositivo disponível:

   ```sh
   flutter run
   ```

   Para web:

   ```sh
   flutter run -d chrome
   ```

## Validação

Em **05/10/2026**, a jornada Flutter web foi executada no navegador integrado com duas contas fictícias em Auth/Firestore demo: cadastro/perfil, livro manual sem capa, status/data, progresso bíblico, vínculo/consulta e desvínculo com dados pessoais preservados. A busca sem chave teve sua mensagem repetida corrigida; análise limpa, 275 testes Flutter e build web demo passaram. Restauração automática após recarga, rede/offline, capas externas e plataformas nativas continuam pendentes. O [registro web](docs/WEB_VALIDATION.md) atualiza o limite da jornada emulada nas evidências anteriores, sem validar produção ou concluir toda a matriz de release.

Para desenvolver com dados isolados, siga [DEVELOPMENT.md](docs/DEVELOPMENT.md). O modo `--dart-define=USE_FIREBASE_EMULATORS=true` usa uma instância nomeada do projeto `demo-bookself`, com Auth/Firestore locais, antes da criação dos serviços; o modo padrão mantém a configuração distribuída. Não há fallback automático do emulador para o banco remoto.

```sh
flutter analyze --no-pub
flutter test --no-pub
```

Na validação de **03/10/2026**, 275 testes Dart passaram: sete sobre dados bíblicos, cinco sobre inicialização, 13 sobre sessão/ciclo de vida, cinco sobre persistência de perfil, cinco sobre as telas de sessão/recuperação, 14 sobre modelos de livro/usuário, 28 sobre operações assíncronas da interface, 37 sobre persistência/interface do progresso bíblico, 16 sobre senhas no login/cadastro, 52 sobre tradução de erros, diagnósticos e fluxos afetados, 31 sobre persistência/interface do tema, dois sobre atualização automática do Início, 14 sobre datas de conclusão, quatro sobre configuração demo e 11 sobre serviço de vínculo/sessão. Outras 31 regressões cobrem catálogo paginado, concorrência de busca, referência externa, capas, fontes reais offline e permissões de foto. A matriz de critérios de QA-01 está em [DEVELOPMENT.md](docs/DEVELOPMENT.md#cobertura-de-regressões-e-validação-dart).

Separadamente, **25 testes de integração passaram nos emuladores Auth/Firestore** usando contas fictícias: cadastro/login/logout e perfil, autorização de dono/parceiro/terceiro, queries, autoria/campos, preservação de dados legados, capítulos válidos dos 66 livros, vínculos simultâneos e desvínculo antigo, revogação de acesso ao ex-parceiro e isolamento de novo parceiro. Comando: `npm --prefix tool/firebase test`, após `npm --prefix tool/firebase ci --no-audit --no-fund`. Os testes usam apenas `demo-bookself`; não alteram produção.

As regressões de conclusão verificam entrada pt-BR, rejeição de datas futuras/formato inválido, datas anteriores a 2000, visibilidade dos livros sem data nas duas estantes, cadastro manual/catálogo, edição sem mudar status/data de inclusão, confirmação da escrita, falha/nova tentativa, cancelamento e descarte. Detalhes e seletor foram verificados em 320 × 480 com texto 2×. Datas futuras já existentes são preservadas; ao corrigi-las, o seletor inicia em hoje. Livros sem data não recebem uma data presumida nem entram nas contagens mensais/anuais. Testes usam serviços substitutos, sem banco remoto; execução real em navegador/dispositivo permanece pendente.

Os testes do Início usam um stream substituto e verificam inclusões, remoções, mudanças de status e contagens mensais/anuais pessoais e do parceiro. Arrastar o conteúdo vazio não mostra indicador de atualização nem cria nova consulta; descartar a tela cancela a assinatura. A entrega real de eventos pelo Firestore e o gesto em dispositivo permanecem pendentes de validação.

Os testes de tema usam armazenamento substituto: verificam recriação do serviço/árvore, restauração antes do primeiro login, padrão escuro, Sistema reagindo ao brilho, logout, confirmação de escrita, falhas/nova tentativa, concorrência, timeout e descarte. O controle no perfil foi verificado em 320 × 480 com texto 2×. Persistência no armazenamento nativo e reabertura real do navegador/dispositivo permanecem pendentes de validação.

As regressões de erros verificam códigos conhecidos/desconhecidos, ausência de mensagem/stack/dados pessoais nos textos e diagnósticos, autenticação, recuperação de perfil, vínculo/desvínculo, HTTP simulado e feedback na interface. A busca distingue limite de uso e indisponibilidade, mantendo cadastro manual; o resumo bíblico pessoal/do parceiro oculta erros brutos e a saída da conta trata falhas mesmo durante o descarte da tela.

As regressões de senha verificam o valor recebido pelo SDK substituto, incluindo espaços iniciais, finais, internos e o limite de seis caracteres; também cobrem validação, correção do formulário e mostrar/ocultar senha. Credenciais são fictícias; isso não valida a política remota de senhas nem autenticação real.

Os testes Dart usam inicializadores controlados e fakes, sem acessar o Firebase remoto. As regressões verificam fechamento de busca/perfil/detalhes durante sucesso ou falha, descarte de diálogos por cancelar/barreira/voltar, retorno de seletores de data após fechamento, ausência de sucesso antes da escrita e feedback de exclusão após retirar o cartão do stream. A cobertura bíblica verifica marcar/desmarcar, bloqueio de operações repetidas, rejeição/indisponibilidade, confirmação atrasada, conflito simulado, falha longe do topo em Salmos e tratamento de falha em 320 × 480 com texto 2×. As fontes nesses testes são substituídas por uma fonte já empacotada pelo Flutter, sem rede; não validam tipografia. Cobrem carregamento, erros, limites de espera, recuperação de cadastro parcial, preservação de perfil existente, descarte/logout/troca de conta, limpeza de campos opcionais e layout em tela pequena com texto ampliado e teclado. A repetição da transação bíblica por conflito é simulada; a concorrência de vínculo e as regras foram verificadas separadamente nos emuladores.

A análise estática está **limpa**, com código de saída zero. Os 47 infos do baseline inicial foram eliminados incrementalmente: logs brutos e `activeColor` nas correções anteriores; QA-04 removeu os 37 restantes usando `withValues(alpha:)`, `initialValue` e retirando `ColorScheme.background` obsoleto, preservando `surface` e os fundos explícitos do app. Não foram adicionadas supressões globais.

O serviço bíblico valida nome, proprietário, capítulo e total do lote antes de escrever. A cobertura de BIBLE-02 verifica 39 livros/929 capítulos no Antigo Testamento e 27 livros/260 capítulos no Novo (1.189 capítulos), IDs únicos, limites e marcação/desmarcação idempotente dos 66 livros sem afetar o progresso do parceiro. Não houve migração nem correção automática de registros existentes.

`flutter build web --no-pub` e o build com `--dart-define=USE_FIREBASE_EMULATORS=true` compilaram com sucesso, incluindo a verificação preliminar Wasm do Flutter. Esse resultado confirma compilação; navegação real no navegador, autenticação remota e publicação ainda precisam de validação.

Em 03/10/2026, os builds Android **debug** padrão e demo passaram com o lockfile atual, sem alterar Gradle, IDs ou configuração Firebase gerada. O log antigo registra falha no compilador Java sem o diagnóstico da causa; ela não reapareceu nos builds atuais. Detalhes, avisos e limites em [ANDROID_BUILD.md](docs/ANDROID_BUILD.md). Nenhum APK foi instalado/executado; a assinatura Android de release continua debug.

O workflow [CI](.github/workflows/ci.yml) está preparado e validado por actionlint, com análise/testes Flutter/build web demo e testes de Auth/Firestore emulado. Instalação por lockfile, SDK/ações fixados e ausência de deploy/credenciais de produção estão documentados em [DEVELOPMENT.md](docs/DEVELOPMENT.md#integração-contínua). Execução no GitHub e proteção de branch obrigando os checks permanecem pendentes; criar o arquivo não garante bloqueio de merge.

Não foram validados: login real em produção, autorização remota por operações com contas reais, jornada Flutter com emuladores no navegador/dispositivo e builds de distribuição Android/iOS. Regras/índices remotos foram consultados somente como metadados, sem ler/escrever documentos pessoais. A aprovação de implantação permanece adiada em SEC-06.

## Estrutura

```text
lib/
  main.dart             Inicialização e escolha entre login e navegação
  firebase_options.dart Configuração gerada pelo FlutterFire
  data/                 Modelos e catálogo local de livros bíblicos
  services/             Autenticação, livros, progresso bíblico e tema
  ui/                   Telas, componentes e temas
  utils/                Tratamento de erros
test/                   Testes existentes
docs/                   Documentação técnica e de produto
android/ ios/ web/       Projetos e configuração por plataforma
```

Consulte o [backlog](BACKLOG.md) antes de iniciar uma melhoria. A expansão deve preservar contas, livros e progresso bíblico existentes.
