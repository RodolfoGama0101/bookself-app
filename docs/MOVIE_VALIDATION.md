# Jornada de filmes — QA-03

09/10/2026. Categoria validada localmente por serviços Dart, widgets e Firestore
demo. QA-03 permanece em andamento: séries/música não estão implementadas, catálogo
real depende de API-02/04 e a jornada visual de duas contas ainda está pendente.

## Cobertura executável

`test/movie_journey_test.dart` encadeia serviços reais Dart com banco substituto:

| Etapa | Evidência |
| --- | --- |
| Encontrar/cadastrar | Manual sem API e HTTP normalizado simulado, busca/detalhes com fornecedor fictício; metadados sem ano/pôster. |
| Salvar | Mesma obra em duas contas, referência preservada e repetição da inclusão sem redefinir progresso. |
| Atualizar | Somente uma pessoa assistiu, com data própria; inclusão original preservada. |
| Compartilhar | Lista recebe seleção mínima, sem status/data pessoal. |
| Sessão | Dupla confirmação; correção exige novo aceite e rejeita revisão antiga. |
| Terminar | PartnerService desfaz os dois vínculos; nova inclusão conjunta recusada e retirada da confirmação própria permitida. |
| Continuar individualmente | Duas entradas preservadas, retorno a Quero assistir limpa data sem mudar inclusão. |

`tool/firebase/test/security.test.cjs` complementa com SDK JS e regras reais no
emulador: duas atualizações do filme com a mesma revisão têm somente uma vencedora;
correção/reconfirmação de experiência, término, retirada e novo parceiro mantêm
as bibliotecas independentes. Ex/parceiro novo/sem autenticação não leem biblioteca
privada e novo parceiro não herda experiência antiga. Regressão anterior cobre
lista/sessão e preservação pessoal; nenhuma regra foi alterada nesta entrega.

Os widgets de filmes verificam consentimento antes do envio, escrita confirmada,
falha/retry, troca de conta, conflito/releitura e filtros. As regressões de UI-03
acrescentam teclado real do teste, semântica/seleção e 320 × 640 com texto 2×.
Fakes não comprovam autorização: essa conclusão vem somente dos testes emulados.

## Jornada observada no navegador

Build demo, Auth 9099/Firestore 8080 de `demo-bookself`, servidor loopback 17362,
conta fictícia criada pela interface. Biblioteca → Filmes → cadastro manual sem
ano/pôster/API → detalhe → Marcar como assistido → retorno à biblioteca confirmou
status e total. Perfil → Cópia dos meus dados gerou cópia com confirmação do
servidor e informou sucesso de cópia; leitura automatizada da área de transferência
do navegador integrado retornou vazia, portanto o conteúdo copiado não foi
inspecionado por esse mecanismo. Estrutura/conteúdo são cobertos nos testes Dart.
Captura local ignorada: `build/personal-export-demo.png`.

Agent-browser não iniciou Chrome por bloqueio do Controle de Aplicativo Windows;
inspeção realizada pelo navegador integrado. Uma primeira aba teve timeout de
loopback; nova aba após reiniciar servidor no host carregou o app. A árvore web
revelou botões duplicados no cartão, corrigidos por MergeSemantics em UI-03.

## Reprodução e limites

```sh
flutter test --no-pub test/movie_journey_test.dart test/movie_ui_test.dart
node tool/firebase/run-tests.cjs
flutter build web --no-pub --dart-define=USE_FIREBASE_EMULATORS=true
```

Em 09/10/2026, análise limpa, **441 testes Flutter e 87 testes Node/demo** aprovados,
mais build web demo. Sem migração, índices/regras remotos ou publicação. Backend
normalizado e fornecedor de catálogo não foram aprovados/implantados; o HTTP do
teste não consulta catálogo externo. Android/iOS, leitores de tela e jornada
visual conjunta completa continuam pendentes. Use [DEVELOPMENT.md](DEVELOPMENT.md)
para preparar os emuladores e [MOVIES.md](MOVIES.md) para ativação e contrato.
