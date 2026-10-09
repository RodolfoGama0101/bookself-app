# Orientações para agentes e colaboradores

## Contexto

Aplicativo Flutter/Dart com Firebase para organizar leituras individualmente e em casal. A expansão planejada inclui filmes, séries e músicas. Bookself App é o nome atual; Entrelace é uma proposta. Não trate funcionalidades planejadas como implementadas.

Leia `README.md`, as tarefas relacionadas em `BACKLOG.md` e os documentos relevantes em `docs/` antes de alterar o projeto.

## Organização do trabalho

- Use `BACKLOG.md` como fonte central de tarefas. Preserve IDs e atualize status, dependências e evidências de conclusão.
- Trabalhe no escopo solicitado pelo usuário; não implemente todo o backlog em resposta a uma solicitação pontual.
- Preserve alterações locais. Consulte `git status` e o diff antes de editar.
- Crie um commit local ao concluir cada tarefa ou parte importante do desenvolvimento, como documentação, refatoração, correção, testes ou implementação. Cada commit deve representar uma entrega coesa e verificada, com a documentação correspondente; não acumule tarefas independentes em um único commit. Essa é uma orientação permanente do usuário. Mantenha segredos, configurações locais e artefatos gerados fora dos commits.
- Use o padrão Conventional Commits: `<tipo>(<escopo opcional>): <descrição>`. Mantenha os tipos convencionais em inglês (`feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `build`, `ci`, `perf`, `style`, `revert`) e escreva a descrição e o corpo em português brasileiro, com acentuação correta. Omita os parênteses quando não houver escopo. Exemplos: `docs: atualiza orientações de contribuição`, `refactor(auth): simplifica restauração de sessão` e `fix: corrige validação da data de conclusão`. Para mudanças incompatíveis, use `!` após o tipo/escopo e explique a incompatibilidade no rodapé `BREAKING CHANGE:`, também em português brasileiro.
- Atualize a documentação quando comportamento, configuração ou modelo de dados mudar.
- Registre decisões pendentes como propostas. Não escolha silenciosamente marca definitiva, fornecedor musical ou política de compartilhamento.
- Use português brasileiro na documentação e interface, mantendo os identificadores em inglês usados no código.

## Sincronização automática das tarefas com o Linear

- Ao criar, iniciar, atualizar, bloquear, reabrir ou concluir uma tarefa, sincronize automaticamente o item de `BACKLOG.md` com o projeto **Bookself-App** pelo plugin Linear, sem aguardar novo pedido do usuário. Faça isso durante o trabalho e confira a sincronização antes de anunciar a entrega.
- `BACKLOG.md` permanece a fonte central. Antes de trabalhar em uma tarefa, leia sua issue no Linear e consulte a [correspondência de IDs](docs/LINEAR.md). Preserve o ID estável no título e na descrição; procure por esse ID no projeto antes de criar uma issue e registre novas correspondências no documento para evitar duplicatas.
- Atribua as tarefas a **Rodolfo Gama**, salvo orientação explícita diferente do usuário. Sincronize título, descrição, critérios, prioridade, dependências, andamento, impedimentos, evidências de validação e limites de implantação/migração/publicação. Não envie segredos ou dados pessoais de teste.
- Mapeie P0/P1/P2/P3 para Urgent/High/Medium/Low. Use Backlog para itens ainda não iniciados, In Progress para trabalho iniciado e Done somente quando o critério de conclusão estiver cumprido com evidência; ao reabrir, retire Done. Registre bloqueios na descrição, mantendo o estado coerente com o andamento real.
- Converta dependências em relações de bloqueio entre as issues correspondentes e ajuste essas relações quando as dependências do item mudarem. Preserve referências documentais com links acessíveis a partir do Linear e não confunda implementação local com implantação concluída.
- Releia a issue após a escrita e confirme responsável, estado, prioridade, conteúdo e dependências. Preserve comentários e alterações alheias; se houver mudança conflitante no Linear, registre a divergência e esclareça o ponto com o usuário antes de sobrescrever o campo em conflito, continuando o trabalho independente.
- Se o plugin estiver indisponível ou a escrita falhar, preserve a atualização local, registre os IDs e campos pendentes em `docs/LINEAR.md` e relate a limitação na entrega. Na próxima execução com acesso, reconcilie as pendências antes de novas alterações nas mesmas tarefas; não declare sincronização sem confirmação.
- Esta sincronização é executada pelos agentes durante as tarefas. A edição deste arquivo não instala um serviço em segundo plano nem sincroniza alterações feitas fora de uma execução do agente.

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
