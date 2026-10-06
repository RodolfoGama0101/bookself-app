# Consentimento e visibilidade do casal

Revisão: 05/10/2026. **COUPLE-01 concluída como decisão de produto; política v1 aprovada pelo usuário.** Política para a evolução; não descreve uma funcionalidade já implementada nem autoriza migração ou implantação de regras.

## Escolha registrada

O usuário escolheu compartilhar biblioteca e progresso por padrão após aceite, com opção de ocultar itens. A alternativa considerada foi manter tudo privado até compartilhar cada item. O padrão escolhido reduz passos após o vínculo; a possibilidade de ocultação exige autorização por registro e não apenas filtros de interface.

Biblioteca e progresso são o escopo aprovado. E-mail, credenciais e dados privados de conta não fazem parte dele. Em 05/10/2026, o usuário escolheu **adotar a proposta recomendada**: convites de sete dias, identidade mínima com nome/foto, biblioteca existente compartilhada preservando ocultação, feed sem retroatividade, Bíblia ocultável por livro, favoritos/opiniões/escutas privados, bloqueio que encerra o vínculo, histórico conjunto restrito aos participantes antigos e experiências com confirmação dos dois. As seções abaixo detalham essa política e seus critérios de implementação.

## Política v1 aprovada

Aprovada em 05/10/2026 para fechar COUPLE-01. SEC-04 e COUPLE-03 podem avançar sob suas demais dependências e critérios. O registro aprova a política de produto, sem aprovar um novo esquema, migração ou implantação.

### Conta individual e identidade

Biblioteca, progresso e Bíblia continuam disponíveis sem parceiro e após o término. A primeira entrega de listas contempla somente listas do casal; listas pessoais ficam para avaliação posterior. Nenhum terceiro ganha acesso por conhecer um código, consultar um convite ou ter participado de uma relação antiga.

O convite e a relação ativa exibem nome e foto opcional. E-mail, credenciais, bloqueios e dados privados de conta ficam restritos ao dono. O código de convite é opaco, não contém o UID e não serve como autorização de leitura. Identificadores internos podem existir no contrato técnico; não serão usados como código público nem exibidos desnecessariamente na interface. A definição de token, índices e armazenamento fica para SEC-04/COUPLE-03/DATA-01.

### Convites e consentimento

Cada conta pode ter um convite enviado ativo e somente uma relação ativa. O convite vale por sete dias desde sua criação, medidos pelo servidor. Conta vinculada não envia nem aceita convites. Conhecer o código permite solicitar a apresentação mínima para decidir; não permite listar contas ou convites, nem ler biblioteca, progresso ou histórico.

Antes de confirmar, remetente e destinatário veem a regra de compartilhamento e a opção de ocultar itens. O destinatário aceita ou recusa; o remetente cancela. Reenviar exige um novo convite e novo código. Um convite terminal nunca volta a ser pendente e não pode ser reutilizado. Proteção contra tentativas repetidas e enumeração é critério técnico obrigatório de COUPLE-03; limites operacionais devem ser registrados nessa implementação.

| Estado de origem | Ação e responsável | Resultado exigido |
| --- | --- | --- |
| Sem convite/relação | Conta livre cria convite | Pendente, com criação e expiração do servidor. |
| Pendente e ainda válido | Destinatário distinto aceita | Aceito e relação ativa na mesma operação atômica, se ambas as contas estiverem livres e não houver bloqueio. |
| Pendente e ainda válido | Destinatário recusa | Recusado, sem relação ou acesso pessoal. |
| Pendente | Remetente cancela | Cancelado, sem relação ou acesso pessoal. |
| Pendente no limite de expiração ou depois | Tentativa de aceite | Expirado; nenhuma relação é criada. |
| Aceito, recusado, cancelado ou expirado | Reuso do código | Rejeitado; nenhuma alteração na relação atual. |

Autoaceite, destinatário diferente, terceiro, cancelamento concorrente e dois aceites concorrentes precisam de autorização no servidor. Se aceite e cancelamento disputarem o mesmo convite, somente uma transição vence. Um convite aceito encerra outros convites pendentes dos participantes; respostas antigas não alteram o novo vínculo. O sucesso só é anunciado depois da confirmação da escrita.

### Biblioteca e progresso compartilhados

O aceite inclui registros existentes e futuros da biblioteca e seu progresso, exceto os já ocultos. Não cria eventos retroativos no feed. Estatísticas pessoais por período podem considerar progresso histórico permitido; a tela de consentimento deve explicar essa diferença. O feed da relação começa no aceite e usa somente atividades posteriores permitidas, sem reconstruir datas/eventos ausentes.

