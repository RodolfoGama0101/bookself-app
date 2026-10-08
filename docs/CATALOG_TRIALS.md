# Ensaios de catálogo — API-02/03

Revisão em **08/10/2026**. Investigação de desenvolvimento, sem fornecedor novo integrado ao Flutter. API-02/03 permanecem abertas; não há aprovação definitiva de fornecedor, contratação, backend ou distribuição comercial.

## Execução reproduzível

Node 22 ou superior, sem novas dependências. Comandos na raiz do projeto:

```sh
node --test tool/catalog/trial.test.cjs
node tool/catalog/trial.cjs musicbrainz
```

O ensaio faz consultas públicas com identificação do aplicativo, intervalo mínimo de 1,1 segundo, timeout de 15 segundos e sem repetição automática. Saída contém somente metadados públicos e resumo HTTP/CORS; não grava respostas nem imagens. Falhas parciais aparecem em `outcome` e `status: partial`; isso não comprova aprovação do fornecedor. Não executar múltiplas instâncias simultâneas: o limite precisa ser respeitado pelo aplicativo inteiro, não apenas por processo.

Para TMDB, o usuário informou nesta sessão que **ainda não tem credencial**. Depois de obter um token de leitura de desenvolvimento e aceitar os termos no painel oficial:

```sh
cp config/tmdb.example.json config/tmdb.local.json
# Preencher TMDB_READ_ACCESS_TOKEN no arquivo local; não na conversa/Git.
node tool/catalog/trial.cjs tmdb config/tmdb.local.json
```

No PowerShell, `Copy-Item` substitui `cp` se necessário. `config/*.local.json` é ignorado pelo Git. O script aceita somente arquivo local nessa pasta; envia o token em cabeçalho exclusivamente ao host da API TMDB, recusa redirecionamentos autenticados e não o passa ao CDN. Não usar esse arquivo como `dart-define`: não protege segredo no aplicativo distribuído. Erros externos e corpos não são impressos. A cópia de exemplo não contém credencial.

## API-02 — TMDB

**Estado:** documentação e ferramenta preparadas; execução autenticada, cobertura pt-BR, episódios, imagens/CORS e decisão do fornecedor pendentes. Não há simulação apresentada como ensaio real.

