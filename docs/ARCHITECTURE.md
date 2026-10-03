# Arquitetura

Revisão: 03/10/2026. As seções iniciais descrevem o código atual; a evolução ao final é uma proposta.

## Inicialização e interface atuais

`lib/main.dart` inicia a interface imediatamente com `BookselfBootstrap`. Ele cria e mantém `ThemeService` na raiz, iniciando a leitura da preferência antes de registrar os ouvintes do Provider. `AppStartup` (`lib/ui/screens/app_startup.dart`) mostra carregamento enquanto aguarda essa leitura e a inicialização Firebase. Apenas após sucesso do Firebase, seu `readyBuilder` registra `AuthService` e cria `BookselfApp`. `SessionGate` decide entre login, carregamento, recuperação de perfil e `MainNavigation` conforme o estado explícito de sessão.

`MainNavigation` usa `IndexedStack` com Início, Estante, Bíblia e Perfil. Busca é acessada pela estante. Serviços de livros e Bíblia são instanciados nas telas; não há backend próprio versionado.

Falhas assíncronas e erros síncronos de configuração mantêm o app em uma tela recuperável com “Tentar novamente”, sem criar os serviços dependentes de Firebase. Há somente uma tentativa ativa; o resultado de uma operação após descarte não usa estado/contexto antigo. As telas iniciais usam fontes locais e não exibem o erro técnico. Não há modo local completo: inicializar o SDK não comprova acesso aos serviços remotos.

Os testes de `test/app_startup_test.dart` simulam sucesso, falha de rede, erro síncrono de configuração, recuperação, toques repetidos, descarte e tela de 320 × 480 com escala de texto 2. Não acessam Firebase de produção e não substituem validação em dispositivo nem testes de sessão/perfil.

## Sessão e recuperação de perfil

`LoginScreen` envia a senha integralmente a `AuthService`, que a repassa ao Firebase Authentication sem normalização. A mesma validação local de pelo menos seis caracteres é usada no login e no cadastro; espaços contam como caracteres e não são removidos. Isso preserva a regra existente do formulário; a aceitação das credenciais e a política remota continuam sob responsabilidade do Firebase. Nome/e-mail mantêm o tratamento anterior. `test/login_password_test.dart` verifica os dois fluxos até o SDK substituto, limites de tamanho, correção após erro de validação e alternância de visibilidade, sem usar contas reais.

`AuthService.sessionState` distingue `restoring`, `signedOut`, `loadingProfile`, `ready`, `missingProfile`, `profileError` e `authError`. Sessão autenticada e perfil disponível são informações separadas: o login só aparece em `signedOut`, e a biblioteca só abre em `ready`. A restauração e a primeira leitura de perfil têm limite de espera de 15 segundos; erro/timeout permite nova tentativa, e uma resposta válida posterior ainda pode recuperar o estado.

`UserProfileService` centraliza leitura, edição de nome/foto e criação dos perfis após cadastro ou recuperação. A ausência de documento apenas no cache não confirma um perfil ausente; escritas locais pendentes não liberam a biblioteca como se estivessem confirmadas. Um perfil existente em cache, sem escrita pendente, pode ser usado. Erros de leitura/serialização mostram recuperação, sem iniciar criação automática.

Quando o servidor confirma ausência, a pessoa pode informar o nome, verificar novamente ou sair. `createIfMissing` lê `users/{uid}` em transação: cria o documento somente quando ausente e retorna o perfil existente sem atualizar qualquer campo, inclusive campos legados desconhecidos. O UID e e-mail vêm da sessão autenticada; não se cria outra conta para recuperar o perfil. O cadastro usa o mesmo caminho e mantém a sessão caso a etapa Firestore falhe.

Login, cadastro e criação/recuperação de perfil têm limite de espera de 15 segundos na interface. Esse limite não cancela a operação do SDK: uma conta ou escrita pode ser confirmada mais tarde, sendo observada pelos streams; a pessoa pode precisar informar o nome novamente. A recuperação é repetível e só libera o perfil após leitura sem escrita pendente ou confirmação da transação. Nenhuma migração ou mudança de esquema/regras foi feita; regras que rejeitem a operação continuarão produzindo erro recuperável.

A assinatura de autenticação é guardada. Troca de conta, logout, perfil indisponível e mudança de parceiro cancelam os ouvintes correspondentes e limpam o estado anterior; `dispose` encerra autenticação, perfil, parceiro e timer. Revisões das assinaturas impedem que eventos/resultados antigos substituam o estado da sessão atual. Atualizar o próprio perfil sem mudar parceiro não recria a assinatura dele.

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

`ProfileScreen` aguarda `UserProfileService.updateName/updatePhoto` antes de anunciar sucesso. As atualizações mantêm os mesmos campos e usam `update`, sem recriar perfis ausentes ou sobrescrever outros campos. Fotos são reduzidas e armazenadas como data URI Base64 no perfil; o código atual não usa Firebase Storage.

