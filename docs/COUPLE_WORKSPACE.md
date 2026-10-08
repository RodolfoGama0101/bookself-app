# Listas, experiências e interesses do casal — COUPLE-05/06/07

Implementação local em **08/10/2026**, acessível por **Nós → Listas e experiências**. Usa a [política aprovada](COUPLE_POLICY.md); regras candidatas ainda dependem de SEC-06. Não implementa catálogos/bibliotecas individuais de filmes, séries ou música, nem escolhe fornecedores.

## Consentimento, seleção e histórico

O convite aceito em `partner_invites/{relationshipId}` é a prova imutável dos dois participantes. Não é criado um documento-pai novo para a relação: suas subcoleções usam esse ID e as regras verificam o convite, a reciprocidade atual e bloqueios. Vínculos legados sem convite aceito não habilitam operações conjuntas; não são convertidos nem migrados. Novo aceite tem outro ID e não herda conteúdo anterior.

`CoupleSelection` contém somente mídia, título, autor/artista opcional, origem, referência opcional e episódio opcional. Faixas/álbuns exigem artista. A tela inicial oferece cadastro manual para as cinco mídias; `library`/`catalog` são origens suportadas pelo contrato, para os futuros seletores. Uma seleção deliberada fica visível aos dois mesmo se o registro pessoal estiver oculto. O aviso vem antes de salvar; não há leitura, cópia ou alteração automática de estado, favorito, opinião ou escuta pessoal.

Experiências de episódio podem informar temporada e número, com ID manual estável gerado uma vez; correção que muda o alvo prepara outro ID. Não compartilham título do episódio nem calculam progresso. Regras de séries pessoais, especiais de fornecedor, disponibilidade e spoilers da comparação continuam em SERIES-01/02/03. Mudar de participante exige outra relação/proposta.

`users/{uid}/couple_history/{relationshipId}` é um índice privado criado para os dois participantes na primeira operação conjunta. Contém somente ID da relação e data de criação; nunca um diretório público. A tela identifica os participantes pelos nomes do convite aceito. Não inclui relações legadas nem faz backfill de dados pessoais.

Após término/bloqueio, os participantes antigos continuam consultando seleções e experiências consentidas dessa relação. Novas inclusões, remoções, correções, confirmações e recusas exigem relação ativa. Retirar a própria confirmação permanece permitido. O novo parceiro e terceiros não consultam o histórico. Acesso offline/cache não é confirmado: erro retira o conteúdo, com atualização explícita para recuperação. Prazo de retenção, exportação e exclusão de conta permanecem em SEC-05; não há promessa de retenção perpétua.

## Experiências e revisões

`couple_relationships/{rid}/experiences/{id}` contém versão de esquema, autor, dois participantes imutáveis, seleção, data civil `YYYY-MM-DD`, revisão da proposta, respostas individuais, criação/atualização do servidor e versão do documento.

- O autor confirma sua versão ao propor/corrigir. Só ele corrige seleção/data; a revisão aumenta, conservando a resposta anterior do outro participante sem tratá-la como aceite novo.
- Cada pessoa confirma, recusa ou retira somente sua resposta. Resposta inclui revisão, decisão e timestamp do servidor.
- A experiência conta **uma vez por ID**, somente quando ambos confirmam a revisão atual. Não há campo agregado que uma pessoa possa forjar para confirmar pelo parceiro.
- `version` aumenta em toda alteração, inclusive resposta. Transações exigem versão esperada; conflito requer releitura e outra intenção, sem sobrescrever alteração concorrente. O erro de domínio também é preservado quando o SDK web reempacota exceções.
- Cada escrita exige snapshot imutável em `history/{version}` na mesma transação. As regras negam alterar/apagar a trilha ou escrever a experiência sem auditoria correspondente. A trilha pode ser consultada pelos participantes pelo serviço/banco autorizado; a tela mostra o estado e revisão atuais.

Datas novas são obrigatórias e validadas como calendário até hoje pelo cliente. As regras limitam estrutura/campos/identidade/transições; não substituem toda validação de calendário do modelo. Correção, recusa, retirada e reconfirmação nunca geram escuta ou conclusão pessoal. A contagem na tela é específica de experiências; não é adicionada às estatísticas de livros nem ao feed atual (COUPLE-08).

