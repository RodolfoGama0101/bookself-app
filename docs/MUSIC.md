# Música

Entrega incremental local de 09/10/2026. Fornecedor musical e backend real
continuam pendentes em API-03. Nenhuma conta externa ou reprodução é necessária.

## Contrato de catálogo — API-04

`MusicCatalog` distingue faixas (`track`) e álbuns (`album`). Sem configuração,
o catálogo fica indisponível e o cadastro manual permanece utilizável.
`MUSIC_CATALOG_URL` é um endereço público HTTPS de intermediário normalizado;
`MUSIC_CATALOG_PROVIDER` identifica o fornecedor, sem tokens no cliente.
Esses parâmetros não implantam um backend nem escolhem fornecedor/licença.

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
trata HTTP/cota/timeout e conserva a alternativa manual. Testes usam HTTP simulado.

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

API-04/MUSIC-01 permanecem parciais até fornecedor/intermediário musical aprovado
e busca real verificada. MUSIC-02/03 concluem o caminho local manual. Regras e
índice continuam candidatos à implantação SEC-06; não houve migração, deploy,
publicação, escolha de marca/fornecedor ou ativação fora dos emuladores.
