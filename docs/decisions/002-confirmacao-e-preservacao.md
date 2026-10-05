# 002 — Confirmar escritas e preservar dados existentes

Data: 03/10/2026. Estado: implementado localmente nas correções CORE e BIBLE-02.

## Contexto e alternativas

Confundir conta autenticada com perfil carregado liberava fluxos sem dados válidos. Sobrescrever perfil na recuperação poderia perder dados criados por outro cliente. Usar `null` tanto para omissão quanto limpeza em `copyWith` impedia apagar opcionais. Anunciar sucesso antes da escrita tornava rejeições e estado exibido inconsistentes.

Alternativas: recriar perfil automaticamente, migrar os documentos atuais, aplicar alterações otimistas com rollback, ou confirmar operações preservando os contratos existentes. Uma migração ou política completa de offline exigiria decisões e ensaios adicionais.

## Escolha e motivos

Separar estados de sessão/perfil, criar perfil somente se ausente em transação e aguardar confirmação antes do sucesso. `BookModel`/`UserModel` distinguem omissão de `null` explícito com marcador privado. Operações assíncronas descartam callbacks após logout/troca/descarte e liberam controladores/assinaturas. Progresso bíblico valida os limites do catálogo antes da escrita; capítulo usa transação e lote substitui somente o documento pessoal.

Essa evolução incremental preserva coleções, autoria, IDs e datas legadas sem migração automática. Fakes permitem validar confirmação, rejeição e retorno antigo sem escrever em produção.

## Efeitos e pendências

Uma escrita já iniciada não é cancelada por fechar a tela. Lotes bíblicos concorrentes substituem a lista; não há junção de intenções de dispositivos. Dados de cache sem escrita pendente podem aparecer, sem garantir leitura recente do servidor. Política ampla de offline/cache, novo esquema e migração permanecem em DATA-01/03/05.

Evidências e contratos: [ARCHITECTURE.md](../ARCHITECTURE.md), [matriz de regressões](../DEVELOPMENT.md#cobertura-de-regressões-e-validação-dart). A confirmação no cliente não substitui autorização no Firestore.
