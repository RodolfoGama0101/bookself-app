# 012 — Preparação recuperável, consultas e sincronização

Estado: implementado e ensaiado localmente em 08/10/2026; adoção nas telas e operações remotas separadas. Escopo: DATA-03, DATA-04 e DATA-05.

## Escolhas e alternativas

Preservar documentos originais e preparar imports imutáveis numa área negada a clientes permite ensaiar sem adaptar silenciosamente datas/duplicatas ao contrato novo. Converter diretamente para `libraries` foi descartado nesta entrega: criação antiga pode ser desconhecida, datas precisam de origem/fuso, e duplicatas não têm sobrevivente aprovado. O comando offline não possui integração com produção. [Plano, backup e recuperação](../DATA_MIGRATION.md).

Paginação usa timestamp + ID, leitura de servidor, limite + 1 e agregação independente. Offset e métricas calculadas pela página visível aumentariam leituras ou produziriam totais incompletos. Cursor ligado à consulta impede confusão entre contas/filtros; autorização continua nas regras. Ordenação não cria snapshot entre páginas, e datas mutáveis legadas exigem atualização. [Consultas, índices e limites](../DATA_ACCESS.md).

O coordenador privado multimídia representa pendência/erro/confirmação/conflito e conserva intenção no retry. Descarte/troca de sessão invalidam retorno; revisão antiga não ganha novo número automaticamente. Uma fila offline própria não foi adotada: seria necessário definir durabilidade, identidade e resolução de conflitos para cada operação. Serviços existentes conservam seus contratos transacionais e de cache, agora documentados por operação.

## Consequências

Nenhuma migração ativa, coleção legada removida, data inventada, nova categoria ou alteração de regra remota. Não há novo fornecedor/dependência. Repositórios novos ainda não estão conectados às telas atuais. SEC-06 continua exigindo revisão de clientes/backup/autorização; ativação remota de consultas exige índices construídos. Conversão ativa e histórico multimídia permanecem entregas posteriores.

Validação: [DEVELOPMENT.md](../DEVELOPMENT.md#preparação-paginação-e-sincronização--data-030405).
