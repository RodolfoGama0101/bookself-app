# Design das telas atuais

O padrão vigente está em [DESIGN.md](../DESIGN.md), na raiz. Este documento preserva o histórico e as evidências. A versão 2, de 09/10/2026, adota Material Design 3 como base de interação, conserva a direção Organic e acompanha sua implementação em UI-06.

## Revisão 2 — UI-06 — 09/10/2026

Pesquisa nas fontes oficiais de Material Design 3 e Flutter, referenciadas no padrão normativo. A implementação concentra cores/controles em `AppTheme` e acrescenta `AppSpace`, `ActionGroup`, `DestinationCard`, `SectionHeading` e `LibraryDestinations`. Superfícies claras têm mais separação do fundo; corpo usa texto principal e metadados preservam cor secundária. Campos, navegação, listas, botões e diálogos compartilham hierarquia e alvos de toque.

Início mostra ações antes do resumo; convite abre diretamente o fluxo anunciado. Paginação fica junto às atividades. Biblioteca usa categorias consistentes com Filmes no ambiente habilitado, cabeçalho rolável e inclusão sem FAB sobre livros. Nós separa atividades/privacidade em cartões com descrição. Busca mantém cadastro manual visível, inclusive na falha de catálogo. Detalhes/filmes recebem intervalos entre ações; Bíblia recebe margens consistentes. Perfil oferece controles acessíveis de 48 para foto/nome. Listas/experiências limitam largura e separam linhas de ações.

Verificações finais:

```sh
dart format <arquivos Dart alterados>
flutter analyze --no-pub
flutter test --no-pub
flutter build web --no-pub --dart-define=USE_FIREBASE_EMULATORS=true
```

Análise sem apontamentos, **430 testes aprovados** e build demo aprovado, incluindo verificação preliminar Wasm. Quatro regressões novas verificam separação real entre atalhos e acionamento em 320 px/texto 2×, além de destinos com texto extenso ativados por toque/teclado nos dois temas. Testes de navegação foram adaptados ao menu lateral compacto e estendidos à volta para 390 px, preservando o testamento. O teste paginado rola até Carregar mais atividades e volta às estatísticas completas, sem depender da posição antiga do controle.

| Inspeção no navegador integrado | Resultado |
| --- | --- |
| Login/cadastro em desktop | Formulário, ações e cadastro de perfil fictício confirmados. |
| Início final em 390 px, escuro | Ações separadas acima do resumo; sessão e tema preservados após recarga. |
| Início/Nós em 1.280 px | Menu estendido, hierarquia e limites de conteúdo conferidos. |
| Nós em 840 px | Menu compacto com rótulos; destinos e descrições legíveis. |
| Nós em 320 px | Rolagem alcança compartilhamento/bloqueios; rótulos e descrições quebram linha. |
| Biblioteca em 390 px | Quero ler, livro salvo, lombada, estado e ações visíveis; contexto mantido ao redimensionar. |
| Busca/manual/detalhes | Cadastro sem catálogo, edição e retorno confirmados; edição/histórico separados. |
| Bíblia em 390 px | Acesso direto, margens e progresso pessoal legíveis. |
| Perfil claro/escuro | Troca de tema confirmada e restaurada após recarga. |
| Listas/experiências em 320 px | Estado sem vínculo acessível; retorno e atualização disponíveis. |

Ambiente exclusivamente local: `demo-bookself`, Auth/Firestore emulados, sem chave de catálogo ou dados reais. O aviso Running in emulator mode foi conferido antes de criar dados fictícios. Capturas ficam fora do Git. Agent-browser não iniciou seu Chrome por bloqueio do Controle de Aplicativo do Windows; o navegador integrado permitiu a inspeção. Preview limitado a `build/web` no loopback.

Não foram executados Android/iOS, leitores de tela reais, toda a matriz offline/câmera/capas externas, nova jornada de vínculo entre duas contas ou fluxo completo de filmes. Regressões automatizadas cobrem estado, persistência, vínculo e mídias habilitadas. Sem alteração de serviços/regras/modelos, implantação, migração ou publicação. UI-03 e REL-04 continuam pendentes sob seus critérios completos. Os resultados abaixo pertencem à revisão histórica de 05/10/2026.

