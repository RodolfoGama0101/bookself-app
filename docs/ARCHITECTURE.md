# Arquitetura

Revisão: 05/10/2026. As seções iniciais descrevem o código atual; a evolução ao final é uma proposta.

## Inicialização e interface atuais

`lib/main.dart` inicia a interface imediatamente com `BookselfBootstrap`. Ele cria e mantém `ThemeService` na raiz, iniciando a leitura da preferência antes de registrar os ouvintes do Provider. `AppStartup` (`lib/ui/screens/app_startup.dart`) mostra carregamento enquanto aguarda essa leitura e a inicialização Firebase. Apenas após sucesso do Firebase, seu `readyBuilder` registra `AuthService` e cria `BookselfApp`. `SessionGate` decide entre login, carregamento, recuperação de perfil e `MainNavigation` conforme o estado explícito de sessão.

`MainNavigation` usa `IndexedStack` com Início, Estante, Bíblia e Perfil. Busca é acessada pela estante. Serviços de livros e Bíblia são instanciados nas telas; não há backend próprio versionado. `FirebaseEnvironment` seleciona a instância para todos os serviços: padrão no modo distribuído e nomeada `demo-bookself` no modo explícito de emuladores. Auth/Firestore locais são configurados antes dos providers; o cache persistente do Firestore fica desabilitado em todos os ambientes, e a inicialização limpa a persistência antiga antes dos serviços. Configuração inválida não faz fallback para o projeto real. Comandos/limites por plataforma estão em [DEVELOPMENT.md](DEVELOPMENT.md).

No demo web, `prepareWebEmulator` (`lib/services/firebase_web_emulator*.dart`) chama `web/firebase_emulator.js` antes de `Firebase.initializeApp`. O helper carrega Core/Auth/Firestore na versão suportada pelo FlutterFire e conecta Auth imediatamente após `initializeAuth`, antes da restauração persistida. Isso corrige o retorno ao login e a tentativa de consulta Auth remota após recarga. O opt-in e a identidade/host locais são validados antes de inicializar; o modo padrão e os clientes nativos mantêm a inicialização anterior. Dependências de persistência acompanham `firebase_auth_web` 6.2.1; upgrades dos plugins ou adição de serviços Firebase exigem revisão desse bootstrap e nova validação de recarga. Evidências em [WEB_VALIDATION.md](WEB_VALIDATION.md).

Falhas assíncronas e erros síncronos de configuração mantêm o app em uma tela recuperável com “Tentar novamente”, sem criar os serviços dependentes de Firebase. Há somente uma tentativa ativa; o resultado de uma operação após descarte não usa estado/contexto antigo. As telas iniciais usam fontes locais e não exibem o erro técnico. Não há modo local completo: inicializar o SDK não comprova acesso aos serviços remotos.

Os testes de `test/app_startup_test.dart` simulam sucesso, falha de rede, erro síncrono de configuração, recuperação, toques repetidos, descarte e tela de 320 × 480 com escala de texto 2. Não acessam Firebase de produção e não substituem validação em dispositivo nem testes de sessão/perfil.

## Sessão e recuperação de perfil

`LoginScreen` envia a senha integralmente a `AuthService`, que a repassa ao Firebase Authentication sem normalização. A mesma validação local de pelo menos seis caracteres é usada no login e no cadastro; espaços contam como caracteres e não são removidos. Isso preserva a regra existente do formulário; a aceitação das credenciais e a política remota continuam sob responsabilidade do Firebase. Nome/e-mail mantêm o tratamento anterior. `test/login_password_test.dart` verifica os dois fluxos até o SDK substituto, limites de tamanho, correção após erro de validação e alternância de visibilidade, sem usar contas reais.

`AuthService.sessionState` distingue `restoring`, `signedOut`, `loadingProfile`, `ready`, `missingProfile`, `profileError` e `authError`. Sessão autenticada e perfil disponível são informações separadas: o login só aparece em `signedOut`, e a biblioteca só abre em `ready`. A restauração e a primeira leitura de perfil têm limite de espera de 15 segundos; erro/timeout permite nova tentativa, e uma resposta válida posterior ainda pode recuperar o estado.

`UserProfileService` centraliza leitura, edição de nome/foto e criação dos perfis após cadastro ou recuperação. A ausência de documento apenas no cache não confirma um perfil ausente; escritas locais pendentes não liberam a biblioteca como se estivessem confirmadas. Um perfil existente em cache, sem escrita pendente, pode ser usado. Erros de leitura/serialização mostram recuperação, sem iniciar criação automática.