| Dimensão | Evidência/documentação e próximo passo |
| --- | --- |
| Acesso | Conta/credencial própria. Token de leitura Bearer autentica as APIs v3/v4; não é necessário conectar a conta de cada usuário para consultar catálogo. [Autenticação oficial](https://developer.themoviedb.org/docs/authentication-application). |
| Busca e detalhes | Script consulta `Central do Brasil` e `Cidade Invisível` em `pt-BR`, depois detalhes e uma temporada com episódios. Busca considera títulos originais/traduzidos/alternativos; localização não garante tradução de todo campo. [Busca](https://developer.themoviedb.org/reference/search-movie), [temporada](https://developer.themoviedb.org/reference/tv-season-details). |
| Imagens | Montar endereço por configuração, tamanho e caminho. Script verifica cabeçalho de pôster via HEAD, sem baixar imagem; renderização/capas ausentes/CORS na web ainda devem ser testados no Flutter. [Imagens](https://developer.themoviedb.org/docs/image-basics). |
| Quota | Limite antigo desativado; há teto variável na ordem de 40 requisições/s. Não assumir capacidade contratada: tratar HTTP 429, evitar busca a cada tecla e repetição ilimitada. [Limites](https://developer.themoviedb.org/docs/rate-limiting). |
| Custo e atribuição | Uso não comercial gratuito com atribuição; atividade voltada a receita exige licença comercial negociada. Logo aprovado e aviso no Sobre/Créditos, menos proeminentes que a marca do app. Aviso exigido: “This product uses the TMDB API but is not endorsed or certified by TMDB.” Não há SLA garantido. [FAQ oficial](https://developer.themoviedb.org/docs/faq). |
| Cache/termos | As páginas consultadas não estabelecem uma autorização universal de retenção, redistribuição ou prazo de cache. Registrar os termos efetivamente aceitos no cadastro antes de definir TTL, persistência e política de imagens; não inventar prazo. [Entrada e termos](https://developer.themoviedb.org/docs/getting-started). |
| Backend | Proposta: intermediário para credencial, quota, timeout e cache aprovado; não existe servidor implementado aqui. A aprovação de fornecedor não autoriza automaticamente contratar/publicar infraestrutura. |

Para fechar API-02: executar o comando com credencial de desenvolvimento, conferir resultados e ausência de dados, validar pôster no Flutter web/nativos, registrar termos de cache/licença e decidir explicitamente TMDB. Episódios futuros/especiais/progresso continuam em SERIES-01/02.

## API-03 — MusicBrainz versus Spotify

| Dimensão | MusicBrainz | Spotify |
| --- | --- | --- |
| Modelo | `recording` distingue gravações; `release-group` agrupa álbum; `release` identifica edição e suas faixas. Não misturar grupo e edição numa identidade. | Faixas/álbuns têm IDs próprios e detalhes; acesso real ao catálogo do projeto ainda não ensaiado. |
| Conta e autorização | Catálogo público sem chave; identificar aplicativo por User-Agent. Escritas/dados de usuário exigem autenticação e ficam fora do MVP. | Client Credentials é fluxo servidor a servidor para recursos sem dados pessoais; exige app e segredo. OAuth/PKCE seria outra jornada, sem segredo no cliente, para acesso autorizado de usuários. |
| Quota/acesso | No máximo uma chamada/s por aplicativo; compartilhada entre buscas/detalhes. | Proprietário Premium, até cinco usuários autenticados em allowlist no modo de desenvolvimento. Quota ampliada exige organização e critérios, incluindo 250 mil usuários ativos mensais; aprovação não presumida. Rate limit usa janela de 30 s e 429/Retry-After. |
| Imagens | Cover Art Archive é serviço separado, pode faltar capa; metadados redirecionam para `index.json`. Não é uma licença geral de direitos de imagem. | Capas/metadados exigem atribuição Spotify e link da obra. Compatibilidade com o produto e direitos/termos devem ser revisados antes de adotar. |
| Web/backend | Respostas de busca observadas com CORS `*`. Isso não comprova a jornada Flutter. Navegador não oferece controle confiável de User-Agent por app; intermediário recomendado também para limite global e cache. | Intermediário necessário para Client Credentials; CORS não protege segredo distribuído. Não foi feito login nem criado app Spotify. |
| Custo/licença | Serviço não comercial gratuito; dados centrais CC0, complementares CC BY-NC-SA 3.0. Uso comercial do serviço exige plano/acordo. Planos variam por cenário; Bronze indicado para apps populares/startups aparece a US$ 100/mês, sem declarar que é o plano aplicável ao projeto. | Não foi contratado plano nem calculado custo total. Premium/infraestrutura/eligibilidade são custos e dependências separados; não prometer API comercial irrestrita. |
| Cache | Separar licença dos dados de condições de acesso ao serviço; cache de metadados centrais pode reduzir chamadas, com origem/edição identificadas. TTL e direitos de capas precisam ser definidos na implementação. | Não assumir armazenamento/redistribuição irrestritos; revisar termos e atribuição antes de definir cache. |

Fontes oficiais: [MusicBrainz API](https://musicbrainz.org/doc/MusicBrainz_API), [licenças dos dados](https://musicbrainz.org/doc/About/Data_License), [planos MetaBrainz](https://metabrainz.org/supporters/account-type), [Cover Art Archive API](https://musicbrainz.org/doc/Cover_Art_Archive/API), [direitos de capas](https://musicbrainz.org/doc/Cover_Art), [Spotify Client Credentials](https://developer.spotify.com/documentation/web-api/tutorials/client-credentials-flow), [modos de quota](https://developer.spotify.com/documentation/web-api/concepts/quota-modes), [limites](https://developer.spotify.com/documentation/web-api/concepts/rate-limits), [política de atribuição/uso](https://developer.spotify.com/policy). Política Spotify também restringe métricas/perfis derivados: compatibilidade com registros de escuta e comparação exige avaliação específica, sem presumir autorização.

O [changelog Spotify de fevereiro de 2026](https://developer.spotify.com/documentation/web-api/references/changes/february-2026) reduz busca a dez resultados e remove endpoints/campos no escopo descrito. As páginas gerais antigas ainda mostram sugestões de chamadas em lote; consultar os changelogs e o modo efetivamente concedido ao app antes de projetar o adaptador. Não prometer streaming, recomendações ou integração de playlists por mera existência de endpoint.

### Ensaio real de MusicBrainz

Consultas em 08/10/2026 às 18:22 UTC, sem credenciais/dados pessoais. Amostra pequena, não mede cobertura completa:

| Consulta | Resultado observado |
| --- | --- |
| Águas de Março / Elis Regina | HTTP 200, 48 resultados estimados, cinco examinados; gravação ao vivo identificada, durações distintas. |
| Tempo Perdido / Legião Urbana | HTTP 200, 13 resultados, cinco examinados; uma duração ausente. |
| Clube da Esquina / Milton Nascimento | HTTP 200, três grupos; primeiro resultado era Clube da Esquina 2. Grupo exato também presente: `b29e94e7-0b0b-3a66-ab06-e02f8fa5054f`. Escolher primeira resposta automaticamente seria incorreto. |
| Abbey Road / The Beatles | HTTP 200, 22 grupos, cinco examinados; nome semelhante não implica mesma versão. |
| Detalhes de álbum | HTTP 503. Ensaio seguinte às 18:23 UTC também teve 503 nas buscas de álbuns. Não atribuir causa ao fornecedor/rede/limite sem evidência adicional. |
| Capas e web real | Não alcançados após falha nos detalhes. CORS observado nas buscas não valida imagens nem execução no navegador. |

**Recomendação provisória:** MusicBrainz é o candidato mais compatível com catálogo sem conta musical para o MVP, condicionada à validação de detalhes/edições/capas, infraestrutura e condições de uso. A pergunta de preferência musical desta sessão ainda não teve resposta; nenhum fornecedor foi escolhido silenciosamente.

Para fechar API-03: repetir detalhes/capas quando acessíveis, validar uma edição com faixas e casos incompletos, verificar jornada web e custo/termos do uso pretendido, obter decisão explícita. Spotify não foi ensaiado com credenciais; as restrições documentadas justificam adiar esse acesso, sem alegar cobertura experimental equivalente.
