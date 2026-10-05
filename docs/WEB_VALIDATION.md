# Validação web com Firebase demo

Data: 05/10/2026. Evidência parcial para DOC-03/API-05/REL-04 e regressões do fluxo atual. Não comprova produção, Android/iOS nem jornadas de categorias planejadas.

## Ambiente e reprodução

- Windows, Flutter 3.44.0/Dart 3.12.0 e dependências locais já instaladas; navegador integrado do Codex.
- Auth em `127.0.0.1:9099` e Firestore em `127.0.0.1:8080`, somente `demo-bookself`, com regras candidatas e contas fictícias. Sem importação/exportação ou consulta de documentos remotos.
- Build `flutter build web --no-pub --dart-define=USE_FIREBASE_EMULATORS=true`, sem define de chave Google Books. Servidor estático temporário limitado a `build/web` no loopback `127.0.0.1:7358`.
- SHA-256 de `main.dart.js` após a correção CORE-12: `5c43f91ab7cad5efb843aa8231387633b299589c51336a28625d1794f875e61c`. O build é gerado/ignorado; o hash identifica este artefato, não garante builds idênticos futuros.

Para repetir, seguir [DEVELOPMENT.md](DEVELOPMENT.md): iniciar os emuladores e executar o Flutter com `USE_FIREBASE_EMULATORS=true`. Conferir o aviso de modo emulador antes de cadastrar contas fictícias. Sem chave de catálogo, usar cadastro manual. Repetir com duas contas distintas; não reutilizar contas reais ou apontar ao projeto distribuído.

O agent-browser não iniciou sua sessão porque o sandbox negou escrita no diretório de sockets. O diagnóstico local passou, mas não comprova lançamento do navegador. A interação foi feita pelo navegador integrado. SDK/emuladores/servidor precisaram de execução fora do sandbox para usar caches e loopback; nenhum deploy foi executado. Os processos desta validação foram encerrados ao terminar.

## Resultados observados

| Cenário | Resultado |
| --- | --- |
| Cadastro e perfil | Duas contas fictícias criadas pela interface Flutter; carregamento de perfil seguido do Início. |
| Livro manual | Título/autor salvos sem capa e sem API; livro apareceu em Quero ler com placeholder. |
| Alteração de estado | Confirmação de Começar a ler moveu o registro para Lendo; nova sessão da proprietária manteve esse estado após desvínculo. |
| Conclusão e histórico | Calendário pt-BR, dias posteriores a 05/10/2026 desabilitados; confirmação de hoje mostrou Lido em Outubro / 2026 e data 05/10/2026. Início atualizou para um livro no mês/ano e atividade de conclusão. |
| Bíblia pessoal | Marcar Gênesis 1 confirmou 1/50 e 2%; segunda conta continuou com 0/50. |
| Sem parceiro | Segunda conta tinha estante pessoal vazia e orientação para vincular na consulta do parceiro. |
| Vínculo atual | Código da primeira conta produziu vínculo com nome do parceiro. Este fluxo continua direto por UID, sem aceite. |
| Consulta do parceiro | Segunda conta viu o livro em Lendo; detalhes sem controles de edição. Resumo bíblico mostrou seu 0/50 e parceiro 1/50. |
| Desvínculo | Confirmação removeu a estante do parceiro e a comparação bíblica; registros pessoais da primeira conta preservados. |
| Nova sessão | Logout/login e, após recompilar, login em uma nova aba demo mantiveram livro Lido, histórico e Gênesis 1/50. Não equivale à restauração automática após recarga. |
| Busca sem configuração | Mensagem de indisponibilidade e ações Manual/Cadastrar manualmente presentes; nenhuma chave fornecida ao build. CORE-12 retirou a frase repetida e foi conferida após recompilar. |
| Console | Nenhuma entrada de nível error observada na nova aba após conferir progresso e busca. Não é auditoria de todas as requisições ou plataformas. |

## Evidências visuais

As capturas contêm somente dados fictícios. As três primeiras foram feitas antes da correção textual CORE-12; a mensagem antiga visível nelas foi corrigida na última captura.

- [Comparação bíblica antes de desvincular](evidence/web-bible-comparison-2026-10-05.png).
- [Progresso sem parceiro após desvincular](evidence/web-bible-unlinked-2026-10-05.png).
- [Livro concluído e histórico pessoal](evidence/web-reading-completed-2026-10-05.png).
- [Progresso pessoal preservado em nova aba](evidence/web-bible-preserved-2026-10-05.png).
- [Mensagem final de busca indisponível](evidence/web-search-unavailable-2026-10-05.png).

