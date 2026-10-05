# 003 — Consistência do vínculo direto existente

Data: 03/10/2026. Estado: código e regras candidatos validados localmente; implantação aguarda aprovação em SEC-06.

## Contexto e alternativas

Duas escritas independentes de `partnerUid` podiam deixar relações divergentes. Ler o destinatário antes de vincular exigiria acesso prévio ao perfil privado e ainda permitiria corrida entre leituras/escritas. Uma transação apenas no cliente não protegeria um cliente que a contornasse. Convites com aceite exigem decisões de COUPLE-01 e não podem ser presumidos como aprovados.

## Escolha e motivos

`PartnerService` envia um lote com duas alterações exclusivamente de `partnerUid`, sem leitura prévia do destinatário. Regras candidatas validam participante autorizado, contas existentes/livres e reciprocidade com estado anterior e `getAfter`. Desvínculo exige o par persistido, impedindo uma operação antiga de afetar uma relação nova. `AuthService` bloqueia repetição e ignora retornos de sessão anterior.

O lote mais validação no servidor permite tratar concorrência e limitar autoria sem substituir o fluxo de produto existente. A escolha implementa consistência técnica; vínculo continua direto por UID e não exige aceite nesta versão.

## Efeitos e pendências

O lote sozinho é insuficiente enquanto o remoto estiver permissivo. Relações legadas divergentes não são reparadas automaticamente. Perfil consultável ainda contém e-mail. **Atualização de 05/10/2026:** consentimento/visibilidade foram definidos em COUPLE-01, conforme [registro 006](006-consentimento-e-visibilidade.md). SEC-04 e COUPLE-03/04/05 continuam pendentes de implementação; a decisão aprovada não substitui o vínculo direto nem implanta regras.

Evidências: 11 regressões de vínculo/sessão e testes de autorização, concorrência e desvínculo nos emuladores. [SECURITY.md](../SECURITY.md) descreve controles, limites, auditoria e condições de implantação. A aprovação da implantação foi explicitamente adiada pelo usuário.
