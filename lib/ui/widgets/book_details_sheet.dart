import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/models/book_model.dart';
import '../../services/book_service.dart';
import '../../utils/error_handler.dart';

class BookDetailsSheet extends StatefulWidget {
  final BookModel book;
  final bool isEditable;
  final BookService? bookService;
  final ValueChanged<SnackBar> onDeletionFeedback;

  const BookDetailsSheet({
    super.key,
    required this.book,
    required this.isEditable,
    required this.onDeletionFeedback,
    this.bookService,
  });

  @override
  State<BookDetailsSheet> createState() => _BookDetailsSheetState();
}

class _BookDetailsSheetState extends State<BookDetailsSheet> {
  late final BookService _bookService = widget.bookService ?? BookService();
  late BookModel _currentBook;
  bool _isLoading = false;
  bool _isConfirmingDelete = false;

  @override
  void initState() {
    super.initState();
    _currentBook = widget.book;
  }

  void _updateStatus(String newStatus) async {
    if (_isLoading || newStatus == _currentBook.status) return;

    DateTime? finishedDate;
    if (newStatus == 'Lido') {
      // Abre seletor de data de término
      final pickedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        helpText: 'Quando você terminou a leitura?',
      );
      if (!mounted || pickedDate == null) return; // cancelou
      finishedDate = pickedDate;
    }

    setState(() => _isLoading = true);

    final updated = _currentBook.copyWith(
      status: newStatus,
      finishedDate: finishedDate,
      addedAt: DateTime.now(), // Atualiza para subir no feed
    );

    try {
      await _bookService.saveBook(updated);
      if (!mounted) return;
      setState(() {
        _currentBook = updated;
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status atualizado para "$newStatus"!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Não foi possível atualizar o status: ${ErrorHandler.getFriendlyErrorMessage(e, operation: ErrorOperation.saveBook)}',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _confirmDelete() async {
    if (_isLoading || _isConfirmingDelete) return;
    setState(() => _isConfirmingDelete = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Excluir Livro',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
            color: Colors.redAccent,
          ),
        ),
        content: Text(
          'Tem certeza de que deseja remover "${_currentBook.title}" da sua estante?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Remover',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => _isConfirmingDelete = false);
    if (confirmed != true) {
      return;
    }
    // Captura tudo antes de fechar: o resultado pertence à tela que abriu a folha.
    final service = _bookService;
    final book = _currentBook;
    final feedback = widget.onDeletionFeedback;
    Navigator.pop(context);
    try {
      await service.deleteBook(book.id);
      feedback(
        SnackBar(
          content: Text('"${book.title}" removido com sucesso.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      feedback(
        SnackBar(
          content: Text(
            'Erro ao remover o livro: ${ErrorHandler.getFriendlyErrorMessage(e, operation: ErrorOperation.deleteBook)}',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasCover =
        _currentBook.coverUrl.isNotEmpty &&
        (_currentBook.coverUrl.startsWith('http://') ||
            _currentBook.coverUrl.startsWith('https://')) &&
        Uri.tryParse(_currentBook.coverUrl)?.hasAbsolutePath == true;

    String dateStr = DateFormat('dd/MM/yyyy').format(_currentBook.addedAt);
    String? finishedDateStr;
    if (_currentBook.status == 'Lido' && _currentBook.finishedDate != null) {
      finishedDateStr = DateFormat(
        'dd/MM/yyyy',
      ).format(_currentBook.finishedDate!);
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.only(top: 12, left: 24, right: 24, bottom: 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barra de Arrasto
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600]?.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Capa Ampliada com Drop Shadow
            Center(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 140,
                    height: 195,
                    child: hasCover
                        ? Image.network(
                            kIsWeb
                                ? 'https://wsrv.nl/?url=${Uri.encodeComponent(_currentBook.coverUrl)}'
                                : _currentBook.coverUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              ErrorHandler.report(
                                error,
                                operation: ErrorOperation.loadBookCover,
                              );
                              return _buildCoverPlaceholder(theme);
                            },
                          )
                        : _buildCoverPlaceholder(theme),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Título e Autor
            Text(
              _currentBook.title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontFamily: GoogleFonts.playfairDisplay().fontFamily,
                fontWeight: FontWeight.bold,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _currentBook.authors.join(', '),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.textTheme.titleMedium?.color?.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            // Informações do Livro
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _currentBook.userId.isEmpty
                  ? [
                      _buildInfoColumn(
                        context,
                        Icons.public_rounded,
                        'Publicado em',
                        _currentBook.publishedDate,
                      ),
                    ]
                  : [
                      _buildInfoColumn(
                        context,
                        Icons.calendar_today_rounded,
                        'Adicionado em',
                        dateStr,
                      ),
                      _buildInfoColumn(
                        context,
                        _getStatusIcon(_currentBook.status),
                        'Status',
                        _currentBook.status,
                        textColor: _getStatusColor(
                          context,
                          _currentBook.status,
                        ),
                      ),
                      if (finishedDateStr != null)
                        _buildInfoColumn(
                          context,
                          Icons.check_circle_rounded,
                          'Lido em',
                          finishedDateStr,
                          textColor: Colors.greenAccent[700],
                        ),
                    ],
            ),
            const SizedBox(height: 16),

            // Ações de Edição/Alteração de Status
            if (widget.isEditable) ...[
              const Divider(),
              const SizedBox(height: 12),
              Text(
                'Mudar Status de Leitura',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
              ),
              const SizedBox(height: 10),
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _buildStatusActionButton(
                        context,
                        'Quero Ler',
                        _currentBook.status == 'Quero Ler',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatusActionButton(
                        context,
                        'Lendo',
                        _currentBook.status == 'Lendo',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatusActionButton(
                        context,
                        'Lido',
                        _currentBook.status == 'Lido',
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent, width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                label: const Text(
                  'Excluir da Estante',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: _isLoading || _isConfirmingDelete
                    ? null
                    : _confirmDelete,
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverPlaceholder(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primaryColor.withOpacity(0.3),
            theme.colorScheme.secondary.withOpacity(0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.book_rounded, size: 48, color: Colors.grey),
      ),
    );
  }

  Widget _buildInfoColumn(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    Color? textColor,
  }) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, size: 20, color: textColor ?? theme.primaryColor),
        const SizedBox(height: 6),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusActionButton(
    BuildContext context,
    String status,
    bool isActive,
  ) {
    if (isActive) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _getStatusColor(context, status).withOpacity(0.15),
          foregroundColor: _getStatusColor(context, status),
          elevation: 0,
          side: BorderSide(color: _getStatusColor(context, status), width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: null, // Desabilita se já for o status atual
        child: Text(
          status,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
    } else {
      return OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.grey[400],
          side: BorderSide(color: Colors.grey[700] ?? Colors.grey),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: () => _updateStatus(status),
        child: Text(status),
      );
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Lido':
        return Icons.check_circle_rounded;
      case 'Lendo':
        return Icons.chrome_reader_mode_rounded;
      default:
        return Icons.bookmark_add_rounded;
    }
  }

  Color _getStatusColor(BuildContext context, String status) {
    final theme = Theme.of(context);
    switch (status) {
      case 'Lido':
        return Colors.green;
      case 'Lendo':
        return theme.primaryColor;
      default:
        return Colors.grey[500] ?? Colors.grey;
    }
  }
}

void showBookDetailsSheet(
  BuildContext context,
  BookModel book,
  bool isEditable, {
  BookService? bookService,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => BookDetailsSheet(
      book: book,
      isEditable: isEditable,
      bookService: bookService,
      onDeletionFeedback: (snackBar) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
        }
      },
    ),
  );
}
