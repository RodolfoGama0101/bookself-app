# Modelo de múltiplas mídias — DATA-01

## Estado, versão e limites

**Proposta técnica v1 consolidada em 08/10/2026**, com revisão contra o [MVP aprovado](PRODUCT.md#mvp-aprovado--prod-01), a [política do casal](COUPLE_POLICY.md), o [mapa de navegação](NAVIGATION.md) e os modelos/serviços atuais. Exemplos fictícios estruturados estão em [data-model/v1.examples.json](data-model/v1.examples.json). A validação documental e de invariantes dos exemplos não é implementação, teste de regras nem aprovação específica do esquema pelo usuário.

DATA-02 implementou localmente o subconjunto privado de catálogo, entrada e referência única, descrito abaixo. O restante continua proposto; não há contrato novo implantado em produção. `users`, `books`, `bible_progress`, convites, projeções, contatos e bloqueios atuais continuam funcionando com seus contratos. Substituição de dados legados depende do ensaio recuperável de DATA-03; implantação remota permanece em SEC-06.

Não escolhe marca, fornecedor audiovisual/musical, cache/licença de fornecedor, spoilers/reassistir/especiais, retenção ou exportação. Esses assuntos continuam em NAME, API-02/03/04, SERIES-01 e SEC-05. Os fornecedores `example_video` e `example_music` dos exemplos são fictícios; Google Books é a integração já existente.

## Entidades e fronteiras

**Atualização DATA-03/04/05 em 08/10/2026:** [ensaio de preparação](DATA_MIGRATION.md) preserva todo o legado numa área distinta de entradas ativas, sem decidir duplicatas/datas desconhecidas. [Consultas e sincronização](DATA_ACCESS.md) implementam páginas/agregações, índices versionados e estados de operação privada. Ainda não há conversão ativa, evento multimídia, ligação das consultas às telas ou implantação; referências a migração pendente neste documento dizem respeito à adoção, não à preparação já ensaiada.

### Subconjunto local implementado — DATA-02

`lib/data/models/media_model.dart` implementa as cinco mídias, identidade externa/manual, metadados, estado pessoal, catálogo e entrada. `MediaLibraryRepository` é substituível; `FirestoreMediaLibraryRepository` recebe Firestore injetado e usa exclusivamente `libraries/{ownerId}/{catalog|entries|reference_slots}`. A interface atual ainda usa `BookService`/`BibleService`: nenhuma nova categoria ou migração foi ativada.

`newCatalog` prepara ID opaco e, sem referência externa, identidade manual sem leitura/escrita. Conservar esse objeto ao repetir `save`; preparar outro significa nova inclusão manual deliberada. `save` cria os três documentos em transação ou devolve a entrada do slot existente, sem substituir catálogo/progresso. IDs de entrada são gerados fora do callback transacional. `readEntry`/`readCatalog` consultam o servidor; `save`/`updatePersonal` aguardam commit e leitura confirmada. Erros de rede/autorização são propagados; se a leitura falhar após commit, repetir `save` reencontra a entrada. Não anuncia sucesso com estado pendente do cache.

`updatePersonal` recebe estado completo, favorito e revisão esperada: rejeita `MediaRevisionConflict` quando a revisão mudou, sem sobrescrever o concorrente. Uma alteração efetiva incrementa revisão e timestamp; operação sem mudança preserva ambos. Conclusão/sessão sem data é válida; mudar para estado incompleto exige data nula. Favorito é exclusivo de música e não cria escuta. O cliente preserva erros de domínio mesmo quando o SDK web os reempacota.

O catálogo persiste também `catalogKey` derivado para cruzar catálogo/slot nas regras. Limite de **1.000 caracteres ASCII** na chave reversível, rejeitado antes de qualquer acesso; nunca truncado. IDs de documentos usados pelo repositório têm até 128 bytes UTF-8 e rejeitam caminhos/reservados. Metadados são snapshots imutáveis; `MediaMetadata.patch` omite para preservar e usa null para limpar. Leitura de opcional ausente equivale a null; escrita completa o explicita. Edição persistente de metadados/exclusão exige uma operação posterior coerente com slots, em BOOK-02 e fluxos por mídia; não há edição parcial genérica do banco.

As regras candidatas permitem somente o dono, inclusive consultas, e exigem criação atômica das referências. Catálogo/slot são imutáveis nesta etapa; entrada preserva dono/tipo/referência/criação e exige revisão +1. Campos desconhecidos, esquema futuro, autoria divergente e projeção nova são rejeitados. `isShared` é **false** e `legacyRef` null no subconjunto: compartilhar exige implementar projeções/transações/autorização antes de habilitar o padrão do produto nas novas telas. Episódios, escutas, relações/listas/experiências e eventos permanecem negados nas coleções propostas. As regras validam a estrutura de datas/listas; validação de calendário, elementos de autores/artistas, HTTPS e derivação Base64 completa ocorre no modelo. O dono pode forjar dados próprios usando outro cliente, mas isso nunca concede acesso à biblioteca alheia; a unicidade por identidade canônica é garantida pelas operações do repositório, não uma normalização de fornecedores feita no servidor.

Validação e limites em [DEVELOPMENT.md](DEVELOPMENT.md#base-privada-multimídia--data-02). Não cria cache global, fornecedor novo, dual-write, migração, projeção ou evento retroativo.

Separar entidades mesmo quando participam da mesma transação. Catálogo descreve a obra; entrada pessoal pertence a uma pessoa; progresso pertence à entrada; experiências e listas pertencem a uma relação identificada. Não há biblioteca pública nem coleção global de itens manuais.

| Entidade | Caminho proposto | Campos centrais e autorização |
| --- | --- | --- |
| `CatalogItem` | `libraries/{ownerId}/catalog/{catalogId}` | `schemaVersion`, `ownerId`, `identity`, `mediaType`, `metadata`, `fetchedAt`. Snapshot privado do catálogo ou metadados manuais, sem estado pessoal. |
| `LibraryEntry` | `libraries/{ownerId}/entries/{entryId}` | `schemaVersion`, `ownerId`, `catalogId`, `mediaType`, `state`, `isShared`, `favorite`, `createdAt`, `updatedAt`, `revision`, `legacyRef`. Somente o dono; favorito privado. |
| Referência única | `libraries/{ownerId}/reference_slots/{catalogKey}` | `schemaVersion`, `entryId`, `catalogId`. Criação transacional da entrada por referência; separação por dono. |
| `EpisodeProgress` | `libraries/{ownerId}/entries/{entryId}/episode_progress/{episodeKey}` | `schemaVersion`, `episodeRef`, `watched`, `watchedOn`, `updatedAt`, `revision`. Somente o dono; episódios separados para não regravar a série inteira. |
| `ListeningRecord` | `libraries/{ownerId}/listens/{listenId}` | `schemaVersion`, `ownerId`, `entryId`, `listenedOn`, `createdAt`, `updatedAt`, `revision`. Somente o dono; ID gerado uma vez por intenção de escuta. |
| `SharedEntry` | `shared_media/{entryId}` | Projeção mínima: `schemaVersion`, `ownerId`, `mediaType`, `selection`, `state`, `createdAt`, `updatedAt`, `sourceRevision`. Dono/parceiro recíproco atual. |
| Progresso permitido de episódio | `shared_media/{entryId}/episode_progress/{episodeKey}` | Somente referência mínima/progresso permitido, sem metadados de spoiler antes de SERIES-01. Acesso exige projeção-pai visível e vínculo ativo. |
| `CoupleRelationship` | `couple_relationships/{relationshipId}` | `schemaVersion`, dois `participantIds`, `status`, `startedAt`, `endedAt`, `origin`. Sem perfil privado; membros e transições compatíveis com o vínculo atual. |
| `CoupleList` e seleção | `couple_relationships/{relationshipId}/lists/{listId}/items/{listItemId}` | Lista com título/autoria/datas; cada item tem `addedBy`, `selection`, `addedAt`, `revision`. Ambos editam na relação ativa; histórico restrito aos membros antigos. |
| `CoupleExperience` | `couple_relationships/{relationshipId}/experiences/{experienceId}` | `schemaVersion`, `authorId`, `participantIds`, `selection`, `occurredOn`, `revision`, `responses`, `createdAt`, `updatedAt`. Confirmação individual por participante/versão. |
| `ActivityEvent` | `libraries/{ownerId}/activity/{eventId}` | `schemaVersion`, `actorId`, `mediaType`, `source`, `action`, `occurredAt`, `relationshipId`, `operationId`. Registro pessoal de transição, sem alterar a origem da entrada. |
| Atividade permitida | `couple_relationships/{relationshipId}/activity/{eventId}` | Projeção de atividade autorizada; não contém favorito/opinião/escuta pessoal. Acesso a eventos pessoais exige também visibilidade atual da entrada e relação ativa. |

`catalogId`, `entryId`, `listenId`, `listId`, `listItemId`, `experienceId` e `eventId` são IDs opacos gerados antes da primeira tentativa de escrita; retry conserva o ID. Não usar títulos, nomes de pessoas ou somente IDs de fornecedor como IDs pessoais. `entryId` deve ser globalmente único para o caminho da projeção; as regras vinculam a projeção ao dono e à entrada correspondentes. Os exemplos usam IDs legíveis exclusivamente para revisão.

Catálogo é privado por dono nesta primeira proposta: evita diretório de cadastros manuais e cache global dependente de fornecedor ainda não aprovado. Pessoas distintas podem ter snapshots da mesma identidade externa. Um cache reutilizável administrado pelo backend é alternativa posterior, sujeita a API-04; não é uma nova dependência do MVP. Atualização do catálogo não muda progresso, favorito, visibilidade ou datas da entrada.

## Identidade, duplicatas e cadastro manual

`mediaType` usa `book`, `movie`, `series`, `track` ou `album`. Bíblia conserva seu domínio separado. `identity` é discriminada:

- Externa: `{kind: external, provider, externalId}`. `provider` é namespace interno estável do adaptador aprovado; IDs externos são preservados exatamente, sem converter maiúsculas/minúsculas, cortar caracteres ou juntar fornecedores.
- Manual: `{kind: manual, ownerId, manualId}`. O ID manual é opaco e imutável; duas pessoas ou duas inclusões deliberadas não são deduplicadas por título/artista. Correção do título/capa não cria nova identidade.

`catalogKey` é Base64 URL-safe, sem padding, dos bytes UTF-8 de um array JSON compacto: `[1, mediaType, "external", provider, externalId]` ou `[1, mediaType, "manual", ownerId, manualId]`. A ordem é fixa e não contém espaços acrescentados pelo serializador. É uma codificação reversível da tupla, evitando ambiguidades por separadores. DATA-02 deve limitar tamanho antes de escrever e rejeitar referências incompatíveis com o caminho; nunca truncar a chave. O namespace `provider` precisa ser validado pelo adaptador; nomes fictícios só são usados nas fixtures.

| Situação | Tratamento definido na proposta |
| --- | --- |
| Mesmo dono salva repetidamente a mesma referência | Transação lê `reference_slots/{catalogKey}`; se já existir, retorna a entrada confirmada sem redefinir progresso ou datas. Disputa simultânea termina com uma entrada e um slot. |
| Duas pessoas salvam a mesma referência | Mesmo `catalogKey`, caminhos privados diferentes, `entryId` e progresso próprios. |
| Mesmo ID externo em fornecedores/tipos diferentes | Tuplas/chaves diferentes; nunca colidem por igualdade apenas de `externalId`. |
| Edições/versões com referências distintas | Entradas distintas; título semelhante não provoca fusão. |
| Nova inclusão manual | Nova identidade deliberada. Reenvio da mesma operação usa a identidade/ID já gerados e não duplica. |
| Associar cadastro manual a catálogo | Ação explícita futura; reler slots/entrada, preservar ID/progresso e resolver conflito antes de trocar referência. Não associar automaticamente. |
| Duplicatas já existentes em `books` | DATA-03 preserva documentos/IDs e registra conflitos; não apagar ou escolher um sobrevivente silenciosamente para preencher um slot. |

## Campos, datas e estados internos

Todos os novos registros persistidos têm `schemaVersion: 1`. `revision` é inteiro positivo, incrementado somente em alteração confirmada; operações com versão esperada antiga são relidas ou rejeitadas conforme a intenção. Autoria, dono, tipo e IDs de referência não mudam numa edição comum. Versão de esquema desconhecida não recebe defaults nem é regravada como v1; requer erro recuperável/cliente compatível.

Campos obrigatórios ausentes ou tipos incompatíveis tornam um registro novo inválido. Opcionais conhecidos usam `null` canônico na gravação completa; leitura de ausência equivale a `null`, sem presumir um valor. Em atualização parcial, omitir preserva e `null` limpa. Lista vazia confirmada é distinta de lista desconhecida (`null`). Nunca transformar metadado desconhecido em progresso zero confirmado. Campos legados desconhecidos permanecem em seus documentos originais até migração validada.

`createdAt` é instante UTC confirmado pelo servidor e imutável; `updatedAt` e `ActivityEvent.occurredAt` são instantes UTC do servidor da alteração. Datas escolhidas pela pessoa, como `finishedOn`, `watchedOn`, `listenedOn` e `occurredOn`, são datas civis `YYYY-MM-DD`, sem conversão por fuso. As fixtures representam instantes como strings ISO-8601; serialização real em Firestore usará timestamps, não essas strings de exemplo.

Uma data pessoal de conclusão/sessão pode ser desconhecida; isso não inventa evento nem entra em contagem por mês/ano. Escuta e experiência novas exigem data explícita. DATA-03 preserva datas antigas/futuras sem correção automática e guarda a origem: `books.addedAt` é mutável no código atual e não comprova a inclusão original. Quando essa origem não puder ser recuperada, `legacyRef` registra a limitação e a migração deve prever `createdAt` desconhecido, sem atribuir a data do ensaio ou de hoje. Essa exceção é de importação, não do cadastro novo v1.

| Mídia | `metadata` de catálogo | `state` pessoal e apresentação |
| --- | --- | --- |
| Livro | `title` obrigatório, `authors` lista (vazia permitida), `coverUrl` e `publishedDate` opcionais. `publishedDate` conserva a precisão conhecida (ano, ano/mês ou dia). | `{status: planned\|reading\|completed, finishedOn: data\|null}` → Quero ler/Lendo/Lido. Fora de `completed`, conclusão nula em nova alteração; legado preservado até tratamento explícito. |
| Filme | `title` obrigatório; `releaseYear`, `coverUrl` opcionais. | `{status: planned\|watched, watchedOn: data\|null}` → Quero assistir/Assistido. `planned` não mantém data de sessão numa nova alteração. |
| Série | `title` obrigatório; `releaseYear`, `coverUrl`, `productionStatus` opcionais; temporadas/episódios conhecidos são metadados separados. | `{status: in_progress\|up_to_date\|completed\|paused}` → Em andamento/Em dia/Concluída/Pausada. A disponibilidade de episódios e cálculo de status dependem de SERIES-01; não derivar concluída pela quantidade conhecida. |
| Faixa | `title` e `artists` não vazios; `albumTitle`, `version`, `durationMs`, `coverUrl` opcionais. | `state: null`, `favorite: bool` separado, escutas próprias em `ListeningRecord`. Salvar/favoritar não presume escuta. |
| Álbum | `title` e `artists` não vazios; `releaseYear`, `edition`, `coverUrl` opcionais; lista de faixas conhecida separada, com completude explícita. | `state: null`, `favorite: bool` separado, escutas próprias. Ouvir álbum não marca/salva suas faixas. |

`favorite` só é usado pelas novas telas musicais do MVP; outros registros novos usam `false`. Avaliações/opiniões não ganham formulário/esquema novo nesta etapa; campos privados legados não são descartados nem copiados para projeções.

`EpisodeProgress.episodeRef` identifica a série e um episódio estável do fornecedor, ou a série manual e um ID manual próprio. `episodeKey` codifica `[1, "episode", "external", provider, seriesExternalId, episodeId]` ou `[1, "episode", "manual", ownerId, seriesManualId, episodeManualId]` com o mesmo algoritmo de `catalogKey`. Números de temporada/episódio são atributos, não identidade exclusiva. Não reutilizar o capítulo 1 ou episódio 1 de duas temporadas como o mesmo registro. Novos episódios/metadados não removem progresso antigo. Identidade de especiais/reassistir e exposição de títulos de episódios precisam de SERIES-01 antes de serem implementadas.

Escutas intencionais repetidas têm IDs diferentes; o mesmo retry usa o mesmo `listenId`. Registro precisa referenciar entrada `track` ou `album` do próprio dono. Não importar escutas externas nem criar escuta automática por confirmação de experiência conjunta.

## Projeções, relação e consentimento

`SharedEntry.selection` é um snapshot mínimo com `mediaType`, identidade de origem autorizada, título, autores/artistas e imagem opcionais, sem `catalogId` privado, `favorite`, opinião, escutas, dados de conta ou campos desconhecidos. A preferência `isShared` permanece na entrada privada. Projeção é criada/atualizada/removida na mesma transação da intenção pessoal; conteúdo e `sourceRevision` precisam corresponder à fonte relida, com lista de campos permitidos validada no servidor.

Ao ocultar a série, remover sua projeção-pai bloqueia também todos os documentos filhos de progresso. Alteração de cada episódio mantém sua projeção mínima sincronizada mesmo enquanto inacessível; mostrar novamente publica o pai somente quando o conjunto tiver sido inicializado/verificado. Não confiar só na remoção de widgets nem exigir exclusão física de todos os episódios em um lote ilimitado. Paginação/ensaio de publicação completa fica em DATA-04 e autorização deve ser testada em SERIES-02/03.

`CoupleRelationship` não substitui os convites atuais. Para relações novas consentidas, a proposta reutiliza o `relationshipId` já gerado no aceite (código consumido), com participantes imutáveis, `origin: consented_invite`, `startedAt` do aceite e estado `active`/`ended`. O identificador persistido não é autorização de leitura nem convite reutilizável. Reciprocidade, `coupleEpoch`, bloqueios e convite terminal continuam sendo conferidos pelo servidor. Criar a projeção de relação deve fazer parte do aceite compatível; instância legada não ganha consentimento por ter `partnerUid`.

Relações antigas terão estratégia própria em DATA-03: conservar UID/IDs, registrar ausência de comprovação e não liberar novas experiências/listas até consentimento validado. Novo vínculo, mesmo entre as mesmas pessoas, tem novo ID e não herda dados. As coleções atuais de convites/perfis/bloqueios não são renomeadas por DATA-01.

| Conteúdo | Dono/participantes | Parceiro ativo | Após término / terceiro |
| --- | --- | --- | --- |
| Catálogo privado, entrada pessoal, favorito e escutas | Dono lê/escreve. | Nenhuma leitura direta. | Ex/terceiro sem acesso. |
| Obra/progresso projetados | Dono; parceiro recíproco consulta somente permitido. | Sem edição alheia; offline/cache não confirma acesso atual. | Ex/terceiro sem acesso pessoal, inclusive em filhos/queries/eventos. |
| Perfil/convites/contatos/bloqueios | Reutilizar contratos atuais e suas autorizações. | Não ampliar diretório ou campos privados. | Bloqueio próprio continua independente; convite antigo não revive. |
| Listas/experiências deliberadamente conjuntas | Somente os dois participantes da relação; autoria explícita. | Ações conforme política, sem alterar entradas pessoais. | Participantes antigos consultam seleção/histórico consentido; sem edição conjunta. Retirada da própria confirmação continua possível. Terceiro/novo parceiro sem acesso. |

Retenção/exclusão de conta não é definida aqui. Histórico é limitado a seleções consentidas, não uma cópia da biblioteca do ex. Uma referência pessoal em evento não concede acesso à fonte depois do término.

## Listas, experiências e eventos

`CatalogSelection` é um valor separado do catálogo privado: guarda metadados mínimos deliberadamente compartilhados e identidade da obra, sem progresso pessoal. `source: library|catalog|manual` informa a origem; `addedBy`/`authorId` registram quem compartilhou. Selecionar obra oculta para lista/experiência exige aviso explícito; não muda `isShared`. Números de episódio podem especificar o alvo, com referência estável; metadados de spoilers ficam sujeitos a SERIES-01.

Lista usa título/autoria/datas e itens separados, evitando regravar toda a lista em disputa. Cada inclusão tem ID próprio gerado uma vez; ambos retiram itens conforme política na relação ativa. Deduplicação por seleção na mesma lista, posição/ordenação e trilha de remoções precisam de COUPLE-06/DATA-04; não inferir que listas musicais são playlists externas.

Experiência tem exatamente os dois participantes da relação, imutáveis nessa instância. Mudar para outra pessoa exige outra relação/experiência e novo consentimento. `revision` identifica a versão de obra/data proposta pelo autor; `responses[uid]` guarda `{revision, decision: confirmed|declined|withdrawn, respondedAt}`. Somente a pessoa autenticada registra sua resposta. O autor confirma sua própria versão ao propor/corrigir; resposta antiga da outra pessoa continua no histórico, mas não confirma a versão nova.

Uma experiência é conjunta confirmada **somente se os dois participantes tiverem `decision: confirmed` para a revisão atual**. Estado agregado é derivado, não um `confirmed: true` editável unilateralmente. Correção de obra/data incrementa revisão; recusa/retirada retira a experiência das métricas conjuntas sem excluir nem alterar progresso, favorito ou escuta de qualquer participante. Na relação encerrada, somente retirar a própria confirmação é permitido; nova confirmação ou correção conjunta não reabre o vínculo. Autoria e transições precisam de histórico em COUPLE-05; o snapshot atual dos exemplos não substitui essa trilha.

Eventos pessoais registram transições efetivas (`entry_added`, `state_changed`, `episode_watched`, `episode_unwatched`, `listen_recorded`, `experience_confirmed`, `experience_confirmation_withdrawn`); favorito/escuta não são publicados no feed compartilhado. `source` inclui tipo/ID/revisão, e `operationId` é conservado em retry. Escrita de domínio e evento devem ser atômicas, para não anunciar atividade de uma alteração rejeitada nem duplicar um retry.

Feed pessoal e feed da relação são consultas distintas. Projeção compartilhada guarda a relação vigente no momento da ação e só publica atividades permitidas posteriores ao aceite; republicar catálogo/visibilidade não cria atividade retroativa. Ocultar entrada remove autorização também de seus eventos pessoais projetados; eventos de experiências/listas consentidas seguem a política própria de histórico. DATA-04/06 devem validar queries, paginação, índices e revogação, sem copiar uma coleção privada inteira para o cliente filtrar.

Estatísticas mantêm unidades por mídia. Uma experiência conta uma vez por `experienceId` confirmado na revisão atual, não uma vez por confirmação ou participante. Eventos de retirar/reconfirmar não são sessões adicionais. Estatísticas pessoais de estado/data e contagem de experiências conjuntas são conceitos separados; nenhuma experiência gera conclusão/escuta pessoal automaticamente.

## Compatibilidade e critérios para implementação

| Caso | Invariante / próxima validação |
| --- | --- |
| Livro legado lido sem data | Não inventar `finishedOn`, inclusão original ou evento histórico; preservar ID e campos. DATA-03/06. |
| Livro com `googleBooksId` | Identidade externa com namespace Google Books separado do ID pessoal; referência ausente não é inferida. DATA-02/03 e BOOK-01. |
| Bíblia | Não transformar livros bíblicos em obras de catálogo nem mover `bible_progress` nesta entrega; conservar IDs, limites, ocultação e capítulos. DATA-03/BIBLE-01. |
| Duas contas / fornecedor e mídia diferentes | Identidade isolada e IDs pessoais distintos, inclusive quando título ou ID externo coincidem. DATA-02/BOOK-01. |
| Duas inclusões concorrentes / retry | Slot/entrada/evento únicos para a mesma intenção; não restaurar progresso antigo. DATA-02/05/06. |
| Episódio novo / metadados incompletos | Progresso estável; desconhecido distinto de zero; status e spoilers dependem de SERIES-01. |
| Ocultação / término / resposta atrasada | Projetados inacessíveis; resposta antiga não modifica relação/versão nova; dados próprios conservados. Regras/QA-02 por mídia. |
| Correção / recusa / retirada de experiência | Dupla confirmação da revisão atual, autoria individual e contagem única; registros pessoais independentes. COUPLE-05/QA-03. |
| Clientes antigos e rollback | Ensaio de backup, contagens, compatibilidade e recuperação antes de substituir livros/vínculos. DATA-03; sem dual-write silencioso. |

## Validação desta proposta

Os grupos e campos `id`/contexto de caminho do JSON são um envelope didático para cruzar referências, não um arquivo importável de documentos Firestore. As projeções mostradas são exemplos selecionados, não uma publicação completa da biblioteca; slots e chaves de episódio têm caminhos derivados pelas tuplas especificadas acima. Nenhum campo extra desse envelope deve ser copiado para uma projeção consultável.

Exemplos JSON verificados localmente: parse, versão, referências catálogo→entrada→progresso/escuta, estados por mídia, identidade por fornecedor/tipo/dono manual, duas contas salvando a mesma obra com estados distintos, isolamento de campos privados na projeção, escutas intencionais separadas e revisão de dupla confirmação da experiência. A matriz acima foi revisada contra MVP/política/código. Links locais e diff verificados.

Essa validação consolida DATA-01 como especificação proposta; não comprova autorização, transações reais, índices, desempenho ou migração. DATA-02 pode implementar os tipos e serviços incrementais com esses invariantes, mantendo a persistência legada até DATA-03. Regras/coleções novas exigem seus próprios testes em emuladores antes de uso; SEC-06 continua separado. Não houve mudança Dart, dependência, regra ativa, banco remoto, build ou publicação.
