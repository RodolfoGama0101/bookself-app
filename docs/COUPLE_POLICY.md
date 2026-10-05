# Consentimento e visibilidade do casal

Revisão: 05/10/2026. COUPLE-01 em andamento. Política para a evolução; não descreve uma funcionalidade já implementada nem autoriza migração ou implantação de regras.

## Escolha registrada

O usuário escolheu compartilhar biblioteca e progresso por padrão após aceite, com opção de ocultar itens. A alternativa considerada foi manter tudo privado até compartilhar cada item. O padrão escolhido reduz passos após o vínculo; a possibilidade de ocultação exige autorização por registro e não apenas filtros de interface.

Biblioteca e progresso são o escopo aprovado. E-mail, credenciais e dados privados de conta não fazem parte dele. Fotos, favoritos, opiniões, escutas, histórico anterior ao aceite e detalhes de atividades conjuntas precisam de delimitação explícita; não presumir autorização por estarem em um mesmo documento.

## Proposta para fechar COUPLE-01

As regras abaixo são propostas para revisão. Não completar COUPLE-01 nem implementar o novo contrato enquanto seus pontos de decisão estiverem pendentes.

| Situação | Comportamento proposto | Decisão/validação pendente |
| --- | --- | --- |
| Conta sem parceiro | Biblioteca, progresso e Bíblia funcionam individualmente; nenhuma leitura por outra conta. | Confirmar que listas pessoais ficam fora do primeiro fluxo de listas do casal. |
| Convite pendente | Sem acesso à biblioteca/progresso; destinatário vê somente a identidade mínima para decidir. Remetente pode cancelar; destinatário pode aceitar ou recusar. | Definir validade, limite de convites, identidade exibida e proteção contra tentativas repetidas; código não deve expor UID. |
| Aceite | Explicar o padrão e a opção de ocultar antes de confirmar; ativação atômica somente com ambas as contas disponíveis e convite válido. | Definir se o padrão inclui itens existentes e atividades anteriores; revisar concorrência/cancelamento simultâneo. |
| Relação ativa | Dono altera seu registro; parceiro consulta somente conteúdo permitido. Ocultar retira o registro de consultas, detalhes, feed, comparação e agregados do parceiro. | Definir se o controle é por item e/ou categoria; Bíblia precisa de unidade própria de visibilidade. |
| Conteúdo pessoal privado | Nunca participar de listas automáticas, coincidências ou estatísticas que revelem o registro ao parceiro. | Definir comportamento de referências que já tenham sido inseridas intencionalmente em uma lista conjunta. |
| Desvinculação | Qualquer participante pode encerrar sem aceite do outro. Preservar livros, progresso bíblico e registros pessoais; revogar novas leituras do ex-parceiro no servidor. | Definir limpeza de telas/cache; dados já entregues não podem ser recolhidos do destinatário. |
| Bloqueio | Impedir novos convites e acesso pela relação bloqueada; não transferir autoria nem excluir os registros da outra pessoa. | Confirmar efeito sobre relação ativa, reversão e informação exibida ao bloqueado. |
| Novo vínculo | Relação nova não herda convites, permissão ou conteúdo conjunto da anterior. | Definir o padrão para itens pessoais antes ocultos: manter ocultação ou pedir nova escolha. |
| Experiência conjunta | Autor registra proposta; outro participante confirma a participação. Não concluir progresso nem alterar opinião alheia automaticamente. | Definir edição, recusa, retirada de confirmação e retenção em COUPLE-05/SEC-05. |
| Listas e momentos após fim | Preservar autoria e impedir acesso do novo parceiro aos dados da relação anterior. | Escolher retenção: consulta histórica pelos participantes, cópia pessoal ou remoção do espaço compartilhado. Nenhuma alternativa escolhida. |

## Efeitos técnicos a validar

- SEC-04 precisa separar o perfil privado do consultável. Firestore entrega documentos inteiros; visibilidade não pode depender de omitir o e-mail na tela.
- COUPLE-03 precisa de estados e transições de convite, expiração, consumo único e concorrência. O batch de vínculo direto atual não implementa aceite.
- COUPLE-04 precisa revogar consultas e ouvintes, tratar conteúdo já exibido/cache e testar ex-parceiro e novo parceiro. Ocultação também precisa evitar vazamento por contagens e feed.
- DATA-01 deve separar catálogo, estado pessoal e experiência conjunta; fornecedor, mídia e proprietário participam das identidades. Este documento não aprova um novo esquema.
- DATA-03 precisa definir compatibilidade para relações existentes antes de migrar. Não considerar um vínculo legado como aceite da política nova.

## Próximos passos

Fechar os pontos da tabela e registrar a versão da política antes de SEC-04/COUPLE-03. Validar não autenticado, dono, participante, terceiro, convite cancelado/expirado, disputas por conta, ocultação durante uma assinatura ativa, desvínculo e novo par em emuladores. Critérios e dependências continuam no [backlog](../BACKLOG.md); comportamento atual e implantação adiada estão em [SECURITY.md](SECURITY.md).