O dono controla visibilidade por entrada pessoal. Na Bíblia, o controle é por livro bíblico, abrangendo todos os seus capítulos. Não há ocultação por capítulo nesta primeira política. Ocultar remove o item/progresso das consultas, detalhes, feed, comparação, coincidências e agregados do parceiro. Totais compartilhados usam somente conteúdo visível; não exibem contagens de itens ocultos nem percentuais com denominadores que revelem progresso privado.

Favoritos, opiniões/comentários e registros pessoais de escuta permanecem privados nesta primeira versão, inclusive quando a obra está visível. Compartilhar uma obra não concede leitura de todos os campos do documento pessoal. Uma faixa/álbum salvo pode ser consultado como item de biblioteca, sem revelar quando ou quantas vezes a pessoa ouviu. Experiências conjuntas são registros separados e consentidos pelos participantes.

Mostrar novamente um item permite consultar seu estado atual, sem gerar um evento histórico fictício. As preferências de ocultação são pessoais e sobrevivem ao término e a novos vínculos; o aceite de outra relação apresenta novamente esse padrão, sem reativar itens ocultos automaticamente.

### Autoria de listas e experiências

Cada pessoa altera somente seu progresso, favorito, opinião e escuta pessoal. Uma ação conjunta nunca conclui um livro, filme, episódio ou escuta pelo parceiro. Quem deseja atualizar seu estado pessoal confirma essa ação separadamente.

Em uma lista ativa, ambos podem adicionar ou retirar seleções; a origem e o autor da inclusão permanecem identificáveis. Adicionar deliberadamente uma obra a uma lista compartilha apenas sua referência de catálogo ou os metadados mínimos manuais escolhidos para a lista. Não compartilha o registro pessoal, progresso ou campos privados. Antes da inclusão, a interface explica que a seleção será visível na lista mesmo se o item pessoal estiver oculto. Ocultar o registro pessoal não retira automaticamente uma seleção conjunta já consentida; remover da lista é uma ação própria.

Uma experiência tem autor da proposta, participantes, obra e data explícitos. O outro participante confirma ou recusa; sem duas confirmações, não aparece como experiência confirmada dos dois nem entra em suas estatísticas conjuntas. O autor pode corrigir a proposta; mudança de obra, data ou participantes exige nova confirmação. Cada pessoa pode retirar sua confirmação, e a experiência deixa de contar como conjunta confirmada. Recusa/retirada não apagam nem modificam registros pessoais. Campos, auditoria e mecanismo de repetição sem duplicatas serão definidos em COUPLE-05/DATA-01.

### Término, bloqueio e novo vínculo

Qualquer participante pode encerrar a relação sem aceite do outro. O servidor revoga o acesso à biblioteca, progresso e perfil consultável pela relação encerrada; dados pessoais e preferências de ocultação são preservados. O cliente encerra ouvintes, remove telas/estado compartilhado e limpa caches do app associados à relação. Dados que já foram entregues, copiados ou capturados pelo destinatário não podem ser recolhidos.

Bloquear encerra a relação ativa entre essas pessoas, invalida seus convites pendentes e impede novos convites/aceites entre elas. O bloqueio é privado; o outro recebe uma mensagem genérica de indisponibilidade, sem revelar quem bloqueou. Somente quem bloqueou pode desfazer seu bloqueio; bloqueios dos dois lados são independentes. Desbloquear não restaura relação, convite ou permissão: exige novo convite e aceite.

Listas e experiências da relação encerrada ficam em um histórico privado, disponível apenas para os dois participantes antigos, sem edição conjunta nem acesso a estados pessoais atuais. O histórico preserva somente seleções e participações intencionalmente compartilhadas; não mantém uma cópia da biblioteca privada do ex-parceiro. Bloqueio não concede novas leituras pessoais e não elimina o histórico de autoria própria; o histórico conjunto segue a mesma restrição do término. Retirada da própria confirmação continua disponível, sem reabrir a relação.

Prazo de retenção, exportação e exclusão de conta continuam em SEC-05. A política de histórico não promete retenção perpétua nem impede futura exclusão compatível com autoria e privacidade. Novo vínculo cria outra relação e nunca herda convites, listas, experiências ou acesso ao histórico anterior, mesmo entre as mesmas duas pessoas.

### Relações existentes

