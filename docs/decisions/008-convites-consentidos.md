# 008 — Convites consentidos e invalidação por versão

Data: 05/10/2026. Estado: **implementado e validado localmente; implantação pendente**. Tarefa: COUPLE-03. Substitui a criação direta de vínculos do [registro 003](003-vinculo-atual.md), preservando desvínculo e relações legadas.

## Escolha

Usar código aleatório de 128 bits, reserva para o primeiro destinatário autenticado e aceite atômico conferido pelas regras. Nome/foto são a apresentação; UID e versões são internos. O remetente confirma consentimento na criação e pode cancelar; o destinatário confirma somente depois de conferir o remetente. A reserva não concede acesso pessoal. Slots e consultas próprias validam um convite enviado ativo, intervalo de criação de um minuto e de descoberta de cinco segundos no servidor, sem novas dependências/backend.

Aceite incrementa a versão dos dois participantes, inutilizando outros convites antigos mesmo após término. Evita consultas globais/listagens e lotes ilimitados para cancelar todos os recebidos. O convite próprio enviado é cancelado no mesmo aceite. Campos e transições, limites e recuperação estão em [COUPLE_INVITATIONS.md](../COUPLE_INVITATIONS.md).

## Alternativas e consequências

- Manter UID como código/vínculo direto: rejeitado, pois não representa aceite do destinatário nem capacidade temporária.
- Código curto ou derivado de identidade: rejeitado por facilitar enumeração e expor identidade desnecessariamente.
- Alterar somente os dois perfis no aceite: insuficiente para impedir reutilização do convite; as regras conferem transição terminal e versões.
- Listar/cancelar todos os recebidos: exigiria índices/listagens e lotes potencialmente ilimitados; a versão invalida sem apagar registros.
- Backend de convites: possível evolução para proteção operacional mais abrangente. Nesta entrega, regras conferem autoria, tempo, limites e operações atômicas; não há prova de proteção contra múltiplas contas.

## Evidências e limites

Análise limpa, 308 testes Flutter, 43 integrações Auth/Firestore e build web demo aprovados. Duas sessões Chrome isoladas validaram a jornada consentida e o término; reuso foi rejeitado. O serviço preserva mensagens de domínio reempacotadas pelo SDK web, com regressão específica. Detalhes em [DEVELOPMENT.md](../DEVELOPMENT.md) e [WEB_VALIDATION.md](../WEB_VALIDATION.md).

Não houve migração/implantação/publicação. Clientes antigos deixam de criar vínculo por UID nas regras novas; relações legadas permanecem e não equivalem a aceite da política v1. Ocultação por item, feed sem retroatividade, bloqueio, cache e categorias futuras permanecem em COUPLE-04/DATA-05 e respectivas tarefas. A implantação/distribuição depende de completar esses controles e revisar SEC-06. Identidades técnicas e fornecedores foram preservados.
