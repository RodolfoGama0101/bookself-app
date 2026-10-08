# Registro de decisões técnicas

Decisões registradas em 03/10/2026 a partir do código já implementado e das evidências locais. Cada registro explicita alternativas, escolha, motivos, consequências e pendências. Alterações futuras devem atualizar o registro ou criar outro que o substitua.

| Registro | Estado | Escopo |
| --- | --- | --- |
| [001 — Ambiente Firebase demo separado](001-firebase-demo.md) | Implementado localmente | Serviços atuais, emuladores e isolamento da configuração distribuída. |
| [002 — Confirmação e preservação de dados](002-confirmacao-e-preservacao.md) | Implementado localmente | Modelos atuais, perfil, progresso e ciclo de vida das operações. |
| [003 — Consistência do vínculo atual](003-vinculo-atual.md) | Criação direta substituída pelo registro 008; legado preservado | Vínculo direto existente, sem definir uma política nova de consentimento. |
| [004 — SDK fixado e verificações de integração](004-sdk-e-ci.md) | SDK local verificado; CI remoto pendente | Flutter/Dart e testes sem produção. |
| [005 — Catálogo e recursos de leitura](005-catalogo-e-recursos.md) | Código local pronto; auditoria/plataformas pendentes | Configuração Google Books, referência externa, fontes locais e capas diretas. |
| [006 — Consentimento e visibilidade do casal](006-consentimento-e-visibilidade.md) | Política v1 aprovada; convites locais, demais controles pendentes | Convites, ocultação, autoria, bloqueio e histórico após término. |
| [007 — Perfil privado e apresentação do parceiro](007-perfil-privado-e-consultavel.md) | Código/regras locais validados; implantação pendente | Leitura mínima, publicação do próprio perfil e compatibilidade de clientes antigos. |
| [008 — Convites consentidos e invalidação por versão](008-convites-consentidos.md) | Código/regras locais validados; implantação pendente | Consentimento, expiração, limites, reuso e compatibilidade legada. |
| [009 — Projeções e revogação](009-visibilidade-e-revogacao.md) | Código/regras locais validados; implantação pendente | Ocultação, dados mínimos, legado, feed e cache nas categorias atuais. |
| [010 — Bloqueios independentes](010-bloqueios-independentes.md) | Código/regras locais; implantação pendente | Identificação mínima por interação autorizada e bloqueio após recusa/término. |
| [011 — Modelo de múltiplas mídias v1](011-modelo-multimidia-v1.md) | Especificação; base privada DATA-02 local, demais entidades pendentes | Identidade de catálogo, estado pessoal, episódios/escutas, relação, listas/experiências e eventos. |
| [012 — Preparação e acesso a dados](012-preparacao-e-acesso-a-dados.md) | Código/ensaio local; adoção nas telas e operações remotas separadas | Backup/recuperação, paginação/contagens/índices e estados de sincronização. |

**Atualização de 05/10/2026:** o usuário escolheu biblioteca/progresso compartilhados por padrão após aceite, com ocultação, e escopo musical com faixas/álbuns, favoritos, escutas e listas do casal. As escolhas estão em [PRODUCT.md](../PRODUCT.md); a [política v1 de consentimento/visibilidade](../COUPLE_POLICY.md) foi aprovada posteriormente nesta data e está no registro 006, com convites no registro 008 e visibilidade/revogação de livros/Bíblia no registro 009; novas mídias e histórico conjunto ainda pendentes. COUPLE-09 implementou bloqueio fora do vínculo em 08/10/2026, conforme registro 010, com implantação remota pendente. Não há decisão aprovada de novo fornecedor audiovisual/musical, marca ou esquema de múltiplas mídias. Firebase e Google Books permanecem as integrações existentes. Ensaios/alternativas de fornecedores estão em [INTEGRATIONS.md](../INTEGRATIONS.md); decisões e dependências estão em [BACKLOG.md](../../BACKLOG.md). A [jornada web de 05/10](../WEB_VALIDATION.md) complementa as evidências históricas destes registros; não valida plataformas nativas nem produção.

**PROD-01 — MVP aprovado em 05/10/2026:** o usuário aprovou escopo, campos/estados gerais e critérios de todas as categorias em [PRODUCT.md](../PRODUCT.md#mvp-aprovado--prod-01). É uma decisão de produto; fornecedores, marca e regras detalhadas de séries continuam pendentes. DATA-01 consolidou posteriormente uma proposta de esquema v1, conforme registro 011. Novas categorias não foram implementadas.

**PROD-02 — Navegação definida em 08/10/2026:** [mapa v1](../NAVIGATION.md) especifica Início/Biblioteca/Nós/Perfil, acesso próprio à Bíblia, fluxos individual/em casal e critérios responsivos. Revisão documental contra código/MVP/política; implementação e validação de uso real ficam em UI-01/PROD-03/UI-03. Não altera decisões de esquema, marca, fornecedores ou implantação.