## Verificações e pendências

Após a correção textual: `dart format lib/ui/screens/search_screen.dart` executado; `flutter analyze --no-pub` sem apontamentos; `flutter test --no-pub` com 275 testes passando; build web demo e verificação preliminar Wasm aprovados. Não foram criados testes duplicados para a alteração de texto; regressões existentes e conferência da interface foram reutilizadas. A suíte de regras não foi repetida: regras, modelo e fluxo de vínculo não mudaram; sua execução anterior está em [SECURITY.md](SECURITY.md).

A primeira recarga no navegador integrado voltou ao login. A causa foi reproduzida e corrigida posteriormente em Chrome isolado, conforme a seção abaixo; o resultado inicial permanece como evidência da falha.

## Recarga da sessão demo — CORE-13

Na mesma data, o agent-browser iniciou um Chrome isolado após liberação de acesso ao diretório de sockets/cache e loopback. O build com o redesign UI-04 reproduziu a falha: cadastro e perfil funcionaram, mas recarregar voltou ao login. A inspeção somente de host/caminho mostrou `identitytoolkit.googleapis.com/v1/accounts:lookup`, em vez de Auth local. Foram usadas apenas opções fictícias e conta demo; não foram coletados corpos, parâmetros, senhas ou tokens.

O FlutterFire web aguarda a restauração dentro de `Firebase.initializeApp`, antes da chamada Dart anterior a `useAuthEmulator`. A persistência já estava habilitada. Em `firebase_auth_web` 6.2.1, a configuração antecipada por sessionStorage funciona somente em localhost/debug, deixando esse build release em `127.0.0.1` sem conexão antecipada. A [referência oficial](https://firebase.google.com/docs/reference/js/auth#connectauthemulator) exige conectar o emulador sincronamente após `initializeAuth`.

`prepareWebEmulator` e `web/firebase_emulator.js` antecipam a conexão apenas no demo web, preservando a persistência. Rejeitam outro projeto, destinos remotos e versões incompatíveis; uma nova tentativa reutiliza o mesmo emulador. A versão JavaScript vem do plugin instalado, sem upgrade ou alteração de configuração Firebase gerada. O helper inicializa os três módulos atualmente usados; upgrades dos plugins ou novos serviços precisam de revisão e nova jornada.

Resultados no build corrigido, servido somente em `127.0.0.1:17358`:

| Cenário | Resultado |
| --- | --- |
| Login da conta demo existente | Perfil abriu e Início exibiu o nome fictício. |
| Recarga com sessão | Retornou automaticamente ao Início, com perfil carregado e aviso de emulador. |
| Destino da restauração | `127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:lookup`; sem host Auth remoto nessa recarga. |
| Logout e recarga | Permaneceu no login com campos vazios, sem reentrada automática. |

Evidências: [sessão restaurada](evidence/web-session-restored-2026-10-05.png) e [logout após recarga](evidence/web-session-logged-out-2026-10-05.png), somente dados fictícios. Build demo final `main.dart.js` SHA-256: `cfe8f2f3b40ef9a0176007cb03378fe1f9e2d86e7709f3c195c7e6d1c29cd20e`; helper `firebase_emulator.js`: `53cd58d7a1dbe12d05d15aebc864ccd3327f4c6b1878dd4d8b76b3d66b2a8bdb`. Os hashes identificam os artefatos observados e não garantem reprodução binária.

Formatação, análise limpa, 283 testes Flutter e seis testes Node de isolamento/ordem/nova tentativa passaram; builds web padrão e demo compilaram, incluindo dry run Wasm. O build padrão foi apenas compilado, sem autenticação em produção. Regras, dados e vínculo não mudaram; testes de regras não foram repetidos. A CI ganhou o comando do bootstrap, ainda sem execução remota. Os processos desta validação foram encerrados ao terminar.

Também permanecem pendentes: capas externas/CORS, execução offline das fontes, recuperação de conexão, câmeras/permissões nativas, execução Android/iOS, contas simultâneas em navegadores distintos, cliente antigo/cache após revogação e autorização remota implantada. A jornada sequencial não substitui os testes de terceiros/concorrência dos emuladores. DOC-03 exige reprodução por outra pessoa; API-05 e REL-04 exigem a matriz de plataformas. Esses itens continuam abertos no [backlog](../BACKLOG.md).