Revisão de 05/10/2026, solicitada pelo usuário com a skill frontend-design. Escopo: login/cadastro, Início, estante, busca/cadastro manual, detalhes, progresso bíblico e perfil. A entrega corresponde a UI-04. Em 08/10/2026, UI-01/02 e BIBLE-01 estenderam essa direção à Biblioteca/Nós e aos estados de conteúdo; a revisão completa de acessibilidade UI-03 permanece pendente.

## Diagnóstico e direção

A interface anterior usava pesos/fontes e cinzas diferentes entre telas, formulários sem limite de largura, cartões de livro com altura fixa e uma coluna de estatísticas que desperdiçava espaço no desktop. A ausência de parceiro aparecia como um participante vazio no Início.

A direção **Organic** usa areia `#E8DCC7`, sálvia `#8B9D83` e musgo `#606C38`. O tema escuro usa verdes profundos e texto areia; o claro mantém fundos areia e texto verde escuro. A tipografia geométrica Outfit é carregada das fontes já empacotadas, sem nova dependência ou download em execução. A faixa lateral dos cartões lembra a lombada de um livro e acompanha o estado de leitura. Login e resumo recebem granulação estática de 2,5%, desenhada em Canvas, sem asset externo ou animação contínua.

## Comportamento da interface

- `AppTheme` centraliza cores semânticas, texto, campos, botões, abas, navegação, diálogos e mensagens. Cinzas fixos e cores de sucesso/erro dos fluxos atuais passam a acompanhar o tema.
- Login: formulário limitado a 460 px em telas pequenas; apresentação e formulário em duas colunas a partir de 900 px, quando a escala de texto permite. A rolagem mantém acesso aos campos e ações.
- Navegação atual: Início/Biblioteca/Nós/Perfil; Bíblia fica na Biblioteca com atalhos no Início/Nós e retorno à origem. A partir de 1.000 px e texto até 1,5×, aparece menu lateral; nas demais situações, barra inferior Material. Abaixo de 380 px com texto acima de 1,5×, menu com rótulos completos mantém os destinos acessíveis. `IndexedStack` e uma chave global preservam telas/abas ao mudar de largura.
- Conteúdo principal limitado a 1.000 px; perfil a 720 px; detalhes em folha de até 680 px. As rotas de busca e capítulos também recebem limite de largura.
- Início: saudação, contagens reais no mês/ano, atividades e ação Adicionar livro. Sem parceiro, mostra apenas estatísticas pessoais e atalho de vínculo. Nomes longos e resumos do casal podem se empilhar; no desktop, as estatísticas pessoais usam uma linha.
- Cartões: altura determinada pelo conteúdo, título até três linhas, autor até duas, status e data em área que pode quebrar linha. Em largura menor que 380 px ou texto acima de 1,5×, ações ficam abaixo dos metadados. Capas ausentes usam um placeholder; títulos não são substituídos por conteúdo inventado.
- Estante: ação explícita Adicionar livro. Busca, estados, datas e agrupamento dos Lidos preservam os contratos atuais.
- Bíblia: títulos, contagens e nomes da comparação recebem espaço flexível; percentuais ficam alinhados à direita. Progresso pessoal e capítulos continuam usando confirmação de escrita.
- Perfil e detalhes: tipografia/paleta consistentes, botões de status com espaço horizontal e estado atual legível. Mostrar/Ocultar senha recebe tooltip.

Não há mudança de marca, identidade técnica ou novas categorias nesta navegação. Convites/ocultação foram implementados nas entregas COUPLE-03/04 posteriores ao redesign; implantação das regras continua pendente. O [mapa incremental](NAVIGATION.md) distingue a base atual das mídias/listas futuras.

## Verificação

