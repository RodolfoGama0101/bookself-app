# Orientações para agentes e colaboradores

## Contexto

Aplicativo Flutter/Dart com Firebase para organizar leituras individualmente e em casal. A expansão planejada inclui filmes, séries e músicas. Bookself App é o nome atual; Entrelace é uma proposta. Não trate funcionalidades planejadas como implementadas.

Leia `README.md`, as tarefas relacionadas em `BACKLOG.md` e os documentos relevantes em `docs/` antes de alterar o projeto.

## Organização do trabalho

- Use `BACKLOG.md` como fonte central de tarefas. Preserve IDs e atualize status, dependências e evidências de conclusão.
- Trabalhe no escopo solicitado pelo usuário; não implemente todo o backlog em resposta a uma solicitação pontual.
- Preserve alterações locais. Consulte `git status` e o diff antes de editar.
- Ao concluir uma atividade com alterações, crie um commit local com as mudanças verificadas e a documentação correspondente. Essa é uma orientação permanente do usuário. Mantenha segredos, configurações locais e artefatos gerados fora dos commits.
- Atualize a documentação quando comportamento, configuração ou modelo de dados mudar.
- Registre decisões pendentes como propostas. Não escolha silenciosamente marca definitiva, fornecedor musical ou política de compartilhamento.
- Use português brasileiro na documentação e interface, mantendo os identificadores em inglês usados no código.

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
