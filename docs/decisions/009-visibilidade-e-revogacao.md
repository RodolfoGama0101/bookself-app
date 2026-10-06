# 009 — Projeções de compartilhamento e revogação

Data: 05/10/2026. Estado: implementado/testado localmente; implantação pendente.

## Problema e escolha

A política aprovada exige ocultação no servidor, sem apagar dados pessoais nem revelar campos privados. Filtrar documentos completos somente na tela continuaria entregando conteúdo; queries sobre um campo novo também excluiriam registros legados sem esse campo. Uma migração global depende de DATA-03.

Escolhemos projeções mínimas em `shared_books` e `shared_bible_progress`, publicadas por transações do dono que releem os registros atuais. Originais ficam privados; ocultação e projeção são atômicas. Preferência fica no original e sobrevive a novos vínculos. Campos legados desconhecidos são preservados, sem copiá-los para o casal. A adaptação não define o contrato futuro de múltiplas mídias.

## Consequências

Há uma cópia derivada e custo de leitura para publicação/verificação. O legado compartilhado depende de o dono abrir a versão atual; a publicação é repetível e não bloqueia uso pessoal em falha. Regras exigem projeção atualizada quando existente, impedem terceiros e revogam consultas após término. Instantes de atividade do servidor não são reconstruídos a partir de datas antigas; mostrar um item novamente não publica eventos passados.

Preferimos memória e confirmação do servidor para dados alheios. A inicialização limpa persistência antiga; offline retira conteúdo compartilhado. O custo é menor disponibilidade offline, com sincronização geral ainda em DATA-05. Nenhuma regra pode recolher capturas/copias externas de dados já entregues.

Bloqueio do parceiro ativo encerra o vínculo e impede convites em ambos os sentidos; retirar bloqueio não restaura a relação. O fluxo fora do vínculo permanece em COUPLE-09, sem inferir revogação de histórico conjunto ainda não implementado.

Contrato, validação e compatibilidade estão em [COUPLE_VISIBILITY.md](../COUPLE_VISIBILITY.md). SEC-06 exige implantação explícita posterior; contas, livros, capítulos, IDs e projeto remoto foram preservados.
