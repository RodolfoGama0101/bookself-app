# Convites do casal — COUPLE-03

Data: 05/10/2026. Código e regras candidatos validados localmente. Implantação, migração e publicação permanecem separadas em SEC-06/DATA-03. Esta entrega substitui a criação direta de vínculo por UID; mantém relações legadas e não as converte em aceite da [política v1](COUPLE_POLICY.md).

## Jornada

No Perfil, uma conta livre abre **Convites do casal**, lê o compartilhamento e confirma o consentimento antes de criar o convite. O app gera 16 bytes com `Random.secure`, representados por 32 caracteres hexadecimais (128 bits), sem derivar o código do UID. O remetente copia somente esse código, aguardando a escrita do clipboard antes do feedback. Enviar somente à pessoa pretendida: quem possui um código ainda não reservado pode reservar o convite para sua conta.

Ao consultar um código, a conta destinatária concorda em apresentar nome/foto ao remetente, conforme aviso antes da consulta. A primeira reserva fixa seu UID interno e apresentação; não cria vínculo nem libera livros, Bíblia ou perfil privado. A pessoa confere nome/foto do remetente, lê o compartilhamento e confirma consentimento para **Aceitar convite**, ou usa **Recusar convite**. O remetente pode cancelar enquanto o convite estiver pendente. Uma conta diferente não pode tomar a reserva nem decidir o convite.

Aceite é uma transação que confirma o convite e os dois perfis recíprocos, somente com ambas as contas livres. O SDK não consulta o documento privado do remetente. O perfil e a apresentação do parceiro continuam vindo dos streams. Sucesso só aparece depois da escrita aceita; sessão trocada/descarte invalidam o feedback antigo. O próprio convite enviado pelo destinatário é cancelado no mesmo aceite.

A tela atual informa o compartilhamento de estante e progresso bíblico permitidos, inclusive registros anteriores, e orienta escolher ocultação em Perfil → Compartilhamento. **Complemento de COUPLE-04:** ocultação, revogação, feed sem retroatividade e cache foram validados localmente nas categorias atuais; [contrato](COUPLE_VISIBILITY.md). Bloqueio fora de vínculo permanece em COUPLE-09 e sincronização geral em DATA-05. Histórico conjunto e novas mídias ainda exigem implementações próprias; distribuição/implantação continuam pendentes.

## Contrato local aditivo

| Caminho | Conteúdo e acesso |
| --- | --- |
| `partner_invites/{code}` | `version: 1`, `senderUid`, `senderEpoch`, `senderName`, `senderPhotoUrl`, `recipientUid`, `recipientEpoch`, `recipientName`, `recipientPhotoUrl`, `status`, `createdAt`, `decidedAt`. Identificadores/versões são internos; a interface usa somente nome/foto para identificar pessoas. Não contém e-mail, registros pessoais ou campos desconhecidos. |
| `partner_invite_slots/{uid}` | `code`, `issuedAt`: último convite enviado. Somente o dono consulta; sem listagem/exclusão pelo cliente. Criação/atualização exige convite novo na mesma operação. |
| `partner_invite_lookups/{uid}` | `code`, `requestedAt`: última tentativa de consulta. Somente o dono consulta; sem listagem/exclusão pelo cliente. Código válido e timestamp do servidor obrigatórios. |
| `users/{uid}` | Adiciona `relationshipId` e `coupleEpoch` no aceite. Preserva UID, campos privados/legados e todos os registros pessoais. Ausência de `coupleEpoch` vale zero. Desvínculo limpa `partnerUid`/`relationshipId`, mantendo a versão. |

`status` persistido é `pending`, `accepted`, `declined` ou `cancelled`. Os três estados de decisão são terminais: não podem voltar a pendente, ter participantes modificados ou ser usados para outro vínculo. `createdAt` é timestamp do servidor; pendente é utilizável somente antes de `createdAt + 7 dias`, comparado com `request.time`. Expiração é derivada, sem tarefa agendada nem escrita automática; cancelar um documento pendente já expirado continua permitido. Recriação usa outro código e mantém o registro anterior.

`senderEpoch` captura a versão do remetente na criação; `recipientEpoch`, a versão do destinatário na reserva. Aceite incrementa `coupleEpoch` dos dois perfis. Convites de versões anteriores ficam inutilizáveis permanentemente, mesmo se seu estado armazenado ainda for pendente e mesmo após término/re-vínculo. Isso invalida também outros convites recebidos sem listar todos os documentos nem exigir lote de tamanho ilimitado. O servidor confere as versões de ambas as contas; não há escrita de limpeza automática em convites antigos. A tela detecta a versão obsoleta do próprio participante; mudança da outra conta é confirmada pelo servidor ao decidir.

