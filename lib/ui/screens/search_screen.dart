import 'package:flutter/material.dart';
import '../widgets/reading_surface.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/book_service.dart';
import '../../data/models/book_model.dart';
import '../widgets/book_card.dart';
import '../widgets/custom_text_field.dart';
import '../../utils/error_handler.dart';
import '../widgets/book_details_sheet.dart';
import '../widgets/dialog_with_controllers.dart';
import '../widgets/completion_date_picker.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.bookService});

  final BookService? bookService;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  late final _bookService = widget.bookService ?? BookService();

  List<BookModel> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  int _requestRevision = 0;
  String _activeQuery = '';
  int? _nextStartIndex;
  bool _isLoadingMore = false;
  String? _searchError;
  String? _paginationError;
  int _skippedCount = 0;

  @override
  void dispose() {
    _requestRevision++;
    _searchController.dispose();
    super.dispose();
  }

  // Executa busca na Google Books API
  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    final revision = ++_requestRevision;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _activeQuery = query;
      _searchResults = [];
      _searchError = null;
      _paginationError = null;
      _nextStartIndex = null;
      _isLoadingMore = false;
      _skippedCount = 0;
    });

    try {
      final page = await _bookService.searchGoogleBooksPage(query);
      if (!mounted || revision != _requestRevision) return;
      setState(() {
        _searchResults = page.books;
        _nextStartIndex = page.nextStartIndex;
        _skippedCount = page.skippedCount;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || revision != _requestRevision) return;
      setState(() {
        _searchResults = [];
        _isLoading = false;
        _searchError = 'Não foi possível buscar livros.';
      });
      if (mounted) {
        final authService = Provider.of<AuthService>(context, listen: false);
        final uid = authService.currentUserModel?.uid ?? '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ErrorHandler.getFriendlyErrorMessage(
                e,
                operation: ErrorOperation.searchBooks,
              ),
            ),
            duration: const Duration(seconds: 7),
            backgroundColor: Theme.of(context).colorScheme.inverseSurface,
            action: SnackBarAction(
              label: 'Manual',
              textColor: Theme.of(context).colorScheme.onInverseSurface,
              onPressed: () {
                if (mounted && uid.isNotEmpty) {
                  _showManualAddDialog(context, uid);
                }
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadMore() async {
    final startIndex = _nextStartIndex;
    if (_isLoading || _isLoadingMore || startIndex == null) return;
    final revision = _requestRevision;
    final query = _activeQuery;
    setState(() {
      _isLoadingMore = true;
      _paginationError = null;
    });
    try {
      final page = await _bookService.searchGoogleBooksPage(
        query,
        startIndex: startIndex,
      );
      if (!mounted || revision != _requestRevision) return;
      final existing = _searchResults
          .map((book) => book.googleBooksId ?? book.id)
          .toSet();
      setState(() {
        _searchResults = [
          ..._searchResults,
          ...page.books.where(
            (book) => existing.add(book.googleBooksId ?? book.id),
          ),
        ];
        _nextStartIndex = page.nextStartIndex;
        _skippedCount += page.skippedCount;
      });
    } catch (error) {
      if (!mounted || revision != _requestRevision) return;
      setState(() {
        _paginationError = ErrorHandler.getFriendlyErrorMessage(
          error,
          operation: ErrorOperation.searchBooks,
        );
      });
    } finally {
      if (mounted && revision == _requestRevision) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  // Abre diálogo para escolher o status e data ao salvar o livro
  void _showAddBookDialog(BuildContext context, BookModel book, String userId) {
    String selectedStatus = 'Quero Ler';
    DateTime selectedDate = DateUtils.dateOnly(DateTime.now());
    final theme = Theme.of(context);
    final screenContext = this.context;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              scrollable: true,
              title: Text(
                'Adicionar à Estante',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // Dropdown de seleção de Status
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Status de Leitura',
                    ),
                    items: ['Quero Ler', 'Lendo', 'Lido']
                        .map(
                          (status) => DropdownMenuItem(
                            value: status,
                            child: Text(status),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedStatus = val;
                        });
                      }
                    },
                  ),

                  // Seletor de Data de Término se o status for "Lido"
                  if (selectedStatus == 'Lido') ...[
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final picked = await showCompletionDatePicker(
                          context,
                          initialDate: selectedDate,
                        );
                        if (picked != null && context.mounted) {
                          setDialogState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: theme.inputDecorationTheme.fillColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.primaryColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Concluído em: ${DateFormat('dd/MM/yyyy').format(selectedDate)}',
                              style: theme.textTheme.bodyMedium,
                            ),
                            Icon(
                              Icons.calendar_today,
                              color: theme.primaryColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!screenContext.mounted) return;
                          setDialogState(() => isSaving = true);
                          // Prepara o livro com o ID do usuário e status selecionados
                          final bookToSave = book.copyWith(
                            id: '', // Força gerar um novo ID no Firestore
                            userId: userId,
                            status: selectedStatus,
                            finishedDate: selectedStatus == 'Lido'
                                ? selectedDate
                                : null,
                            addedAt: DateTime.now(),
                          );

                          try {
                            final result = await _bookService.addCatalogBook(
                              bookToSave,
                            );
                            if (context.mounted &&
                                ModalRoute.of(context)?.isCurrent == true) {
                              Navigator.pop(context);
                            }
                            if (screenContext.mounted) {
                              ScaffoldMessenger.of(screenContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    result.created
                                        ? '"${book.title}" adicionado com sucesso!'
                                        : 'Este livro já está na sua biblioteca. Seu progresso foi preservado.',
                                  ),
                                  backgroundColor: theme.colorScheme.primary,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              setDialogState(() => isSaving = false);
                            }
                            if (screenContext.mounted) {
                              ScaffoldMessenger.of(screenContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Não foi possível salvar o livro. ${ErrorHandler.getFriendlyErrorMessage(e, operation: ErrorOperation.saveBook)}',
                                  ),
                                  backgroundColor: theme.colorScheme.error,
                                ),
                              );
                            }
                          }
                        },
                  child: Text(
                    'Salvar',
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
      },
    );
  }

  // Abre formulário para cadastro de livro manual
  void _showManualAddDialog(BuildContext context, String userId) {
    final manualId = BookService.newManualId();
    final titleController = TextEditingController();
    final authorController = TextEditingController();
    final coverController = TextEditingController();
    String selectedStatus = 'Quero Ler';
    DateTime selectedDate = DateUtils.dateOnly(DateTime.now());
    final theme = Theme.of(context);
    final formKey = GlobalKey<FormState>();
    final screenContext = this.context;
    bool isSaving = false;

    showDialogWithControllers(
      controllers: [titleController, authorController, coverController],
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              scrollable: true,
              title: Text(
                'Adicionar Manualmente',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CustomTextField(
                        controller: titleController,
                        label: 'Título do Livro',
                        hint: 'Ex: Dom Casmurro',
                        validator: (val) => val == null || val.isEmpty
                            ? 'Insira o título'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        controller: authorController,
                        label: 'Autor(es)',
                        hint: 'Ex: Machado de Assis',
                        validator: (val) => val == null || val.isEmpty
                            ? 'Insira o autor'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        controller: coverController,
                        label: 'URL da Capa (Opcional)',
                        hint: 'https://exemplo.com/capa.jpg',
                        keyboardType: TextInputType.url,
                        validator: (val) {
                          if (val != null && val.trim().isNotEmpty) {
                            final uri = Uri.tryParse(val.trim());
                            if (uri == null ||
                                !uri.hasAbsolutePath ||
                                !uri.scheme.startsWith('http')) {
                              return 'Insira uma URL válida (http/https) ou deixe vazio';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'Status de Leitura',
                        ),
                        items: ['Quero Ler', 'Lendo', 'Lido']
                            .map(
                              (status) => DropdownMenuItem(
                                value: status,
                                child: Text(status),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedStatus = val;
                            });
                          }
                        },
                      ),
                      if (selectedStatus == 'Lido') ...[
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () async {
                            final picked = await showCompletionDatePicker(
                              context,
                              initialDate: selectedDate,
                            );
                            if (picked != null && context.mounted) {
                              setDialogState(() {
                                selectedDate = picked;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: theme.inputDecorationTheme.fillColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: theme.primaryColor.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Concluído: ${DateFormat('dd/MM/yyyy').format(selectedDate)}',
                                  style: theme.textTheme.bodyMedium,
                                ),
                                Icon(
                                  Icons.calendar_today,
                                  color: theme.primaryColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!screenContext.mounted) return;
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSaving = true);

                          final bookToSave = BookModel(
                            id: manualId,
                            userId: userId,
                            title: titleController.text.trim(),
                            authors: [authorController.text.trim()],
                            coverUrl: coverController.text.trim(),
                            status: selectedStatus,
                            publishedDate: 'Manual',
                            finishedDate: selectedStatus == 'Lido'
                                ? selectedDate
                                : null,
                            addedAt: DateTime.now(),
                          );

                          try {
                            await _bookService.saveBook(bookToSave);

                            if (context.mounted &&
                                ModalRoute.of(context)?.isCurrent == true) {
                              Navigator.pop(context);
                            }
                            if (screenContext.mounted) {
                              ScaffoldMessenger.of(screenContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '"${bookToSave.title}" cadastrado com sucesso!',
                                  ),
                                  backgroundColor: theme.colorScheme.primary,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              setDialogState(() => isSaving = false);
                            }
                            if (screenContext.mounted) {
                              ScaffoldMessenger.of(screenContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Não foi possível cadastrar o livro. ${ErrorHandler.getFriendlyErrorMessage(e, operation: ErrorOperation.saveBook)}',
                                  ),
                                  backgroundColor: theme.colorScheme.error,
                                ),
                              );
                            }
                          }
                        },
                  child: Text(
                    'Cadastrar',
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUserModel;
    final theme = Theme.of(context);

    if (user == null) return const Scaffold();

    return ReadingPage(
      child: Scaffold(
        appBar: AppBar(
          title: Text('Buscar Livros'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              tooltip: 'Cadastro Manual',
              onPressed: () => _showManualAddDialog(context, user.uid),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => _showManualAddDialog(context, user.uid),
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('Cadastrar manualmente'),
                ),
              ),
            ),
            // Campo de Busca
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _searchController,
                      label: 'Pesquisar livro',
                      hint: 'Título, autor ou ISBN...',
                      prefixIcon: Icons.search_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Buscar livros',
                    icon: const Icon(Icons.search_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.all(14),
                    ),
                    onPressed: _performSearch,
                  ),
                ],
              ),
            ),

            // Área de Resultados
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _searchResults.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _hasSearched
                                  ? Icons.search_off_rounded
                                  : Icons.library_books_rounded,
                              size: 48,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _searchError ??
                                  (_hasSearched
                                      ? 'Nenhum resultado encontrado.\nTente buscar por outros termos ou adicione manualmente.'
                                      : 'Pesquise pelo título ou autor para encontrar novos livros.'),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (_searchError != null)
                              TextButton(
                                onPressed: _performSearch,
                                child: const Text('Tentar novamente'),
                              ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final book = _searchResults[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: BookCard(
                            book: book,
                            onTap: () => showBookDetailsSheet(
                              this.context,
                              book,
                              false,
                              bookService: _bookService,
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                Icons.add_box_rounded,
                                color: theme.primaryColor,
                                size: 28,
                              ),
                              tooltip: 'Adicionar à estante',
                              onPressed: () =>
                                  _showAddBookDialog(context, book, user.uid),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (_skippedCount > 0)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  'Alguns resultados não estão disponíveis.',
                  textAlign: TextAlign.center,
                ),
              ),
            if (_paginationError != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(_paginationError!, textAlign: TextAlign.center),
              ),
            if (_nextStartIndex != null || _isLoadingMore)
              Padding(
                padding: const EdgeInsets.all(8),
                child: TextButton(
                  onPressed: _isLoadingMore ? null : _loadMore,
                  child: Text(
                    _isLoadingMore
                        ? 'Carregando mais livros…'
                        : _paginationError != null
                        ? 'Tentar carregar mais'
                        : 'Carregar mais',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
