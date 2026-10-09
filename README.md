# Bookself App

Aplicativo de organização de leituras para uso individual e em casal, desenvolvido em Flutter com Firebase. Cada pessoa mantém sua estante, acompanha capítulos bíblicos lidos e pode consultar a estante e o progresso do parceiro vinculado.

O produto está em fase de MVP. A evolução planejada inclui filmes, séries e músicas. **Entrelace** é a proposta inicial de novo nome; a escolha e a aplicação da marca ainda estão pendentes. O aplicativo continua se chamando Bookself App no código.

O [MVP da expansão](docs/PRODUCT.md#mvp-aprovado--prod-01) foi aprovado em 05/10/2026: preserva livros/Bíblia e define filmes, séries, faixas/álbuns, cadastro manual e experiências do casal. Essa é uma decisão de produto; as novas categorias ainda precisam ser implementadas.

## Documentação

| Arquivo | Conteúdo |
| --- | --- |
| [BACKLOG.md](BACKLOG.md) | Fonte central de tarefas, prioridades, dependências e critérios de conclusão. |
| [AGENTS.md](AGENTS.md) | Orientações para trabalhar neste repositório. |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Arquitetura atual, limitações e proposta de evolução. |
| [docs/WEB_VALIDATION.md](docs/WEB_VALIDATION.md) | Jornada Flutter web em ambiente demo, evidências e cenários pendentes. |
| [docs/PRODUCT.md](docs/PRODUCT.md) | Expansão, experiência do casal e nomes candidatos. |
| [docs/BOOK_LIBRARY.md](docs/BOOK_LIBRARY.md) | Identidade de livros, datas, histórico privado, edição manual e filtros pessoais. |
| [docs/NAVIGATION.md](docs/NAVIGATION.md) | Navegação atual de livros/Bíblia/Nós e mapa incremental das mídias futuras. |
| [docs/DATA_MODEL.md](docs/DATA_MODEL.md) | Modelo v1 e contratos locais: base privada, listas/experiências; progresso episódico, escutas pessoais e migração ativa pendentes. |
| [docs/DATA_MIGRATION.md](docs/DATA_MIGRATION.md) | Backup/plano offline e ensaio recuperável; conversão ativa e produção separadas. |
| [docs/DATA_ACCESS.md](docs/DATA_ACCESS.md) | Paginação, índices, agregações e sincronização; telas de livros habilitadas no demo e ativação remota separada. |
| [docs/COUPLE_INVITATIONS.md](docs/COUPLE_INVITATIONS.md) | Jornada, contrato local e limites de convites consentidos. |
| [docs/COUPLE_POLICY.md](docs/COUPLE_POLICY.md) | Política de consentimento aprovada para a evolução e critérios de implementação. |
| [docs/COUPLE_WORKSPACE.md](docs/COUPLE_WORKSPACE.md) | Listas e experiências consentidas, revisões, autoria e histórico restrito. |
| [DESIGN.md](DESIGN.md) | Sistema de design Material 3, tokens, componentes, navegação e padrões de interface. |
| [docs/DESIGN.md](docs/DESIGN.md) | Histórico e evidências das revisões visuais. |
| [docs/ACCESSIBILITY.md](docs/ACCESSIBILITY.md) | Correções de contraste/semântica/teclado, roteiro de avaliação humana e limites por plataforma. |
| [docs/INTEGRATIONS.md](docs/INTEGRATIONS.md) | Integrações atuais e candidatas, com fontes oficiais. |
| [docs/CATALOG_TRIALS.md](docs/CATALOG_TRIALS.md) | Ensaio de fornecedores, comandos sem segredos e pendências TMDB/MusicBrainz/Spotify. |
| [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) | Configuração isolada de Auth/Firestore, comandos e clientes por plataforma. |
| [docs/SECURITY.md](docs/SECURITY.md) | Auditoria remota, regras candidatas, concorrência de vínculo e implantação pendente. |
| [docs/PRIVACY.md](docs/PRIVACY.md) | Cópia pessoal parcial em JSON; exclusão e retenção ainda propostas. |
| [docs/decisions/README.md](docs/decisions/README.md) | Alternativas, escolhas técnicas implementadas e pendências. |
| [docs/ANDROID_BUILD.md](docs/ANDROID_BUILD.md) | Builds Android atuais, log histórico e limites de distribuição. |
| [docs/CONFIGURATION.md](docs/CONFIGURATION.md) | Inventário sem valores, configuração Google Books por ambiente e auditoria pendente. |
| [docs/IOS_VALIDATION.md](docs/IOS_VALIDATION.md) | Permissões de foto e verificação Apple ainda pendente. |

## Funcionalidades implementadas

- Perfil → Cópia dos meus dados: JSON parcial de perfil e biblioteca pessoais, copiado por ação explícita após leitura do servidor. Não inclui histórico do casal nem oferece restauração/exclusão de conta. [Escopo e limites](docs/PRIVACY.md).

- Interesses em comum na lista do vínculo ativo: compara seleções adicionadas pelos dois, explica coincidências e permite destacar próxima opção sem alterar progresso. Sem consultas pessoais adicionais. Ativação acompanha as listas locais; [contrato](docs/COUPLE_WORKSPACE.md#interesses-em-comum--couple-07).

- Nós → Listas e experiências: seleções manuais de livros, filmes, séries/episódios, faixas e álbuns; listas com autoria e retirada concorrente; experiências com data, proposta/correção e duas confirmações da revisão atual. Histórico restrito aos participantes antigos, com retirada da própria confirmação após término. Código/regras locais: **ativação remota depende de SEC-06**. Não cria bibliotecas pessoais das novas mídias nem altera progresso do parceiro. [Contrato](docs/COUPLE_WORKSPACE.md).
- Biblioteca e Início com paginação nos emuladores; ativação explícita em outro ambiente por `USE_PAGED_LIBRARY=true` após instalar índices. Carregar mais conserva filtros, cursores e buffers por origem; totais/estatísticas usam agregações completas. [Limites dos filtros e ativação](docs/DATA_ACCESS.md#telas-paginadas--ui-05).

- Cadastro, login, recuperação de senha e saída com Firebase Authentication.
- Login e cadastro preservam a senha digitada, inclusive espaços; a validação local exige pelo menos seis caracteres nos dois formulários.
- Erros de autenticação, dados e rede têm mensagens em português; diagnósticos do app registram somente operação, categoria e códigos permitidos.
- Restauração de sessão com estados de carregamento/erro e conclusão de perfil após cadastro parcial, preservando perfis existentes.
- Busca paginada de livros no Google Books, com timeout, tratamento de resposta parcial e descarte de buscas antigas; referência do catálogo preservada em registros novos. Cadastro manual disponível sem chave ou rede.
- Fontes Outfit/Playfair Display empacotadas para carregamento sem rede; capas em HTTPS com fallback, sem proxy externo.
- Mesma referência Google Books reencontra o livro pessoal sem substituir progresso; edições diferentes e cadastros manuais deliberados permanecem independentes. Metadados manuais podem ser corrigidos pelo dono; filtros combinam título/autor, status e período de inclusão/conclusão.
- Datas de inclusão preservadas em mudanças de status; criação/atualização e histórico privado com timestamps do servidor. O Início usa a última atividade explícita por livro, sem reconstruir acontecimentos antigos. [Contrato e limites](docs/BOOK_LIBRARY.md).
- Estante com os estados “Quero Ler”, “Lendo” e “Lido”, data de conclusão e histórico por mês e ano.
- Navegação Início/Biblioteca/Nós/Perfil. Biblioteca reúne os livros pessoais, busca/cadastro e acesso à Bíblia; Nós reúne consulta do parceiro, comparação bíblica, convites, compartilhamento e bloqueios. Filtros/testamento são preservados entre destinos; a Bíblia retorna à origem. Filmes, séries e músicas só entrarão após seus fluxos funcionais.
- Carregamento, vazio e falha de livros/progresso têm mensagens e ações próprias. Falha/offline da comparação retira dados alheios sem bloquear a Bíblia pessoal; ausência de apresentação do parceiro não apaga o vínculo.
- Limpeza da data de conclusão ao mudar um livro de “Lido” para “Lendo” ou “Quero Ler”.
- Livros lidos sem data aparecem em uma seção própria da estante, inclusive na consulta do parceiro. O dono pode informar ou corrigir a conclusão nos detalhes sem trocar o status; novas datas vão até hoje, em português e formato dia/mês/ano.
- Convites de sete dias com código aleatório, apresentação por nome/foto, reserva, aceite explícito, recusa e cancelamento. Consulta não cria vínculo; aceite confirma as duas contas em transação, sujeito às regras locais. Relações legadas permanecem. Consulta do casal usa projeções permitidas; Perfil → Compartilhamento oculta livros/progresso por livro bíblico, preservando dados pessoais. Feed conjunto começa no aceite, sem retroatividade. Bloqueio do parceiro ativo encerra acesso; desbloquear exige novo convite. O Início atualiza feed e estatísticas pelo stream.
- Acompanhamento de capítulos lidos nos 66 livros da Bíblia, com comparação do progresso do casal. Marcação individual/em lote aguarda confirmação, bloqueia ações repetidas e permite nova tentativa após falha.
- Edição de nome e foto de perfil; escolha de tema Claro, Escuro ou Sistema, salva localmente e restaurada ao abrir o app.
- Pessoas e bloqueios em Convites e Compartilhamento: identificação privada por convite reservado ou término, bloqueio após recusa/desvínculo e desbloqueio independente. Convites antigos não voltam a valer; regras locais ainda dependem de SEC-06. [Contrato e limites](docs/decisions/010-bloqueios-independentes.md).
- Perfil do parceiro usa apresentação separada com nome/foto, sem e-mail. Ausência/falha mantém consulta de leituras e desvínculo com apresentação neutra. As regras locais protegem o perfil privado; a proteção remota depende da implantação de SEC-06, conforme [SECURITY.md](docs/SECURITY.md).
- Dados compartilhados exigem confirmação do servidor; offline/término/ocultação retiram conteúdo das telas. Persistência Firestore desabilitada e cache antigo limpo na inicialização; proteção remota ainda depende de SEC-06. [Contrato e limites](docs/COUPLE_VISIBILITY.md).
- Design Organic com paleta areia/sálvia/musgo, tipografia Outfit, cartões flexíveis e navegação lateral em telas grandes. Login, busca, capítulos e perfil têm limites de largura; telas pequenas têm barra inferior e, abaixo de 380 px com texto acima de 1,5×, menu com os quatro destinos.
- Fechamento seguro de busca, perfil, detalhes e diálogos durante requisições, com resultado de exclusão na estante.

A seção da Bíblia registra progresso: **não contém textos ou versículos para leitura**. Filmes têm cadastro manual, detalhes, biblioteca/status/data e seleção para listas/sessões do casal no código local, habilitados nos emuladores. A busca externa aguarda fornecedor aprovado e intermediário; séries e músicas ainda não estão implementadas. [Ativação, contrato e limites de filmes](docs/MOVIES.md). Convites consentidos estão prontos no código/regras locais; a implantação depende de SEC-06 e dos controles restantes de COUPLE-04.

Sem preferência salva, o tema inicial continua escuro. “Sistema” acompanha o brilho do dispositivo; Claro/Escuro explícitos permanecem fixos. A preferência é do app no dispositivo/navegador, vale também no login e permanece após logout; outros dispositivos têm escolhas independentes. Limpar os dados locais remove a preferência. A tela de carregamento da inicialização mantém a aparência escura; a interface principal abre após a leitura da escolha salva.

## Tecnologias e plataformas

Flutter/Dart, localização do SDK Flutter, Provider, Firebase Core, Firebase Authentication, Cloud Firestore, HTTP, Google Fonts, Image Picker, Intl e Shared Preferences. Os requisitos declarados em `pubspec.yaml` são Flutter `>=3.44.0` e Dart `^3.12.0`.

Há projetos para Android, iOS e web, com opções Firebase para essas plataformas. Isso não significa que todas tenham sido validadas em execução. Windows, macOS e Linux não possuem configuração Firebase nesta versão.

## Configuração e execução

APK Android **1.3.0+4** com o novo design disponível na [pré-release v1.3.0](https://github.com/RodolfoGama0101/bookself-app/releases/tag/v1.3.0), com arquivo SHA-256. Versão para testes com assinatura debug; catálogo sem chave Google Books, mantendo cadastro manual de livros. Filmes e o novo espaço de listas/experiências/interesses permanecem desativados no APK padrão, até ativação explícita e regras/índices implantados. [Notas e limites](docs/releases/v1.3.0.md).

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

Em **09/10/2026 — REL-02/SEC-05/UI-03/QA-03**, assinatura release separada de debug,
cópia pessoal parcial e acessibilidade/regressões de filmes entregues localmente.
Análise limpa, **441 testes Flutter**, **87 testes Node/demo**, build web demo e
build Android debug aprovados; release sem credenciais recusada como esperado.
Filme manual/status e geração da cópia foram executados na web demo. Os quatro
itens permanecem em andamento pelos critérios externos restantes: chave definitiva,
exclusão/retenção, leitores de tela e demais mídias/jornada conjunta completa.
[Evidências e limites](docs/MOVIE_VALIDATION.md), [privacidade](docs/PRIVACY.md).

Em **08/10/2026 — API-04/MOVIE-01/02/03**, categoria de filmes manual integrada, com biblioteca/status/data e ações consentidas de lista/sessão do casal. Análise limpa, **426 testes Flutter**, **86 testes Node/demo** e build web demo aprovados; jornada web confirmou cadastro, mudança de status, data e filtro. API-04/MOVIE-01 permanecem parciais pela ausência de fornecedor/intermediário real; MOVIE-02/03 concluídas localmente, sem produção. [Contrato e pendências](docs/MOVIES.md), [evidências](docs/DEVELOPMENT.md#filmes--api-04-movie-010203).

Em **08/10/2026 — DOC-03/PROD-03/UI-03/API-05**, roteiro reproduzível e servidor web local adicionados; contraste, nomes/estados acessíveis e grade bíblica ajustados. Análise limpa, **402 testes Flutter**, **85 testes Node/demo** e build web demo aprovados. Jornada web confirmou manual sem chave, capa/fallback, leitura/recarga e capítulos pelo teclado. Os quatro itens continuam em andamento: reprodução independente, feedback humano, leitores de tela reais e execução Android/iOS ainda pendentes. [Achados e roteiro](docs/ACCESSIBILITY.md), [evidências](docs/WEB_VALIDATION.md#validação-local-de-fluxos-e-acessibilidade--08102026).

Em **08/10/2026 — COUPLE-07 e ensaios API-02/03**, interesses de listas consentidas verificados com análise limpa, **398 testes Flutter**, quatro testes Node da ferramenta de catálogo e build web demo aprovados. MusicBrainz teve buscas reais bem-sucedidas e detalhes com HTTP 503; TMDB aguarda credencial e nenhuma decisão de fornecedor foi presumida. [Evidências e limites](docs/DEVELOPMENT.md#interesses-e-ensaios-de-catálogo--couple-07-api-0203).

Em **08/10/2026 — COUPLE-05/06 e UI-05**, listas/experiências com revisão/dupla confirmação e histórico restrito, mais páginas/agregações das telas de livros, foram verificadas localmente: análise limpa, **394 testes Flutter**, **85 testes Node/demo** e build web demo aprovados. Testes de widgets incluem texto 2×/tela pequena e filtros ao carregar mais. Sem jornada nova em navegador/nativos, migração, implantação ou publicação; ativação remota das novas telas depende das regras/índices e dos defines documentados. [Evidências e limites](docs/DEVELOPMENT.md#listas-experiências-e-paginação--couple-0506-ui-05).

Em **08/10/2026 — UI-01/02 e BIBLE-01**, navegação e feedback das categorias atuais implementados e progresso preservado. Análise limpa, **373 testes Flutter**, seis testes offline de migração e build web demo aprovados. Jornada visual nos emuladores incluiu Bíblia, marcação confirmada e consulta após recarga; [evidências e limites](docs/WEB_VALIDATION.md#biblioteca-nós-e-bíblia--ui-0102-bible-01). Android/iOS e produção não executados.

Em **08/10/2026 — DATA-03/04/05**, foram implementados ensaio de migração preservando originais, consultas com cursores/agregações e coordenador de sincronização privado multimídia. Formatação, análise limpa, **363 testes Flutter** e **78 testes Node/emuladores demo** aprovados. Índices versionados; nenhuma migração/implantação/publicação executada. Estante/feed atuais ainda usam streams completos; integração paginada às telas permanece em UI-05/COUPLE-08. [Contratos e limites](docs/DATA_ACCESS.md), [ensaio](docs/DATA_MIGRATION.md).

Em **05/10/2026**, a jornada Flutter web foi executada no navegador integrado com duas contas fictícias em Auth/Firestore demo: cadastro/perfil, livro manual sem capa, status/data, progresso bíblico, vínculo/consulta e desvínculo com dados pessoais preservados. A busca sem chave teve sua mensagem repetida corrigida; análise limpa, 275 testes Flutter e build web demo passaram. CORE-13 posteriormente corrigiu e validou a restauração automática após recarga no Chrome demo, incluindo logout/recarga; análise limpa, 283 testes Flutter, seis testes Node e builds web padrão/demo passaram. Rede/offline, capas externas, plataformas nativas e autenticação em produção continuam pendentes. O [registro web](docs/WEB_VALIDATION.md) atualiza o limite da jornada emulada nas evidências anteriores, sem validar produção ou concluir toda a matriz de release.

Para desenvolver com dados isolados, siga [DEVELOPMENT.md](docs/DEVELOPMENT.md). O modo `--dart-define=USE_FIREBASE_EMULATORS=true` usa uma instância nomeada do projeto `demo-bookself`, com Auth/Firestore locais, antes da criação dos serviços; o modo padrão mantém a configuração distribuída. Não há fallback automático do emulador para o banco remoto.

```sh
flutter analyze --no-pub
flutter test --no-pub
```

Na validação de **03/10/2026**, 275 testes Dart passaram: sete sobre dados bíblicos, cinco sobre inicialização, 13 sobre sessão/ciclo de vida, cinco sobre persistência de perfil, cinco sobre as telas de sessão/recuperação, 14 sobre modelos de livro/usuário, 28 sobre operações assíncronas da interface, 37 sobre persistência/interface do progresso bíblico, 16 sobre senhas no login/cadastro, 52 sobre tradução de erros, diagnósticos e fluxos afetados, 31 sobre persistência/interface do tema, dois sobre atualização automática do Início, 14 sobre datas de conclusão, quatro sobre configuração demo e 11 sobre serviço de vínculo/sessão. Outras 31 regressões cobrem catálogo paginado, concorrência de busca, referência externa, capas, fontes reais offline e permissões de foto. A matriz de critérios de QA-01 está em [DEVELOPMENT.md](docs/DEVELOPMENT.md#cobertura-de-regressões-e-validação-dart).

Atualização de **05/10/2026 — SEC-04:** análise limpa, **295 testes Flutter**, **32 testes de integração nos emuladores Auth/Firestore** e build web demo aprovados. Perfil privado fica restrito ao dono nas regras locais; parceiro consulta somente nome/foto, sem fallback privado. Cobertura nova inclui escrita atômica, nome/foto concorrentes, legado sem projeção, campos privados rejeitados, revogação de nova atualização do perfil ao ex-parceiro e perfil disponível/ausente em 320 × 480. Sem execução nova da jornada em navegador/dispositivo nem implantação remota; detalhes e limites em [DEVELOPMENT.md](docs/DEVELOPMENT.md) e [SECURITY.md](docs/SECURITY.md).

Os testes Auth/Firestore usam contas fictícias: cadastro/login/logout e perfil, autorização de dono/parceiro/terceiro, queries, autoria/campos, preservação de dados legados, capítulos válidos dos 66 livros, vínculos simultâneos e desvínculo antigo, revogação de acesso ao ex-parceiro e isolamento de novo parceiro. Comando: `npm --prefix tool/firebase test`, após `npm --prefix tool/firebase ci --no-audit --no-fund`. Os testes usam apenas `demo-bookself`; não alteram produção.

As regressões de conclusão verificam entrada pt-BR, rejeição de datas futuras/formato inválido, datas anteriores a 2000, visibilidade dos livros sem data nas duas estantes, cadastro manual/catálogo, edição sem mudar status/data de inclusão, confirmação da escrita, falha/nova tentativa, cancelamento e descarte. Detalhes e seletor foram verificados em 320 × 480 com texto 2×. Datas futuras já existentes são preservadas; ao corrigi-las, o seletor inicia em hoje. Livros sem data não recebem uma data presumida nem entram nas contagens mensais/anuais. Testes usam serviços substitutos, sem banco remoto; execução real em navegador/dispositivo permanece pendente.

Os testes do Início usam um stream substituto e verificam inclusões, remoções, mudanças de status e contagens mensais/anuais pessoais e do parceiro. Arrastar o conteúdo vazio não mostra indicador de atualização nem cria nova consulta; descartar a tela cancela a assinatura. A entrega real de eventos pelo Firestore e o gesto em dispositivo permanecem pendentes de validação.

Os testes de tema usam armazenamento substituto: verificam recriação do serviço/árvore, restauração antes do primeiro login, padrão escuro, Sistema reagindo ao brilho, logout, confirmação de escrita, falhas/nova tentativa, concorrência, timeout e descarte. O controle no perfil foi verificado em 320 × 480 com texto 2×. Persistência no armazenamento nativo e reabertura real do navegador/dispositivo permanecem pendentes de validação.

As regressões de erros verificam códigos conhecidos/desconhecidos, ausência de mensagem/stack/dados pessoais nos textos e diagnósticos, autenticação, recuperação de perfil, vínculo/desvínculo, HTTP simulado e feedback na interface. A busca distingue limite de uso e indisponibilidade, mantendo cadastro manual; o resumo bíblico pessoal/do parceiro oculta erros brutos e a saída da conta trata falhas mesmo durante o descarte da tela.

As regressões de senha verificam o valor recebido pelo SDK substituto, incluindo espaços iniciais, finais, internos e o limite de seis caracteres; também cobrem validação, correção do formulário e mostrar/ocultar senha. Credenciais são fictícias; isso não valida a política remota de senhas nem autenticação real.

Os testes Dart usam inicializadores controlados e fakes, sem acessar o Firebase remoto. As regressões verificam fechamento de busca/perfil/detalhes durante sucesso ou falha, descarte de diálogos por cancelar/barreira/voltar, retorno de seletores de data após fechamento, ausência de sucesso antes da escrita e feedback de exclusão após retirar o cartão do stream. A cobertura bíblica verifica marcar/desmarcar, bloqueio de operações repetidas, rejeição/indisponibilidade, confirmação atrasada, conflito simulado, falha longe do topo em Salmos e tratamento de falha em 320 × 480 com texto 2×. As fontes nesses testes são substituídas por uma fonte já empacotada pelo Flutter, sem rede; não validam tipografia. Cobrem carregamento, erros, limites de espera, recuperação de cadastro parcial, preservação de perfil existente, descarte/logout/troca de conta, limpeza de campos opcionais e layout em tela pequena com texto ampliado e teclado. A repetição da transação bíblica por conflito é simulada; a concorrência de vínculo e as regras foram verificadas separadamente nos emuladores.

A análise estática está **limpa**, com código de saída zero. Os 47 infos do baseline inicial foram eliminados incrementalmente: logs brutos e `activeColor` nas correções anteriores; QA-04 removeu os 37 restantes usando `withValues(alpha:)`, `initialValue` e retirando `ColorScheme.background` obsoleto, preservando `surface` e os fundos explícitos do app. Não foram adicionadas supressões globais.

O serviço bíblico valida nome, proprietário, capítulo e total do lote antes de escrever. A cobertura de BIBLE-02 verifica 39 livros/929 capítulos no Antigo Testamento e 27 livros/260 capítulos no Novo (1.189 capítulos), IDs únicos, limites e marcação/desmarcação idempotente dos 66 livros sem afetar o progresso do parceiro. Não houve migração nem correção automática de registros existentes.

`flutter build web --no-pub` e o build com `--dart-define=USE_FIREBASE_EMULATORS=true` compilaram com sucesso, incluindo a verificação preliminar Wasm do Flutter. Esse resultado confirma compilação; navegação real no navegador, autenticação remota e publicação ainda precisam de validação.

Em 03/10/2026, os builds Android **debug** padrão e demo passaram com o lockfile atual, sem alterar Gradle, IDs ou configuração Firebase gerada. O log antigo registra falha no compilador Java sem o diagnóstico da causa; ela não reapareceu nos builds atuais. Detalhes, avisos e limites em [ANDROID_BUILD.md](docs/ANDROID_BUILD.md). Nenhum APK foi instalado/executado. Desde 09/10/2026, release exige configuração própria de assinatura e recusa credenciais ausentes; a chave definitiva permanece pendente em REL-02.

O workflow [CI](.github/workflows/ci.yml) está preparado e validado por actionlint, com análise/testes Flutter/build web demo e testes de Auth/Firestore emulado. Instalação por lockfile, SDK/ações fixados e ausência de deploy/credenciais de produção estão documentados em [DEVELOPMENT.md](docs/DEVELOPMENT.md#integração-contínua). Os dois checks passaram no [GitHub em 05/10/2026](https://github.com/RodolfoGama0101/bookself-app/actions/runs/37344664198), após corrigir a seleção do canal stable no runner. Proteção de branch obrigando os checks e comprovação de bloqueio de merge permanecem pendentes.

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

Atualização de **05/10/2026 — COUPLE-03:** convites consentidos prontos localmente, com análise limpa, **308 testes Flutter**, **43 testes Auth/Firestore** e build web demo aprovados. Jornada em dois Chromes isolados confirmou criação/reserva/aceite e término; reuso foi rejeitado, com mensagem de domínio conferida no build final. Sem deploy/migração/publicação. Controles de visibilidade/bloqueio/cache e feed sem retroatividade permanecem em COUPLE-04/DATA-05. [Contrato e limites](docs/COUPLE_INVITATIONS.md).
