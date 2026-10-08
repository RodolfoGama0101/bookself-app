# Consultas e sincronização — DATA-04/DATA-05

Implementação local de **08/10/2026**, substituível por fakes e com Firestore injetável. A interface atual conserva os streams de `BookService`/`BibleService`; ainda não usa estas páginas. A ligação às novas telas pertence à UI-01. Esta entrega não adiciona mídias, feed de eventos futuro, cache de fornecedor ou fila de sincronização offline.

## Paginação e estatísticas

`LibraryQueryRepository`/`FirestoreLibraryQueryRepository`, em `lib/services/library_query_service.dart`, oferecem:

| Operação | Filtro e ordenação | Métrica |
| --- | --- | --- |
| `readMediaPage` | Biblioteca privada por dono; mídia opcional; `createdAt desc`, ID desc. | `countMedia` por mídia/estado, sem cursor ou limite. |
| `readBookPage` | `books` pessoais ou `shared_books` permitidos, sempre filtrando dono; `addedAt desc`, ID desc. | `countBooks` por estado, sem carregar os documentos. |
| `readBookPage(activitySince: ...)` | Atividade a partir do início capturado da relação; `activityAt desc`, ID desc. | Não presume eventos históricos ausentes. |
| `countBooks` com período | Estado Lido obrigatório, conclusão em `[finishedFrom, finishedBefore)`. | Lidos sem data são contados no total por estado, fora dos períodos. |

Páginas entre 1 e 100 itens (padrão 20) leem no máximo limite + 1 documentos para detectar término; o cursor aponta o último item entregue, não o extra. Timestamp e ID desempatem datas iguais e permitem continuar mesmo se o documento anterior for removido. O cursor inclui dono/tipo/coleção/início do feed; reutilização em outra consulta é recusada antes da leitura. Páginas usam `Source.server` e rejeitam metadata de cache/escrita pendente. Erros e ausência de autorização são propagados.

Contagens usam agregação `count()` no servidor, independente da página carregada. Total e páginas são leituras diferentes, sem snapshot atômico entre ambas. Inclusões, remoções e alterações podem mudar resultados entre requisições; atualizar/recomeçar a consulta revela itens novos acima do cursor. A ordem privada multimídia usa criação imutável. No legado, `addedAt`/`activityAt` podem mudar: não se promete snapshot consistente de todas as páginas durante edição. Troca de relação/ocultação exige limpar páginas previamente carregadas, como os controles atuais de visibilidade já fazem; um cursor nunca concede autorização.

Para feed do casal, consultar somente o dono e o parceiro atual separadamente, usando o mesmo início de relação e ordenação; mesclar apenas os resultados autorizados e conservar cursor/buffer de cada origem. Não usar a página parcial como fonte das estatísticas. O repositório desta entrega fornece as consultas por origem; a composição paginada da interface será feita na UI-01/COUPLE-08. Atividades multimídia ainda dependem de DATA-06 e não têm queries liberadas.

`firestore.indexes.json` versiona oito índices: mídia/criação e mídia/estado para entradas; dono/inclusão, dono/atividade e dono/estado/conclusão para livros pessoais e projeções. Índices de campo único cobrem ordenação sem filtro de mídia e filtros isolados. O arquivo é usado pelos emuladores; índices não foram implantados. O emulador verifica execução/autorização, mas não reproduz a exigência de todos os índices de produção. Revisar/criar índices no ambiente de desenvolvimento e aguardar construção antes de ativar estas consultas remotamente.