Ambiente: Windows, Flutter 3.44.0/Dart 3.12.0, navegador integrado, Auth/Firestore locais de `demo-bookself`. Build sem chave Google Books, com `USE_FIREBASE_EMULATORS=true`; servidores HTTP limitados a `build/web` no loopback. Só foram usados perfis e registros fictícios.

```sh
dart format <arquivos Dart alterados>
flutter analyze --no-pub
flutter test --no-pub
flutter build web --no-pub --dart-define=USE_FIREBASE_EMULATORS=true
```

Resultado: análise sem apontamentos; 283 testes aprovados, incluindo oito novos em `test/design_layout_test.dart`; build web demo e verificação preliminar Wasm aprovados. Os novos testes usam fontes reais empacotadas e verificam cartões com duas ações/data, títulos e nomes longos, Início do casal e login em 320 px com texto 2×, além de largura do formulário em 1.440 px. As regressões existentes cobrem persistência, tema, datas e operações assíncronas.

SHA-256 do `main.dart.js` final demo: `f7a1132a5f1777aa97780da8cad09570bbd09bd0d6a6c8b5d52a52612815ab2a`. Identifica o artefato local conferido; não é uma garantia de reprodutibilidade binária.

Capturas locais são entregues no chat e mantidas fora do commit, conforme AGENTS.md. Não incluem contas reais. O registro de inspeção abaixo complementa a [jornada web anterior](WEB_VALIDATION.md).

| Inspeção | Resultado |
| --- | --- |
| Login desktop, 1.280 × 720 | Duas colunas, campos e ações legíveis; textos de apresentação sem controles falsos. |
| Início claro/escuro, 1.280 × 720 | Resumo em linha e atividades acessíveis por rolagem; atalho de vínculo sem participante fictício. |
| Estante, 390 × 844 | Título longo, placeholder, status e duas ações visíveis; Quero ler preservado ao trocar menu lateral por barra inferior. |
| Detalhes do livro | Folha com largura limitada, metadados e botões de status sem rótulos comprimidos. |
| Bíblia e capítulos, 390 × 844 | Livros/progresso e grade acessíveis; marcação demo confirmou Gênesis 1/50 e capítulo selecionado. |
| Perfil e troca de tema | Conteúdo limitado, vínculo e aparência acessíveis; tema Claro confirmado antes das capturas móveis. |
| Busca e formulário manual | Cadastro manual acessível sem chave; diálogo com rolagem e campos utilizáveis. |
| 320 px | Navegação e conteúdo conferidos visualmente; texto 2× validado nos testes de widgets. |

Durante a inspeção foram corrigidos um acesso ao tema do diálogo após seu fechamento, um título que falhava na pintura durante troca de tema, o cabeçalho do Início com texto 2× e o espaçamento/alinhamento das ações/contagens. Nenhuma supressão de análise ou alteração no SDK foi usada.

## Limites

Em 08/10/2026, UI-03 ajustou o primário do tema claro para uma variante do musgo `#465227` (contraste de 6,21:1 sobre areia, 5,63:1 sobre cartão). Paleta original, fontes, lombadas e superfícies Organic preservadas. Cartões e capítulos receberam nomes/estados acessíveis; grade bíblica adapta células à escala. [Achados, protocolo e limites](ACCESSIBILITY.md) distinguem inspeção web/testes da validação com leitores de tela reais.

Agent-browser não abriu sessão por falta de escrita no diretório de sockets; a revisão visual usou o navegador integrado. Uma aba recarregada voltou ao login e a autenticação não se confirmou ali; uma nova aba/origem identificada pelo aviso de emulador permitiu a jornada. A restauração após recarga continua na investigação já registrada em WEB_VALIDATION.md, sem atribuir causa a este redesign.

Não foram executados Android/iOS, leitor de tela completo, teclado de todas as rotas, capas externas/CORS, câmera/galeria ou toda a matriz offline. Regras/modelos/vínculo não mudaram, portanto a suíte de regras não foi repetida. Não houve implantação, migração ou publicação. UI-03 e REL-04 permanecem abertas para essas verificações.
