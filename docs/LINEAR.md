# Backlog no Linear

Importação realizada em **09/10/2026**, pelo plugin Linear, no projeto [Bookself-App](https://linear.app/rodolfo-gama/project/bookself-app-70f4cc7d7b97).

[BACKLOG.md](../BACKLOG.md) permanece a fonte central. A importação inicial foi uma cópia pontual. A partir de 09/10/2026, o [AGENTS.md](../AGENTS.md#sincronização-automática-das-tarefas-com-o-linear) exige sincronização pelo plugin Linear durante a criação e atualização das tarefas, sem novo pedido do usuário, incluindo atribuição ao solicitante, estado, prioridade, conteúdo e dependências. Antes de criar tarefas novamente, consulte a correspondência abaixo para evitar duplicatas. Não há serviço em segundo plano: mudanças fora das execuções dos agentes precisam ser conciliadas na próxima execução pertinente.

Foram importados os **87 itens** existentes na leitura inicial: **31 abertos em Backlog** e **56 concluídos em Done**, preservando descrições, critérios, avanços, evidências e limites. Todos foram atribuídos ao usuário solicitante no Linear. IDs originais aparecem nos títulos e nas descrições. P0/P1/P2/P3 correspondem a Urgent/High/Medium/Low; 133 dependências foram registradas como relações de bloqueio, inclusive quando a tarefa dependente ou predecessora já estava concluída.

Conferência pelo plugin: total, unicidade, responsável, status e prioridades dos 87 itens; leitura das relações dos 65 itens com dependências confirmou todas as 133 referências. A importação não altera os critérios de conclusão nem aprova implantação, migração, fornecedores ou marca. Não foram executadas verificações Flutter, pois esta entrega altera somente documentação e cadastro de tarefas.

## MusicBrainz local — sincronização de 14/10/2026

API-04/ROD-48 e MUSIC-01/ROD-70 foram lidas antes do trabalho, iniciadas e
atualizadas pelo plugin com a integração musical local e suas evidências:
**507 testes Flutter**, **14 Node**, análise limpa, smoke público de busca/detalhes/
paginação e jornada Android API 34 de faixa/álbum salvos e relidos em **23 s**.
Releitura confirmou **In Progress**, Rodolfo Gama, prioridade High, conteúdo e
relações de bloqueio preservadas. Sem divergências nem pendências de escrita.

MUSIC-01 continua pela jornada web real pendente; API-04 também pelo audiovisual
de API-02. Hospedagem/condições públicas, capas e SEC-06 não foram liberadas.
[Escopo e comandos](MUSIC.md#musicbrainz-local--14102026). Commits locais podem
ainda não aparecer na branch remota; nenhuma implantação, migração ou publicação.

## Correspondência de IDs

| ID no repositório | Tarefa no Linear |
| --- | --- |
| DOC-01 | [ROD-5](https://linear.app/rodolfo-gama/issue/ROD-5/doc-01-criar-este-backlog-agentsmd-indice-no-readme-e-documentos-de) |
| DOC-02 | [ROD-6](https://linear.app/rodolfo-gama/issue/ROD-6/doc-02-registrar-decisoes-tecnicas-relevantes-em-docsdecisions-a) |
| DOC-03 | [ROD-7](https://linear.app/rodolfo-gama/issue/ROD-7/doc-03-documentar-configuracao-reproduzivel-de-desenvolvimento-e) |
| PROD-01 | [ROD-8](https://linear.app/rodolfo-gama/issue/ROD-8/prod-01-fechar-o-mvp-de-cada-categoria-especialmente-musica-faixas) |
| PROD-02 | [ROD-9](https://linear.app/rodolfo-gama/issue/ROD-9/prod-02-definir-navegacao-para-biblioteca-por-midia-espaco-do-casal-e) |
| PROD-03 | [ROD-10](https://linear.app/rodolfo-gama/issue/ROD-10/prod-03-validar-fluxos-e-acessibilidade-com-prototipos-e-uso-real) |
| CORE-01 | [ROD-11](https://linear.app/rodolfo-gama/issue/ROD-11/core-01-criar-estados-de-inicializacao-carregamento-e-falha-do) |
| CORE-02 | [ROD-12](https://linear.app/rodolfo-gama/issue/ROD-12/core-02-diferenciar-sessao-autenticada-de-perfil-firestore-carregando) |
| CORE-03 | [ROD-13](https://linear.app/rodolfo-gama/issue/ROD-13/core-03-permitir-limpar-campos-opcionais-em-copywith-sobretudo) |
| CORE-04 | [ROD-14](https://linear.app/rodolfo-gama/issue/ROD-14/core-04-guardarcancelar-a-assinatura-de-autenticacao-e-encerrar) |
| CORE-05 | [ROD-15](https://linear.app/rodolfo-gama/issue/ROD-15/core-05-revisar-mounted-contextos-de-dialogos-e-descarte-de) |
| CORE-06 | [ROD-16](https://linear.app/rodolfo-gama/issue/ROD-16/core-06-aguardar-e-tratar-escritas-biblicas-individuais-e-em-lote) |
| CORE-07 | [ROD-17](https://linear.app/rodolfo-gama/issue/ROD-17/core-07-preservar-o-valor-digitado-de-senha-removendo-trim-da-senha-no) |
| CORE-08 | [ROD-18](https://linear.app/rodolfo-gama/issue/ROD-18/core-08-unificar-mensagens-de-autenticacaofirestorerede-e-remover) |
| CORE-09 | [ROD-19](https://linear.app/rodolfo-gama/issue/ROD-19/core-09-persistir-preferencia-de-tema) |
| CORE-10 | [ROD-20](https://linear.app/rodolfo-gama/issue/ROD-20/core-10-dar-comportamento-coerente-ao-gesto-de-atualizar-do-inicio) |
| CORE-11 | [ROD-21](https://linear.app/rodolfo-gama/issue/ROD-21/core-11-revisar-datas-de-conclusao-edicao-de-registros-lidos-sem-data) |
| CORE-12 | [ROD-22](https://linear.app/rodolfo-gama/issue/ROD-22/core-12-evitar-orientacao-duplicada-na-mensagem-de-falha-da-busca) |
| CORE-13 | [ROD-23](https://linear.app/rodolfo-gama/issue/ROD-23/core-13-preservar-sessao-na-recarga-do-web-demo-e-configurar-auth) |
| CORE-14 | [ROD-92](https://linear.app/rodolfo-gama/issue/ROD-92/core-14-configurar-firestore-demo-antes-da-primeira-operacao-nativa) |
| SEC-01 | [ROD-24](https://linear.app/rodolfo-gama/issue/ROD-24/sec-01-auditar-regras-remotas-e-versionar-regras-do-firestore) |
| SEC-02 | [ROD-25](https://linear.app/rodolfo-gama/issue/ROD-25/sec-02-configurar-firebase-emulator-suite-para-authfirestore-e-dados) |
| SEC-03 | [ROD-26](https://linear.app/rodolfo-gama/issue/ROD-26/sec-03-inventariar-chavescredenciais-e-separar-configuracao-por) |
| SEC-04 | [ROD-27](https://linear.app/rodolfo-gama/issue/ROD-27/sec-04-separar-perfil-consultavel-pelo-parceiro-de-dados-privados-como) |
| SEC-05 | [ROD-28](https://linear.app/rodolfo-gama/issue/ROD-28/sec-05-definir-exportacao-exclusao-de-conta-e-retencao-de-dados) |
| SEC-06 | [ROD-29](https://linear.app/rodolfo-gama/issue/ROD-29/sec-06-revisar-e-publicar-as-regras-candidatas-no-ambiente-remoto) |
| COUPLE-01 | [ROD-30](https://linear.app/rodolfo-gama/issue/ROD-30/couple-01-definir-consentimento-visibilidade-padraoopcional) |
| COUPLE-02 | [ROD-31](https://linear.app/rodolfo-gama/issue/ROD-31/couple-02-tornar-vinculodesvinculo-atuais-consistentes-sob) |
| COUPLE-03 | [ROD-32](https://linear.app/rodolfo-gama/issue/ROD-32/couple-03-substituir-vinculo-direto-por-convites-com-aceite-recusa) |
| COUPLE-04 | [ROD-33](https://linear.app/rodolfo-gama/issue/ROD-33/couple-04-aplicar-visibilidade-e-revogar-acesso-ao-desvincular-em) |
| COUPLE-05 | [ROD-34](https://linear.app/rodolfo-gama/issue/ROD-34/couple-05-definir-e-implementar-registro-de-experiencia-conjunta) |
| COUPLE-06 | [ROD-35](https://linear.app/rodolfo-gama/issue/ROD-35/couple-06-criar-listas-internas-do-casal-para-proximas-leituras-filmes) |
| COUPLE-07 | [ROD-36](https://linear.app/rodolfo-gama/issue/ROD-36/couple-07-mostrar-interesses-em-comum-e-ajudar-a-escolher-o-proximo) |
| COUPLE-08 | [ROD-37](https://linear.app/rodolfo-gama/issue/ROD-37/couple-08-unificar-feed-e-estatisticas-por-midia-para-o-casal) |
| COUPLE-09 | [ROD-38](https://linear.app/rodolfo-gama/issue/ROD-38/couple-09-permitir-bloquear-apos-recusatermino-e-gerir-bloqueios) |
| DATA-01 | [ROD-39](https://linear.app/rodolfo-gama/issue/ROD-39/data-01-consolidar-modelo-de-catalogo-entrada-pessoal-progresso) |
| DATA-02 | [ROD-40](https://linear.app/rodolfo-gama/issue/ROD-40/data-02-implementar-modelosrepositorios-e-identidade-por) |
| DATA-03 | [ROD-41](https://linear.app/rodolfo-gama/issue/ROD-41/data-03-preparar-migracao-de-livros-e-vinculos-com-backup-versao) |
| DATA-04 | [ROD-42](https://linear.app/rodolfo-gama/issue/ROD-42/data-04-definir-indices-paginacao-e-estatisticas-que-nao-dependam-de) |
| DATA-05 | [ROD-43](https://linear.app/rodolfo-gama/issue/ROD-43/data-05-centralizar-acesso-a-dados-e-estrategia-de-cachesincronizacao) |
| DATA-06 | [ROD-44](https://linear.app/rodolfo-gama/issue/ROD-44/data-06-separar-createdat-atualizacao-e-eventos-de-atividade-preservar) |
| API-01 | [ROD-45](https://linear.app/rodolfo-gama/issue/ROD-45/api-01-robustecer-busca-google-books-e-preservar-referencia-externa) |
| API-02 | [ROD-46](https://linear.app/rodolfo-gama/issue/ROD-46/api-02-ensaiar-tmdb-para-filmesseries-e-decidir-fornecedor) |
| API-03 | [ROD-47](https://linear.app/rodolfo-gama/issue/ROD-47/api-03-comparar-spotify-e-musicbrainz-para-o-escopo-musical-escolhido) |
| API-04 | [ROD-48](https://linear.app/rodolfo-gama/issue/ROD-48/api-04-criar-adaptadores-de-catalogo-e-configuracao-segura-para) |
| API-05 | [ROD-49](https://linear.app/rodolfo-gama/issue/ROD-49/api-05-revisar-imagens-externas-proxy-web-e-fontes-sem-rede) |
| NAME-01 | [ROD-50](https://linear.app/rodolfo-gama/issue/ROD-50/name-01-escolher-nome-definitivo-entre-entrelace-nosso-repertorio-a) |
| NAME-02 | [ROD-51](https://linear.app/rodolfo-gama/issue/ROD-51/name-02-verificar-disponibilidade-do-candidato-escolhido-em-marcas) |
| NAME-03 | [ROD-52](https://linear.app/rodolfo-gama/issue/ROD-52/name-03-aplicar-nome-exibido-textos-icone-e-metadados-nas-plataformas) |
| UI-01 | [ROD-53](https://linear.app/rodolfo-gama/issue/ROD-53/ui-01-implementar-biblioteca-com-filtros-por-midia-buscacadastro-e) |
| UI-02 | [ROD-54](https://linear.app/rodolfo-gama/issue/ROD-54/ui-02-padronizar-estados-de-carregamento-vazio-erro-offline-e-ausencia) |
| UI-03 | [ROD-55](https://linear.app/rodolfo-gama/issue/ROD-55/ui-03-revisar-acessibilidade-contraste-escala-de-texto-foco-e-layout) |
| UI-04 | [ROD-56](https://linear.app/rodolfo-gama/issue/ROD-56/ui-04-renovar-o-design-das-telas-atuais-com-frontend-design-e-validar) |
| UI-06 | [ROD-57](https://linear.app/rodolfo-gama/issue/ROD-57/ui-06-reestruturar-o-design-com-um-sistema-consolidado-e-documentar) |
| UI-05 | [ROD-58](https://linear.app/rodolfo-gama/issue/ROD-58/ui-05-ligar-paginasagregacoes-e-sincronizacao-as-bibliotecas-e-ao-feed) |
| BOOK-01 | [ROD-59](https://linear.app/rodolfo-gama/issue/ROD-59/book-01-preservar-ids-do-catalogo-e-prevenir-duplicatas-na-mesma) |
| BOOK-02 | [ROD-60](https://linear.app/rodolfo-gama/issue/ROD-60/book-02-permitir-editar-metadados-manuais-e-melhorar-buscafiltros-da) |
| BIBLE-01 | [ROD-61](https://linear.app/rodolfo-gama/issue/ROD-61/bible-01-preservar-progresso-biblico-na-nova-navegacao-e-nas-migracoes) |
| BIBLE-02 | [ROD-62](https://linear.app/rodolfo-gama/issue/ROD-62/bible-02-ampliar-verificacao-da-estrutura-biblica-e-comportamento-de) |
| BIBLE-03 | [ROD-63](https://linear.app/rodolfo-gama/issue/ROD-63/bible-03-avaliar-um-leitor-de-textos-biblicos-como-recurso-separado) |
| MOVIE-01 | [ROD-64](https://linear.app/rodolfo-gama/issue/ROD-64/movie-01-implementar-busca-detalhes-e-cadastro-manual-de-filmes) |
| MOVIE-02 | [ROD-65](https://linear.app/rodolfo-gama/issue/ROD-65/movie-02-implementar-bibliotecastatus-de-filme-e-data-da-sessao) |
| MOVIE-03 | [ROD-66](https://linear.app/rodolfo-gama/issue/ROD-66/movie-03-conectar-filmes-as-listas-e-sessoes-do-casal) |
| SERIES-01 | [ROD-67](https://linear.app/rodolfo-gama/issue/ROD-67/series-01-definir-estados-temporadas-especiais-series-em-andamento) |
| SERIES-02 | [ROD-68](https://linear.app/rodolfo-gama/issue/ROD-68/series-02-implementar-catalogo-de-series-e-progresso-por) |
| SERIES-03 | [ROD-69](https://linear.app/rodolfo-gama/issue/ROD-69/series-03-comparar-progresso-do-casal-e-registrar-episodios-vistos) |
| MUSIC-01 | [ROD-70](https://linear.app/rodolfo-gama/issue/ROD-70/music-01-implementar-buscadetalhes-e-cadastro-manual-de-faixasalbuns) |
| MUSIC-02 | [ROD-71](https://linear.app/rodolfo-gama/issue/ROD-71/music-02-implementar-favoritos-e-registros-de-escuta-proprios) |
| MUSIC-03 | [ROD-72](https://linear.app/rodolfo-gama/issue/ROD-72/music-03-criar-descobertaslistas-musicais-e-momentos-do-casal) |
| QA-01 | [ROD-73](https://linear.app/rodolfo-gama/issue/ROD-73/qa-01-cobrir-regressoes-de-modelos-sessao-e-falhas-de-persistencia) |
| QA-02 | [ROD-74](https://linear.app/rodolfo-gama/issue/ROD-74/qa-02-testar-autorizacao-e-concorrencia-de-vinculo-em-emuladores) |
| QA-03 | [ROD-75](https://linear.app/rodolfo-gama/issue/ROD-75/qa-03-validar-uma-jornada-completa-por-midia-individual-e-em-casal) |
| QA-04 | [ROD-76](https://linear.app/rodolfo-gama/issue/ROD-76/qa-04-resolver-os-47-infos-da-analise-estatica-substituindo-apis) |
| QA-05 | [ROD-77](https://linear.app/rodolfo-gama/issue/ROD-77/qa-05-criar-ci-de-analise-e-testes-incluindo-regras-quando-disponiveis) |
| REL-01 | [ROD-78](https://linear.app/rodolfo-gama/issue/ROD-78/rel-01-reproduzir-a-falha-android-registrada-em-buildlog-com) |
| REL-02 | [ROD-79](https://linear.app/rodolfo-gama/issue/ROD-79/rel-02-configurar-assinatura-android-de-distribuicao-e-remover-uso-de) |
| REL-03 | [ROD-80](https://linear.app/rodolfo-gama/issue/ROD-80/rel-03-revisar-permissoes-e-configuracao-ios-de-cameragaleria-e) |
| REL-04 | [ROD-81](https://linear.app/rodolfo-gama/issue/ROD-81/rel-04-validar-androidiosweb-conexao-imagem-e-autenticacao-antes-de) |
| REL-05 | [ROD-82](https://linear.app/rodolfo-gama/issue/ROD-82/rel-05-definir-sdk-reproduzivel-e-revisar) |
| REL-06 | [ROD-83](https://linear.app/rodolfo-gama/issue/ROD-83/rel-06-preparar-checklist-e-notas-da-primeira-distribuicao-com-nova) |
| REL-07 | [ROD-84](https://linear.app/rodolfo-gama/issue/ROD-84/rel-07-gerar-apk-atualizado-e-publicar-release-no-github-a-pedido-do) |
| REL-08 | [ROD-85](https://linear.app/rodolfo-gama/issue/ROD-85/rel-08-gerar-apk-atualizado-e-publicar-nova-release-no-github-a-pedido) |
| REL-09 | [ROD-86](https://linear.app/rodolfo-gama/issue/ROD-86/rel-09-publicar-apk-com-o-redesign-de-ui-06-a-pedido-do-usuario) |
| IDEA-01 | [ROD-87](https://linear.app/rodolfo-gama/issue/ROD-87/idea-01-avaliacoes-comentarios-e-comparacoes-de-gosto-por-midia) |
| IDEA-02 | [ROD-88](https://linear.app/rodolfo-gama/issue/ROD-88/idea-02-metas-lembretes-e-retrospectivas-do-casal) |
| IDEA-03 | [ROD-89](https://linear.app/rodolfo-gama/issue/ROD-89/idea-03-conectar-contas-de-musica-e-sincronizar-playlistshistorico) |
| IDEA-04 | [ROD-90](https://linear.app/rodolfo-gama/issue/ROD-90/idea-04-memoria-compartilhada-com-datas-e-contexto-dos-momentos) |
| IDEA-05 | [ROD-91](https://linear.app/rodolfo-gama/issue/ROD-91/idea-05-avaliar-links-de-onde-assistirouvir-e-reproducaosessoes) |

## Histórico da pendência de 09/10/2026 — conciliada em 14/10/2026

### Continuação de QA-03 / REL-04 em 14/10/2026

ROD-75 e ROD-81 receberam evidências da jornada nativa pessoal e da ampliação para duas contas no Android 34: álbum, convite consentido, lista, experiência com duas confirmações, privacidade e revogação após término. Permanecem **In Progress**, atribuídas a Rodolfo Gama, prioridade High e dependências preservadas. [Escopo e limites](ANDROID_BUILD.md#jornada-de-duas-contas--qa-03--rel-04--14102026): repetição final aprovada em 1 min 38 s; Pixel 9 validado apenas no escopo pessoal anterior. Sem implantação, migração ou publicação. Links remotos podem ainda mostrar versões anteriores aos commits locais.

Em 14/10/2026, sob as instruções atuais de sincronização automática, as cinco issues foram relidas com relações, atualizadas por acréscimo dos avanços locais abaixo e movidas para **In Progress**. A releitura confirmou conteúdo, Rodolfo Gama, prioridades e dependências preservadas. Não houve conflito nem rejeição nesta rodada. O registro histórico abaixo descreve o impedimento anterior, já resolvido para esses cinco itens; os critérios completos continuam pendentes e nenhum deles foi marcado Done.

Na mesma rodada, **CORE-14/ROD-92** foi pesquisada antes da criação, vinculada à dependência SEC-02/ROD-25 e concluída com correção/validação Android demo; **REL-04/ROD-81** recebeu andamento e evidências, mantendo **In Progress**. Releitura confirmou responsável Rodolfo Gama, prioridade High, descrições e relações de ambos. Evidências em [ANDROID_BUILD.md](ANDROID_BUILD.md); commits/documentação locais podem ainda não aparecer nos links remotos. Nenhuma implantação, migração ou publicação.

Após reler AGENTS.md a pedido do usuário, as cinco issues abaixo foram consultadas com relações. Todas permaneciam em Backlog, atribuídas a Rodolfo Gama, com prioridades e dependências coerentes com a origem. A atualização de ROD-7 foi rejeitada pela revisão automática de aprovação: envio de detalhes internos de implementação e link de repositório a um serviço externo sem autorização explícita aceita para esse conteúdo/destino. Nenhuma escrita desta rodada foi confirmada; não foram tentados caminhos alternativos. É necessária autorização para sincronizar os avanços abaixo. Não marcar Done, pois os critérios integrais continuam pendentes.

| Item | Issue | Campos a conciliar | Evidência local e limite |
| --- | --- | --- | --- |
| QA-03 | ROD-75 | In Progress; andamento/validação | Recuperação do feed em 66ec1aa já consta na descrição importada; acrescentar conferência final de 506 Flutter/análise limpa e jornada pessoal demo. Catálogo real/plataformas e sintoma anterior não reproduzido continuam pendentes. |
| SERIES-02 | ROD-68 | In Progress; avanço/validação | Atualização incremental de episódios preserva progresso, revisões, omitidos e pausa; 4b1b2db, três regressões novas. Busca real/intermediário/implantação pendentes. |
| SEC-05 | ROD-28 | In Progress; escopo/validação | Cópia inclui episódios paginados/configurações/ocultação próprios e documento pai ausente; 280c087, três regressões novas e geração confirmada no Chrome. Exclusão/retenção/reautenticação destrutiva pendentes. |
| UI-03 | ROD-55 | In Progress; avanço/validação | Voltar preservado após troca de conta/término; seleção/anúncios de séries; aa0ee35, cinco regressões novas. Leitores de tela reais/matriz completa pendentes. |
| DOC-03 | ROD-7 | In Progress; avanço/validação | Launcher local, dois testes Node, build/jornada demo e encerramento próprio verificados; docs/DEVELOPMENT.md e docs/WEB_VALIDATION.md. Reprodução por outra pessoa pendente. |

Preservar responsável, títulos, critérios, comentários, prioridades (High em DOC-03/SERIES-02/QA-03; Medium em SEC-05/UI-03) e relações de bloqueio existentes. Dependências não mudaram nesta rodada. Antes de repetir, reler as issues e verificar conflitos; após autorização e escrita, reler os campos e relações. Os commits desta rodada ainda são locais; links da branch remota podem mostrar versões anteriores até o push.
