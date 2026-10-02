# Arquitetura

Revisão: 02/10/2026. As seções iniciais descrevem o código atual; a evolução ao final é uma proposta.

## Inicialização e interface atuais

`lib/main.dart` inicia a interface imediatamente com `AppStartup` (`lib/ui/screens/app_startup.dart`). Essa fronteira mantém os estados de carregamento, falha e sucesso da inicialização Firebase. Apenas após sucesso, seu `readyBuilder` registra `AuthService` e `ThemeService` em `MultiProvider` e cria `BookselfApp`. `SessionGate` decide entre login, carregamento, recuperação de perfil e `MainNavigation` conforme o estado explícito de sessão.

`MainNavigation` usa `IndexedStack` com Início, Estante, Bíblia e Perfil. Busca é acessada pela estante. Serviços de livros e Bíblia são instanciados nas telas; não há backend próprio versionado.

Falhas assíncronas e erros síncronos de configuração mantêm o app em uma tela recuperável com “Tentar novamente”, sem criar os serviços dependentes de Firebase. Há somente uma tentativa ativa; o resultado de uma operação após descarte não usa estado/contexto antigo. As telas iniciais usam fontes locais e não exibem o erro técnico. Não há modo local completo: inicializar o SDK não comprova acesso aos serviços remotos.

Os testes de `test/app_startup_test.dart` simulam sucesso, falha de rede, erro síncrono de configuração, recuperação, toques repetidos, descarte e tela de 320 × 480 com escala de texto 2. Não acessam Firebase de produção e não substituem validação em dispositivo nem testes de sessão/perfil.

## Sessão e recuperação de perfil

`AuthService.sessionState` distingue `restoring`, `signedOut`, `loadingProfile`, `ready`, `missingProfile`, `profileError` e `authError`. Sessão autenticada e perfil disponível são informações separadas: o login só aparece em `signedOut`, e a biblioteca só abre em `ready`. A restauração e a primeira leitura de perfil têm limite de espera de 15 segundos; erro/timeout permite nova tentativa, e uma resposta válida posterior ainda pode recuperar o estado.

`UserProfileService` centraliza a leitura dos perfis e sua criação após cadastro ou recuperação. A ausência de documento apenas no cache não confirma um perfil ausente; escritas locais pendentes não liberam a biblioteca como se estivessem confirmadas. Um perfil existente em cache, sem escrita pendente, pode ser usado. Erros de leitura/serialização mostram recuperação, sem iniciar criação automática.

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
| Perfil | `lib/services/user_profile_service.dart` | Leitura de perfis e criação transacional sem sobrescrever documentos existentes. |
| Livros | `lib/services/book_service.dart` | Google Books, persistência e streams de estante/feed. |
| Bíblia | `lib/services/bible_service.dart` | Progresso e marcação de capítulos com transação. |
| Tema | `lib/services/theme_service.dart` | Alternância em memória, com modo escuro inicial. |
| Interface | `lib/ui/` | Formulários, navegação, estatísticas e exibição. |
| Erros | `lib/utils/error_handler.dart` | Conversão parcial de erros para português. |

`ProfileScreen` escreve nome/foto diretamente no Firestore. Fotos são reduzidas e armazenadas como data URI Base64 no perfil; o código atual não usa Firebase Storage.

## Dados no Firestore

| Coleção e ID | Campos principais | Uso |
| --- | --- | --- |
| `users/{uid}` | `uid`, `name`, `email`, `partnerUid`, `photoUrl`, `createdAt` | Perfil e ligação ao parceiro. |
| `books/{documentId}` | `userId`, `title`, `authors`, `coverUrl`, `status`, `publishedDate`, `finishedDate`, `addedAt` | Livro na estante de uma pessoa. |
| `bible_progress/{uid_nomeNormalizado}` | `userId`, `bookName`, `readChapters`, `updatedAt` | Capítulos lidos por pessoa/livro bíblico. |

Inclusão pela busca e formulário manual força um ID vazio para criar documento próprio. `BookService.saveBook` aceita IDs existentes para atualizar. O ID do Google Books não é mantido em campo próprio no documento, dificultando detecção de duplicatas e reconciliação de catálogo.

O feed consulta livros de uma ou duas pessoas, ordenados por `addedAt` no cliente. Alterações de status também atualizam esse campo: ele representa inclusão e última atividade. Não há histórico separado de eventos. Estatísticas mensais/anuais usam o estado atual `Lido` e `finishedDate`.

## Vínculo e autorização atuais

O código de vínculo é o UID da outra conta. `linkPartner` consulta o perfil, verifica o vínculo do destinatário e atualiza ambos os perfis com batch. Não existe convite pendente, aceite ou validação transacional das duas contas para evitar vínculos concorrentes. Desvinculação também escreve nos dois perfis.

A estante do parceiro aparece sem controles de edição. Não é possível concluir pelo repositório se o banco remoto impede acesso indevido: regras e índices não estão versionados. Essa autorização precisa ser auditada e testada em emuladores.

## Limitações observadas

- `BookModel.copyWith` usa `??`, impossibilitando limpar `finishedDate` com `null`.
- Algumas operações assíncronas podem chamar `setState` depois do fechamento da tela.
- Marcação bíblica não aguarda persistência antes de anunciar sucesso/finalizar a interação.
- Falhas de busca recebem mensagem genérica de cota/indisponibilidade.
- Estante/feed não têm paginação; ordenação e estatísticas ocorrem em memória.
- Tema não persiste. Imagens e serviços externos requerem avaliação de uso sem rede.

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
