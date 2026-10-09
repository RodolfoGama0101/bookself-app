# Séries

## Regras aprovadas — SERIES-01 — 09/10/2026

O usuário aprovou nesta data as seguintes regras do MVP:

- Temporada 0 contém especiais opcionais, fora do cálculo dos estados gerais.
- Episódios futuros não entram no conjunto disponível. Data desconhecida não
  comprova disponibilidade; cadastro manual permite informar disponibilidade.
- Em dia exige metadados completos do conjunto disponível e todos esses episódios
  vistos. Concluída exige também produção encerrada e catálogo completo, sem
  episódios regulares futuros ou de disponibilidade desconhecida.
- Pausada é uma escolha pessoal independente; retomar recalcula o estado.
- Reassistir e ciclos de progresso ficam fora desta versão. Desmarcar corrige
  a marcação atual, sem apagar a identidade do episódio.
- Comparação nunca recebe títulos/sinopses de episódios: mostra somente número
  de temporada/episódio e marcações permitidas. O nome da série pode aparecer.
- Proposta/dupla confirmação de episódio conjunto não marca progresso pessoal
  de ninguém. Cada pessoa controla a própria biblioteca.

Episódios mantêm identidade estável dentro da série. Atualizar catálogo não
remove marcações antigas; numeração é atributo, não chave de identidade externa.
Ausência de lista completa permanece desconhecida e não vira série concluída.

Fornecedor audiovisual, intermediário real e ensaio de API-02 continuam pendentes.
Estas regras aprovam o comportamento de séries, sem escolher fornecedor, migrar
livros/Bíblia ou autorizar implantação de regras em produção (SEC-06).

## Biblioteca e progresso — SERIES-02

Ativação local: emuladores ou USE_SERIES_LIBRARY=true. Biblioteca → Séries
oferece páginas de 20 entradas e total do servidor; filtros por título/estado
consideram as páginas carregadas. Cadastro manual exige título, ano/pôster
opcionais; episódios disponíveis são acrescentados com temporada/número.
O catálogo privado e a entrada pessoal continuam separados por dono e identidade.

SeriesCatalog implementa somente um contrato de intermediário normalizado:
SERIES_CATALOG_URL (HTTPS público) e SERIES_CATALOG_PROVIDER (namespace), sem
segredos. GET series/search?q=...&language=pt-BR[&cursor=...] retorna provider,
items e nextCursor; GET series/{id} retorna provider/item. Metadados básicos
seguem filmes; detalhes aceitam episodes (id estável seguro para documento,
season, number, availableOn opcional, available booleano), complete e ended.
Não recebe nem armazena título/sinopse de episódios. Sem data, available precisa
ser explícito; datas futuras prevalecem sobre available. Máximo de 500 episódios
por série nesta entrega; excesso falha explicitamente, sem calcular totais parciais.

Progresso privado em libraries/{owner}/series/{entry}/episodes/{id}, com
schemaVersion, season/number, availableOn/available, watched, revision e updatedAt
servidor. Configuração em libraries/{owner}/series/{entry} mantém complete,
ended, paused, revision e updatedAt. Estado geral é calculado ao consultar;
state da entrada-base não é fonte do status episódico nem de estatísticas.
Não há exclusão física de episódios, ciclos de reassistir ou migração do legado.

Transações validam entrada de série própria e revisão esperada. Retry de marcação
conserva ID/valor desejado; conflito exige releitura. Novos episódios não apagam
os anteriores. Pausa/retomada preservam marcações; escrita só conclui após commit.
Atualizações de metadados mantêm progresso por ID; falha no cadastro externo pode
ter salvo a série e parte dos episódios: repetir usa slot/IDs existentes.

Validação de 09/10/2026: análise limpa, 19 testes direcionados de catálogo,
progresso e interface (320 px/texto 2×), mais 94 testes Node/demo aprovados.
Cobertura de autorização, calendário, concorrência, retry, pausa/desmarcação e
novos episódios. Busca real depende de API-02/API-04; caminho manual está pronto.
Android/iOS, catálogo real e implantação SEC-06 permanecem pendentes.

Suíte completa: 485 testes Flutter aprovados e build web demo concluído, incluindo verificação preliminar Wasm. Sem jornada visual nova em navegador nesta etapa.
