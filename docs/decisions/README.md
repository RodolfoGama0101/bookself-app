# Registro de decisões técnicas

Decisões registradas em 03/10/2026 a partir do código já implementado e das evidências locais. Cada registro explicita alternativas, escolha, motivos, consequências e pendências. Alterações futuras devem atualizar o registro ou criar outro que o substitua.

| Registro | Estado | Escopo |
| --- | --- | --- |
| [001 — Ambiente Firebase demo separado](001-firebase-demo.md) | Implementado localmente | Serviços atuais, emuladores e isolamento da configuração distribuída. |
| [002 — Confirmação e preservação de dados](002-confirmacao-e-preservacao.md) | Implementado localmente | Modelos atuais, perfil, progresso e ciclo de vida das operações. |
| [003 — Consistência do vínculo atual](003-vinculo-atual.md) | Código e regras locais; implantação pendente | Vínculo direto existente, sem definir uma política nova de consentimento. |
| [004 — SDK fixado e verificações de integração](004-sdk-e-ci.md) | SDK local verificado; CI remoto pendente | Flutter/Dart e testes sem produção. |
| [005 — Catálogo e recursos de leitura](005-catalogo-e-recursos.md) | Código local pronto; auditoria/plataformas pendentes | Configuração Google Books, referência externa, fontes locais e capas diretas. |

**Não há decisão aprovada de novo fornecedor audiovisual/musical, marca, consentimento, visibilidade ou esquema de múltiplas mídias.** Firebase e Google Books permanecem as integrações existentes, sem novo fornecedor nesta entrega. Ensaios/alternativas de fornecedores estão em [INTEGRATIONS.md](../INTEGRATIONS.md); decisões de produto e dependências estão em [BACKLOG.md](../../BACKLOG.md).
