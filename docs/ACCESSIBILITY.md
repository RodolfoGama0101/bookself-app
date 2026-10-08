# Acessibilidade e avaliação dos fluxos

Revisão em **08/10/2026**, escopo DOC-03, PROD-03, UI-03 e API-05. Resultados locais não equivalem à aprovação de produção ou à avaliação por pessoas usuárias.

## Problemas encontrados e corrigidos

| Problema | Efeito | Correção e evidência |
| --- | --- | --- |
| Primário claro `#606C38` sobre areia/cartão | Contraste de 4,19:1/3,80:1 para textos pequenos | Variante `#465227`: 6,21:1/5,63:1 e mínimo 4,65:1 nas superfícies verificadas; teste de luminância nos dois temas. Musgo original permanece na paleta. |
| Capítulo identificado somente pelo número/cor/coração | Estado próprio e do parceiro sem descrição acessível | Nome do livro/capítulo, estado próprio, seleção, parceiro e gravação descritos; teclado Enter e confirmação cobertos por regressão. |
| Cinco colunas fixas nos capítulos | Espaço insuficiente com texto muito ampliado | Células com altura derivada da escala de texto e quantidade de colunas adaptável. Mantidos IDs, ordem, streams e escrita confirmada. |
| Botão pendente substituía o nome por um indicador | Operação sem nome acessível durante a espera | Nome preservado e anúncio de operação em andamento; envio continua bloqueado. |
| Capa agrupava o cartão como imagem na árvore web | Livro não identificado como ação para detalhes | Capa decorativa excluída da semântica; cartão com ação de abertura identificado como botão. Confirmado na árvore web e abertura por Enter/fechamento por Escape. |
| Livro bíblico agrupado como indicador de progresso | Ação de abrir capítulos sem papel de botão | Nome, total de capítulos e contagem própria/do parceiro com papel de botão; dados de comparação indisponível não entram no anúncio. Regressão de navegação preserva o progresso pessoal. |
| Documento web sem idioma | Pronúncia podia usar idioma do navegador | `lang="pt-BR"` no HTML de origem. |

`test/accessibility_test.dart` verifica contraste e botão com espera/Tab/Enter; `test/bible_screen_test.dart` verifica leitura, seleção, gravação e teclado; `test/book_cover_test.dart` verifica exclusão semântica da capa. Regressões anteriores cobrem telas de 320 px/texto 2×, datas, confirmação/retry e cancelamento.

## Roteiro para validação humana

Use exclusivamente [o ambiente demo](DEVELOPMENT.md#jornada-web-reproduzível--doc-03). Duas pessoas devem executar as tarefas sem orientação passo a passo do avaliador; instruções abaixo são objetivos, não afirmações de resultado. Registre dispositivo, navegador/leitor de tela, escala de texto, tema, êxito, dificuldade, comentário voluntário e prioridade. Não registre e-mails, senhas, códigos de convite ou dados reais.

1. Encontrar a busca, interpretar indisponibilidade sem chave e incluir um livro manual sem capa.
2. Encontrar o livro, iniciar leitura, concluir com data, corrigir a data e consultar o histórico.
3. Abrir a Bíblia, alternar testamento, marcar/desmarcar um capítulo e reconhecer confirmação/falha.
4. Criar/consultar um convite, identificar a outra pessoa, aceitar e conferir que os dados pessoais continuam independentes.
5. Em Nós, adicionar seleções a uma lista, reconhecer interesses em comum e destacar uma próxima opção; propor uma experiência e obter as duas confirmações da mesma revisão.
6. Encerrar o vínculo e verificar que a consulta compartilhada sai, enquanto registros pessoais permanecem.

Repetir os fluxos principais com teclado (Tab/Shift+Tab/Enter/Escape), leitor de tela e texto 2×. Verificar foco ao abrir/fechar diálogos, nomes das ações repetidas, estado selecionado, mensagens de erro e alcance de ações por rolagem. Usar 320 px, celular habitual e desktop; testar temas Claro/Escuro. Não atribuir dificuldades ao participante nem presumir aprovação pela ausência de comentários.

Modelo de registro:

| Data/plataforma/tecnologia assistiva | Objetivo | Resultado observado | Feedback sem identificação | Problema/ID/prioridade |
| --- | --- | --- | --- | --- |
| A preencher pelo avaliador | A preencher | Não executado | Não coletado | A definir após evidência |

## Limites e próximas verificações

A árvore semântica web e testes Flutter não demonstram funcionamento de NVDA, VoiceOver ou TalkBack. Inspeção automática do canvas não certifica todas as combinações de contraste/foco. A validação exploratória pelo agente não substitui feedback de pessoas usuárias em PROD-03, nem reprodução independente por outra pessoa em DOC-03. UI-03 permanece em andamento até a matriz de leitor de tela/teclado dos fluxos principais ficar completa.

API-05 teve capa externa web ensaiada; fontes reais sem rede são evidência de teste Flutter. Execução offline completa do navegador e dispositivos Android/iOS continua pendente. Ver [jornada observada](WEB_VALIDATION.md) e [integrações](INTEGRATIONS.md).
