# Orientações para agentes e colaboradores

## Contexto

Aplicativo Flutter/Dart com Firebase para organizar leituras individualmente e em casal, com expansão planejada para filmes, séries e músicas. Bookself App é a identidade técnica; confira no README e na documentação da branch o nome exibido, as decisões de marca e o escopo disponível. Não trate funcionalidades planejadas como implementadas.

Leia `README.md`, as issues relacionadas no GitHub, o índice `BACKLOG.md` e os documentos relevantes em `docs/` antes de alterar o projeto.

## Organização do trabalho

- Use GitHub Issues como fonte única de tarefas. Preserve IDs e mantenha critérios, estado, dependências e evidências nas issues; `BACKLOG.md` é um índice de acesso.
- Trabalhe no escopo solicitado pelo usuário; não implemente todo o backlog em resposta a uma solicitação pontual.
- Preserve alterações locais. Consulte `git status` e o diff antes de editar.
- Crie um commit local ao concluir cada tarefa ou parte importante do desenvolvimento, como documentação, refatoração, correção, testes ou implementação. Cada commit deve representar uma entrega coesa e verificada, com a documentação correspondente; não acumule tarefas independentes em um único commit. Essa é uma orientação permanente do usuário. Mantenha segredos, configurações locais e artefatos gerados fora dos commits.
- Use o padrão Conventional Commits: `<tipo>(<escopo opcional>): <descrição>`. Mantenha os tipos convencionais em inglês (`feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `build`, `ci`, `perf`, `style`, `revert`) e escreva a descrição e o corpo em português brasileiro, com acentuação correta. Omita os parênteses quando não houver escopo. Exemplos: `docs: atualiza orientações de contribuição`, `refactor(auth): simplifica restauração de sessão` e `fix: corrige validação da data de conclusão`. Para mudanças incompatíveis, use `!` após o tipo/escopo e explique a incompatibilidade no rodapé `BREAKING CHANGE:`, também em português brasileiro.
- Atualize a documentação quando comportamento, configuração ou modelo de dados mudar.
- Registre decisões pendentes como propostas. Não escolha silenciosamente marca definitiva, fornecedor musical ou política de compartilhamento.
- Use português brasileiro na documentação e interface, mantendo os identificadores em inglês usados no código.

## Gestão de tarefas no GitHub

GitHub Issues é a fonte única de tarefas, critérios, prioridades, dependências, andamento e evidências desde 13/11/2026, por orientação do usuário. Repositório: [Bookself App](https://github.com/RodolfoGama0101/bookself-app/issues). O [guia e correspondência de IDs](docs/GITHUB.md) facilita a consulta. `BACKLOG.md` é somente um índice; não mantenha estados paralelos nele. O Linear é histórico: não crie nem sincronize tarefas lá.

### 1. Consultar e criar

- Antes de começar, leia a issue completa, comentários, relações de bloqueio e sub-issues, além do README e documentos relevantes. Procure issues abertas e fechadas pelo ID e pelo problema antes de criar; reutilize o item existente e preserve os IDs DOC/CORE/SEC/etc.
- Novas tarefas devem usar `[ÁREA-NN] descrição em português`, com próximo ID livre confirmado na busca e em `docs/GITHUB.md`. Registre a correspondência ID → número/URL nesse documento e em `docs/github-issues.json`; o conteúdo operacional continua na issue.
- Use o formulário de tarefa. Registre objetivo/problema, escopo, critérios verificáveis, branch/base e ambiente, prioridade, dependências e limites de implantação/migração/publicação. Decisões ainda não aprovadas devem continuar como propostas.
- Atribua a `RodolfoGama0101` (Rodolfo Gama), salvo instrução explícita diferente. Aplique uma label `prioridade:p0`, `prioridade:p1`, `prioridade:p2` ou `prioridade:p3`, uma `status:*`, uma `area:*` e uma `tipo:*`; use o milestone da etapa pertinente. P0 bloqueia ampliação de acesso/distribuição/migração; P1 é a próxima base/entrega; P2 é posterior; P3 requer priorização.
- Registre dependências no corpo com links e nas relações nativas `blocked by`. Agrupe trabalho maior por sub-issues, preservando critérios próprios; uma etapa da main não está concluída porque suas tarefas de origem foram encerradas na develop.

### 2. Iniciar

- Confira `git status`, diff, branch atual e base remota antes de editar. Preserve alterações alheias. Para entregas destinadas à main, use branch `codex/<id>-<descrição-curta>` a partir da main atualizada; outra base deve estar justificada na issue.
- Atualize a issue para `status:em-andamento`, removendo a label de estado anterior, e registre abordagem, branch e escopo. Faça isso durante o trabalho, sem aguardar novo pedido do usuário.
- Consulte bloqueios antes de executar etapas dependentes. Trabalho independente e decisões podem avançar quando isso estiver explicitado; uma dependência fechada na develop não comprova presença na main.
- Antes de reaproveitar código posterior à main, confira o diff, as dependências reais e as evidências. Selecione entregas coesas; a organização das tarefas não autoriza integrar toda a develop, implementar todo o backlog ou alterar produção.

### 3. Executar e atualizar

- Trabalhe somente no escopo solicitado. Registre descobertas, mudanças de escopo, testes, falhas e impedimentos na issue, com links para commits/PRs e documentos acessíveis no GitHub. Crie outra issue para trabalho independente e vincule a relação apropriada.
- Mantenha corpo, checklists, labels, milestone e relações coerentes. Atualize dependências nos dois sentidos quando mudarem. Preserve comentários e edições alheias; releia antes de escrever e resolva divergências sem sobrescrever campos conflitantes silenciosamente.
- Para impedimento, mantenha a issue aberta com `status:bloqueada` e registre motivo, impacto, responsável pela próxima ação e condição de retomada. Não trate falta de autorização, ambiente Apple ou credencial como conclusão.
- Ao retomar, confirme a resolução do impedimento, registre a evidência e substitua a label por `status:em-andamento`. Ao enviar PR para revisão, use `status:em-revisao`; correções solicitadas retornam para andamento.
- Não envie tokens, senhas, dados pessoais de teste ou logs sensíveis. Autorizações de deploy, migração, credenciais e publicação continuam específicas. SEC-06 permanece pendente de autorização própria; organizar issues não a concede.

### 4. Validar, registrar e revisar

- Execute as verificações pertinentes abaixo e registre comando, resultado, ambiente, commit e limitações na issue e no PR. Para documentação, confira links, consistência e diff; não é necessário recompilar Flutter.
- Crie commits locais coesos e verificados, com documentação correspondente e Conventional Commits em português conforme a regra de organização. Não inclua configurações locais, segredos ou artefatos gerados.
- Abra PR com problema, comportamento final, validação e limites. Use `Refs #N` quando o PR for parcial, vier antes de implantação pendente ou tiver como destino uma branch que não cumpre o critério da issue.
- Use `Closes #N` somente quando o PR cumprir integralmente o critério e sua integração à branch de destino representar a conclusão. Evite fechamento automático de uma issue de implantação por um PR de preparação. Não integre PRs com verificações obrigatórias falhando; comprove os checks efetivos, sem assumir proteção de branch instalada.

### 5. Concluir, reabrir e conferir

- Para entrega destinada à main, feche como concluída somente após integração à main e confirmação dos critérios com evidências. Atualize checklists e use `status:concluida`, removendo outras labels de estado. Documentação, decisão, ensaio e entrega local podem ter critérios próprios explícitos; nunca amplie sua conclusão para implantação ou publicação.
- O histórico importado com `origem:develop` preserva o escopo original. Sua integração à main é acompanhada nas etapas MAIN-01 a MAIN-08 e no roadmap, sem reabrir toda a história nem anunciar disponibilidade indevida.
- Ao encontrar regressão, reabra a issue quando for o mesmo problema, retire o estado de concluída e registre reprodução/impacto. Problema independente deve ter issue própria. Duplicatas e desistências exigem motivo e link; feche como não planejada com `status:cancelada`, sem simular entrega concluída.
- Antes de anunciar a entrega, releia no GitHub título/ID, responsável, estado/label, prioridade, milestone, critérios, evidências, dependências e PRs. Atualize a etapa pai; encerre-a somente quando seus critérios próprios forem cumpridos.
- Se o acesso ou escrita falhar, preserve o trabalho local, registre em `docs/GITHUB.md` os IDs, campos e operações pendentes, e relate a limitação. Reconcilie com o estado remoto antes de novas alterações nesses itens; não declare atualização sem releitura confirmada.
- Este fluxo é executado pelos colaboradores/agentes durante as tarefas. O arquivo não instala serviço em segundo plano, board ou proteção automática de branch.

## Código e arquitetura

- Siga a separação atual: modelos em `lib/data/models`, serviços em `lib/services`, interface em `lib/ui` e utilitários em `lib/utils`.
- Evite dependências e abstrações extensas sem necessidade concreta. Evolua a arquitetura de forma incremental.
- Concentre novos acessos a Firebase/APIs em serviços ou repositórios; evite novas escritas diretamente em widgets.
- Na expansão, separe metadados de catálogo, estado pessoal e atividades compartilhadas. A proposta em `docs/ARCHITECTURE.md` precisa ser validada antes de virar contrato.
- Não use apenas o ID externo de uma obra como ID de um registro pessoal. Considere fornecedor, mídia e proprietário.
- Preserve contas, `books` e `bible_progress` até existir uma migração compatível, verificável e com recuperação.
- Cancele assinaturas, descarte controladores e verifique `mounted` após operações assíncronas antes de usar estado/contexto.
- Aguarde escritas antes de anunciar sucesso; trate rede, autorização e dados ausentes.
- Proteja autoria e acesso no banco. A ausência de controles de edição na tela do parceiro não substitui regras do Firestore.

## Configuração e dados

- Não registre senhas, tokens, dados pessoais ou segredos em logs/documentação.
- Não adicione segredos de fornecedores ao app ou ao Git. Configuração distribuída no cliente não é um cofre de segredos.
- Configuração Firebase de cliente não substitui autorização; restrições de chaves e ambientes são verificações separadas.
- Use ambiente de desenvolvimento ou emuladores para testes que escrevam dados. Não execute migrações ou altere regras de produção como efeito colateral de testes.
- Não altere IDs de aplicativos, projeto Firebase ou bundle identifiers apenas para trocar o nome exibido. Documente os efeitos antes de migrar identidade técnica.
- Evite editar artefatos gerados, `build/`, `.dart_tool/` e o SDK. Regenere `lib/firebase_options.dart` com FlutterFire quando sua configuração mudar.

## Verificação

Após mudar código Dart, formate os arquivos afetados e execute as verificações pertinentes:

```sh
dart format <arquivos-alterados>
flutter analyze --no-pub
flutter test --no-pub
```

Execute `flutter pub get` se dependências mudarem ou não estiverem disponíveis. Teste regressões relevantes; não adicione testes que apenas repitam a implementação. Para documentação, verifique links locais, consistência com o código e diff; não é necessário recompilar.

Em alterações de regras, vínculo ou migração, valide terceiros sem acesso, concorrência e desvinculação. Para interface ou plataforma, valide as telas afetadas quando o ambiente permitir. Relate verificações não executadas e suas razões.

Baseline de 02/10/2026: quatro testes de dados bíblicos passam; análise estática retorna 47 infos, sem erros ou warnings. Esse baseline não comprova funcionamento em produção. Não introduza novos apontamentos nem esconda os existentes com supressões globais.

## Conclusão

Marque uma tarefa como concluída somente após cumprir seu critério. Relate mudanças, validação e limitações. Diferencie código pronto de implantação, migração e publicação ainda pendentes.
