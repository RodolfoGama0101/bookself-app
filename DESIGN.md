# Sistema de design — Bookself App

Versão 2 · 09/10/2026 · padrão normativo para interface e novas telas. Implementação e validação em **UI-06**, no [backlog](BACKLOG.md). Evidências anteriores preservadas em [docs/DESIGN.md](docs/DESIGN.md).

## Propósito e direção

O aplicativo organiza leituras pessoais e permite acompanhá-las em casal. A interface facilita encontrar uma obra, atualizar seu estado e consultar o que foi compartilhado. Continua útil para quem usa sozinho. Toda tela deve explicar onde a pessoa está, qual é a ação principal e como voltar.

**Base consolidada: Material Design 3**, usando componentes nativos do Flutter. A escolha aproveita comportamentos conhecidos de toque, foco, formulários, diálogos e navegação adaptável, sem uma biblioteca visual adicional. Material define estrutura e papéis semânticos; cores, intervalos e breakpoints abaixo são personalizações do projeto.

A direção visual **Organic** conserva areia, musgo e sálvia, tipografia geométrica Outfit, superfícies arredondadas e granulação discreta nos destaques. A assinatura é a faixa de lombada nos cartões de livros: o estado tem cor e rótulo legível. O objetivo é uma estante acolhedora, com controles claros e poucos elementos competindo pela atenção.

Bookself App permanece a marca atual; Entrelace é proposta. Filmes têm fluxo local condicionado à configuração; séries e músicas não ganham destinos pessoais antes de seus fluxos estarem prontos. Os contratos de [produto](docs/PRODUCT.md), [navegação](docs/NAVIGATION.md) e [privacidade](docs/COUPLE_POLICY.md) continuam válidos.

## Pesquisa e referências

Fontes oficiais consultadas em 09/10/2026:

