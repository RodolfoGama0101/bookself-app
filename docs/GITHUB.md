# Gestão de tarefas no GitHub

Atualização de **13/11/2026**, por solicitação do usuário. [Issues](https://github.com/RodolfoGama0101/bookself-app/issues) são a fonte única de tarefas e estados. O [AGENTS.md](../AGENTS.md#gestão-de-tarefas-no-github) define o fluxo obrigatório; [BACKLOG.md](../BACKLOG.md) é somente um índice. O Linear permanece histórico, sem sincronização.

## Visão de trabalho

Comece pelo [roadmap](https://github.com/RodolfoGama0101/bookself-app/issues/1), com oito etapas e suas sub-issues. Os [milestones](https://github.com/RodolfoGama0101/bookself-app/milestones) organizam a sequência sem inventar prazos. Cada tarefa tem responsável, prioridade, área, tipo, estado, critérios, dependências e evidências próprias.

- [MAIN-01 — 1. Base reproduzível e CI](https://github.com/RodolfoGama0101/bookself-app/issues/90).
- [MAIN-02 — 2. Confiabilidade e regressões do aplicativo](https://github.com/RodolfoGama0101/bookself-app/issues/91).
- [MAIN-03 — 3. Autorização, consentimento e privacidade de acesso](https://github.com/RodolfoGama0101/bookself-app/issues/92).
- [MAIN-04 — 4. Dados, livros e preservação da Bíblia](https://github.com/RodolfoGama0101/bookself-app/issues/93).
- [MAIN-05 — 5. Experiência, navegação e acessibilidade](https://github.com/RodolfoGama0101/bookself-app/issues/94).
- [MAIN-06 — 6. Expansão incremental e decisões de produto](https://github.com/RodolfoGama0101/bookself-app/issues/95).
- [MAIN-07 — 7. Validação e distribuição controlada](https://github.com/RodolfoGama0101/bookself-app/issues/96).
- [MAIN-08 — 8. Ideias e decisões posteriores ao MVP](https://github.com/RodolfoGama0101/bookself-app/issues/97).

## Convenções

| Campo | Regra |
| --- | --- |
| Identidade | Preservar ID no título e corpo; número do GitHub é a referência operacional |
| Responsável padrão | Rodolfo Gama, usuário `RodolfoGama0101` |
| Prioridade | Uma label `prioridade:p0` a `prioridade:p3` |
| Estado | Uma label `status:backlog`, `em-andamento`, `bloqueada`, `em-revisao`, `concluida` ou `cancelada` |
| Estado nativo | Aberta até cumprir critérios; fechada/completed para entrega; fechada/not_planned para duplicata/desistência justificada |
| Área e natureza | Labels `area:*` e `tipo:*` |
| Etapa | Milestone e sub-issue de uma etapa/roadmap |
| Dependência | Link no corpo e relação nativa `blocked by`, atualizados juntos |
| Branch | Registrar base, destino, ambiente e commit; `origem:develop` não comprova integração à main |
| PR parcial | `Refs #N`; fechar somente quando o critério integral for cumprido |
| PR completo | `Closes #N` apenas se a integração realmente concluir a tarefa |

Não há GitHub Project ou proteção de branch instalado por este fluxo. Labels e milestones constituem a organização operacional; a efetividade dos checks/proteções é tratada em [QA-05](https://github.com/RodolfoGama0101/bookself-app/issues/75). Dependências de decisão e de implantação devem ter limites explícitos; histórico fechado pode ter sucessores ainda abertos.

## Migração e branches

- Origem: [develop 2ccc222](https://github.com/RodolfoGama0101/bookself-app/tree/2ccc222eeec290dd18d3fb8e1e10d7e1d41fd841); 88 itens, sendo 65 com conclusão documentada e 23 abertos no momento da importação.
- Base da análise: [main 4201dde](https://github.com/RodolfoGama0101/bookself-app/tree/4201dde5a6ec79e4886b30e42a90a6a5ad64958d), 80 commits atrás da develop naquele momento.
- Foram criadas também oito etapas MAIN, o roadmap e a tarefa GITHUB-01 de organização: **98 issues**, com IDs únicos. A migração preserva o escopo das conclusões anteriores; não declara essas funcionalidades presentes na main.
- As etapas MAIN exigem revisão, integração por conjuntos coesos e validação própria. A criação das issues não executa as funcionalidades planejadas.
- As referências históricas usam snapshots imutáveis; avanços posteriores devem usar links de commit/PR acessíveis. O [registro anterior do Linear](LINEAR.md) foi preservado sem apagar conteúdo remoto.
- Publicação de regras, migração, credenciais e releases continuam ações separadas. A [SEC-06](https://github.com/RodolfoGama0101/bookself-app/issues/27) preserva a autorização pendente; [SEC-03](https://github.com/RodolfoGama0101/bookself-app/issues/24), [QA-05](https://github.com/RodolfoGama0101/bookself-app/issues/75) e [REL-03](https://github.com/RodolfoGama0101/bookself-app/issues/78) preservam os demais impedimentos conhecidos.

## Conferência da entrega

Releitura remota em **13/11/2026** confirmou **98 issues únicas**, todas atribuídas a `RodolfoGama0101`, com prioridades, classificação e estados coerentes, **43 labels de organização**, **oito milestones**, **151 dependências nativas** e **97 vínculos de sub-issues**. Critérios, referências e correspondências foram conferidos, sem divergências. Validação documental: 17 links locais existentes na main, dois YAMLs válidos, JSON com 98 IDs/números únicos e `git diff --check` aprovado. Nenhum arquivo funcional do aplicativo foi alterado; verificações Flutter não são necessárias para esta entrega documental. Publicação e evidências finais são acompanhadas na [GITHUB-01](https://github.com/RodolfoGama0101/bookself-app/issues/98).

## Correspondência de IDs

Tabela de identidade, sem duplicar estados vivos. Consulte o conteúdo e o andamento na issue. O [arquivo JSON](github-issues.json) contém a mesma correspondência para ferramentas; ao criar um ID novo, atualize os dois no mesmo commit.

| ID estável | Issue | Tarefa |
| --- | --- | --- |
| ROADMAP-01 | [#1](https://github.com/RodolfoGama0101/bookself-app/issues/1) | organizar melhorias e integração validada à main |
| DOC-01 | [#2](https://github.com/RodolfoGama0101/bookself-app/issues/2) | criar este backlog, `AGENTS.md`, índice no README e documentos de arquitetura, produto e integrações |
| DOC-02 | [#3](https://github.com/RodolfoGama0101/bookself-app/issues/3) | registrar decisões técnicas relevantes em `docs/decisions/` à medida que forem tomadas |
| DOC-03 | [#4](https://github.com/RodolfoGama0101/bookself-app/issues/4) | documentar configuração reproduzível de desenvolvimento e emuladores |
| PROD-01 | [#5](https://github.com/RodolfoGama0101/bookself-app/issues/5) | fechar o MVP de cada categoria, especialmente música: faixas, álbuns, listas internas e registros de escuta |
| PROD-02 | [#6](https://github.com/RodolfoGama0101/bookself-app/issues/6) | definir navegação para Biblioteca por mídia, espaço do casal e acesso à Bíblia |
| PROD-03 | [#7](https://github.com/RodolfoGama0101/bookself-app/issues/7) | validar fluxos e acessibilidade com protótipos e uso real |
| CORE-01 | [#8](https://github.com/RodolfoGama0101/bookself-app/issues/8) | criar estados de inicialização, carregamento e falha do Firebase |
| CORE-02 | [#9](https://github.com/RodolfoGama0101/bookself-app/issues/9) | diferenciar sessão autenticada de perfil Firestore carregando, ausente ou com erro |
| CORE-03 | [#10](https://github.com/RodolfoGama0101/bookself-app/issues/10) | permitir limpar campos opcionais em `copyWith`, sobretudo `finishedDate` |
| CORE-04 | [#11](https://github.com/RodolfoGama0101/bookself-app/issues/11) | guardar/cancelar a assinatura de autenticação e encerrar assinaturas de usuário/parceiro em `AuthService.dispose` |
| CORE-05 | [#12](https://github.com/RodolfoGama0101/bookself-app/issues/12) | revisar `mounted`, contextos de diálogos e descarte de controladores após operações assíncronas |
| CORE-06 | [#13](https://github.com/RodolfoGama0101/bookself-app/issues/13) | aguardar e tratar escritas bíblicas, individuais e em lote |
| CORE-07 | [#14](https://github.com/RodolfoGama0101/bookself-app/issues/14) | preservar o valor digitado de senha, removendo `trim()` da senha no envio do login/cadastro |
| CORE-08 | [#15](https://github.com/RodolfoGama0101/bookself-app/issues/15) | unificar mensagens de autenticação/Firestore/rede e remover detalhes técnicos dos textos ao usuário |
| CORE-09 | [#16](https://github.com/RodolfoGama0101/bookself-app/issues/16) | persistir preferência de tema |
| CORE-10 | [#17](https://github.com/RodolfoGama0101/bookself-app/issues/17) | dar comportamento coerente ao gesto de atualizar do Início, cujo callback atual é vazio |
| CORE-11 | [#18](https://github.com/RodolfoGama0101/bookself-app/issues/18) | revisar datas de conclusão, edição de registros lidos sem data e formatação/localização de seletores |
| CORE-12 | [#19](https://github.com/RodolfoGama0101/bookself-app/issues/19) | evitar orientação duplicada na mensagem de falha da busca |
| CORE-13 | [#20](https://github.com/RodolfoGama0101/bookself-app/issues/20) | preservar sessão na recarga do web demo e configurar Auth local antes da restauração |
| CORE-14 | [#21](https://github.com/RodolfoGama0101/bookself-app/issues/21) | configurar Firestore demo antes da primeira operação nativa |
| SEC-01 | [#22](https://github.com/RodolfoGama0101/bookself-app/issues/22) | auditar regras remotas e versionar regras do Firestore; registrar índices necessários |
| SEC-02 | [#23](https://github.com/RodolfoGama0101/bookself-app/issues/23) | configurar Firebase Emulator Suite para Auth/Firestore e dados de teste isolados |
| SEC-03 | [#24](https://github.com/RodolfoGama0101/bookself-app/issues/24) | inventariar chaves/credenciais e separar configuração por ambiente |
| SEC-04 | [#25](https://github.com/RodolfoGama0101/bookself-app/issues/25) | separar perfil consultável pelo parceiro de dados privados, como e-mail |
| SEC-05 | [#26](https://github.com/RodolfoGama0101/bookself-app/issues/26) | definir exportação, exclusão de conta e retenção de dados pessoais/compartilhados |
| SEC-06 | [#27](https://github.com/RodolfoGama0101/bookself-app/issues/27) | revisar e publicar as regras candidatas no ambiente remoto |
| COUPLE-01 | [#28](https://github.com/RodolfoGama0101/bookself-app/issues/28) | definir consentimento, visibilidade padrão/opcional, bloqueio/cancelamento, dados após desvínculo e autoria de experiências |
| COUPLE-02 | [#29](https://github.com/RodolfoGama0101/bookself-app/issues/29) | tornar vínculo/desvínculo atuais consistentes sob concorrência, validando ambas as contas e reciprocidade |
| COUPLE-03 | [#30](https://github.com/RodolfoGama0101/bookself-app/issues/30) | substituir vínculo direto por convites com aceite, recusa, expiração e cancelamento |
| COUPLE-04 | [#31](https://github.com/RodolfoGama0101/bookself-app/issues/31) | aplicar visibilidade e revogar acesso ao desvincular em todas as categorias |
| COUPLE-05 | [#32](https://github.com/RodolfoGama0101/bookself-app/issues/32) | definir e implementar registro de experiência conjunta |
| COUPLE-06 | [#33](https://github.com/RodolfoGama0101/bookself-app/issues/33) | criar listas internas do casal para próximas leituras, filmes, séries e músicas |
| COUPLE-07 | [#34](https://github.com/RodolfoGama0101/bookself-app/issues/34) | mostrar interesses em comum e ajudar a escolher o próximo item |
| COUPLE-08 | [#35](https://github.com/RodolfoGama0101/bookself-app/issues/35) | unificar feed e estatísticas por mídia para o casal |
| COUPLE-09 | [#36](https://github.com/RodolfoGama0101/bookself-app/issues/36) | permitir bloquear após recusa/término e gerir bloqueios independentes fora de uma relação ativa |
| DATA-01 | [#37](https://github.com/RodolfoGama0101/bookself-app/issues/37) | consolidar modelo de catálogo, entrada pessoal, progresso específico, relação e evento |
| DATA-02 | [#38](https://github.com/RodolfoGama0101/bookself-app/issues/38) | implementar modelos/repositórios e identidade por fornecedor/tipo/ID externo, com itens manuais |
| DATA-03 | [#39](https://github.com/RodolfoGama0101/bookself-app/issues/39) | preparar migração de livros e vínculos com backup, versão, ensaio e recuperação |
| DATA-04 | [#40](https://github.com/RodolfoGama0101/bookself-app/issues/40) | definir índices, paginação e estatísticas que não dependam de carregar toda a biblioteca |
| DATA-05 | [#41](https://github.com/RodolfoGama0101/bookself-app/issues/41) | centralizar acesso a dados e estratégia de cache/sincronização, retirando escritas de perfil dos widgets |
| DATA-06 | [#42](https://github.com/RodolfoGama0101/bookself-app/issues/42) | separar `createdAt`, atualização e eventos de atividade; preservar histórico |
| API-01 | [#43](https://github.com/RodolfoGama0101/bookself-app/issues/43) | robustecer busca Google Books e preservar referência externa |
| API-02 | [#44](https://github.com/RodolfoGama0101/bookself-app/issues/44) | ensaiar TMDB para filmes/séries e decidir fornecedor |
| API-03 | [#45](https://github.com/RodolfoGama0101/bookself-app/issues/45) | comparar Spotify e MusicBrainz para o escopo musical escolhido |
| API-04 | [#46](https://github.com/RodolfoGama0101/bookself-app/issues/46) | criar adaptadores de catálogo e configuração segura para provedores aprovados |
| API-05 | [#47](https://github.com/RodolfoGama0101/bookself-app/issues/47) | revisar imagens externas, proxy web e fontes sem rede |
| NAME-01 | [#48](https://github.com/RodolfoGama0101/bookself-app/issues/48) | escolher nome definitivo entre Entrelace, Nosso Repertório, A Dois, Sintonia ou outra proposta |
| NAME-02 | [#49](https://github.com/RodolfoGama0101/bookself-app/issues/49) | verificar disponibilidade do candidato escolhido em marcas, lojas, domínios e perfis relevantes |
| NAME-03 | [#50](https://github.com/RodolfoGama0101/bookself-app/issues/50) | aplicar nome exibido, textos, ícone e metadados nas plataformas |
| UI-01 | [#51](https://github.com/RodolfoGama0101/bookself-app/issues/51) | implementar Biblioteca com filtros por mídia, busca/cadastro e espaço Nós |
| UI-02 | [#52](https://github.com/RodolfoGama0101/bookself-app/issues/52) | padronizar estados de carregamento, vazio, erro, offline e ausência de parceiro |
| UI-03 | [#53](https://github.com/RodolfoGama0101/bookself-app/issues/53) | revisar acessibilidade, contraste, escala de texto, foco e layout responsivo |
| UI-04 | [#54](https://github.com/RodolfoGama0101/bookself-app/issues/54) | renovar o design das telas atuais com frontend-design e validar visualmente |
| UI-06 | [#55](https://github.com/RodolfoGama0101/bookself-app/issues/55) | reestruturar o design com um sistema consolidado e documentar todos os padrões |
| UI-05 | [#56](https://github.com/RodolfoGama0101/bookself-app/issues/56) | ligar páginas/agregações e sincronização às bibliotecas e ao feed |
| BOOK-01 | [#57](https://github.com/RodolfoGama0101/bookself-app/issues/57) | preservar IDs do catálogo e prevenir duplicatas na mesma biblioteca conforme política definida |
| BOOK-02 | [#58](https://github.com/RodolfoGama0101/bookself-app/issues/58) | permitir editar metadados manuais e melhorar busca/filtros da própria estante |
| BIBLE-01 | [#59](https://github.com/RodolfoGama0101/bookself-app/issues/59) | preservar progresso bíblico na nova navegação e nas migrações |
| BIBLE-02 | [#60](https://github.com/RodolfoGama0101/bookself-app/issues/60) | ampliar verificação da estrutura bíblica e comportamento de progresso |
| BIBLE-03 | [#61](https://github.com/RodolfoGama0101/bookself-app/issues/61) | avaliar um leitor de textos bíblicos como recurso separado |
| MOVIE-01 | [#62](https://github.com/RodolfoGama0101/bookself-app/issues/62) | implementar busca, detalhes e cadastro manual de filmes |
| MOVIE-02 | [#63](https://github.com/RodolfoGama0101/bookself-app/issues/63) | implementar biblioteca/status de filme e data da sessão |
| MOVIE-03 | [#64](https://github.com/RodolfoGama0101/bookself-app/issues/64) | conectar filmes às listas e sessões do casal |
| SERIES-01 | [#65](https://github.com/RodolfoGama0101/bookself-app/issues/65) | definir estados, temporadas especiais, séries em andamento, reassistir e spoilers |
| SERIES-02 | [#66](https://github.com/RodolfoGama0101/bookself-app/issues/66) | implementar catálogo de séries e progresso por temporada/episódio |
| SERIES-03 | [#67](https://github.com/RodolfoGama0101/bookself-app/issues/67) | comparar progresso do casal e registrar episódios vistos juntos |
| MUSIC-01 | [#68](https://github.com/RodolfoGama0101/bookself-app/issues/68) | implementar busca/detalhes e cadastro manual de faixas/álbuns conforme decisão |
| MUSIC-02 | [#69](https://github.com/RodolfoGama0101/bookself-app/issues/69) | implementar favoritos e registros de escuta próprios |
| MUSIC-03 | [#70](https://github.com/RodolfoGama0101/bookself-app/issues/70) | criar descobertas/listas musicais e momentos do casal |
| QA-01 | [#71](https://github.com/RodolfoGama0101/bookself-app/issues/71) | cobrir regressões de modelos, sessão e falhas de persistência |
| QA-02 | [#72](https://github.com/RodolfoGama0101/bookself-app/issues/72) | testar autorização e concorrência de vínculo em emuladores |
| QA-03 | [#73](https://github.com/RodolfoGama0101/bookself-app/issues/73) | validar uma jornada completa por mídia individual e em casal |
| QA-04 | [#74](https://github.com/RodolfoGama0101/bookself-app/issues/74) | resolver os 47 infos da análise estática, substituindo APIs obsoletas e logs inadequados |
| QA-05 | [#75](https://github.com/RodolfoGama0101/bookself-app/issues/75) | criar CI de análise e testes, incluindo regras quando disponíveis |
| REL-01 | [#76](https://github.com/RodolfoGama0101/bookself-app/issues/76) | reproduzir a falha Android registrada em `build.log` com dependências atuais |
| REL-02 | [#77](https://github.com/RodolfoGama0101/bookself-app/issues/77) | configurar assinatura Android de distribuição e remover uso de debug na release |
| REL-03 | [#78](https://github.com/RodolfoGama0101/bookself-app/issues/78) | revisar permissões e configuração iOS de câmera/galeria e validar build |
| REL-04 | [#79](https://github.com/RodolfoGama0101/bookself-app/issues/79) | validar Android/iOS/web, conexão, imagem e autenticação antes de release |
| REL-05 | [#80](https://github.com/RodolfoGama0101/bookself-app/issues/80) | definir SDK reproduzível e revisar dependências/configurações/arquivos gerados |
| REL-06 | [#81](https://github.com/RodolfoGama0101/bookself-app/issues/81) | preparar checklist e notas da primeira distribuição com nova marca/categorias |
| REL-07 | [#82](https://github.com/RodolfoGama0101/bookself-app/issues/82) | gerar APK atualizado e publicar release no GitHub a pedido do usuário |
| REL-08 | [#83](https://github.com/RodolfoGama0101/bookself-app/issues/83) | gerar APK atualizado e publicar nova release no GitHub a pedido do usuário |
| REL-09 | [#84](https://github.com/RodolfoGama0101/bookself-app/issues/84) | publicar APK com o redesign de UI-06, a pedido do usuário |
| IDEA-01 | [#85](https://github.com/RodolfoGama0101/bookself-app/issues/85) | avaliações, comentários e comparações de gosto por mídia |
| IDEA-02 | [#86](https://github.com/RodolfoGama0101/bookself-app/issues/86) | metas, lembretes e retrospectivas do casal |
| IDEA-03 | [#87](https://github.com/RodolfoGama0101/bookself-app/issues/87) | conectar contas de música e sincronizar playlists/histórico externo |
| IDEA-04 | [#88](https://github.com/RodolfoGama0101/bookself-app/issues/88) | memória compartilhada com datas e contexto dos momentos |
| IDEA-05 | [#89](https://github.com/RodolfoGama0101/bookself-app/issues/89) | avaliar links de onde assistir/ouvir e reprodução/sessões sincronizadas |
| MAIN-01 | [#90](https://github.com/RodolfoGama0101/bookself-app/issues/90) | revisar e integrar à main: base reproduzível e ci |
| MAIN-02 | [#91](https://github.com/RodolfoGama0101/bookself-app/issues/91) | revisar e integrar à main: confiabilidade e regressões do aplicativo |
| MAIN-03 | [#92](https://github.com/RodolfoGama0101/bookself-app/issues/92) | revisar e integrar à main: autorização, consentimento e privacidade de acesso |
| MAIN-04 | [#93](https://github.com/RodolfoGama0101/bookself-app/issues/93) | revisar e integrar à main: dados, livros e preservação da bíblia |
| MAIN-05 | [#94](https://github.com/RodolfoGama0101/bookself-app/issues/94) | revisar e integrar à main: experiência, navegação e acessibilidade |
| MAIN-06 | [#95](https://github.com/RodolfoGama0101/bookself-app/issues/95) | revisar e integrar à main: expansão incremental e decisões de produto |
| MAIN-07 | [#96](https://github.com/RodolfoGama0101/bookself-app/issues/96) | revisar e integrar à main: validação e distribuição controlada |
| MAIN-08 | [#97](https://github.com/RodolfoGama0101/bookself-app/issues/97) | priorizar ideias posteriores ao MVP |
| GITHUB-01 | [#98](https://github.com/RodolfoGama0101/bookself-app/issues/98) | centralizar tarefas e documentar o fluxo de trabalho no GitHub |

## Pendências de acesso ou escrita

Nenhuma pendência registrada nesta preparação. Se uma operação falhar, anotar aqui data, ID, campos/operações pendentes e evidência do último estado confirmado, sem segredos. Reconciliar antes de novas alterações; o GitHub continua sendo a fonte de estado.
