import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/book_service.dart';
import '../../data/models/book_model.dart';
import '../widgets/book_card.dart';
import 'search_screen.dart';
import '../../utils/error_handler.dart';
import '../widgets/book_details_sheet.dart';
import '../widgets/completion_date_picker.dart';
import '../widgets/content_state.dart';

enum BookshelfScope { combined, personal, partner }

class BookshelfScreen extends StatefulWidget {
  const BookshelfScreen({
    super.key,
    this.bookService,
    this.scope = BookshelfScope.combined,
    this.onOpenBible,
    this.onClose,
  });

  final BookService? bookService;
  final BookshelfScope scope;
  final VoidCallback? onOpenBible;
  final VoidCallback? onClose;

  @override
  State<BookshelfScreen> createState() => _BookshelfScreenState();
}

class _BookshelfScreenState extends State<BookshelfScreen>
    with TickerProviderStateMixin {
  late TabController _userTabController;
  late TabController _myInnerTabController;
  late TabController _partnerInnerTabController;
  late final BookService _bookService = widget.bookService ?? BookService();
  final Set<String> _pendingCompletions = {};
  final _streams = <String, Stream<List<BookModel>>>{};
  final _retries = <String, int>{};

  void _openSearch() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => SearchScreen(bookService: _bookService),
    ),
  );

  @override
  void initState() {
    super.initState();
    // TabController de 2 abas: "Minha Estante" e "Estante do Parceiro"
    _userTabController = TabController(length: 2, vsync: this);
    _myInnerTabController = TabController(length: 3, vsync: this);
    _partnerInnerTabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _userTabController.dispose();
    _myInnerTabController.dispose();
    _partnerInnerTabController.dispose();
    super.dispose();
  }

  // Mapeamento dos nomes dos meses em Português
  String _getMonthName(int month) {
    const months = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];
    return months[month - 1];
  }

  // Agrupa os livros lidos por Ano e Mês
  Map<int, Map<int, List<BookModel>>> _groupBooksByDate(List<BookModel> books) {
    final Map<int, Map<int, List<BookModel>>> grouped = {};

    // Filtra apenas os concluídos e que possuem data de conclusão
    final readBooks = books
        .where((b) => b.status == 'Lido' && b.finishedDate != null)
        .toList();

    // Ordena de forma decrescente pela data de conclusão
    readBooks.sort((a, b) => b.finishedDate!.compareTo(a.finishedDate!));

    for (var book in readBooks) {
      final year = book.finishedDate!.year;
      final month = book.finishedDate!.month;

      grouped.putIfAbsent(year, () => {});
      grouped[year]!.putIfAbsent(month, () => []);
      grouped[year]![month]!.add(book);
    }

    return grouped;
  }

  // Abre seletor de data e atualiza o livro para "Lido"
  void _markAsRead(BuildContext context, BookModel book) async {
    if (!_pendingCompletions.add(book.id)) return;
    final pickedDate = await showCompletionDatePicker(context);
    if (!context.mounted) return;
    if (pickedDate == null) {
      _pendingCompletions.remove(book.id);
      return;
    }
    setState(() {});

    if (context.mounted) {
      final updatedBook = book.copyWith(
        status: 'Lido',
        finishedDate: pickedDate,
        addedAt: DateTime.now(), // Atualiza para subir no feed recente
      );
      try {
        await _bookService.saveBook(updatedBook);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${book.title}" marcado como lido!'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Não foi possível marcar como lido. ${ErrorHandler.getFriendlyErrorMessage(e, operation: ErrorOperation.saveBook)}',
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      } finally {
        _pendingCompletions.remove(book.id);
        if (mounted) setState(() {});
      }
    }
  }

  // Abre diálogo de confirmação para exclusão de livro
  void _confirmAndDeleteBook(BuildContext context, BookModel book) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            'Excluir Livro',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          content: Text(
            'Tem certeza de que deseja remover "${book.title}" da sua estante?',
            style: theme.textTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                if (!context.mounted) return;
                Navigator.pop(dialogContext);
                try {
                  await _bookService.deleteBook(book.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('"${book.title}" removido com sucesso.'),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Erro ao remover o livro: ${ErrorHandler.getFriendlyErrorMessage(e, operation: ErrorOperation.deleteBook)}',
                        ),
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                    );
                  }
                }
              },
              child: Text(
                'Remover',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Diálogo de confirmação para começar leitura
  void _confirmAndStartReading(BuildContext context, BookModel book) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            'Começar Leitura',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Deseja iniciar a leitura de "${book.title}" agora?',
            style: theme.textTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                if (!context.mounted) return;
                Navigator.pop(dialogContext);
                try {
                  await _bookService.saveBook(
                    book.copyWith(status: 'Lendo', finishedDate: null),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Você começou a ler "${book.title}"! Boa leitura!',
                        ),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Não foi possível iniciar a leitura. ${ErrorHandler.getFriendlyErrorMessage(e, operation: ErrorOperation.saveBook)}',
                        ),
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                    );
                  }
                }
              },
              child: Text(
                'Começar',
                style: TextStyle(
                  color: theme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUserModel;
    final partner = authService.partnerUserModel;
    final theme = Theme.of(context);

    if (user == null) {
      return const Scaffold(
        body: ContentState(title: 'Carregando sua conta', loading: true),
      );
    }

    if (widget.scope != BookshelfScope.combined) {
      final personal = widget.scope == BookshelfScope.personal;
      return Scaffold(
        appBar: AppBar(
          leading: widget.onClose == null
              ? null
              : BackButton(onPressed: widget.onClose),
          title: Text(personal ? 'Biblioteca' : 'Biblioteca do parceiro'),
        ),
        body: Column(
          children: [
            if (personal)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Chip(
                      avatar: Icon(Icons.library_books_outlined),
                      label: Text('Livros'),
                    ),
                    if (widget.onOpenBible != null)
                      OutlinedButton.icon(
                        onPressed: widget.onOpenBible,
                        icon: const Icon(Icons.menu_book_outlined),
                        label: const Text('Acompanhar Bíblia'),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: personal
                  ? _buildShelfView(user.uid, isEditable: true)
                  : user.partnerUid == null
                  ? const ContentState(
                      title: 'Nenhum vínculo ativo',
                      message: 'Envie ou aceite um convite em Nós.',
                      icon: Icons.favorite_border_rounded,
                    )
                  : _buildShelfView(user.partnerUid!, isEditable: false),
            ),
          ],
        ),
        floatingActionButton: personal
            ? FloatingActionButton.extended(
                onPressed: _openSearch,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Adicionar livro'),
              )
            : null,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Estantes'),
        bottom: TabBar(
          controller: _userTabController,
          tabs: [
            const Tab(text: 'Minha Estante'),
            Tab(
              text: partner != null ? 'Estante de ${partner.name}' : 'Parceiro',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _userTabController,
        children: [
          // ABA 1: MINHA ESTANTE (Permite edição e exclusão)
          _buildShelfView(user.uid, isEditable: true),

          // ABA 2: ESTANTE DO PARCEIRO (Somente visualização)
          partner != null
              ? _buildShelfView(partner.uid, isEditable: false)
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.favorite_border_rounded,
                          size: 48,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Aguardando conexão com o seu amor.\nVincule a conta na aba de perfil!',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SearchScreen()),
          );
        },
        backgroundColor: theme.primaryColor,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Adicionar livro'),
        tooltip: 'Buscar ou cadastrar um livro',
      ),
    );
  }

  Widget _buildShelfView(String userId, {required bool isEditable}) {
    final scope =
        '$userId/$isEditable/${isEditable ? "personal" : context.read<AuthService>().currentUserModel?.relationshipId}';
    // Remove ouvintes de contas/relações anteriores; StreamBuilder cancela o
    // stream substituído. Rebuild de tema/abas não reinicia a mesma consulta.
    _streams.removeWhere(
      (key, _) => key.split('/')[1] == '$isEditable' && key != scope,
    );
    final stream = _streams.putIfAbsent(
      scope,
      () => isEditable
          ? _bookService.streamUserBooks(userId)
          : _bookService.streamSharedBooks(userId),
    );
    final controller = isEditable
        ? _myInnerTabController
        : _partnerInnerTabController;
    return StreamBuilder<List<BookModel>>(
      key: ValueKey('$scope/${_retries[scope] ?? 0}'),
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ContentState(
            title: 'Não foi possível carregar a biblioteca',
            message: ErrorHandler.getFriendlyErrorMessage(
              snapshot.error,
              operation: ErrorOperation.loadLibrary,
            ),
            icon: Icons.cloud_off_outlined,
            actionLabel: 'Tentar novamente',
            onAction: () => setState(() {
              _streams.remove(scope);
              _retries[scope] = (_retries[scope] ?? 0) + 1;
            }),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ContentState(title: 'Carregando livros', loading: true);
        }

        final books = snapshot.data ?? [];

        final readingBooks = books.where((b) => b.status == 'Lendo').toList();
        final wishlistBooks = books
            .where((b) => b.status == 'Quero Ler')
            .toList();

        // TabController de 3 sub-abas: "Lendo", "Lidos", "Quero Ler"
        return Column(
          children: [
            Container(
              color: Theme.of(context).appBarTheme.backgroundColor,
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                controller: controller,
                tabs: const [
                  Tab(text: 'Lendo'),
                  Tab(text: 'Lidos'),
                  Tab(text: 'Quero ler'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: controller,
                children: [
                  // SUB-ABA: LENDO
                  _buildBookList(
                    readingBooks,
                    isEditable,
                    emptyMessage: 'Nenhum livro sendo lido no momento.',
                  ),

                  // SUB-ABA: LIDOS (Com agrupamento por mês/ano)
                  _buildGroupedReadList(books, isEditable),

                  // SUB-ABA: QUERO LER
                  _buildBookList(
                    wishlistBooks,
                    isEditable,
                    emptyMessage: isEditable
                        ? 'Sua lista de desejos está vazia.'
                        : 'Nenhum livro compartilhado para ler.',
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // Construtor de listagem simples para "Lendo" e "Quero Ler"
  Widget _buildBookList(
    List<BookModel> books,
    bool isEditable, {
    required String emptyMessage,
  }) {
    final theme = Theme.of(context);
    if (books.isEmpty) {
      return ContentState(
        title: emptyMessage,
        message: isEditable
            ? 'Busque um livro ou cadastre manualmente.'
            : 'Aqui aparecem somente os livros compartilhados com você.',
        actionLabel: isEditable ? 'Adicionar livro' : null,
        onAction: isEditable ? _openSearch : null,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: BookCard(
            book: book,
            onTap: () => showBookDetailsSheet(
              this.context,
              book,
              isEditable,
              bookService: _bookService,
            ),
            onDelete: isEditable
                ? () => _confirmAndDeleteBook(this.context, book)
                : null,
            trailing: isEditable && book.status == 'Lendo'
                ? IconButton(
                    icon: Icon(
                      Icons.check_circle_outline_rounded,
                      color: theme.primaryColor,
                    ),
                    tooltip: 'Marcar como Lido',
                    onPressed: _pendingCompletions.contains(book.id)
                        ? null
                        : () => _markAsRead(this.context, book),
                  )
                : isEditable && book.status == 'Quero Ler'
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.chrome_reader_mode_outlined,
                          color: theme.primaryColor,
                        ),
                        tooltip: 'Começar a ler',
                        onPressed: () =>
                            _confirmAndStartReading(this.context, book),
                      ),
                      IconButton(
                        tooltip: 'Excluir livro',
                        icon: Icon(
                          Icons.delete_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        onPressed: () =>
                            _confirmAndDeleteBook(this.context, book),
                      ),
                    ],
                  )
                : null,
          ),
        );
      },
    );
  }

  // Construtor para lista agrupada por Mês e Ano de leituras concluídas
  Widget _buildGroupedReadList(List<BookModel> books, bool isEditable) {
    final theme = Theme.of(context);
    final groupedData = _groupBooksByDate(books);
    final undatedBooks = books
        .where((book) => book.status == 'Lido' && book.finishedDate == null)
        .toList();

    if (groupedData.isEmpty && undatedBooks.isEmpty) {
      return ContentState(
        title: 'Nenhuma leitura concluída ainda.',
        message: isEditable
            ? 'Você pode registrar um livro que já leu.'
            : 'Aqui aparecem somente leituras compartilhadas com você.',
        actionLabel: isEditable ? 'Adicionar livro' : null,
        onAction: isEditable ? _openSearch : null,
      );
    }

    final List<Widget> listItems = [];

    // Navega pelos Anos e Meses ordenados
    final sortedYears = groupedData.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    for (var year in sortedYears) {
      final monthsData = groupedData[year]!;
      final sortedMonths = monthsData.keys.toList()
        ..sort((a, b) => b.compareTo(a));

      for (var month in sortedMonths) {
        final monthBooks = monthsData[month]!;

        // Cabeçalho da Seção de Data (ex: "Maio / 2026")
        listItems.add(
          Padding(
            padding: const EdgeInsets.only(
              left: 20.0,
              top: 16.0,
              bottom: 8.0,
              right: 20.0,
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  '${_getMonthName(month)} / $year',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontFamily: GoogleFonts.outfit().fontFamily,
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),
                Text(
                  '${monthBooks.length} ${monthBooks.length == 1 ? 'lido' : 'lidos'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );

        // Livros lidos naquele mês
        for (var book in monthBooks) {
          listItems.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: BookCard(
                book: book,
                onTap: () => showBookDetailsSheet(
                  context,
                  book,
                  isEditable,
                  bookService: _bookService,
                ),
                onDelete: isEditable
                    ? () => _confirmAndDeleteBook(context, book)
                    : null,
              ),
            ),
          );
        }
      }
    }

    if (undatedBooks.isNotEmpty) {
      listItems.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            'Data de conclusão não informada',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
          ),
        ),
      );
      for (final book in undatedBooks) {
        listItems.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: BookCard(
              book: book,
              onTap: () => showBookDetailsSheet(
                context,
                book,
                isEditable,
                bookService: _bookService,
              ),
              onDelete: isEditable
                  ? () => _confirmAndDeleteBook(context, book)
                  : null,
            ),
          ),
        );
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: listItems,
    );
  }
}
