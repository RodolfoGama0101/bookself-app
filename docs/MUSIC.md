# Música

MusicBrainz foi aprovado para metadados em API-03 em 09/10/2026. A integração
local de 14/10/2026 usa o intermediário descrito abaixo. Nenhuma conta externa
ou reprodução é necessária; infraestrutura pública continua pendente.

## MusicBrainz local — 14/10/2026

Requer Node 22 ou superior e acesso HTTPS a musicbrainz.org. Na raiz:

```sh
node tool/catalog/musicbrainz-server.cjs
```

Mantenha uma única instância ativa, inclusive ao executar ensaios: o limite é
compartilhado entre busca/detalhes/faixas/álbuns **nesse processo**, com intervalo
mínimo de 1.100 ms entre inícios de consultas. Não execute `trial.cjs` em paralelo.
O servidor identifica o aplicativo pelo User-Agent com o endereço do repositório,
consulta exclusivamente a origem HTTPS MusicBrainz e recusa redirecionamentos.
Sem chave, token ou conta MusicBrainz no cliente ou no intermediário.

O servidor escuta somente `127.0.0.1:17370`; `MUSIC_CATALOG_PORT` permite outra
porta livre. Valida Host e aceita CORS somente de origens HTTP localhost/127.0.0.1.
O Android emulado acessa o computador por `10.0.2.2`. Somente no modo
`USE_FIREBASE_EMULATORS=true`, o cliente permite HTTP nesses três hosts; fora do
modo demo continua exigindo HTTPS. Não é um servidor público e não deve ser
exposto em rede, túnel ou hospedagem. Não recebe identidade Firebase nem registra
consultas, usuários, respostas ou cabeçalhos em logs.

```sh
flutter run -d emulator-5556 --no-pub --dart-define=USE_FIREBASE_EMULATORS=true --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2 --dart-define=MUSIC_CATALOG_PROVIDER=musicbrainz --dart-define=MUSIC_CATALOG_URL=http://10.0.2.2:17370
```

Confirme o dispositivo com `flutter devices` e mantenha os emuladores Firebase
demo iniciados conforme [DEVELOPMENT.md](DEVELOPMENT.md). Na web demo HTTP, use
`MUSIC_CATALOG_URL=http://127.0.0.1:17370`; a validação visual web continua pendente.
Sem servidor/rede, o cadastro manual permanece disponível.

### Identidade, campos e busca

- Faixa = entidade `recording`, ID MBID da gravação; não é o ID de uma posição
  da faixa numa edição. Duração e desambiguação/versão são opcionais. Não se escolhe
  um álbum entre as muitas edições que podem conter a gravação.
- Álbum = entidade `release`, MBID da edição, com tipo primário Album confirmado
  pelo release-group. O ID do grupo não substitui o da edição. Ano é o da edição,
  e a descrição reúne desambiguação, data, país e formatos disponíveis. Edições
  distintas com título/artistas iguais permanecem independentes.
- Busca aceita palavras de título/artista, escapando operadores Lucene. Cada
  palavra precisa aparecer no título ou artista; termos extras podem reduzir
  resultados. Página de 25, cursor associado ao tipo e hash da consulta, até
  offset 10.000. Parcial inválido é descartado sem encerrar uma página bruta válida.
- Campos obrigatórios inválidos impedem seleção; opcionais ausentes não são
  inventados. Sem capas nesta etapa: placeholder existente, sem chamadas ao Cover
  Art Archive. Capa não faz parte da licença dos metadados MusicBrainz.

### Cache, indisponibilidade e implantação

Cache somente em memória dos **metadados normalizados**: busca por 60 s, detalhes
por 1 h, até 100 entradas, remoção da entrada mais antiga ao atingir capacidade.
Consultas idênticas em andamento são compartilhadas; erros não entram no cache.
Não persistem documentos brutos, tags, avaliações ou dados suplementares. O
snapshot pessoal já previsto pelo modelo conserva os campos normalizados ao salvar.

Timeout de 10 s cobre espera/rede/leitura; fila de início limitada a quatro e até
oito operações distintas em andamento. Excesso retorna 429. Resposta externa de
até 2 MiB; JSON inválido/rede/redirecionamento retorna 502, timeout 504, item ausente
404. HTTP 429/503 conserva Retry-After numérico ou data (mínimo 2 s, padrão 5 s),
com pausa compartilhada e novas consultas recusadas durante ela. Não há retry
automático. Mensagens não expõem conteúdo ou endereços recebidos do fornecedor.

