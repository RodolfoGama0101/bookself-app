# Integrações

Referências revisadas em 02/10/2026. Revalidar requisitos, limites e termos antes de implementar. Nenhum fornecedor novo está aprovado ou integrado nesta versão.

## Integrações atuais

| Serviço | Uso | Pendências |
| --- | --- | --- |
| Firebase Authentication | Conta e sessão por e-mail/senha. | Inicialização, ciclo de vida, erros e testes. |
| Cloud Firestore | Perfis, vínculos, livros e progresso em tempo real. | Regras, índices necessários, emuladores e migração. |
| Google Books | Busca de volumes com até 20 resultados por chamada. | Chave embutida, timeout, paginação, IDs externos e erros. |
| Google Fonts | Fontes Playfair Display e Outfit. | Validar carregamento sem rede e possível empacotamento. |
| Image Picker | Avatar salvo em Base64 no Firestore. | Permissões, falhas e estratégia de armazenamento. |
| `wsrv.nl` | Proxy de capas em cards/detalhes na web. | Dependência, disponibilidade e alternativa. |

Não há servidor próprio no repositório. `storageBucket` na configuração Firebase não significa que haja upload para Firebase Storage implementado.

## Filmes e séries

**TMDB** é um candidato para metadados de filmes, TV e imagens. Exige registro de credencial e concordância com termos; autenticação e limites precisam entrar no desenho, conforme a [documentação oficial](https://developer.themoviedb.org/docs/getting-started).

O ensaio deve verificar português, temporadas/episódios, imagens, erros, plataformas, atribuição, condições comerciais, cache, quota e custos. Metadados de catálogo não fornecem por si acesso aos vídeos. Seleção e validação: API-02.

## Músicas

| Opção | Capacidade documentada | Avaliar |
| --- | --- | --- |
| Spotify Web API | Metadados, busca, playlists e controles de reprodução. | Autorização, elegibilidade, escopos, quotas e endpoints disponíveis. |
| MusicBrainz API | Busca/consulta de metadados em JSON/XML. | Cobertura, gravações/lançamentos, imagens complementares, web e condições comerciais. |

A [documentação do Spotify](https://developer.spotify.com/documentation/web-api) descreve essas capacidades e informa requisito de conta Premium para usar a Web API no guia. Verificar a elegibilidade concreta do app, modos de quota e diferenças entre metadados e reprodução. Não assumir acesso para qualquer conta ou disponibilidade de todos os endpoints.

A [documentação do MusicBrainz](https://musicbrainz.org/doc/MusicBrainz_API) informa consultas gerais sem chave, identificação por `User-Agent` e limite de uma chamada por segundo por aplicativo. Uso não comercial do serviço é gratuito; uso comercial exige avaliar condições/planos. Não é streaming. No navegador, validar identificação e eventual necessidade de intermediário.

Proposta: escolher primeiro catálogo para busca e registros próprios. Contas externas, histórico automático e sincronização de playlists são escopos posteriores. Decisão e ensaio: API-03; sincronização opcional: IDEA-03.

## Contrato proposto

Preservar fornecedor, ID externo e tipo da mídia nos metadados normalizados. Busca, detalhes e paginação devem ser explícitos; temporadas/episódios são específicos de séries. Itens manuais continuam válidos sem fornecedor.

Prever timeout, descarte de resultados antigos, respostas parciais, ausência de imagem, limitação de chamadas e erros específicos. Evitar repetição ilimitada de requisições. Cache deve seguir o contrato do fornecedor.

Chaves/tokens no cliente podem ser inspecionados. Se houver segredo, troca confidencial de credenciais ou quota central, definir backend apropriado; `--dart-define` sozinho não protege segredo. A necessidade de infraestrutura deve ser decidida no ensaio.

As fontes orientam o planejamento; não substituem revisão dos termos na implementação. Tarefas e critérios estão em [BACKLOG.md](../BACKLOG.md).