## Listas, autoria e repetição

`couple_relationships/{rid}/lists/{listId}` contém título, autor, timestamps e versão. Ambos adicionam seleções independentes em `items/{itemId}`. A inclusão preserva `authorId`, origem e criação; ambos podem retirar durante a relação ativa. A retirada é uma marca `removed: true`, com `removedBy`, atualização e versão incrementada: conserva autoria e impede que uma requisição atrasada restaure o item. A tela oculta retirados; o histórico autorizado conserva a marca de remoção. Não há exclusão física automática.

IDs de lista, item e experiência são preparados antes da primeira escrita. A ação **Repetir alteração** conserva a mesma intenção/ID; retry de criação reencontra o documento do autor sem redefinir conteúdo. Repetir retirada/correção com versão antiga produz conflito. Inclusões simultâneas em itens diferentes não regravam toda a lista; duas retiradas da mesma versão têm um vencedor. Nova inclusão deliberada é outro ID, inclusive para título semelhante: não há fusão por título nem deduplicação automática entre mídias/fornecedores. Listas são internas; não são playlists externas.

## Verificação e ativação

### Interesses em comum — COUPLE-07

No vínculo ativo, abrir uma lista mostra as seleções incluídas independentemente pelos dois. `commonCoupleSelections` compara mídia, origem, referência, título/autor/artista (somente caixa e espaços normalizados) e temporada/episódio quando existentes. Retirados, terceiros e inclusões repetidas por uma única pessoa não contam. Seleções semelhantes não são fundidas no banco; referências/edições diferentes não são tratadas como iguais. A tela explica o motivo e a incerteza da coincidência por texto.

O botão **Destacar próxima opção** percorre as coincidências em ordem de mídia/título para apoiar uma conversa. Não faz sorteio, recomendação externa, escrita, confirmação de experiência ou progresso. Não consulta bibliotecas individuais, ocultos, favoritos, opiniões ou escutas; seleções deliberadas continuam consentidas independentemente da ocultação pessoal, como prevê COUPLE-01. Sem coincidências há convite para cada participante adicionar suas escolhas; sem parceiro/histórico encerrado há orientação sem novas sugestões. Falha do stream, retirada, troca de lista/conta/vínculo removem as opções derivadas; não há cache separado nem novas regras/índices.

Regressões em `test/couple_interests_test.dart` cobrem autoria/remoção/terceiros/duplicatas, separação de mídias/artistas/origens/referências, opção explícita e remoção em 320 × 480/texto 2×. Regras e confirmação do servidor são as de COUPLE-06, sem ampliação de acesso. Validação nativa/produção permanece separada.

Regressões Dart em `test/couple_workspace_service_test.dart` e `test/couple_workspace_ui_test.dart` verificam confirmação atrasada, retry sem duplicação, revisão concorrente, duas confirmações, retirada/término, ausência de acesso pessoal, descarte/troca de conta e formulário em 320 × 480 com texto 2×. Testes de regras no projeto `demo-bookself` verificam consultas de participantes/terceiros/sem autenticação, auditoria atômica, campos privados negados, disputa por versão, remoção concorrente, término e novo parceiro sem herdar acesso. [Comandos/resultados](DEVELOPMENT.md#listas-experiências-e-paginação--couple-0506-ui-05).

Emuladores e fakes não comprovam proteção remota nem uso Android/iOS. Não houve implantação, migração, publicação ou escrita de produção. Validar os clientes/documentos e implantar as regras pelo processo separado de [SEC-06](SECURITY.md#implantação-pendente) antes de habilitar a funcionalidade remotamente.

O acesso em Nós fica habilitado automaticamente somente com `USE_FIREBASE_EMULATORS=true`. Depois de implantar/verificar as regras em outro ambiente, `USE_COUPLE_WORKSPACE=true` habilita explicitamente a tela. O define não publica regras. Sem ele, o cliente distribuído conserva a navegação anterior, até a ativação autorizada.
