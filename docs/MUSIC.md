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
