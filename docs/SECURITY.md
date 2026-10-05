# Autorização e vínculo atuais

Revisão: 03/10/2026. Auditoria remota somente de regras/índices; validação das novas regras exclusivamente em emuladores. Nenhuma escrita, migração ou implantação remota foi executada.

## Resultado da auditoria remota

A sessão já existente do Firebase CLI permitiu consultar a release ativa de `cloud.firestore` do projeto configurado em `firebase.json`, usando a API Firebase Rules. A regra publicada contém um match recursivo para todos os documentos com:

```text
allow read, write: if request.auth != null;
```

Essa condição verifica autenticação e permite acesso a qualquer documento para qualquer conta autenticada. O código da interface que oculta edição do parceiro não oferece autorização no servidor. A consulta separada dos metadados de índices retornou `indexes: []` e `fieldOverrides: []`. Não foram consultados documentos de pessoas reais nem executados testes de escrita no projeto remoto.

SHA-256 do conteúdo retornado para a regra ativa: `67e516d2c05f980cfb40f5eba63cd673b94054122fdaa102f7bdf838028830b0`.

**O risco permanece no projeto remoto enquanto as regras candidatas não forem implantadas.** A release foi lida em 03/10/2026; esse retrato não garante que a configuração continue igual depois dessa data. Antes da implantação, repetir a leitura e comparar alterações.

## Regras candidatas versionadas

`firestore.rules` é usado somente pela configuração de emuladores. Não foi conectado automaticamente ao `firebase.json` distribuído. Os controles correspondem ao comportamento já existente do MVP; não definem nova política de consentimento/visibilidade.

| Dados/operação | Controle local validado |
| --- | --- |
| Perfil | Dono lê seu documento, inclusive ausência; parceiro recíproco lê o perfil existente. Terceiros e listagem de usuários são negados. |
| Criação de perfil | UID/caminho/e-mail correspondem à sessão; nome não vazio, até 200 caracteres e data de criação válida. Vínculo e foto iniciam ausentes/nulos. Campos desconhecidos são rejeitados na criação. |
| Edição de perfil | Só o dono altera nome/foto; UID, e-mail e criação não podem ser alterados. Campos legados não afetados são preservados. Exclusão de perfil pelo cliente é negada enquanto SEC-05 não definir exclusão de conta. |
| Livros | Dono cria/edita/exclui. Autoria não pode ser transferida. Parceiro recíproco apenas lê; terceiro não acessa. Campos/estados/tipos conhecidos são exigidos; até 50 autores, todos strings. |
| Conclusão | Novas datas vão até o instante atual e só existem em Lido. Lidos legados sem data continuam válidos; uma data futura já persistida pode ser mantida ou corrigida. Não há limpeza/migração automática. |
| Bíblia | Dono marca/desmarca/exclui seu progresso; parceiro recíproco lê. ID combina proprietário e nome normalizado. Nome e autoria não podem mudar no update; lista sem duplicatas, capítulos dentro do limite do livro e timestamp do servidor são exigidos. |
| Outras coleções | Acesso negado por padrão. Novas categorias exigem regras específicas antes de aparecer como implementadas. |

As queries de estante/Bíblia devem filtrar `userId`. O feed pode consultar `in` com os dois participantes de vínculo recíproco. Queries globais e filtros para terceiros são negados. A autorização depende de ambos os perfis persistidos apontarem um para o outro, não apenas de um ponteiro local.

Firestore autoriza documentos inteiros. O perfil atual contém e-mail/foto, então o parceiro recíproco ainda recebe esses campos. Separar perfil consultável e dados privados permanece em SEC-04. **Atualização de 05/10/2026:** COUPLE-01 foi concluída como decisão com a [política v1 aprovada](COUPLE_POLICY.md), que permite nome/foto e mantém e-mail e demais dados privados restritos ao dono. Convites com aceite e visibilidade opcional continuam pendentes de implementação; código e regras atuais não foram alterados pela decisão.

## Consistência do vínculo

`PartnerService` envia um lote de duas atualizações de `partnerUid` e aguarda o commit. Não lê o documento privado do destinatário antes do vínculo. A informação de código inválido/conta ocupada é uma rejeição da operação, sem revelar dados da pessoa. A tela mostra a mensagem traduzida do serviço.

