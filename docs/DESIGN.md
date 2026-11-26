# Design da interface

A direção Organic usa areia no tema claro, musgo no escuro e sálvia para destacar ações e seleção. As capas reais dão identidade aos livros. Sem capa disponível, a interface usa um marcador com ícone. O tema compartilhado está em [AppTheme](../lib/ui/theme.dart) e as fontes empacotadas têm licenças em [assets/fonts](../assets/fonts).

- **Entrada e cadastro** usam duas colunas a partir de 840 px com escala de texto até 1,5×. Em telas menores, a marca e o formulário ficam em uma coluna rolável.
- **Navegação** usa barra inferior em telas compactas e menu lateral a partir de 900 px de largura e 440 px de altura, com escala de texto até 1,5×. Abaixo de 400 px com texto acima de 1,5×, o menu Navegar expõe os quatro destinos por extenso. A aba selecionada e seu conteúdo continuam montados ao redimensionar.
- **Início** reúne atalhos de livro e vínculo, conclusões do mês e do ano e atividade recente. A assinatura da atividade acompanha a identidade da conta e do vínculo.
- **Estante** mantém as abas pessoal e do parceiro, os estados de leitura e o histórico. O botão de inclusão fica em uma área própria abaixo da lista. Os cartões quebram títulos e metadados e reorganizam ações em largura compacta.

O recorte reaproveita o sistema visual de [UI-04](https://github.com/RodolfoGama0101/bookself-app/issues/54) e [UI-06](https://github.com/RodolfoGama0101/bookself-app/issues/55) sobre os destinos e fluxos da base main. A integração é acompanhada em [MAIN-05](https://github.com/RodolfoGama0101/bookself-app/issues/94).

## Verificação

No Windows com Flutter 3.44.0, `flutter analyze --no-pub` e `flutter test --no-pub` passaram. Os 16 testes incluem login, resumo do casal e cartões em ambos os temas, com texto de 2× em 320 px, além do login a 1.440 px.

O build `flutter build web --no-pub --dart-define=USE_FIREBASE_EMULATORS=true` passou. A sessão Chrome de ensaio cobriu entrada e estante em 390 × 844 e 1.280 × 800, criação de conta, cadastro de livro manual, alternância de tema e redimensionamento da navegação. Android e iOS permanecem pendentes de validação visual.