As fontes oficiais distinguem [dados centrais CC0 e suplementares](https://musicbrainz.org/doc/About/Data_License),
[busca e entidades](https://musicbrainz.org/doc/MusicBrainz_API/Search) e
[limites de acesso](https://musicbrainz.org/doc/MusicBrainz_API/Rate_Limiting).
Esta entrega usa dados centrais para desenvolvimento local. Antes de publicar:
definir hospedagem, HTTPS/CORS/autorização operacional, limitador compartilhado
entre instâncias, monitoramento, política de cache e condições do serviço para
o uso comercial pretendido. Capas/direitos continuam separados em API-05;
ativação remota da biblioteca depende de SEC-06. Nada foi contratado ou implantado.

### Verificação reproduzível

```sh
node --test tool/catalog/musicbrainz-server.test.cjs tool/catalog/trial.test.cjs
node tool/catalog/musicbrainz-smoke.cjs
flutter test integration_test/musicbrainz_demo_test.dart -d emulator-5556 --no-pub --dart-define=USE_FIREBASE_EMULATORS=true --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2 --dart-define=RUN_MUSICBRAINZ_DEMO_TESTS=true --dart-define=MUSIC_CATALOG_PROVIDER=musicbrainz --dart-define=MUSIC_CATALOG_URL=http://10.0.2.2:17370
```

O smoke é somente de leitura e exige o intermediário na porta padrão. A jornada
Android exige opt-in, cria conta fictícia nova no demo, busca/seleciona/salva faixa
e álbum pela tela e relê os dados confirmados, sem favoritos/escutas automáticos.
Não apaga contas/dados de outras sessões. Indisponibilidade pública pode impedir
o ensaio; testes determinísticos usam HTTP simulado.

**Evidência de 14/10/2026:** smoke público aprovou busca/detalhes de Águas de março
(Elis Regina), busca/detalhes de edições de Clube da Esquina por Milton Nascimento
e segunda página de gravações. Android API 34 (`emulator-5556`) aprovou uma jornada
nativa em **23 s**, com faixa e álbum salvos/reconsultados no Firebase demo,
identidade externa/tipo/artistas/edição preservados, capa ausente e favorito falso.
O primeiro ensaio precisou corrigir a rolagem do teste até o resumo selecionado;
a repetição passou sem intervenção. Log local ignorado em
`build/validation/android-2026-10-14/musicbrainz-api34.log`.

Formatação aprovada, análise sem apontamentos, **507 testes Flutter** e **14 testes
Node** de catálogo/ensaios aprovados na revisão final. Casos cobrem fila, intervalo
conjunto, TTL/capacidade, operações simultâneas, cursores Unicode/troca de consulta,
timeout, resposta inválida/grande, identidade divergente e Host/CORS/origem.

MUSIC-01 continua em andamento pela jornada web real pendente. API-04 permanece
parcial também pelo fornecedor audiovisual. Nenhum destes resultados valida iOS,
funcionamento offline, uso comercial, hospedagem pública ou publicação.

## Contrato de catálogo — API-04

`MusicCatalog` distingue faixas (`track`) e álbuns (`album`). Sem configuração,
o catálogo fica indisponível e o cadastro manual permanece utilizável.
`MUSIC_CATALOG_URL` é um endereço público HTTPS de intermediário normalizado;
`MUSIC_CATALOG_PROVIDER` identifica o fornecedor, sem tokens no cliente.
Esses parâmetros não implantam um backend nem autorizam licença comercial.

GET `music/tracks/search` ou `music/albums/search` recebe `q`, `language=pt-BR`
e cursor opaco opcional. Resposta: `provider`, `items`, `nextCursor` anulável.
Detalhes em `music/tracks/{id}` ou `music/albums/{id}` retornam `provider`, `item`.
Cada item contém `id`, `title`, `artists` (lista não vazia), `coverUrl` opcional.
Faixa aceita `albumTitle`, `version`, `durationMs`; álbum aceita `releaseYear`,
`edition`. Opcionais incompletos ficam ausentes; falta de título/identidade/artistas
descarta o resultado. IDs distintos preservam versões/edições; a chave inclui tipo,
fornecedor e identidade, sem deduplicação por título. Detalhes não podem trocar ID.

Páginas têm até 100 resultados; o cliente deduplica somente IDs da página,
recusa redirecionamentos e fornecedor divergente, limita cursor e consulta,
trata HTTP/cota/timeout e conserva a alternativa manual. Testes de contrato usam
HTTP simulado; o intermediário local MusicBrainz também tem ensaio de rede.

## Biblioteca e cadastro — MUSIC-01

Ativa nos emuladores ou com USE_MUSIC_LIBRARY=true, após revisão das regras do
ambiente (SEC-06). Biblioteca → Música oferece páginas de faixas e álbuns,
contagem completa por tipo e filtro de título/artista apenas nas páginas carregadas.
Cadastro manual exige título/artistas, separados por ponto e vírgula; aceita capa
HTTPS e versão/edição, e álbum da faixa. Detalhes externos conservam duração/ano.
Salvar aguarda confirmação; retry mantém a identidade preparada. Dono, tipo e
fornecedor compõem a deduplicação; versões com IDs diferentes são independentes.
Nenhuma operação cria faixas de um álbum automaticamente. Metadados e estado
pessoal continuam separados, sem alterações em books/bible_progress.

Testes de serviço cobrem retry, isolamento de identidade e espera por confirmação;
widget verifica artistas obrigatórios, detalhes e layout 320 px com texto 2×.

## Favoritos e escutas — MUSIC-02

Favoritar usa revisão otimista; conflito exige Recarregar seleção antes de outra
intenção. O filtro Favoritos considera somente páginas carregadas e não muda
a contagem total do tipo. Estado musical permanece null, sem concluído/assistido.
Escutas exigem data civil escolhida até hoje. Cada nova intenção gera um ID opaco;
retry conserva ID e data, e uma segunda escuta deliberada pode ter a mesma data.

Escutas imutáveis ficam em libraries/{owner}/listens/{id}, com schemaVersion=1,
ownerId, entryId, listenedOn, createdAt/updatedAt do servidor e revision=1.
As regras exigem entrada própria track/album, calendário válido e data até o dia
UTC do servidor; o seletor também limita ao dia local. Em fusos adiantados, a
virada local pode exigir aguardar a virada UTC para registrar o novo dia.
Não há edição/exclusão de escuta nesta entrega. Paginação de 20 + um marcador
usa createdAt e ID, escopo por dono/entrada, apenas resultados confirmados.
O índice correspondente está versionado, sem implantação. Atualizar minhas escutas
relê a primeira página; Carregar mais amplia o histórico.

Favoritos/escutas nunca são projetados ao parceiro. Término preserva os dados
pessoais; ouvir álbum não cadastra nem marca faixas. Cópia pessoal JSON inclui
escutas. Serviço/testes de regras cobrem data inválida/futura, terceiros,
concorrência, retry e preservação após término.

## Descobertas e momentos do casal — MUSIC-03

Detalhes → Adicionar à lista do casal escolhe uma lista existente; a criação
fica em Nós → Listas e experiências. Ambos podem adicionar/retirar seleções
no vínculo ativo. Compartilhar exige consentimento explícito e envia somente
tipo, título, artistas e referência de catálogo/manual, inclusive se a entrada
pessoal estiver oculta. Favorito, escutas, IDs pessoais e datas privadas não
são copiados. A referência opaca conserva a versão da obra; não dá acesso ao
catálogo privado da outra pessoa.

Propor momento musical exige data e consentimento, seguido de confirmação do
outro em Nós. Correção exige nova confirmação da revisão atual; retirada de
confirmação deixa de contar como momento conjunto. Nenhuma proposta/aceite cria
escutas ou favoritos pessoais. Retry conserva a intenção; troca de conta/relação
impede sucesso tardio. Histórico após término fica restrito aos antigos
participantes, com retirada da própria confirmação; novo parceiro e terceiros
não herdam acesso. Não há reprodução interna, playlist externa ou conta musical.

## Evidências e limites — 09/10/2026

Análise estática limpa; 466 testes Flutter e 93 testes Node/demo aprovados; build
web com USE_FIREBASE_EMULATORS=true aprovado. Regressões cobrem manual, catálogo
HTTP simulado, favoritos, escutas repetidas/retry, cursor com empate, conta trocada,
seleção mínima, dupla confirmação, correção, conflito e desvinculação. Regras
validam terceiros, ausência de autenticação, autoria, calendário e concorrência
real em demo-bookself, sem escrita em produção.

Navegador integrado: cadastro fictício de faixa, detalhes, favorito, duas
escutas deliberadas na mesma data persistência da faixa/favorito após recarga e layout em 1.280 × 720 e 390 × 844 observados.
Captura local não versionada em build/music-demo.png. Jornada visual conjunta
com duas contas, catálogo real, Android/iOS e leitores de tela reais ainda não
foram executados nesta entrega. Testes de widgets cobrem confirmação/consentimento
e descarte; os emuladores cobrem autorização de duas contas. Chrome da skill
agent-browser foi bloqueado pelo Controle de Aplicativo do Windows; inspeção
realizada no navegador integrado.

Naquela entrega, API-04/MUSIC-01 permaneciam parciais até integração musical real;
o avanço de 14/10 está acima. MUSIC-02/03 concluem o caminho local manual. Regras e
índice continuam candidatos à implantação SEC-06; não houve migração, deploy,
publicação, escolha de marca/fornecedor ou ativação fora dos emuladores.
