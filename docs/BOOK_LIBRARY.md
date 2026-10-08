# Livros: identidade, datas, histórico e filtros

DATA-06, BOOK-01 e BOOK-02 foram implementadas em 08/10/2026 na coleção atual `books`, preservando contas, Bíblia e IDs existentes. Não convertem a biblioteca para o modelo multimídia v1.

## Datas e atividades

Novos livros recebem `createdAt` e `updatedAt` do servidor. Atualizações preservam `addedAt` e `createdAt`; registros antigos sem criação comprovada mantêm `createdAt: null`. O `addedAt` legado pode ter sido alterado por versões antigas: congelá-lo agora não recupera a inclusão original.

Inclusão e mudança de status escrevem, na mesma transação, o livro, sua projeção permitida e um evento imutável em `books/{id}/activity/{eventId}`. O evento contém `userId`, `bookId`, `action`, `beforeStatus`, `status` e `occurredAt` do servidor. `latestActivityAt`, `activityEventId`, `activityStatus` e `activityAction` identificam a última atividade pessoal; `activityAt` controla a disponibilidade compartilhada. Ocultar/republicar preserva eventos e a última atividade privada, sem criar atividade retroativa.

O Início mostra a última atividade explícita de cada livro, usando o status registrado no evento e timestamp do servidor. Não reconstrói um evento a partir de `addedAt` ou do status atual. O histórico nos detalhes pessoais mostra até 100 atividades recentes; o parceiro não acessa essa subcoleção. Estatísticas continuam contando o estado atual Lido com `finishedDate` informada; inclusão de um livro já lido não inventa uma conclusão no dia do cadastro. O feed multimídia completo permanece em COUPLE-08.

Editar título, autores, capa ou data de conclusão atualiza o registro sem criar evento de status. Excluir o livro remove o registro/projeção; o Firestore não remove automaticamente as subcoleções. Retenção e exclusão integral desses eventos dependem da política SEC-05; não foi implementada uma limpeza administrativa.

## Referências e duplicatas

Novas referências Google Books usam identidade reversível com versão, proprietário, mídia e fornecedor, além do ID externo. Repetir a mesma referência retorna o registro confirmado pelo servidor, sem substituir status, datas ou metadados. Uma referência legada única conserva seu ID; duas referências legadas iguais geram aviso para revisão, sem fusão ou exclusão automática.

IDs externos distintos representam edições independentes, mesmo com título igual. Cada cadastro manual deliberado representa um registro independente; o diálogo prepara um ID aleatório uma vez e o conserva nas tentativas de salvar. Fechar e iniciar outro cadastro cria outra intenção. A política não deduplica por título/autor nem usa apenas o ID externo como ID pessoal. Disputas entre clientes atuais convergem para a mesma referência; clientes antigos com IDs aleatórios continuam exigindo revisão de compatibilidade antes da implantação.

BOOK-01 usa o caminho local de API-01. Não comprova restrições, quotas ou disponibilidade de uma chave real: a auditoria SEC-03 permanece pendente.

## Edição e filtros pessoais

O dono pode editar título, autores separados por ponto e vírgula e capa HTTPS opcional de registros manuais (`googleBooksId` ausente e `publishedDate: Manual`). Título é obrigatório e limitado a 500 caracteres; autores podem ficar vazios. A transação compara os metadados vistos ao abrir o formulário, preserva progresso/datas/preferência e rejeita correção concorrente. Escrita e releitura no servidor precedem o sucesso da interface.

Biblioteca → Buscar e filtrar combina palavras de título/autor sem distinção de caixa com a aba Lendo/Lidos/Quero ler e período inclusivo de inclusão ou conclusão. Datas de conclusão ausentes ficam fora do período; inclusão usa `addedAt` preservado, sujeito à limitação legada acima. Limpar filtros restaura os resultados. Filtros permanecem durante a sessão e são limpos ao trocar de conta. A estante alheia não oferece edição ou histórico privado. A filtragem atual é em memória; paginação e agregações na interface continuam em UI-05.

## Regras e preparação offline

Regras candidatas exigem evento e ponteiro atômicos nos registros modernos, timestamps do servidor e autoria própria. Eventos não permitem atualização/exclusão pelo cliente; consultas de histórico exigem propriedade do livro. Projeções contêm apenas o último marcador permitido, sem timestamps privados ou ID do evento. Terceiros, parceiro e ex-parceiro não recebem o histórico.

Clientes antigos que alteram `addedAt` ou escrevem status sem evento em registros modernos serão incompatíveis com essas regras. SEC-06 precisa coordenar a transição; não houve implantação de regras, índices, migração ou publicação.

O ensaio offline conserva a criação comprovada quando presente e desconhecida quando ausente. Subcoleções de atividades permanecem no backup e rollback, sem serem interpretadas como livros. Planos preparados pela versão anterior devem ser recalculados a partir do backup preservado; hashes antigos não autorizam aplicar um plano divergente. A conversão ativa continua separada.

Validação e limites de plataforma: [DEVELOPMENT.md](DEVELOPMENT.md). Jornada real do SDK web em emuladores: [WEB_VALIDATION.md](WEB_VALIDATION.md).