Desvínculo relê somente o perfil próprio em transação e compara parceiro e `relationshipId` capturados. Uma solicitação antiga do mesmo par não pode encerrar uma nova relação desse par. Relação legada sem identificador usa `null`; vínculo legado divergente não é reparado automaticamente. Regras exigem limpar o par recíproco na mesma operação e impedem alterar a versão no término.

O wrapper de transações preserva exceções de domínio com mensagens fixas quando FlutterFire web reempacota o callback como erro SDK. Exceções de rede/autorização continuam seguindo `ErrorHandler`, sem código/UID/e-mail/token em diagnósticos. Consulta negativa não expõe o estado privado da outra conta.

## Limites contra abuso

- Um convite enviado ativo por conta, validado por slot e estado anterior nas regras. Chamadas repetidas do serviço retornam o convite existente sem criar outro. Isso é recuperação de operação, não reenvio com novo consentimento.
- Intervalo mínimo de um minuto entre criações, inclusive depois de cancelamento/recusa. O timestamp e o intervalo são conferidos pelo servidor.
- Intervalo mínimo de cinco segundos entre tentativas de descoberta por conta, incluindo código inexistente; somente o código registrado pode ser descoberto por um minuto. A reserva exige essa consulta. Há também intervalo local na tela para feedback imediato.
- Sem listagem de convites, usuários, slots ou consultas. Descoberta pontual exige autenticação, código aleatório válido, convite pendente não reservado e a consulta recente da própria conta. Depois da reserva, somente participantes consultam o convite; terceiro não decide nem altera participantes.

São limites por conta, não proteção absoluta contra múltiplas contas ou custo de tráfego. Quotas, restrições de configuração e proteção operacional devem ser revisadas antes da implantação em SEC-03/SEC-06. Nenhum backend, fornecedor, segredo ou dependência nova foi adicionado. A consulta apresenta identidade mínima antes do aceite; conhecer um código nunca concede leitura dos registros pessoais.

## Validação e implantação

**308 testes Flutter e análise limpa**, incluindo parser/expiração, código inválido sem SDK, confirmação da criação, reserva sem leitura privada, versões/legado, cancelamento/recusa, troca de streams, erro de domínio reempacotado, ciclo de sessão, consentimento, layout 320 × 480 com texto 2×, descarte e clipboard. **43 testes Auth/Firestore** nos emuladores locais, incluindo terceiro, estados terminais, campos forjados, criação/consulta limitadas, expiração do servidor, dois aceites, aceite × cancelamento, invalidação após término, cancelamento do convite enviado e preservação pessoal. [Comandos](DEVELOPMENT.md).

Build web demo aprovado com verificação preliminar Wasm; jornada Flutter real em dois Chromes isolados cobriu cadastro, criação, reserva, identificação, aceite recíproco e término. Reuso após término foi rejeitado; o diagnóstico da mensagem web gerou a correção de preservação do erro de domínio. [Resultados da jornada](WEB_VALIDATION.md). Nenhum build/execução Android/iOS ou escrita remota nesta tarefa.

As regras candidatas não foram implantadas. Clientes antigos ainda tentam vincular por UID e não terão autorização para criar novos vínculos após a implantação; também terão a leitura privada do parceiro negada, conforme SEC-04. Desvínculo legado recíproco continua permitido. Revisar versão compatível, projeções, backup/recuperação, campos divergentes e COUPLE-04 antes da distribuição. A regra remota permissiva auditada permanece uma pendência; estes testes não comprovam proteção em produção.

A validação usa a [autorização de operações atômicas](https://firebase.google.com/docs/firestore/security/rules-conditions) e [transações do Firestore](https://firebase.google.com/docs/firestore/manage-data/transactions), sem ler documentos pessoais remotos.

## Complemento de COUPLE-04

[Visibilidade/revogação](COUPLE_VISIBILITY.md) acrescenta projeções mínimas, ocultação de livros/Bíblia, feed sem retroatividade e tratamento de cache nas categorias atuais. Convites respeitam bloqueios privados em ambos os sentidos; bloquear parceiro ativo encerra o vínculo/incrementa versão do bloqueador. Desbloquear não restaura códigos ou relação. COUPLE-09 estende bloqueio fora do vínculo. A proteção remota continua em SEC-06.