| Referência | Aplicação |
| --- | --- |
| [Material 3 no Flutter](https://docs.flutter.dev/ui/widgets/material) | Componentes, temas e estados de interação nativos. |
| [Tipografia Material 3](https://m3.material.io/styles/typography/applying-type) | Papéis de título, corpo e rótulo; escala de texto e contraste. |
| [Layouts adaptáveis no Flutter](https://docs.flutter.dev/ui/adaptive-responsive/best-practices) | Decidir por espaço disponível, limitar largura, suportar teclado e preservar estado. |
| [Espaçamento Material 3](https://m3.material.io/foundations/layout/grids-spacing/spacing) | Ritmo consistente entre conteúdo, controles e seções. |
| [Botões Material 3](https://m3.material.io/components/buttons/guidelines) | Hierarquia entre ação principal, alternativa e consulta. |
| [Navegação Material 3](https://m3.material.io/components/navigation-bar/guidelines) | Destinos persistentes com ícone e texto. |

As páginas interativas do Material exigem JavaScript. A documentação oficial do Flutter sustenta a implementação; os valores abaixo são decisões locais. Documentação online pode refletir SDK posterior ao Flutter 3.44.0 fixado no projeto: conferir compatibilidade antes de adotar APIs novas.

## Princípios

1. **Uma prioridade por contexto.** Adicionar na Biblioteca, entrar no login e confirmar no formulário recebem o maior destaque.
2. **Espaço faz parte do controle.** Botões independentes nunca encostam; quebra de linha também precisa de intervalo vertical.
3. **Destinos previsíveis.** Biblioteca é pessoal; Nós reúne a relação; Perfil reúne preferências e conta. Atalhos abrem diretamente a tarefa anunciada.
4. **Dados verdadeiros.** Contagens vêm dos serviços. Desconhecido não aparece como zero. Não inventar nomes, métricas ou atividades.
5. **Leitura antes de decoração.** Ornamentos não recebem foco nem substituem rótulos. Usar ícones Material, sem emojis como controles.
6. **Confirmação antes de sucesso.** Escrita pendente bloqueia repetição; falha preserva dados e oferece recuperação. Design respeita autorização e consentimento.

## Cores e superfícies

Implementação: [AppTheme](lib/ui/theme.dart). Widgets consomem `colorScheme` e `textTheme`; não repetem valores hexadecimais por tela.

| Papel | Claro | Escuro | Uso |
| --- | --- | --- | --- |
| Fundo | `#E8DCC7` | `#202820` | Página. |
| Superfície | `#EDE3D1` | `#303C30` | Cartões, diálogos e folhas. |
| Superfície baixa | `#E2D6C0` | `#293329` | Agrupamentos secundários. |
| Primário | `#465227` | `#BBCB9B` | Ação principal, seleção e progresso pessoal. |
| Sobre primário | `#E8DCC7` | `#202820` | Texto/ícone do botão principal. |
| Contêiner primário | `#D3D9BF` | `#3A4636` | Destino destacado e categoria selecionada. |
| Texto principal | `#293329` | `#E8DCC7` | Títulos e conteúdo. |
| Texto secundário | `#505C49` | `#BAC6B3` | Ajuda e metadados. |
| Secundário | `#80563D` | `#D4B895` | Progresso do parceiro e sinais complementares. |
| Erro | `#963E29` | `#E8A48B` | Falha, exclusão e bloqueio. |
| Contorno | `#707A63` | `#84917B` | Campos e controles. |
| Contorno suave | `#B9AF98` | `#465240` | Divisores e bordas de cartões. |

Sálvia `#8B9D83`, musgo original `#606C38` e argila `#B08B6E` são referências da paleta, sem garantia para texto pequeno. Evitar branco/preto puros, fundos creme, sombras decorativas e gradientes saturados. Elevação principal zero; bordas e superfícies estabelecem agrupamento. Textura estática de 2,5% somente em `ReadingSurface`, sem assets externos ou animação contínua.

Texto comum e controles primários mantêm contraste mínimo de 4,5:1 nas superfícies utilizadas. Seleção, erro, compartilhamento e conclusão precisam de texto/ícone/estado semântico além de cor. Claro, Escuro e Sistema continuam opções locais persistentes.

## Tipografia

Família única **Outfit**, empacotada em `assets/fonts`, sem busca pela rede em execução. Usar os estilos do tema; não criar tamanhos por tela.

| Estilo | Tamanho / peso | Aplicação |
| --- | --- | --- |
| `displayLarge` | 40 / 600 | Marca na apresentação ampla. |
| `headlineLarge` | 32 / 600 | Saudação. |
| `headlineMedium` | 28 / 600 | Entrada de formulário. |
| `headlineSmall` | 24 / 600 | Destaque de contexto. |
| `titleLarge` | 22 / 600 | Barra superior e resumo. |
| `titleMedium` | 18 / 600 | Seção e título de livro. |
| `titleSmall` | 15 / 600 | Destino secundário. |
| `bodyLarge` | 16 / 400 | Campo e explicação principal. |
| `bodyMedium` | 14 / 400 | Conteúdo comum. |
| `bodySmall` | 12 / 400 | Metadados. |
| `labelLarge` | 14 / 600 | Botão, aba e filtro. |
| `labelMedium` | 12 / 600 | Etiqueta de estado. |

Entrelinha padrão 1,35. Títulos à esquerda; centralizar apenas mensagens curtas isoladas. Texto funcional cresce e quebra linha; não reduzir fonte para caber. Cartões permitem até três linhas de título e duas de autor, com conteúdo completo nos detalhes. Não aplicar altura fixa ao conteúdo variável.

## Espaçamento, forma e dimensão

Tokens: [AppSpace e componentes](lib/ui/widgets/design_components.dart). Unidade: pixel lógico do Flutter.

| Token / regra | Valor e aplicação |
| --- | --- |
| `xs` | 4: detalhe interno e título/descrição. |
| `sm` | 8: metadados próximos. |
| `md` | 12: intervalo mínimo entre ações e cartões de destino. |
| `lg` | 16: cartão e margem compacta. |
| `xl` | 24: margem ampla e destaque. |
| `section` | 32: início de grupo temático. |
| Área acionável | Mínimo 48 × 48; principais com mínimo de 52 de altura. |
| Raios | 16 em campos/controles; 20 em FAB/listas; 24 em cartões/diálogos; 28 em destaques/folhas. |
| Conteúdo | Até 1.000 de largura. |
| Perfil/formulário dedicado | Até 720; login até 460 na coluna compacta. |
| Folha de detalhes | Até 680. |

Usar separação explícita entre irmãos: padding interno não separa botões diferentes. `ActionGroup` empilha abaixo de 420 de largura disponível ou acima de 1,5× de texto; fora disso usa `Wrap` com 12 nos dois eixos. Rodapés respeitam área segura e teclado virtual. Formulários compridos sempre podem rolar.

## Navegação e responsividade

Quatro destinos: **Início / Biblioteca / Nós / Perfil**, identificados por ícone e rótulo. Arquitetura detalhada em [NAVIGATION.md](docs/NAVIGATION.md).

| Espaço e escala | Comportamento |
| --- | --- |
| Menos de 720 | Barra inferior. |
| 720–1.199 e texto até 1,5× | Menu lateral compacto com rótulos. |
| A partir de 1.200 e texto até 1,5× | Menu lateral estendido com marca. |
| Texto acima de 1,5× | Navegação inferior para dar largura ao conteúdo. |
| Menos de 380 e texto acima de 1,5× | Menu Navegar com todos os destinos por extenso. |

Limites locais considerando rótulos em português. Usar espaço disponível e escala, sem detectar modelo de dispositivo. Trocar largura conserva filtros, testamento, contexto e assinaturas. `IndexedStack` e chaves preservam telas; trocar conta/relação invalida os dados correspondentes.

Rotas secundárias têm Voltar e retornam ao contexto de origem. Bíblia retorna ao destino de onde foi aberta, inclusive pelo voltar do sistema. Cabeçalho da Biblioteca rola para liberar espaço em telas baixas; ações não cobrem o último livro.

## Componentes

| Componente | Contrato |
| --- | --- |
| `FilledButton` / `CustomButton` | Ação principal; verbo explícito como Entrar ou Adicionar livro. |
| `OutlinedButton` | Alternativa visível ou edição complementar. |
| `TextButton` | Consulta, cancelamento ou ação contextual. |
| `IconButton` | Tooltip, alvo mínimo e nome acessível; tarefa essencial também precisa ser encontrável por texto. |
| `ActionGroup` | Ações independentes com quebra e espaço nos dois eixos. |
| `DestinationCard` | Ícone, título, descrição útil e seta; toda a superfície abre a mesma tarefa. |
| `SectionHeading` | Cabeçalho semântico com respiro de 32 antes e 12 depois. |
| `LibraryDestinations` | Categorias entregues como seleção; Bíblia como acompanhamento separado. |
| `BookCard` | Capa decorativa com fallback, título, autor, estado, data e ações autorizadas; lombada por estado. |
| `ReadingSurface` | Resumo/apresentação com textura discreta e conteúdo verdadeiro. |
| `ReadingPage` | Limite comum sem perder rolagem do Scaffold. |
| `ContentState` | Carregamento, vazio ou falha com explicação e recuperação pertinente. |
| Campo | Rótulo persistente; exemplo no hint; erro junto ao campo. |
| Diálogo | Uma decisão, conteúdo rolável, cancelar sem gravar e ações separadas. |
| Detalhes | Metadados primeiro; mudança de estado em grupo; edição/histórico separados; exclusão ao final. |

Um fornecedor indisponível não bloqueia cadastro manual. Biblioteca do parceiro é consulta, sem escrita em seus registros. Desconhecido, privado e vazio são estados distintos.

## Composição por tela

- **Login/cadastro:** apresentação breve e formulário; duas colunas a partir de 900 quando a escala permitir; recuperação junto à senha e cadastro abaixo da ação principal.
- **Início:** saudação, resumo real, Adicionar livro/Acompanhar Bíblia com intervalo, atividades. Vincular parceiro abre diretamente Convites do casal.
- **Biblioteca:** categoria/Bíblia, inclusão explícita, busca/filtros na barra superior, abas de estado e livros. Cabeçalho rolável; nenhuma ação flutuante cobre a lista pessoal. Filtros ativos são identificados e podem ser limpos.
- **Busca:** campo/Buscar, cadastro manual permanente, resultados ou estado útil. Falha conserva a alternativa manual no mesmo lugar.
- **Detalhes:** estado atual, ações agrupadas, pendência desabilitada e exclusão distante das mudanças rotineiras.
- **Bíblia:** testamentos, livros/progresso e capítulos acessíveis. Rótulos pessoais/do parceiro separados; indisponibilidade alheia não bloqueia o pessoal.
- **Nós:** contexto da relação; sem vínculo, convite é a ação principal. Compartilhar momentos reúne listas, consulta e comparação disponíveis. Vínculo e privacidade reúne gestão, compartilhamento e bloqueios.
- **Perfil:** identidade editável, relação, aparência, compartilhamento, segurança e saída. Foto/nome têm controles com área de toque e nome acessível.
- **Listas/experiências:** largura limitada, vínculo/histórico identificado; seleção, proposta e confirmação separadas. Nenhuma ação modifica o progresso pessoal do parceiro.
- **Filmes no ambiente habilitado:** mesmas categorias, superfícies, campos, estados e intervalos. Redesign não habilita a funcionalidade na distribuição padrão.

## Texto, feedback e movimento

Português brasileiro, acentuação e verbos concretos. Datas em dia/mês/ano. Preservar identificadores e valores legados armazenados ao melhorar rótulos. Evitar jargão técnico, títulos decorativos e mensagens que culpem a pessoa.

Carregamento tem descrição; vazio orienta o próximo passo; falha indica o que não funcionou e oferece recuperação. Rede, permissão, ausência, ocultação e pendência são situações distintas. Conteúdo alheio não confirmado sai da tela. Sucesso exige escrita aceita. Não exibir erro bruto nem registrar segredos/dados pessoais.

Manter transições e estados Material de foco/hover/pressionamento. Futuras animações próprias: suaves, 300–500 ms e respeitando redução de movimento. Sem animação contínua, parallax ou atrasos artificiais para registrar progresso.

## Acessibilidade e verificação

Antes de concluir uma mudança:

1. Conferir claro/escuro e estados vazio/carregando/falha.
2. Conferir 320/390, tablet/desktop, texto 1×/2×, tela baixa e teclado quando a plataforma permitir.
3. Confirmar espaço, quebra de rótulos e rolagem até a última ação.
4. Navegar por Tab/Shift+Tab; ativar por Enter/Espaço; fechar diálogos por Escape quando apropriado.
5. Conferir nomes, seleção, progresso e operação pendente na semântica; não anunciar capas decorativas repetidamente.
6. Preservar filtros ao trocar destino/largura/tema; limpar contexto ao trocar conta/vínculo.
7. Executar formatação, análise e regressões pertinentes; complementar com inspeção visual.

O [protocolo de acessibilidade](docs/ACCESSIBILITY.md) distingue leitores de tela reais e avaliação humana. Widgets/inspeção web não aprovam Android/iOS, produção, migração ou publicação. UI-03 permanece independente.

## Evolução

Toda nova tela segue este sistema. Novo token/componente precisa resolver repetição concreta, ter papel documentado e funcionar nos dois temas. Alterar um token exige revisar consumidores; não adicionar exceções silenciosas. Atualizar este arquivo quando o padrão mudar e registrar evidências/limitações no backlog e nos documentos pertinentes.