Quando o servidor confirma ausência, a pessoa pode informar o nome, verificar novamente ou sair. `createIfMissing` lê `users/{uid}` em transação: cria o documento somente quando ausente e retorna o perfil existente sem atualizar qualquer campo, inclusive campos legados desconhecidos. A mesma transação cria/atualiza `partner_profiles/{uid}` somente com nome/foto do perfil efetivamente encontrado. O UID e e-mail vêm da sessão autenticada; não se cria outra conta para recuperar o perfil. O cadastro usa o mesmo caminho e mantém a sessão caso a etapa Firestore falhe.

Login, cadastro e criação/recuperação de perfil têm limite de espera de 15 segundos na interface. Esse limite não cancela a operação do SDK: uma conta ou escrita pode ser confirmada mais tarde, sendo observada pelos streams; a pessoa pode precisar informar o nome novamente. A recuperação é repetível e só libera o perfil após leitura sem escrita pendente ou confirmação da transação. A correção inicial de sessão não migrou dados; SEC-04 adicionou posteriormente a projeção consultável descrita abaixo, sem substituir o perfil privado. Regras que rejeitem a operação continuam produzindo erro recuperável.

A assinatura de autenticação é guardada. Troca de conta, logout, perfil indisponível e mudança de parceiro cancelam os ouvintes correspondentes e limpam o estado anterior; `dispose` encerra autenticação, perfil, parceiro e timer. Revisões das assinaturas impedem que eventos/resultados antigos substituam o estado da sessão atual. Atualizar o próprio perfil sem mudar parceiro não recria a assinatura dele. A assinatura do parceiro usa exclusivamente `partner_profiles`, com modelo `PartnerProfile` separado de `UserModel`, sem e-mail, data de criação ou vínculo da outra conta.

`test/auth_service_test.dart`, `test/user_profile_service_test.dart` e `test/session_gate_test.dart` cobrem falhas parciais, recuperação, limites de espera, preservação integral, repetição simulada de transação por conflito, cache, ciclo de vida e telas pequenas com texto ampliado/teclado. Os dublês Firestore têm exceções de análise apenas nas três declarações que implementam APIs marcadas `sealed` pelo SDK, restritas aos testes. Não há supressão global nem mudança de dependências. A cobertura não comprova regras remotas, concorrência no servidor ou funcionamento em dispositivo; essas validações permanecem nas tarefas SEC/QA/REL.

## Responsabilidades

| Camada | Local | Responsabilidade |
| --- | --- | --- |
| Modelos | `lib/data/models/` | Serialização de usuário, livro e progresso bíblico. |
| Dados bíblicos | `lib/data/bible_data.dart` | Nomes, capítulos e testamento dos 66 livros, sem versículos. |
| Autenticação | `lib/services/auth_service.dart` | Conta, streams de perfil/parceiro, vínculo e desvínculo. |
| Perfil | `lib/services/user_profile_service.dart` | Leitura de perfis, atualização de nome/foto e criação transacional sem sobrescrever documentos existentes. |
| Livros | `lib/services/book_service.dart` | Google Books, persistência e streams de estante/feed. |
| Bíblia | `lib/services/bible_service.dart` | Progresso confirmado, transação individual e escrita do livro completo. |
| Tema | `lib/services/theme_service.dart` | Restauração e persistência local de Claro/Escuro/Sistema, com modo escuro inicial. |
| Interface | `lib/ui/` | Formulários, navegação, estatísticas e exibição. |
| Erros | `lib/utils/error_handler.dart` | Tradução por tipo/código para português e diagnóstico com identificadores permitidos. |

`ProfileScreen` aguarda `UserProfileService.updateName/updatePhoto` antes de anunciar sucesso. As atualizações usam transação para alterar somente a intenção no documento privado e no perfil consultável; documento ausente não é recriado. Quando a projeção está ausente/desatualizada, ela é reconstruída apenas com nome/foto atuais. Campos privados/legados são preservados. Fotos são reduzidas e armazenadas como data URI Base64 nos dois documentos; o código atual não usa Firebase Storage.

