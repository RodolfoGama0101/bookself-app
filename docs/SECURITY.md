# Autorização e vínculo atuais

Atualização de 08/10/2026 — DATA-02: regras candidatas acrescentam apenas catálogo/entrada/slot privados por dono em `libraries`, com referências atômicas, autoria imutável e revisão. Parceiro/ex/terceiro/sem autenticação são negados também em consultas; demais coleções multimídia propostas continuam negadas localmente. Seis casos novos passaram na suíte de 69 integrações demo, incluindo disputa real. [Contrato e limites](DATA_MODEL.md#subconjunto-local-implementado--data-02). Não houve atualização da regra remota: a base não foi conectada à interface e não deve ser ativada em clientes distribuídos antes de SEC-06 corrigir/validar a autorização remota auditada abaixo.

Atualização de 08/10/2026 — COUPLE-09: contatos privados exigem convite reservado ou relação recíproca comprovados; não criam diretório nem autorização pessoal. Bloqueio fora do vínculo exige contato persistido e incremento atômico de `coupleEpoch`, comprovado por `lastBlockedUid` e novo bloqueio. Terceiros, falsificação de nome/participante, versões avulsas, reuso de convite e bloqueios bilaterais foram verificados em emuladores. [Contrato e compatibilidade](decisions/010-bloqueios-independentes.md); [resultados](DEVELOPMENT.md#bloqueios-independentes--couple-09). A revisão de implantação SEC-06 deve incluir a nova coleção e o campo opcional, sem tomar o resultado local como autorização remota.

Revisão: 05/10/2026. Auditoria remota de 03/10 somente de regras/índices; validação das novas regras exclusivamente em emuladores. Nenhuma escrita, migração ou implantação remota foi executada pelo agente.

## Resultado da auditoria remota

A sessão já existente do Firebase CLI permitiu consultar a release ativa de `cloud.firestore` do projeto configurado em `firebase.json`, usando a API Firebase Rules. A regra publicada contém um match recursivo para todos os documentos com:

```text
allow read, write: if request.auth != null;
```

Essa condição verifica autenticação e permite acesso a qualquer documento para qualquer conta autenticada. O código da interface que oculta edição do parceiro não oferece autorização no servidor. A consulta separada dos metadados de índices retornou `indexes: []` e `fieldOverrides: []`. Não foram consultados documentos de pessoas reais nem executados testes de escrita no projeto remoto.

SHA-256 do conteúdo retornado para a regra ativa: `67e516d2c05f980cfb40f5eba63cd673b94054122fdaa102f7bdf838028830b0`.

**O risco permanece no projeto remoto enquanto as regras candidatas não forem implantadas.** A release foi lida em 03/10/2026; esse retrato não garante que a configuração continue igual depois dessa data. Antes da implantação, repetir a leitura e comparar alterações.

## Regras candidatas versionadas

`firestore.rules` é usado somente pela configuração de emuladores. Não foi conectado automaticamente ao `firebase.json` distribuído. Os controles locais incluem SEC-04 e os convites de COUPLE-03, sob a política v1 aprovada. Ocultação, bloqueio, feed sem retroatividade e cache permanecem em COUPLE-04/DATA-05.

| Dados/operação | Controle local validado |
| --- | --- |
| Perfil privado (`users`) | Só o dono lê seu documento, inclusive ausência. Parceiro, terceiro e listagem de usuários são negados. Campos privados/legados são preservados. |
| Perfil consultável (`partner_profiles`) | Dono/parceiro recíproco consultam por ID; não é público nem listável. Conteúdo permite somente nome/foto. Documento contaminado com campos privados é negado ao parceiro. |
| Escrita do perfil consultável | Só o dono cria/atualiza; nome/foto devem coincidir com `getAfter` do perfil privado. Campos desconhecidos, autoria forjada e exclusão são negados. |
| Criação de perfil | UID/caminho/e-mail correspondem à sessão; nome não vazio, até 200 caracteres e data de criação válida. Vínculo e foto iniciam ausentes/nulos. Campos desconhecidos são rejeitados na criação. |
| Edição de perfil | Só o dono altera nome/foto; UID, e-mail e criação não podem ser alterados. Campos legados não afetados são preservados. Exclusão de perfil pelo cliente é negada enquanto SEC-05 não definir exclusão de conta. |
| Livros | Dono cria/edita/exclui. Autoria não pode ser transferida. Parceiro recíproco apenas lê; terceiro não acessa. Campos/estados/tipos conhecidos são exigidos; até 50 autores, todos strings. |
| Conclusão | Novas datas vão até o instante atual e só existem em Lido. Lidos legados sem data continuam válidos; uma data futura já persistida pode ser mantida ou corrigida. Não há limpeza/migração automática. |
| Bíblia | Dono marca/desmarca/exclui seu progresso; parceiro recíproco lê. ID combina proprietário e nome normalizado. Nome e autoria não podem mudar no update; lista sem duplicatas, capítulos dentro do limite do livro e timestamp do servidor são exigidos. |
| Convites e descoberta | Código opaco, reserva e aceite do destinatário, validade de sete dias, decisões terminais, versões contra reuso e limites de criação/consulta. Identificadores internos não são exibidos como códigos de pessoas. Listagens e exclusão pelo cliente negadas. |
| Outras coleções | Acesso negado por padrão. Novas categorias exigem regras específicas antes de aparecer como implementadas. |

As queries de estante/Bíblia devem filtrar `userId`. O feed pode consultar `in` com os dois participantes de vínculo recíproco. Queries globais e filtros para terceiros são negados. A autorização depende de ambos os perfis persistidos apontarem um para o outro, não apenas de um ponteiro local.

Firestore autoriza documentos inteiros; esconder um campo na tela não restringe sua leitura. [Limites oficiais de acesso por campo](https://firebase.google.com/docs/firestore/security/rules-fields). Em 05/10/2026, SEC-04 separou o modelo e as regras locais: `users` conserva os dados privados/legados e `partner_profiles` contém apenas nome/foto. O cliente não consulta `users` do parceiro, mesmo quando sua apresentação está ausente. O perfil do casal deixou de exibir e-mail alheio. A proteção do banco remoto permanece dependente de SEC-06, pois a regra permissiva auditada não foi substituída.

Cadastro/recuperação e edição de nome/foto escrevem os dois documentos em transação. Edições simultâneas aplicam somente o campo alterado quando a projeção está atual, preservando a outra intenção; falha não deixa escrita parcial. Contas existentes publicam somente a própria apresentação quando esta versão recebe o perfil válido; a transação relê dados atuais e preserva integralmente o documento privado. Falha/timeout de publicação não impede uso individual; o perfil indisponível tem apresentação neutra, sem fallback privado. Detalhes e repetição em [ARCHITECTURE.md](ARCHITECTURE.md).

A [política v1 aprovada](COUPLE_POLICY.md) permite nome/foto e mantém e-mail e demais dados privados restritos ao dono. Nesta etapa, leitura da apresentação exige o vínculo recíproco atual. COUPLE-03 implementou convites consentidos localmente; ocultação e bloqueio do parceiro ativo foram validados localmente em COUPLE-04; extensão de bloqueio fora do vínculo em COUPLE-09. Vínculos legados não foram transformados em consentimento.

## Consistência do vínculo

Novo vínculo exige convite reservado e aceite do destinatário. A transação grava estado aceito e os dois perfis recíprocos com identificador/versão, sem consultar o perfil privado do remetente. Regras exigem contas livres, convite atual/não expirado e estado anterior pendente; criação direta por UID, participantes forjados, substituição de parceiro e mudanças unilaterais são negadas. Aceite cancela o convite enviado do destinatário e incrementa as duas versões, invalidando outros convites antigos permanentemente.

Desvínculo mantém compatibilidade com pares legados recíprocos. O serviço compara o parceiro e identificador capturados em transação que lê somente o perfil próprio; uma solicitação antiga do mesmo casal não encerra sua relação nova. As regras exigem limpar os dois perfis e preservar a versão. Pares divergentes não são reparados automaticamente.

`AuthService` exige sessão/perfil válido, bloqueia repetição e invalida feedback de logout/troca/descarte. A tela exige consentimento antes de criar/aceitar e cancela assinaturas/controladores/timers. Erros de domínio reempacotados pelo SDK web conservam mensagens fixas, sem diagnóstico com código/identidade. [Contrato, ameaça de código compartilhado e limites](COUPLE_INVITATIONS.md).

**Transações do cliente exigem regras implantadas para proteger concorrência e acesso.** Nenhuma alteração remota foi feita; clientes antigos/maliciosos continuam sendo um risco enquanto a regra permissiva auditada estiver publicada.

## Evidências locais e limites

`npm --prefix tool/firebase test` executou **43 testes aprovados** em Auth/Firestore reais dos emuladores em 05/10/2026, somente no projeto demo. Cobrem: ausência de autenticação, dono/parceiro/terceiro, autoria e campos inválidos, queries usadas pelo app, dados legados, capítulos dos 66 livros, vínculos unilaterais/ausentes/ocupados, disputa simultânea, desvínculo antigo, revogação de leituras/queries do ex-parceiro e isolamento de novo parceiro. Sete novas regressões incluem perfil mínimo não público/listável, negação de campos privados, escrita atômica/rejeição sem estado parcial, nome/foto concorrentes, projeção contaminada, legado sem projeção e negação de nova atualização em assinatura do ex-parceiro. Onze regressões de convites acrescentam ausência de acesso antes do aceite, reserva/destinatário/terceiro, campos forjados, limites de criação/consulta, expiração, estados terminais, aceite × cancelamento, dois aceites e invalidação após término. Os dados são fictícios e o runner encerra os emuladores.

Os testes Dart complementam confirmação das escritas, configuração demo, bloqueio de ações concorrentes, falhas/nova tentativa e isolamento de retornos após troca de sessão. O SDK JS faz uma jornada de cadastro/login/logout em Auth e criação/leitura de perfil em Firestore local. COUPLE-03 também validou a jornada Flutter web em dois Chromes isolados; isso não comprova plataformas nativas nem autorização remota aplicada.

A revogação foi verificada no servidor para novas leituras/queries. Dados já entregues ao dispositivo não podem ser recuperados do destinatário. COUPLE-04 acrescenta revogação das projeções e limpeza de estado/cache descritas abaixo; estratégia geral de sincronização permanece em DATA-05. Admin SDKs/credenciais administrativas não usam estas regras; permissões IAM são uma verificação separada.

No teste da assinatura, após o desvínculo o dono atualiza nome no perfil privado/consultável; o ex-parceiro recebe `permission-denied`, sem receber o novo nome. Isso não demonstra notificação imediata do emulador só pela alteração da dependência de vínculo. No cliente, a emissão do próprio perfil sem parceiro cancela o ouvinte e limpa a apresentação; regressões Dart cobrem logout, troca, falha e descarte.

## Implantação pendente

**SEC-06 aguarda aprovação do usuário desde 03/10/2026.** O usuário pediu para deixar a decisão anotada e continuar atividades independentes. Retomar esta pendência quando ele estiver disponível; não publicar regras, migrar dados nem alterar produção automaticamente. O lembrete está no [backlog](../BACKLOG.md#pendência-de-aprovação-do-usuário), sem agendamento ou data definida.

Antes de publicar, revisar a release atual, backup/recuperação, compatibilidade dos documentos legados e dos clientes distribuídos, além de validar a jornada em desenvolvimento. A auditoria não inventariou dados pessoais reais; perfis com tipos/campos divergentes e vínculos antigos inconsistentes precisam de revisão controlada. Regras mais estritas podem rejeitar operações que antes eram permitidas; essa mudança deve acompanhar a versão compatível do app.

**Compatibilidade de COUPLE-03:** as regras novas negam criação direta de vínculo por UID em clientes antigos, inclusive 1.1.0. Desvínculo legado recíproco permanece permitido; aceite adiciona somente identificador/versão aos perfis, sem migrar/remover registros. Atualizar clientes e completar COUPLE-04 antes de distribuir o fluxo como política v1 completa.

**Compatibilidade de SEC-04:** clientes antigos, inclusive a pré-release 1.1.0, ainda consultam `users` do parceiro e terão essa leitura negada pelas novas regras. A implantação exige planejar a atualização dos clientes e a disponibilidade das projeções. Contas que ainda não abriram esta versão podem não ter `partner_profiles`; o cliente novo mantém estante/Bíblia/desvínculo com apresentação neutra até a publicação pelo dono. Não ler perfis privados para preencher apresentação de outro usuário nem executar preenchimento em massa sem plano separado. Alterações de nome/foto por cliente antigo podem deixar a projeção desatualizada até nova sincronização pelo cliente atualizado.

Caches persistentes de versões antigas podem conter documentos privados já recebidos. O app novo não os consulta como perfil do parceiro, e COUPLE-04 limpa a persistência antiga antes dos serviços e desabilita persistência Firestore. Limpeza nativa depende da execução em Android/iOS; sincronização geral permanece em DATA-05. A separação não recolhe dados já entregues nem comprova autorização em produção.

A implantação das regras deve ser uma ação explícita posterior. Não execute migração, correção de vínculos ou deploy como parte de testes. As tarefas de consentimento, privacidade e migração continuam no [backlog](../BACKLOG.md).

Execução local reproduzível: [DEVELOPMENT.md](DEVELOPMENT.md).

## Configuração de catálogo e referência opcional

Em 03/10/2026, a regra candidata passou a aceitar `googleBooksId` ausente/null ou string de 1 a 200 caracteres. A referência não autoriza leitura/escrita: dono/parceiro/terceiro continuam seguindo as mesmas regras, e pessoas distintas podem salvar a mesma referência em documentos próprios. O teste novo de referência, legado e negação passou junto das 25 integrações em Auth/Firestore emulados. Rever compatibilidade do campo na release ao implantar; nenhuma regra foi publicada.

O literal de chave Google Books saiu do serviço e foi preservado somente em configuração local ignorada; exemplo versionado é vazio. Inventário, separação de ambiente, limites de defines, histórico Git e avaliação de rotação estão em [CONFIGURATION.md](CONFIGURATION.md). A consulta remota de restrições/quotas foi rejeitada pela revisão automática porque enviaria a chave para um endpoint Google sem autorização explícita para esse destino. Ela não foi executada; SEC-03 permanece pendente de autorização/revisão manual, independente da implantação adiada em SEC-06.

## Visibilidade local — COUPLE-04

A suíte atual passou com **53 testes Auth/Firestore demo** e **321 Flutter**, análise limpa e build web demo. Originais `books`/`bible_progress` são privados; projeções mínimas só permitem dono/parceiro recíproco. Ocultar exige remoção atômica; terceiros, campos privados/forjados, edição alheia e republicação de ocultos são negados. Preservação de legado, novos documentos transacionais, ocultação/publicação concorrentes, ex/novo parceiro e bloqueio/término concorrentes foram verificados.

A consulta do parceiro não usa cache/offline. Inicialização limpa persistência anterior antes dos serviços; builders/rotas abertas limpam conteúdo ao perder vínculo/projeção. Duas sessões Chrome fictícias confirmaram revogação em detalhes já abertos, comparação bíblica após recarga, bloqueio/desbloqueio e preservação própria. Isso não recolhe cópias externas nem valida limpeza nativa. [Contrato, projeções e limitações](COUPLE_VISIBILITY.md).

**Compatibilidade adicional:** clientes antigos consultam registros pessoais do parceiro e passam a ser negados. Edições em originais com projeção existente exigem sincronização/remoção atômica. O dono publica seu próprio legado ao abrir esta versão; outra conta não preenche sua projeção. Não implantar antes de planejar atualização, disponibilidade, backup/recuperação e ensaio com clientes/documentos reais. SEC-06 permanece adiada; regras remotas não alteradas.
