# 006 — Consentimento e visibilidade do casal

Data: 05/10/2026. Estado: **decisão de produto aprovada; implementação pendente**. Tarefa: COUPLE-01.

## Contexto

O app atual vincula contas diretamente por UID. O usuário já havia escolhido compartilhar biblioteca/progresso por padrão após aceite, permitindo ocultar itens. Faltavam regras de convite, bloqueio, histórico e autoria para orientar SEC-04 e COUPLE-03/04 sem presumir acesso a campos privados.

## Escolha

O usuário respondeu **“Adotar a proposta recomendada”** à proposta apresentada nesta tarefa. A [política v1](../COUPLE_POLICY.md) é o contrato de produto para a evolução: convites válidos por sete dias, um enviado ativo por conta, aceite único com contas livres, nome/foto como identidade mínima, biblioteca existente compartilhada preservando ocultação, feed sem retroatividade e Bíblia ocultável por livro. Favoritos, opiniões e escutas pessoais permanecem privados.

Bloqueio encerra o vínculo e impede novos convites até ser desfeito; desbloqueio não restaura acesso. Desvínculo preserva dados pessoais. Listas e experiências ficam em histórico restrito aos participantes antigos, sem edição conjunta nem herança por novo parceiro. Experiências requerem confirmação dos dois e nunca alteram o progresso alheio automaticamente.

## Alternativas consideradas

- Compartilhar somente itens adicionados depois do aceite: não escolhida; a biblioteca existente participa, respeitando itens ocultos e sem republicar atividades antigas.
- Manter tudo privado até compartilhar item a item: alternativa anterior não escolhida; o padrão aprovado compartilha biblioteca/progresso após consentimento.
- Adiar o fechamento para ajustar a política: o usuário preferiu adotar a proposta recomendada.
- Copiar ou remover o espaço conjunto após término: alternativas anteriores substituídas pelo histórico restrito aos participantes antigos. Prazo de retenção e exclusão continuam em SEC-05.

## Motivos e consequências

O padrão reduz passos após o aceite; a ocultação preserva controle pessoal. Convites terminais e ativação atômica impedem reutilização e relações concorrentes. Nome/foto permitem reconhecer o convite sem expor e-mail. Histórico conjunto mantém as seleções e participações consentidas sem conceder acesso à biblioteca atual do ex-parceiro. Um novo vínculo exige novo aceite e não herda dados da relação anterior.

Firestore entrega documentos inteiros; SEC-04/DATA-01 devem separar campos consultáveis de favoritos, opiniões, escutas e dados privados. COUPLE-03/04 precisam implementar autorização e revogação no servidor, concorrência e limpeza de estado/cache. A matriz da política é critério de validação futura, não evidência de testes já executados.

## Limites

Esta entrega altera somente documentação. Convites, bloqueio, ocultação e histórico conjunto ainda não existem no app. Não escolhe coleções, IDs, fornecedor ou marca. DATA-03 deve preservar vínculos/dados legados sem presumir aceite da política nova. Retenção temporal, exportação e exclusão de conta ficam em SEC-05; campos e persistência de experiências/listas ficam em COUPLE-05/06 e DATA-01.

Não houve alteração de código Dart, regras, Firebase remoto ou dados. Não foi autorizada migração, publicação nem implantação de SEC-06. A conclusão de COUPLE-01 libera sua dependência de decisão, mantendo os demais critérios das tarefas no [backlog](../../BACKLOG.md).

Atualização de 05/10/2026: convites foram implementados localmente em [registro 008](008-convites-consentidos.md); ocultação, bloqueio, feed sem retroatividade e cache continuam pendentes. Esta decisão não comprova política completa nem implantação remota.