Vínculos legados diretos não comprovam aceite desta política. DATA-03 deve definir uma transição compatível, mantendo contas, livros e capítulos; a ativação da nova política requer consentimento explícito dos dois participantes. Não converter silenciosamente `partnerUid` em aceite, nem reparar vínculos divergentes como efeito colateral. Sem migração validada, o contrato e o fluxo atuais permanecem os descritos em [ARCHITECTURE.md](ARCHITECTURE.md).

## Critérios para validar a implementação futura

Esta matriz define verificações necessárias; nenhum cenário novo foi executado nesta tarefa de decisão/documentação.

| Cenário | Resultado exigido | Tarefa responsável |
| --- | --- | --- |
| Conta sem parceiro, terceiro e não autenticado | Progresso pessoal utilizável pelo dono; leituras alheias e listagens negadas. | SEC-04, COUPLE-03/04 |
| Código conhecido e convite pendente | Somente apresentação mínima; nenhum e-mail, biblioteca, progresso ou histórico. | SEC-04, COUPLE-03 |
| Aceite válido e repetição de envio | Uma relação ativa; confirmação só após escrita; convite consumido uma vez. | COUPLE-03 |
| Recusa, cancelamento, expiração no limite e reuso | Nenhuma relação/acesso criado; estado terminal preservado. | COUPLE-03 |
| Aceite/cancelamento simultâneo e disputa pela mesma pessoa | Um resultado atômico; outra relação e convites antigos não sobrescritos. | COUPLE-03, QA-02 |
| Aceite com itens existentes, ocultos e atividades anteriores | Biblioteca permitida acessível; ocultos privados; feed sem retroatividade. | COUPLE-04, DATA-06 |
| Ocultação durante consultas e assinatura ativa | Revogação no servidor e limpeza de estado; ausência de vazamento por contagens, feed e comparação bíblica. | COUPLE-04, DATA-05 |
| Obra visível com favorito, opinião ou escuta privada | Leitura do documento inteiro não entrega os campos privados. | SEC-04, DATA-01/02 |
| Inclusão deliberada de item oculto numa lista | Só seleção mínima compartilhada, com aviso e autoria; registro pessoal continua privado. | COUPLE-06 |
| Proposta, confirmação, edição, recusa e retirada de experiência | Nenhuma alteração de progresso alheio; contagem conjunta somente com confirmações válidas. | COUPLE-05 |
| Desvínculo/bloqueio e escrita atrasada do par antigo | Revogação de leituras pessoais; dados próprios e relação nova preservados. | COUPLE-03/04, QA-02 |
| Desbloqueio e novo vínculo, inclusive com o mesmo ex-parceiro | Novo aceite obrigatório; ocultação mantida; nenhum acesso ao histórico de outra relação. | COUPLE-03/04, DATA-03 |
| Histórico após término/bloqueio | Só participantes antigos consultam conteúdo conjunto consentido; sem biblioteca atual ou edição conjunta. | COUPLE-05/06, SEC-05 |
| Relação legada sem aceite da política | Nenhuma conversão automática; ensaio preserva dados e prevê recuperação. | DATA-03 |

## Efeitos técnicos e sequência

SEC-04 separou localmente o perfil consultável do privado, conforme [registro 007](decisions/007-perfil-privado-e-consultavel.md), com implantação remota pendente. COUPLE-03 implementou localmente convites e transições consentidas; contrato e limites em [COUPLE_INVITATIONS.md](COUPLE_INVITATIONS.md). Relações legadas permanecem, sem conversão automática em aceite. COUPLE-04 implementou localmente visibilidade/revogação de livros e Bíblia, com projeções mínimas, ouvintes e limpeza de cache/estado; [contrato e limites](COUPLE_VISIBILITY.md). Bloqueio fora do vínculo permanece em COUPLE-09; novas mídias, listas e experiências precisam de implementações próprias. DATA-01 deve separar catálogo, estado pessoal e experiência conjunta; esta política não escolhe nomes de coleções ou IDs do novo esquema.

A decisão explícita do usuário está registrada nesta política e no [registro 006](decisions/006-consentimento-e-visibilidade.md); COUPLE-01 está concluída no backlog. As dependências podem avançar em desenvolvimento, mas só ficam concluídas com código e testes próprios. A aprovação de uma política não autoriza implantação de regras, migração ou publicação. SEC-06 continua aguardando aprovação separada, conforme [SECURITY.md](SECURITY.md#implantação-pendente). Critérios e dependências permanecem no [backlog](../BACKLOG.md).