Ao receber um perfil próprio válido, `AuthService` solicita `ensurePartnerProfile` em segundo plano. A transação relê os dados atuais do dono, corrige somente a projeção e não escreve se ela já corresponder ao perfil. Isso permite que contas antigas publiquem sua apresentação ao abrir esta versão, sem alterar contas, vínculos, livros ou Bíblia. Falha/timeout não bloqueia a biblioteca pessoal; uma nova emissão de perfil ou sessão tenta novamente. Uma operação já iniciada pode terminar depois do limite de 15 s, sem anunciar sucesso nem alterar estado de outra sessão.

Perfil consultável ausente, inválido ou sem autorização não provoca leitura alternativa de `users`. O app usa o vínculo do próprio usuário e apresentação neutra “Seu parceiro”; a tela de perfil informa indisponibilidade e permite desvincular. Estante, feed e comparação bíblica continuam usando a identidade do vínculo atual, sujeitos à autorização dessas coleções. Quando a projeção chega pelo stream, nome/foto substituem a apresentação neutra. Essa compatibilidade incremental não executa migração em lote nem presume aceite da futura política de convites.

## Mensagens de erro e diagnósticos

`ErrorHandler` reconhece códigos de Authentication/Firestore, exceções tipadas de conexão/timeout/dados e permissões de câmera/fotos. Os textos são definidos pelo app; mensagens, `details`, URLs, stack traces e `toString()` de erros externos não compõem o feedback. Códigos desconhecidos usam fallback em português. `failed-precondition` não revela índices ou configuração do banco. Credenciais inválidas têm orientação comum no login; recuperação de senha com conta ausente orienta conferir o endereço, sem pedir senha.

`getFriendlyErrorMessage` também registra diagnóstico; `report` registra falhas sem criar texto de interface, como inicialização, leitura do parceiro e capas. Os logs usam `ErrorOperation` e categorias/códigos permitidos; um código externo desconhecido vira `unknown`, e status HTTP só aparece como número entre 400 e 599. Não se registram mensagens externas, dados da conta, títulos, consultas, chaves, URLs ou stack. Falhas retornadas pelo SDK podem conter esses dados, por isso a classificação não depende de buscas em sua descrição. Logs internos de SDKs/plataforma ficam fora desse contrato do código do app.

Autenticação, recuperação de perfil, vínculo/desvínculo, saída, livros, feed, perfil e Bíblia usam essa fronteira. O cadastro parcial mantém o aviso de conta criada e acrescenta a orientação da falha de perfil. Sair da conta tem feedback tanto no perfil quanto na recuperação de sessão; retornos após descarte não acessam o contexto antigo.

`BookService` lança `CatalogRequestException` com apenas o status HTTP nas respostas sem sucesso. Falhas de conexão/JSON preservam seu tipo até o tratamento da interface; os logs brutos de busca/persistência foram removidos. A busca apresenta a orientação correspondente e mantém o atalho de cadastro manual. O cliente HTTP pode ser injetado para simular respostas; quem o injeta é responsável por fechá-lo. O transporte padrão continua usando `http.get`, sem mudança de dependências ou credenciais.

`test/error_handler_test.dart`, `test/auth_errors_test.dart`, `test/book_search_errors_test.dart` e `test/error_ui_test.dart` têm 52 regressões de tradução, diagnóstico, serviços e interface. Usam credenciais fictícias e HTTP/Firebase substitutos; verificam códigos desconhecidos, descrição externa que não pode ser impressa, ausência de dados pessoais no diagnóstico, permissões, timeout, cadastro parcial, vínculo/desvínculo e feedback em login, recuperação, busca, resumo bíblico pessoal/do parceiro e saída. A suíte completa tem 244 testes Dart passando; análise limpa após QA-04. Outros 24 testes validam Auth/Firestore nos emuladores. Compilação web e verificação preliminar Wasm passaram; jornada Flutter em navegador/dispositivo e autorização remota aplicada continuam pendentes.

## Preferência de tema