As regras usam o estado anterior de ambas as contas e `getAfter` para exigir reciprocidade depois do lote. Apenas um participante pode iniciar/finalizar sua relação; ambos os perfis precisam existir e estar livres para novo vínculo. Auto-vínculo, mudança unilateral, vínculo de terceiros e substituição direta de parceiro são negados. Nenhum outro campo do destinatário pode ser alterado junto com o vínculo. [Condições e operações atômicas nas regras](https://firebase.google.com/docs/firestore/security/rules-conditions).

Desvincular exige o par recíproco persistido. Um lote criado com um parceiro antigo falha se algum participante já estiver em outra relação, preservando o novo par. O novo vínculo deve ocorrer depois de desvincular. Relações legadas divergentes não são reparadas automaticamente: exigem diagnóstico e estratégia compatível, com recuperação; não se escreve em um possível novo parceiro para tentar corrigir o estado antigo.

`AuthService` captura as identidades da operação, impede ações repetidas enquanto aguarda a escrita e rejeita novas ações sem sessão/perfil válido. Logout/troca de conta/descarte invalidam o retorno antigo; ele não anuncia sucesso nem desbloqueia uma operação da sessão seguinte. O perfil/vínculo confirmado continua vindo do stream.

**A atomicidade do lote sozinho não evita vínculos concorrentes. A consistência depende das regras candidatas no servidor.** Enquanto o remoto continuar com a regra auditada, os novos guardas do cliente são insuficientes para impedir clientes antigos ou maliciosos.

## Evidências locais e limites

`npm --prefix tool/firebase test` executa 25 testes em Auth/Firestore reais dos emuladores, somente no projeto demo. Cobrem: ausência de autenticação, dono/parceiro/terceiro, autoria e campos inválidos, queries usadas pelo app, dados legados, capítulos dos 66 livros, vínculos unilaterais/ausentes/ocupados, disputa simultânea, desvínculo antigo, revogação de leituras/queries do ex-parceiro e isolamento de novo parceiro. Os dados são fictícios e o runner encerra os emuladores.

Os testes Dart complementam confirmação das escritas, configuração demo, bloqueio de ações concorrentes, falhas/nova tentativa e isolamento de retornos após troca de sessão. O SDK JS faz uma jornada de cadastro/login/logout em Auth e criação/leitura de perfil em Firestore local. Isso não equivale a uma jornada Flutter em dispositivo, nem comprova autorização remota aplicada.

A revogação foi verificada no servidor para novas leituras/queries. Dados já entregues ao dispositivo não podem ser recuperados do destinatário; limpeza/visibilidade de cache e evolução do compartilhamento permanecem em COUPLE-04/DATA-05. Admin SDKs/credenciais administrativas não usam estas regras; permissões IAM são uma verificação separada.

## Implantação pendente

**SEC-06 aguarda aprovação do usuário desde 03/10/2026.** O usuário pediu para deixar a decisão anotada e continuar atividades independentes. Retomar esta pendência quando ele estiver disponível; não publicar regras, migrar dados nem alterar produção automaticamente. O lembrete está no [backlog](../BACKLOG.md#pendência-de-aprovação-do-usuário), sem agendamento ou data definida.

Antes de publicar, revisar a release atual, backup/recuperação, compatibilidade dos documentos legados e dos clientes distribuídos, além de validar a jornada em desenvolvimento. A auditoria não inventariou dados pessoais reais; perfis com tipos/campos divergentes e vínculos antigos inconsistentes precisam de revisão controlada. Regras mais estritas podem rejeitar operações que antes eram permitidas; essa mudança deve acompanhar a versão compatível do app.

A implantação das regras deve ser uma ação explícita posterior. Não execute migração, correção de vínculos ou deploy como parte de testes. As tarefas de consentimento, privacidade e migração continuam no [backlog](../BACKLOG.md).

Execução local reproduzível: [DEVELOPMENT.md](DEVELOPMENT.md).

## Configuração de catálogo e referência opcional

Em 03/10/2026, a regra candidata passou a aceitar `googleBooksId` ausente/null ou string de 1 a 200 caracteres. A referência não autoriza leitura/escrita: dono/parceiro/terceiro continuam seguindo as mesmas regras, e pessoas distintas podem salvar a mesma referência em documentos próprios. O teste novo de referência, legado e negação passou junto das 25 integrações em Auth/Firestore emulados. Rever compatibilidade do campo na release ao implantar; nenhuma regra foi publicada.

O literal de chave Google Books saiu do serviço e foi preservado somente em configuração local ignorada; exemplo versionado é vazio. Inventário, separação de ambiente, limites de defines, histórico Git e avaliação de rotação estão em [CONFIGURATION.md](CONFIGURATION.md). A consulta remota de restrições/quotas foi rejeitada pela revisão automática porque enviaria a chave para um endpoint Google sem autorização explícita para esse destino. Ela não foi executada; SEC-03 permanece pendente de autorização/revisão manual, independente da implantação adiada em SEC-06.
