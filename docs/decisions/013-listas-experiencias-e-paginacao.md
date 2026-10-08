# 013 — Listas, experiências e paginação incremental

Data: 08/10/2026. Estado: código e regras locais; ativação remota separada.

O usuário autorizou COUPLE-05, COUPLE-06 e UI-05. Implementação segue a política de duas confirmações e histórico consentido restrito aos participantes antigos.

## Escolha e alternativas

Reutilizar o convite aceito como fonte imutável dos participantes evita uma segunda prova de relação que precisaria ser criada/migrada junto ao aceite. As subcoleções propostas de `couple_relationships` são usadas sem criar documento-pai, e um índice privado permite reencontrar histórico. Reciprocidade e bloqueios são exigidos para editar; conhecer o ID não concede acesso. A alternativa de criar/projetar outra entidade de relação continua possível se surgirem requisitos concretos; não se converte vínculo legado silenciosamente.

Experiências têm revisão da proposta separada da versão do documento. Respostas pertencem à pessoa autenticada; alteração exige snapshot de auditoria atômico. Guardar apenas um booleano conjunto permitiria confirmação unilateral e perderia o significado de aceites antigos. Listas usam itens separados e marca de remoção para preservar autoria e rejeitar requisições concorrentes/atrasadas. Inclusões deliberadas têm IDs próprios; retry conserva o ID, sem deduplicar por título.

Bibliotecas de livros e Início usam consultas existentes de DATA-04 com janela viva limitada ao conteúdo carregado, cursores exatos do servidor, buffers por origem e agregações independentes da página. Uma nova inclusão desloca a borda da janela e atualiza o cursor antes de carregar mais. O feed exibe o próximo prefixo global ordenado, sem antecipar uma origem lenta nem perder o buffer da outra. A alternativa de manter streams completos segue como caminho distribuído de compatibilidade enquanto os índices remotos não forem revisados/construídos.

## Consequências

Paginação ativa automaticamente somente no modo demo/emuladores; `USE_PAGED_LIBRARY=true` habilita explicitamente outro ambiente após preparo de índices. Textos/períodos/status continuam conservados na interface; texto/período filtram os livros carregados, com aviso quando há continuação. Não há busca textual indexada nova, fila offline própria ou migração de livros/Bíblia. Estatísticas de experiências não se misturam às de livros; feed multimídia e os fluxos pessoais futuros continuam nas tarefas correspondentes.

[Contrato conjunto](../COUPLE_WORKSPACE.md), [acesso paginado](../DATA_ACCESS.md), [validação](../DEVELOPMENT.md#listas-experiências-e-paginação--couple-0506-ui-05) e [backlog](../../BACKLOG.md). Implantação, fornecedores, marca, política de retenção e plataformas nativas permanecem separados.