## Mensagens de erro e diagnósticos

`ErrorHandler` reconhece códigos de Authentication/Firestore, exceções tipadas de conexão/timeout/dados e permissões de câmera/fotos. Os textos são definidos pelo app; mensagens, `details`, URLs, stack traces e `toString()` de erros externos não compõem o feedback. Códigos desconhecidos usam fallback em português. `failed-precondition` não revela índices ou configuração do banco. Credenciais inválidas têm orientação comum no login; recuperação de senha com conta ausente orienta conferir o endereço, sem pedir senha.

`getFriendlyErrorMessage` também registra diagnóstico; `report` registra falhas sem criar texto de interface, como inicialização, leitura do parceiro e capas. Os logs usam `ErrorOperation` e categorias/códigos permitidos; um código externo desconhecido vira `unknown`, e status HTTP só aparece como número entre 400 e 599. Não se registram mensagens externas, dados da conta, títulos, consultas, chaves, URLs ou stack. Falhas retornadas pelo SDK podem conter esses dados, por isso a classificação não depende de buscas em sua descrição. Logs internos de SDKs/plataforma ficam fora desse contrato do código do app.

Autenticação, recuperação de perfil, vínculo/desvínculo, saída, livros, feed, perfil e Bíblia usam essa fronteira. O cadastro parcial mantém o aviso de conta criada e acrescenta a orientação da falha de perfil. Sair da conta tem feedback tanto no perfil quanto na recuperação de sessão; retornos após descarte não acessam o contexto antigo.

`BookService` lança `CatalogRequestException` com apenas o status HTTP nas respostas sem sucesso. Falhas de conexão/JSON preservam seu tipo até o tratamento da interface; os logs brutos de busca/persistência foram removidos. A busca apresenta a orientação correspondente e mantém o atalho de cadastro manual. O cliente HTTP pode ser injetado para simular respostas; quem o injeta é responsável por fechá-lo. O transporte padrão continua usando `http.get`, sem mudança de dependências ou credenciais.

`test/error_handler_test.dart`, `test/auth_errors_test.dart`, `test/book_search_errors_test.dart` e `test/error_ui_test.dart` têm 52 regressões de tradução, diagnóstico, serviços e interface. Usam credenciais fictícias e HTTP/Firebase substitutos; verificam códigos desconhecidos, descrição externa que não pode ser impressa, ausência de dados pessoais no diagnóstico, permissões, timeout, cadastro parcial, vínculo/desvínculo e feedback em login, recuperação, busca, resumo bíblico pessoal/do parceiro e saída. A suíte completa tem 207 testes passando; análise com 38 infos preexistentes. Compilação web e verificação preliminar Wasm passaram; execução real em navegador/dispositivo e serviços remotos continuam em QA/REL/SEC.

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

Streams de livro e resumo usam `includeMetadataChanges: true` e ignoram snapshots com `hasPendingWrites`. Assim, uma alteração apenas local não aparece como progresso confirmado, e a confirmação que muda somente metadata ainda é entregue. Dados de cache sem escritas pendentes podem ser apresentados; isso não comprova uma leitura recente do servidor nem muda a política de autorização.

A tela de capítulos mantém uma assinatura do dono e, quando há vínculo, uma do parceiro. Enquanto aguarda uma escrita, mostra “Salvando progresso…” e bloqueia capítulos e lote, inclusive callbacks repetidos antes do próximo frame. O capítulo acionado também mostra carregamento no próprio botão. Sucesso aparece depois da confirmação. Rejeição/indisponibilidade mostra aviso com “Repetir” na área ativa mesmo longe do topo e deixa o erro visível e libera nova tentativa da mesma intenção; não há alteração otimista feita pela tela. Uma nova ação limpa o erro anterior. A grade e as mensagens compartilham uma rolagem para permitir acesso à recuperação em telas pequenas com texto ampliado.

Falha na leitura do próprio progresso impede escritas até recuperação; falha na comparação do parceiro não impede progresso pessoal. Fechar a tela cancela os ouvintes e ignora retornos de escritas já iniciadas. Trocar os parâmetros de dono/livro/serviço renova assinaturas e descarta resultados da identidade anterior. Mudar somente o parâmetro de parceiro atualiza sua assinatura e mantém o bloqueio da escrita pessoal em curso.

Escritas já iniciadas não são canceladas pelo fechamento. Não há timeout que trate uma escrita ainda pendente como rejeitada: o SDK pode manter o lote pendente sem conexão e confirmar após reconexão; a tela continua aguardando. A estratégia mais ampla de offline/cache e conflitos entre dispositivos continua em DATA-05. A mudança não valida regras remotas nem torna a comparação visual um controle de acesso.

