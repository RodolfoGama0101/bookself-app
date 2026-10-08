# Filmes: entrega incremental

Implementação local de 08/10/2026 para API-04 e MOVIE-01/02/03. Filmes usam o contrato incremental de [DATA_MODEL.md](DATA_MODEL.md), sem migração de `books` ou `bible_progress`.

## Ativação e navegação

O modo `USE_FIREBASE_EMULATORS=true` habilita Biblioteca → Filmes e o espaço de listas/experiências. Fora dos emuladores, `USE_MOVIE_LIBRARY=true` habilita a biblioteca; as ações conjuntas exigem também o espaço do casal habilitado e vínculo ativo. Distribuição depende de SEC-06, regras/índices e validação em ambiente de desenvolvimento. Não habilitar a flag como substituto da implantação das regras.

Biblioteca mantém Livros, Filmes e Bíblia na mesma sessão. Filmes carregam páginas de até 20 entradas, com contagem total no servidor. Filtros por título/status consideram somente as páginas carregadas, conforme o aviso da tela; “Carregar mais filmes” amplia o conjunto. Detalhes retornam à mesma página/filtro. Troca de conta limpa registros/filtros e invalida resultados pendentes.

## Cadastro e progresso pessoal

Cadastro manual exige título (até 300 caracteres); ano e pôster são opcionais. O ano aceita 1–9999 e o pôster exige HTTPS sem credenciais. Ausência/falha de imagem usa o fallback existente. O filme entra em **Quero assistir**. Metadados e referência de catálogo ficam separados da entrada pessoal, identificada por documento próprio; fornecedor, mídia, ID externo e dono continuam compondo a deduplicação adequada.

**Assistido** aceita data desconhecida. Informar/editar data marca como assistido; limpar data conserva o estado assistido. Voltar a Quero assistir limpa a data. Datas civis inválidas/futuras são recusadas e a inclusão original permanece independente. Escritas aguardam transação e leitura confirmada; falha não anuncia sucesso. Retry conserva o catálogo preparado e resolve o slot existente. Conflito de revisão exige releitura antes de uma nova intenção.

## Catálogo configurável

`MovieCatalog` oferece busca paginada, detalhes e disponibilidade. `HttpMovieCatalog` implementa um **contrato de intermediário normalizado**, ainda sem backend implementado, contratado ou implantado. Não constitui aprovação de TMDB nem liberação do adaptador real de API-02. Sem configuração válida, o catálogo fica indisponível e o cadastro manual funciona.

Configurações públicas: `MOVIE_CATALOG_URL` (base HTTPS, sem usuário/senha, query ou fragmento) e `MOVIE_CATALOG_PROVIDER` (namespace do fornecedor aprovado). **Nenhum token de fornecedor deve ser passado em defines, URL ou aplicativo.** Autenticação confidencial, quotas, atribuição e termos devem ser resolvidos no intermediário após aprovação do fornecedor. O cliente não usa cache persistente de resultados: mantém somente a busca aberta em memória; política de cache depende dos termos aprovados.

Contrato para implementação futura do intermediário:

```text
GET {base}/movies/search?q={consulta}&language=pt-BR[&cursor={cursor}]
200 {"provider":"namespace", "items":[{"id":"ID externo", "title":"Título",
     "releaseYear":2020, "coverUrl":"https://..."}], "nextCursor":null}

GET {base}/movies/{ID externo codificado como um segmento}
200 {"provider":"namespace", "item":{"id":"ID externo", "title":"Título",
     "releaseYear":null, "coverUrl":null}}
```

O cliente limita consulta a 300 caracteres, cursor a 1.000 e página a 100 resultados. Identidade/título inválidos descartam o item parcial; ano/pôster inválidos viram ausência. Referência divergente nos detalhes ou fornecedor divergente no envelope falham. IDs preservam caixa e caracteres reservados. Duplicatas na página são removidas, cursor repetido é encerrado pela tela, respostas antigas são descartadas e uma página vazia termina a paginação. Timeout de 15 segundos inclui resposta; HTTP 429 informa limitação, outros erros mantêm nova tentativa manual. Redirecionamentos são recusados. Não há retry automático ilimitado.

## Listas e sessões do casal

Detalhes → **Adicionar à lista do casal** seleciona uma lista já criada em Nós. **Propor sessão do casal** exige data e segue a dupla confirmação existente em Nós → Listas e experiências. As duas ações exigem consentimento explícito para compartilhar título, ano e referência; não copiam status/data pessoal ou ID de entrada pessoal. Cadastro manual tem referência própria de catálogo, incluindo sua identidade manual.

O serviço existente verifica o vínculo ativo no servidor, conserva autoria/auditoria e o ID da intenção durante retry. A sessão somente fica confirmada com as respostas dos dois na revisão atual. Isso não atualiza bibliotecas pessoais. Após término, seleções/sessões históricas continuam legíveis somente aos participantes antigos; novas escritas/aceites são negados, retirada da própria confirmação segue o contrato existente e novo parceiro não herda histórico. Consulte [COUPLE_WORKSPACE.md](COUPLE_WORKSPACE.md).

A entrega usa entradas pessoais privadas (`isShared=false`). Consulta completa da biblioteca de filmes do parceiro, projeções por mídia, feed e métricas unificadas ainda não existem; dependem da extensão do contrato de compartilhamento e de COUPLE-08. Isso não redefine a política aprovada de compartilhamento: seleções explícitas são a parte implementada agora.

## Verificação e limites

Testes de catálogo cobrem respostas parciais, UTF-8, IDs codificados, fornecedor, cursor, timeout, HTTP 302/429/503 e configuração indisponível. Persistência cobre commit aguardado, retry, isolamento, conflito, datas e preservação das coleções legadas. Widgets cobrem falha/retry, troca de conta/vínculo durante escrita, conflito/releitura, consentimento e filtros em 320 px com texto 2×. As regras demo verificam duas bibliotecas independentes, seleção mínima, confirmação do parceiro, terceiros/ex/novo parceiro e histórico após término.

API-04 permanece parcial: falta fornecedor audiovisual aprovado/ensaio autenticado e adaptador musical. MOVIE-01 mantém a busca real pendente; cadastro manual/detalhes e contrato cliente estão prontos localmente. MOVIE-02/03 são entregas locais com catálogo manual. Android/iOS, catálogo real, backend, implantação de regras/índices, migração e publicação não foram realizados.
