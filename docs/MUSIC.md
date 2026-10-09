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
