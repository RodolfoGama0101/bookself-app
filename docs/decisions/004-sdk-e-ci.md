# 004 — SDK fixado e verificações antes da integração

Data: 03/10/2026. Estado: SDK validado localmente; configuração de CI pronta, execução/proteção remotas pendentes.

## Contexto e alternativas

O requisito mínimo no `pubspec.yaml` não garante que colaboradores e CI usem a mesma versão do Flutter. Instalar sempre o stable mais recente poderia mudar compilador/dependências sem revisão. Adicionar um gerenciador de SDK obrigatório ampliaria ferramentas sem necessidade concreta. Somente testes Dart com fakes não verificam regras Firestore.

## Escolha e motivos

Registrar Flutter 3.44.0/Dart 3.12.0 e revisão exata em `tool/flutter-sdk.json`, conferindo o SDK com `tool/check_sdk.dart`. A instalação usa o repositório oficial/tag e verifica o commit. Manter `pubspec.lock` e o lockfile npm; instalar com verificação do lockfile, sem upgrades automáticos. Node fica em `.node-version`.

CI possui jobs separados para análise/testes Flutter/build web demo e Auth/Firestore emulado, com ações oficiais fixadas por commit, timeout e permissão de leitura. Nenhum job faz login Firebase, usa credenciais de produção, executa migração/deploy ou assina uma distribuição. O evento `merge_group` permite executar os mesmos checks em filas de integração.

## Efeitos e pendências

Atualizar SDK requer mudar o registro, validar compilação/análise/testes e revisar os lockfiles. Dependências não foram atualizadas apenas para esta tarefa. CI só executará após o workflow chegar ao GitHub; tornar os dois checks obrigatórios em proteção de branch exige configuração remota. Não se presume bloqueio de merge apenas por existir um YAML.

Comandos, versões e ativação: [DEVELOPMENT.md](../DEVELOPMENT.md). Registro Android: [ANDROID_BUILD.md](../ANDROID_BUILD.md). Fornecedores, marca, política de compartilhamento e regras de produção continuam fora dessa decisão.
