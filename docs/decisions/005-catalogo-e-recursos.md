# 005 — Catálogo existente e recursos de leitura

Data: 03/10/2026. Estado: implementação local pronta, auditoria de chave e validação em plataformas pendentes. Escopo: SEC-03/API-01/API-05, Google Books já existente; sem decisão de fornecedor, contrato de múltiplas mídias ou política de duplicatas.

## Escolhas e alternativas

O identificador Google Books sai do literal e é fornecido por arquivo local ignorado/define de compilação. Alternativas seriam manter o literal ou criar backend agora. O arquivo evita versionar valores e permite ambiente explícito; não protege um segredo dentro do app. Backend não foi introduzido sem necessidade/fornecedor aprovado. Restrições/quotas reais e eventual rotação precisam de revisão, impedida pela rejeição da revisão automática da consulta remota; detalhes em [CONFIGURATION.md](../CONFIGURATION.md).

`googleBooksId` opcional preserva a referência conhecida sem substituir o documento pessoal. Alterar todos os IDs ou adotar já o esquema multimídia exigiria migração/decisão ainda pendente. O legado permanece válido, sem referência inferida. Regras candidatas e testes mantêm autoria e acesso independentemente desse campo. A biblioteca ainda pode conter duas inclusões da mesma obra; BOOK-01 depende de política própria.

Busca usa páginas explícitas, timeout, mensagens tipadas e revisão de operações na tela. Resultados antigos são ignorados; páginas repetidas eliminam referências duplicadas na lista apresentada. Não há retry automático ilimitado, cache de catálogo ou escrita remota pelos testes.

Outfit/Playfair Display nos pesos usados são assets com licenças OFL, evitando depender de rede para a tipografia. Fontes do sistema ou download em execução eram alternativas; o empacotamento mantém a aparência existente e adiciona os bytes registrados em `assets/fonts/manifest.json`. Novos pesos/itálicos exigem asset correspondente. Não houve redesenho visual.

Capas deixam de passar pelo proxy `wsrv.nl` e usam HTTPS direto com placeholder. Na web, a estratégia HTML do Flutter oferece fallback de carregamento; CORS/limitações e dispositivos ainda precisam de ensaio real. Manter o proxy implicaria disponibilidade e envio das URLs a outro operador, sem necessidade comprovada. A mudança não garante disponibilidade do servidor de origem.

## Evidência e limites

Análise limpa, 275 testes Flutter (fontes reais no teste dedicado), 25 testes em emuladores e builds web/Android debug demo aprovados. Login web demo inspecionado com fontes; jornada completa e execução offline não verificadas. Apple e permissões nativas em [IOS_VALIDATION.md](../IOS_VALIDATION.md). Nenhuma migração, produção, publicação ou implantação de regras. Backlog mantém dependência SEC-03 em API-01 e validação de plataformas em API-05/REL-03.
