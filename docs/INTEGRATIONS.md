# Integrações

Referências revisadas em 02/10/2026. Revalidar requisitos, limites e termos antes de implementar. Nenhum fornecedor novo está aprovado ou integrado nesta versão.

**Atualização de 08/10/2026 — API-02/03:** [comparação e ensaios reproduzíveis](CATALOG_TRIALS.md) revisam fontes oficiais, limitações comerciais/cache/backend e mostram resultados reais de buscas MusicBrainz com falha 503 nos detalhes. Credencial TMDB ainda ausente, Spotify sem acesso autenticado e fornecedor musical não escolhido. Não representam adaptadores implementados nem conclusão dos ensaios.

## Integrações atuais

| Serviço | Uso | Pendências |
| --- | --- | --- |
| Firebase Authentication | Conta e sessão por e-mail/senha; emulador local com projeto demo. | Validação da jornada Flutter em plataformas e autenticação remota. |
| Cloud Firestore | Perfis, vínculos, livros e progresso em tempo real; regras/índices candidatos versionados e emulador isolado. | Implantação das regras, dados privados do perfil, visibilidade/cache e migração. |
| Google Books | Busca de volumes com até 20 resultados por chamada, timeout de 15 s, paginação e `googleBooksId` opcional. | Revisão real de restrições/quotas (SEC-03) e jornada do catálogo em plataformas. |
| Google Fonts | Fontes Playfair Display e Outfit empacotadas; busca de fontes na rede desabilitada. | Inspeção visual em plataformas. |
| Image Picker | Avatar salvo em Base64 no Firestore; cancelamento/negação tratados e descrições de uso iOS adicionadas. | Permissões nativas/build Apple e estratégia de armazenamento. |
| Capas HTTPS | Carregamento direto com fallback; web permite elemento HTML quando a decodificação falha por CORS. | Verificação real Android/iOS/web; `wsrv.nl` removido do app. |

Não há servidor próprio no repositório. `storageBucket` na configuração Firebase não significa que haja upload para Firebase Storage implementado.

## Busca e recursos locais de leitura

Implementação local de 03/10/2026: `BookService.searchGoogleBooksPage` normaliza a consulta, codifica parâmetros e usa `startIndex`. Avança pela quantidade bruta recebida, inclusive quando descarta itens sem identidade; página vazia encerra o percurso mesmo com total estimado maior. Campo parcial válido usa título/autor/data padrão. Resposta com estrutura inválida falha; quota conhecida em HTTP 403 é distinta de autorização, e HTTP 429 continua limite de uso. Erros não exibem corpo externo nem URL com chave. Não há retry automático ilimitado ou cache de catálogo implementado.

A tela ignora sucesso/falha antigos, mantém os resultados quando uma página seguinte falha e permite nova tentativa na mesma posição. Páginas subsequentes removem referências repetidas da lista apresentada, sem impor política de duplicatas na biblioteca. Cadastro manual e formulários de inclusão funcionam com rolagem e status expandido em tela pequena/texto ampliado. Referência externa opcional não substitui a identidade pessoal. Configuração, inventário e impedimento da revisão remota em [CONFIGURATION.md](CONFIGURATION.md).

`BookCover` atende cards/detalhes: ausência, endereço inválido, carregamento e falha usam o placeholder existente. Endereços HTTP válidos são elevados para HTTPS; URLs com credenciais e esquemas não HTTP(S) são rejeitadas. O app não envia capas ao proxy anterior. Na web, `WebHtmlElementStrategy.fallback` permite a alternativa HTML da versão fixada do Flutter, com as limitações de plataforma do SDK; funcionamento CORS real continua pendente.

As oito fontes estáticas em `assets/fonts/` cobrem Outfit/Playfair Display nos pesos 400/500/600/700. `GoogleFonts.config.allowRuntimeFetching = false` força os assets; `manifest.json` registra origem, bytes e SHA-256 conferidos. Licenças OFL estão junto dos arquivos; referências de origem: [Outfit](https://github.com/google/fonts/tree/main/ofl/outfit) e [Playfair Display](https://github.com/google/fonts/tree/main/ofl/playfairdisplay). Teste próprio carrega fontes reais sem o mock de tipografia dos demais testes. Novos pesos/itálicos precisam ser empacotados antes de uso.

Verificações locais: análise limpa, 275 testes Flutter, 25 testes em Auth/Firestore emulados e builds web/Android debug demo aprovados. Login web demo inspecionado no navegador integrado com fontes exibidas e sem erros de console observados; sem credenciais enviadas. Agent-browser bloqueado pelo Controle de Aplicativo Windows. A conferência visual foi limitada ao login, com rede disponível; não valida funcionamento offline em navegador nem capas/CORS. Build não comprova execução ou aparência nativa. Permissões/build Apple e matriz de execução estão em [IOS_VALIDATION.md](IOS_VALIDATION.md); API-05/REL-03 continuam abertas para validação em plataformas.

Em 03/10/2026, a auditoria remota somente de metadados confirmou regra permitindo qualquer leitura/escrita a uma conta autenticada. A correção foi validada em emuladores; implantação permanece separada. Consulte [SECURITY.md](SECURITY.md) e [DEVELOPMENT.md](DEVELOPMENT.md).

## Verificação web de imagens — API-05, 08/10/2026

No build demo, uma capa HTTPS de Open Library renderizou na biblioteca. A URL foi apenas uma fixture visual pública; não adiciona fornecedor de catálogo nem autenticação. Corrigir o mesmo livro manual para um endereço HTTPS inacessível mostrou o placeholder nos detalhes, sem retirar título/autoria/status. `BookCover` exclui a imagem decorativa da árvore acessível; metadados e ações são anunciados pelo cartão/detalhes. [Jornada e limites](WEB_VALIDATION.md#validação-local-de-fluxos-e-acessibilidade--08102026).

Os testes de fontes reais sem rede e fallback estão entre os 402 Flutter aprovados. Não foi desconectado o navegador inteiro nem executado Android/iOS; CORS de todos os hosts e a matriz offline/nativa permanecem pendentes. API-05 continua aberta.

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