`test/bible_service_test.dart` tem 11 testes de contratos de persistência/streams; `test/bible_screen_test.dart` tem 21 testes de confirmação, falhas, repetição, marcação/desmarcação, descarte, capítulo 100 de Salmos e tela pequena. Usam futures controladas, fakes Firestore e fontes locais de teste compartilhadas com as regressões da CORE-05. As exceções de análise para APIs `sealed` ficam nas cinco declarações do dublê `test/support/bible_firestore_fake.dart`. A repetição da transação por conflito é simulada; concorrência real, regras e funcionamento em dispositivo precisam de emuladores/QA.

## Dados no Firestore

| Coleção e ID | Campos principais | Uso |
| --- | --- | --- |
| `users/{uid}` | `uid`, `name`, `email`, `partnerUid`, `photoUrl`, `createdAt` | Perfil e ligação ao parceiro. |
| `books/{documentId}` | `userId`, `title`, `authors`, `coverUrl`, `status`, `publishedDate`, `finishedDate`, `addedAt` | Livro na estante de uma pessoa. |
| `bible_progress/{uid_nomeNormalizado}` | `userId`, `bookName`, `readChapters`, `updatedAt` | Capítulos lidos por pessoa/livro bíblico. |

Inclusão pela busca e formulário manual força um ID vazio para criar documento próprio. `BookService.saveBook` aceita IDs existentes para atualizar. O ID do Google Books não é mantido em campo próprio no documento, dificultando detecção de duplicatas e reconciliação de catálogo.

O feed consulta livros de uma ou duas pessoas, ordenados por `addedAt` no cliente. Alterações de status também atualizam esse campo: ele representa inclusão e última atividade. Não há histórico separado de eventos. Estatísticas mensais/anuais usam o estado atual `Lido` e `finishedDate`.

No Início, `StreamBuilder` recebe `BookService.streamCoupleFeed`, baseado em snapshots do Firestore, e recalcula cartões e contagens a cada emissão. O gesto de atualização manual com callback vazio foi removido; a rolagem usa o comportamento padrão da plataforma. Não há consulta forçada ao servidor nem confirmação de sincronização ao arrastar. `HomeScreen` aceita um serviço substituto para testar esse fluxo sem acesso remoto. `test/home_feed_test.dart` verifica inclusões/remoções, mudanças de status e estatísticas das duas pessoas, ausência de indicador de atualização no gesto e cancelamento da assinatura ao descartar a tela.

### Cópia e limpeza de campos opcionais

Em `BookModel.copyWith`, omitir `finishedDate` preserva a conclusão; passar `null` limpa o campo, e passar `DateTime` substitui a data. `UserModel.copyWith` usa a mesma semântica para `partnerUid` e `photoUrl`, com valores `String`. Os argumentos usam `Object?` com um marcador privado para distinguir omissão de `null`; casts rejeitam tipos incompatíveis em execução. Os demais campos mantêm a semântica anterior de cópia. `BibleProgressModel` não possui campos anuláveis e não exige esse marcador.

Os detalhes do livro já enviam `finishedDate: null` ao mudar de `Lido` para `Lendo` ou `Quero Ler`; o atalho “Começar leitura” também limpa a data explicitamente. `copyWith` não deduz limpeza somente pelo status: outros chamadores que mudem o livro para um estado não concluído devem informar `finishedDate: null`. Cópias para alterar título/ID preservam a conclusão quando o argumento é omitido.

`toMap` mantém as mesmas chaves e representa campos limpos como `null`, permitindo que a escrita existente de `BookService` remova o valor anterior. A limpeza de `partnerUid` no modelo não altera por si só o vínculo no banco nem substitui seu fluxo de autorização. Não há migração ou limpeza automática de registros antigos. Os testes `test/book_model_test.dart` e `test/user_model_test.dart` cobrem preservação, limpeza, substituição, serialização e compatibilidade com campos ausentes. Visibilidade de livros lidos legados sem data e regras de edição de conclusão continuam em CORE-11.

## Vínculo e autorização atuais

O código de vínculo é o UID da outra conta. `linkPartner` consulta o perfil, verifica o vínculo do destinatário e atualiza ambos os perfis com batch. Não existe convite pendente, aceite ou validação transacional das duas contas para evitar vínculos concorrentes. Desvinculação também escreve nos dois perfis.

A estante do parceiro aparece sem controles de edição. Não é possível concluir pelo repositório se o banco remoto impede acesso indevido: regras e índices não estão versionados. Essa autorização precisa ser auditada e testada em emuladores.

## Limitações observadas

- Estante/feed não têm paginação; ordenação e estatísticas ocorrem em memória.
- Imagens e serviços externos requerem avaliação de uso sem rede.

As tarefas correspondentes estão em [BACKLOG.md](../BACKLOG.md).

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