`ThemeService` usa `SharedPreferencesAsync` do [plugin oficial Shared Preferences](https://pub.dev/packages/shared_preferences). A chave local `theme_mode` guarda `light`, `dark` ou `system`, sem depender de UID ou escrever no Firebase. A instância fica acima dos fluxos de sessão e permanece no logout. Cada instalação/origem do navegador tem sua preferência; limpeza dos dados locais retorna ao padrão. O plugin é apropriado para preferências simples, sem garantia de durabilidade crítica em disco após o retorno de uma gravação.

Sem valor salvo, o app mantém Escuro, preservando o comportamento anterior. “Sistema” passa `ThemeMode.system` ao `MaterialApp`, que acompanha o brilho da plataforma; Claro/Escuro explícitos ignoram essas mudanças. A restauração termina antes de abrir `BookselfApp`, inclusive o primeiro login. A tela de carregamento/erro de `AppStartup` continua escura. A leitura inicial tem limite de cinco segundos; falha/valor inválido usa o padrão sem apagar dados, registra diagnóstico seguro e deixa uma ação de releitura no perfil. Respostas posteriores a um timeout não substituem a escolha atual. Falha em uma releitura preserva o modo atual.

O perfil oferece as três escolhas e mantém o atalho de alternância, que escolhe o oposto do brilho visível e sai de Sistema para um modo explícito. Escritas são aguardadas antes de mudar o tema; durante a gravação, o perfil mostra “Salvando tema…” e bloqueia seletor/atalho. Falha mantém o tema anterior e mostra mensagem em português, permitindo repetir a escolha. O serviço impede gravações concorrentes e aguarda uma restauração pendente antes de salvar. Releitura não concorre com gravação; descarte ignora retornos sem notificar estado/contexto antigo. Uma gravação iniciada pode terminar no armazenamento após descarte.

`test/theme_service_test.dart` tem 15 regressões e `test/theme_ui_test.dart` tem 16, usando preferências substitutas, inicializador controlado e Firebase fictício. Cobrem recriação de serviço/árvore, primeiro uso/login, brilho, logout, leitura/escrita rejeitada, repetição, concorrência, timeout, confirmação, descarte e controle em 320 × 480 com texto 2×. `flutter pub get` resolveu `shared_preferences` 2.5.5 e seus adaptadores; o requisito Flutter `>=3.44.0` foi explicitado junto ao Dart `^3.12.0`. Android usa o mínimo do SDK (24 no Flutter validado) e iOS já declara 13.0; identificadores e configuração Firebase foram preservados. Compilação web passou, mas persistência nativa/reabertura real e builds Android/iOS continuam em QA/REL.

## Operações assíncronas e diálogos

Busca, perfil e detalhes verificam `mounted` depois de operações externas, antes de atualizar estado ou acessar contexto. Seleção e leitura da imagem interrompem o fluxo caso a tela seja descartada antes da escrita; uma escrita já iniciada continua no serviço e seu retorno não acessa a tela descartada. Cancelar o seletor de imagem restaura o estado de carregamento. Estas proteções não cancelam requisições HTTP ou operações do Firebase e não definem uma política nova de sincronização/offline.

Diálogos com controladores locais usam `showDialogWithControllers`: o resultado da navegação pode chegar antes do fim da animação, então o descarte aguarda `DialogRoute.completed`. Cancelar, tocar a barreira e voltar passam pelo mesmo descarte. O cadastro bloqueia submissões repetidas enquanto aguarda escrita; somente a rota de diálogo ainda atual pode ser fechada por seu resultado. Seletores de data verificam o contexto do diálogo/folha após retornar.

Exclusão pelos detalhes captura o livro, serviço e callback antes de fechar a folha. A estante recebe sucesso ou erro somente após a escrita; o callback usa o contexto da tela, que permanece válido mesmo se o stream retirar o cartão. Os atalhos da estante e a recuperação de senha também usam o contexto da tela para feedback. Se a tela de origem for descartada, seu retorno não mostra mensagens nela. Edição de nome fecha o formulário, confirma a atualização no serviço e informa sucesso/falha no perfil.

`BookService` resolve a instância Firestore ao acessar persistência. Busca/estante/detalhes aceitam um serviço substituto; perfil aceita `UserProfileService` e `ImagePicker` substitutos. `test/async_ui_test.dart` usa fakes, futures controladas, streams locais e uma fonte já empacotada pelo Flutter para verificar 28 regressões sem rede, Firebase remoto ou seletor nativo. Seleção real de câmera/galeria, tipografia e funcionamento em dispositivo continuam pendentes em QA/REL. A estratégia mais ampla de cache/sincronização segue em DATA-05.

## Persistência do progresso bíblico

`BibleService.toggleChapter` preserva os demais capítulos ao marcar/desmarcar em transação. `markAllChapters` continua escrevendo a lista completa ou vazia em um único documento. Ambos retornam `Future<List<int>>` com os capítulos somente após confirmação da transação/escrita; a tela usa esse resultado mesmo se o stream ainda não tiver entregue o novo estado. Isso também preserva capítulos recebidos em uma repetição da transação após conflito. Coleção, composição dos IDs, campos e timestamp do servidor permanecem iguais; não houve migração.

Antes de escrever, ambos validam proprietário não vazio/sem separador de caminho e nome exato do livro em `BibleData.books`. O capítulo precisa estar entre 1 e o limite do catálogo; o total informado ao lote precisa coincidir com esse limite, inclusive ao desmarcar. Entradas inválidas lançam `ArgumentError`/`RangeError` sem acessar o Firestore. A UI já fornece os valores do catálogo; esta validação não substitui as regras nem corrige automaticamente documentos legados. Marcar/desmarcar repetidamente mantém o mesmo conjunto de capítulos; cada lote substitui a lista do dono em uma escrita, sem juntar intenções concorrentes de outros dispositivos.

Streams de livro e resumo usam `includeMetadataChanges: true` e ignoram snapshots com `hasPendingWrites`. Assim, uma alteração apenas local não aparece como progresso confirmado, e a confirmação que muda somente metadata ainda é entregue. Dados de cache sem escritas pendentes podem ser apresentados; isso não comprova uma leitura recente do servidor nem muda a política de autorização.

A tela de capítulos mantém uma assinatura do dono e, quando há vínculo, uma do parceiro. Enquanto aguarda uma escrita, mostra “Salvando progresso…” e bloqueia capítulos e lote, inclusive callbacks repetidos antes do próximo frame. O capítulo acionado também mostra carregamento no próprio botão. Sucesso aparece depois da confirmação. Rejeição/indisponibilidade mostra aviso com “Repetir” na área ativa mesmo longe do topo e deixa o erro visível e libera nova tentativa da mesma intenção; não há alteração otimista feita pela tela. Uma nova ação limpa o erro anterior. A grade e as mensagens compartilham uma rolagem para permitir acesso à recuperação em telas pequenas com texto ampliado.

Falha na leitura do próprio progresso impede escritas até recuperação; falha na comparação do parceiro não impede progresso pessoal. Fechar a tela cancela os ouvintes e ignora retornos de escritas já iniciadas. Trocar os parâmetros de dono/livro/serviço renova assinaturas e descarta resultados da identidade anterior. Mudar somente o parâmetro de parceiro atualiza sua assinatura e mantém o bloqueio da escrita pessoal em curso.

Escritas já iniciadas não são canceladas pelo fechamento. Não há timeout que trate uma escrita ainda pendente como rejeitada: o SDK pode manter o lote pendente sem conexão e confirmar após reconexão; a tela continua aguardando. A estratégia mais ampla de offline/cache e conflitos entre dispositivos continua em DATA-05. A mudança não valida regras remotas nem torna a comparação visual um controle de acesso.

`test/bible_service_test.dart` tem 16 testes de contratos de persistência/streams, incluindo limites e lotes nos 66 livros; `test/widget_test.dart` tem sete testes de estrutura, totais, ordem e unicidade. `test/bible_screen_test.dart` tem 21 testes de confirmação, falhas, repetição, marcação/desmarcação, descarte, capítulo 100 de Salmos e tela pequena. Usam futures controladas, fakes Firestore e fontes locais de teste compartilhadas com as regressões da CORE-05. As exceções de análise para APIs `sealed` ficam nas cinco declarações do dublê `test/support/bible_firestore_fake.dart`. A repetição da transação por conflito é simulada; concorrência de vínculo e regras foram verificadas nos emuladores, enquanto concorrência bíblica real e funcionamento em dispositivo permanecem pendentes.

## Dados no Firestore

| Coleção e ID | Campos principais | Uso |
| --- | --- | --- |
| `users/{uid}` | `uid`, `name`, `email`, `partnerUid`, `photoUrl`, `createdAt`, `relationshipId`, `coupleEpoch` | Perfil e ligação ao parceiro. |
| `partner_invites/{code}` | Participantes/versões internos, nome/foto, estado e timestamps do servidor | Convite temporário, reserva e decisão; sem acesso pessoal antes do aceite. |
| `partner_invite_slots/{uid}` | `code`, `issuedAt` | Último convite enviado; consulta própria e controle de criação. |
| `partner_invite_lookups/{uid}` | `code`, `requestedAt` | Consulta própria e limite de descoberta. |
| `partner_profiles/{uid}` | `name`, `photoUrl` opcional/nulo | Apresentação mínima, consultável somente pelo dono/parceiro recíproco nas regras candidatas. UID vem do caminho, sem duplicá-lo no conteúdo. |
| `shared_books/{documentId}` | Metadados/progresso mínimos, sem preferência nem campos privados | Consulta do dono/parceiro recíproco; ausente quando oculto. |
| `shared_bible_progress/{uid_nomeNormalizado}` | `userId`, `bookName`, `readChapters`, `updatedAt` | Projeção permitida por livro bíblico. |
| `partner_blocks/{uid}/targets/{otherUid}` | Nome mínimo e `createdAt` | Bloqueio privado do dono; impede convites entre as duas contas. |
| `partner_contacts/{uid}/targets/{otherUid}` | `name`, `invitationCode` anulável | Identificação privada por interação autorizada; não concede acesso pessoal. |
| `books/{documentId}` | `userId`, `title`, `authors`, `coverUrl`, `status`, `publishedDate`, `finishedDate`, `addedAt`, `googleBooksId` opcional | Livro na estante de uma pessoa. |
| `bible_progress/{uid_nomeNormalizado}` | `userId`, `bookName`, `readChapters`, `updatedAt` | Capítulos lidos por pessoa/livro bíblico. |

Inclusão pela busca e formulário manual força um ID vazio para criar documento próprio. `BookService.saveBook` aceita IDs existentes para atualizar. Registros novos vindos do catálogo preservam `googleBooksId` opcional, separado do ID pessoal; livros manuais/legados continuam sem referência. Não há preenchimento retroativo nem política de deduplicação da biblioteca (BOOK-01). O campo nomeia somente o fornecedor de livros já existente; não aprova o contrato proposto para múltiplas mídias de DATA-01.

O feed consulta livros de uma ou duas pessoas, ordenados por `addedAt` no cliente. Alterações de status também atualizam esse campo: ele representa inclusão e última atividade. Não há histórico separado de eventos. Estatísticas mensais/anuais usam o estado atual `Lido` e `finishedDate`.

No Início, `StreamBuilder` recebe `BookService.streamCoupleFeed`, baseado em snapshots do Firestore, e recalcula cartões e contagens a cada emissão. O gesto de atualização manual com callback vazio foi removido; a rolagem usa o comportamento padrão da plataforma. Não há consulta forçada ao servidor nem confirmação de sincronização ao arrastar. `HomeScreen` aceita um serviço substituto para testar esse fluxo sem acesso remoto. `test/home_feed_test.dart` verifica inclusões/remoções, mudanças de status e estatísticas das duas pessoas, ausência de indicador de atualização no gesto e cancelamento da assinatura ao descartar a tela.

### Cópia e limpeza de campos opcionais

Em `BookModel.copyWith`, omitir `finishedDate` preserva a conclusão; passar `null` limpa o campo, e passar `DateTime` substitui a data. `UserModel.copyWith` usa a mesma semântica para `partnerUid` e `photoUrl`, com valores `String`. Os argumentos usam `Object?` com um marcador privado para distinguir omissão de `null`; casts rejeitam tipos incompatíveis em execução. Os demais campos mantêm a semântica anterior de cópia. `BibleProgressModel` não possui campos anuláveis e não exige esse marcador.

Os detalhes do livro já enviam `finishedDate: null` ao mudar de `Lido` para `Lendo` ou `Quero Ler`; o atalho “Começar leitura” também limpa a data explicitamente. `copyWith` não deduz limpeza somente pelo status: outros chamadores que mudem o livro para um estado não concluído devem informar `finishedDate: null`. Cópias para alterar título/ID preservam a conclusão quando o argumento é omitido.

`toMap` mantém as chaves anteriores e representa conclusão limpa como `null`. A referência opcional `googleBooksId` só é escrita quando preenchida; omissão em `copyWith` preserva e `null` remove. Como `saveBook` substitui o mapa do documento, a remoção explícita também é persistida. A limpeza de `partnerUid` no modelo não altera por si só o vínculo no banco nem substitui seu fluxo de autorização. Não há migração ou limpeza automática de registros antigos. Os testes `test/book_model_test.dart` e `test/user_model_test.dart` cobrem preservação, limpeza, substituição, serialização e compatibilidade com campos ausentes.

### Datas de conclusão

`showCompletionDatePicker` centraliza os quatro fluxos de seleção: cadastro manual, inclusão do catálogo, atalho de conclusão na estante e detalhes. Usa localização Material/Widgets/Cupertino de `flutter_localizations` do SDK, com `pt_BR`, botões e validação em português, entrada dia/mês/ano e calendário até hoje no dispositivo. `BookselfApp` também declara essa localização. Novas conclusões são datas locais sem hora; o intervalo vai do ano 1 até hoje, permitindo corrigir leituras anteriores a 2000. Registros existentes, inclusive futuros, não são reescritos automaticamente. O seletor usa a data anterior quando válida e hoje quando ausente ou fora do intervalo.

A aba Lidos mantém agrupamento por ano/mês para registros datados e acrescenta “Data de conclusão não informada” para os demais, nas estantes pessoal e do parceiro. Não usa `addedAt` como substituto de conclusão; as estatísticas mensais/anuais continuam exigindo `finishedDate`. Detalhes mostram “Data não informada” e, para o dono, ação para informar/editar. A edição mantém status e `addedAt`, usando a persistência existente de `BookService.saveBook`; mudança de status mantém seu comportamento anterior de atualizar o feed. O agrupamento só muda após o stream entregar a escrita.

A seleção bloqueia ações concorrentes; a escrita mostra carregamento e só anuncia sucesso/atualiza os detalhes depois da confirmação do serviço. Cancelar ou confirmar a mesma data não escreve; falha preserva a data anterior e permite repetir. O parceiro consulta a data sem controles de edição; autorização no servidor continua em SEC. Fechar a tela durante seletor/escrita ignora retornos; operações já iniciadas não são canceladas. A persistência continua salvando o documento inteiro; conflitos entre dispositivos seguem em DATA-05.

`test/completion_dates_test.dart` contém 14 regressões por serviços substitutos: localização e entrada inválida/futura, leitura anterior a 2000, inclusão manual/catálogo, estantes pessoal/do parceiro, preservação de datas futuras legadas, confirmação atrasada, falha/nova tentativa, cancelamento/mesma data, descarte, bloqueio de repetição e detalhes/seletor em 320 × 480 com texto 2×. Não valida banco remoto, autorização nem dispositivos reais.

## Vínculo e autorização atuais

COUPLE-03 substitui novos vínculos diretos por convites com código aleatório de 128 bits, apresentação mínima, reserva, aceite, recusa e cancelamento. As regras conferem validade de sete dias, um enviado ativo, intervalos de criação/consulta e aceite do destinatário com as duas contas livres. A consulta não libera registros pessoais. `PartnerService` concentra os acessos; `AuthService` guarda sessão/operação e a tela confirma consentimento antes de criar/aceitar.

Aceite grava convite e os dois perfis em transação, sem ler o perfil privado do remetente. `relationshipId` identifica o convite consumido e `coupleEpoch` incrementa a versão dos dois participantes, invalidando convites antigos mesmo após término. O convite enviado do destinatário é cancelado no mesmo aceite. Desvínculo lê somente o perfil próprio e compara parceiro/identificador capturados; o servidor exige limpeza recíproca e preservação da versão. Legados sem identificador/versão continuam suportados, sem conversão automática em consentimento. [Contrato e consequências](COUPLE_INVITATIONS.md).

SEC-04 restringe `users` ao dono e `partner_profiles` a nome/foto do dono/parceiro recíproco. COUPLE-04 acrescenta ocultação/revogação, feed sem retroatividade e cache nas categorias atuais; COUPLE-09 estende o bloqueio a pessoas identificadas por interação autorizada, e a sincronização geral permanece em DATA-05. **As regras não estão implantadas no remoto**: a auditoria de 03/10/2026 encontrou autorização recursiva para qualquer conta autenticada. Código local não comprova proteção remota nem aprovação de distribuição.

`firebase.emulators.json` usa somente `demo-bookself`, Auth/Firestore locais, sem substituir `firebase.json`. Os filtros atuais não exigem índices compostos. A suíte tem 43 integrações de autorização/concorrência; regressões Dart cobrem contrato, confirmação, falhas, sessão, troca de streams, consentimento e tela pequena. Duas sessões Flutter web demo validaram a jornada consentida. [Evidências e implantação pendente](SECURITY.md).

## Limitações observadas

- Estante/feed não têm paginação; ordenação e estatísticas ocorrem em memória.
- Imagens e serviços externos requerem avaliação de uso sem rede.

As tarefas correspondentes estão em [BACKLOG.md](../BACKLOG.md).

## Bloqueios independentes

COUPLE-09 acrescentou identificação mínima e bloqueios independentes em 08/10/2026. Reserva/término registram contatos privados em transação; bloqueio de ex-parceiro preserva o vínculo atual e incrementa `coupleEpoch` com `lastBlockedUid` para comprovação atômica nas regras. Convites anteriores da conta precisam ser substituídos, mesmo após desbloqueio. [Escolhas, compatibilidade e limites](decisions/010-bloqueios-independentes.md). Esta extensão é do modelo atual, sem aprovar o esquema proposto abaixo.

## Proposta para múltiplas mídias

Consolidar esta proposta em uma decisão técnica antes da implementação. As entidades abaixo não são o esquema atual nem uma migração já autorizada.

| Entidade proposta | Dados | Motivo da separação |
| --- | --- | --- |
| Item de catálogo | Tipo, fornecedor, ID externo, título, imagem, metadados específicos. | Uma obra pode existir nas bibliotecas de várias pessoas. |
| Entrada pessoal | Dono, item, status, datas, nota/comentário, visibilidade. | Progresso e opinião de uma pessoa não substituem os do parceiro. |
| Progresso específico | Episódios/temporadas e estados apropriados por mídia. | Categorias não compartilham todos os campos. |
| Relação e convite | Participantes, estado, aceite, criação, expiração, encerramento. | Acesso depende de vínculo ativo e consentido. |
| Lista/experiência do casal | Relação, itens, participantes, datas compartilhadas. | Fazer algo juntos difere de possuir a mesma obra. |
| Evento de atividade | Autor, mídia, ação, instante, visibilidade. | Histórico deve ser independente do estado e data de inclusão. |

Identidade de catálogo deve combinar fornecedor, tipo e ID externo. Itens manuais precisam de identidade própria. Estados internos estáveis devem ser traduzidos na apresentação e ter regras por categoria. Bíblia conserva progresso próprio e compatibilidade.

Compartilhar busca, capas, cards e filtros quando útil. Manter formulários/progresso específicos: músicas não precisam de capítulos; séries exigem mais que um único estado assistido.

## Migração proposta

Antes de substituir coleções: inventariar dados/regras, definir versão de esquema, preparar backup e ensaio em ambiente separado, testar migração repetível e compatibilidade com clientes antigos, e documentar recuperação. A publicação da migração é uma etapa explícita, distinta da criação de seu código.

Trocar nome exibido não exige trocar IDs técnicos. Alterações de `applicationId`, bundle ID e projeto Firebase precisam de avaliação própria. A expansão deve preservar contas, livros, vínculos e capítulos lidos.

## Visibilidade e revogação atuais

COUPLE-04 acrescenta `isShared` opcional aos registros pessoais (ausente = visível), sem substituir IDs ou remover legado. `SharingService` publica projeções mínimas após releitura transacional; livros/Bíblia próprios permanecem privados. Salvar capítulos/livro conserva preferência e campos desconhecidos e sincroniza projeção; ocultar a remove atomicamente. A estante do parceiro consulta `shared_books`; comparação bíblica consulta `shared_bible_progress`. O feed combina streams pessoais e compartilhados separados, com cancelamento conjunto, e usa `activityAt` do servidor posterior ao aceite para atividades conjuntas. Estatísticas usam todo conteúdo permitido do período. `addedAt`/histórico imutável permanecem em DATA-06.

Builders usam identidade/relação como chave; detalhes abertos e capítulos acompanham revogação. Cache/offline alheio retira conteúdo; a apresentação do parceiro também exige confirmação de servidor. Bloqueio do parceiro ativo grava documento privado e término/versionamento em transação; o fluxo fora de vínculo foi implementado em COUPLE-09, conforme [registro 010](decisions/010-bloqueios-independentes.md). [Contrato completo](COUPLE_VISIBILITY.md) e [ADR 009](decisions/009-visibilidade-e-revogacao.md). Nenhuma mídia planejada foi implementada nem regra remota publicada.