Ordenação Firestore exclui documentos sem o campo ordenado. Entradas novas sempre possuem criação; um livro legado sem `addedAt` ou atividade não pode ser convertido para uma data presumida. O inventário de DATA-03 identifica a origem e preserva esses documentos; os streams atuais continuam disponíveis durante a transição. [Cursores oficiais](https://firebase.google.com/docs/firestore/query-data/query-cursors), [agregações oficiais](https://firebase.google.com/docs/firestore/query-data/aggregation-queries).

## Estados e operações de sincronização

`MediaSyncService` coordena o repositório privado multimídia: `idle`, `pending`, `confirmed`, `failed`, `conflict`. Selecionar dono/logout limpa dados/erro/intenção e invalida resultados antigos; `dispose` invalida notificações tardias. Uma operação pendente bloqueia outra na mesma instância. A instância pertence à sessão, precisa acompanhar mudanças de UID e ser descartada pelo chamador.

`save` captura o catálogo já preparado; retry usa o **mesmo objeto/identidade manual**. Confirmação exige o repositório terminar commit e leitura de servidor. `update` captura entrada/revisão/estado: conflito exige `reload` e nova intenção explícita; retry automático nunca substitui a revisão concorrente. Se a rede falhar depois de um commit, repetir inclusão reencontra o slot; repetir edição pode resultar em conflito da revisão, então recarregar antes de decidir. Uma escrita iniciada não pode ser cancelada por descartar a tela; apenas seu resultado visual é invalidado. Novo dono não herda resultado/intenção anterior.

Estado pessoal previamente confirmado pode continuar disponível enquanto outra alteração está pendente/falha; só `confirmed` sinaliza a confirmação da intenção atual. O serviço não apresenta mensagens nem registra erros brutos. Interfaces devem usar `ErrorHandler` e os estados, oferecendo nova tentativa/releitura; não exibir `error.toString()`. Ainda não há uma tela multimídia conectada ao coordenador.

| Operação atual | Cache/offline, confirmação e conflito |
| --- | --- |
| Perfil, nome/foto | `UserProfileService`/`PartnerProfileService` centralizam transações e projeção; patches por campo preservam nome/foto concorrentes. Sessão distingue perfil pendente/ausente/falha. Não há escrita Firebase em widgets. |
| Livros pessoais | `BookService` aguarda transação e espelha visibilidade; streams pessoais podem emitir cache em memória/escrita pendente. UI não anuncia sucesso antes da future. Edição completa usa o último commit; não há revisão otimista legada. |
| Bíblia | `BibleService` valida e aguarda; capítulos confirmados e transações evitam inverter um stream atrasado. Interface bloqueia ações concorrentes no livro e permite repetir a mesma intenção. |
| Visibilidade e legado | `SharingService` relê origem/preferência em transação e mantém projeção coerente. Retry não reativa ocultos; publicação legada falha sem impedir uso pessoal e pode ser repetida. |
| Convite, vínculo e bloqueio | Serviços transacionais com versão/estado terminal; ações antigas/conflitantes são recusadas. Interface espera servidor, limpa retorno de sessão antiga e não enfileira aceite offline. |
| Conteúdo do parceiro | Perfil/estante/Bíblia compartilhados exigem confirmação, retiram dados de cache/offline e cancelam streams após término/ocultação. Não reutilizar último conteúdo alheio como autorização. |
| Biblioteca multimídia | Repositório server-only, identidade estável, revisão otimista; coordenador desta entrega explicita pendência/falha/conflito. Nenhuma projeção multimídia foi liberada. |
| Tema e catálogo externo | Tema é armazenamento local aguardado, independente do UID; catálogo tem timeout/paginação/retry, sem fila de escrita ou cache persistente novo. |

Inicialização já desabilita persistência Firestore e limpa cache antigo antes dos serviços (COUPLE-04). Isso não elimina cache em memória, cópias externas ou dados entregues em versões antigas. Não há fila própria durável ou promessa de confirmação offline. Uma transação offline falha; escritas SDK que ainda aguardem rede permanecem pendentes até resposta. Resolução uniforme por revisão não é retroativamente aplicada ao contrato legado.

DATA-05 consolida acesso centralizado e a estratégia por operação; novos widgets devem usar estes serviços/repositórios. Execução nativa e proteção remota continuam nas tarefas QA/REL/SEC; novas mídias não ganham compartilhamento por existirem tipos privados. [Evidências](DEVELOPMENT.md#preparação-paginação-e-sincronização--data-030405), [migração](DATA_MIGRATION.md).
