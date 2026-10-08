# 010 — Identificação mínima e bloqueios independentes

## Estado e contexto

Implementado localmente em 08/10/2026, seguindo a política v1 aprovada. COUPLE-04 oferecia bloqueio somente do parceiro ativo; após recusa ou término não havia uma identificação persistida que permitisse bloquear com segurança. Implantação remota continua em SEC-06.

## Alternativas e escolha

Não foi criado um diretório de contas nem entrada de UID/e-mail. Consultar perfis privados de antigos parceiros também não é permitido. A solução incremental guarda `partner_contacts/{uid}/targets/{otherUid}`, privado para o dono, com somente `name` e `invitationCode` (nulo para identificação por relação). O nome é uma apresentação histórica, não um perfil atualizado nem identidade única; homônimos podem aparecer separadamente. Fotos, e-mails, biblioteca e progresso não entram no registro.

Reservar um convite publica as duas identificações na mesma transação, fundamentadas nos participantes e nomes do convite conferido pelas regras. Reconsultar um convite reservado pode recompor esses registros. Encerrar ou bloquear uma relação registra as duas identificações junto ao término, com o nome do próprio perfil para a outra pessoa e a identificação histórica já confirmada para o dono; contato ausente usa “Pessoa conhecida”. Não consulta a apresentação do parceiro, para não impedir término/bloqueio quando ela falhar ou estiver contaminada. Isso cobre relações legadas ainda ativas sem convertê-las em consentimento novo. As regras permitem escrita somente por participantes da interação comprovada; o contato nunca concede leitura de perfil ou registros pessoais.

Bloqueio de pessoa conhecida relê contato, perfil próprio e bloqueio em transação. Grava o bloqueio privado e incrementa `coupleEpoch`, com `lastBlockedUid` como evidência para as regras exigirem que a nova versão corresponda à criação atômica de um bloqueio. Não modifica o vínculo atual quando a pessoa bloqueada é um ex-parceiro. Bloqueio do parceiro ativo mantém término recíproco e registro de contato em uma transação. Cada lado administra somente seu próprio documento; retirar um bloqueio não retira o do outro.

## Consequências e limites

- Incrementar a versão invalida **todos** os convites anteriores daquela conta, inclusive outros destinatários/remetentes; é a mesma fronteira de versão usada no aceite. Convites pendentes continuam canceláveis, mas precisam ser substituídos para um novo aceite. Remover o bloqueio não reduz a versão nem restaura convites ou relações.
- A tela “Pessoas e bloqueios”, acessível em Convites e Perfil → Compartilhamento, confirma ações, aguarda escrita e permite repetir após falha. Nomes/ações quebram linhas; leitura falha retira ações. Troca de conta, mudança do vínculo durante confirmação e descarte não aplicam um resultado à tela antiga.
- Contatos são dados privados persistentes. Exclusão de conta/exportação/retenção permanece em SEC-05; este registro não aprova uma política de retenção nova.
- Não há preenchimento administrativo nem recuperação automática de términos antigos. Convites antigos conhecidos podem recompor identificação quando ainda reservados e consultáveis. Relações legadas encerradas por clientes anteriores, sem contato persistido, não passam a oferecer identificação retroativa.
- Nenhuma nova mídia, migração ou configuração de produção é incluída. Clientes anteriores podem encerrar relações sem registrar contatos; implantação exige a revisão de compatibilidade de SEC-06.

## Verificação

Regressões Flutter em `test/partner_invitation_test.dart` e `test/partner_blocks_ui_test.dart`; autorização, gravação atômica, terceiros, bloqueios bilaterais, ex/novo parceiro e concorrência nos emuladores em `tool/firebase/test/security.test.cjs`. Comandos, resultados e limites em [DEVELOPMENT.md](../DEVELOPMENT.md#bloqueios-independentes--couple-09).
