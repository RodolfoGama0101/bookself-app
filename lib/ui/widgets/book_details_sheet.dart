import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import 'book_cover.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/models/book_model.dart';
import '../../services/book_service.dart';
import '../../utils/error_handler.dart';
import 'completion_date_picker.dart';
import 'dialog_with_controllers.dart';
import 'content_state.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  bool _isPickingDate = false;
  bool _isConfirmingDelete = false;
  bool _isEditingMetadata = false;
  bool get _isBusy =>
      _isLoading || _isPickingDate || _isConfirmingDelete || _isEditingMetadata;

  Future<void> _editMetadata() async {
    if (_isBusy) return;
    setState(() => _isEditingMetadata = true);
    final title = TextEditingController(text: _currentBook.title);
    final authors = TextEditingController(
      text: _currentBook.authors.join('; '),
    );
    final cover = TextEditingController(text: _currentBook.coverUrl);
    final form = GlobalKey<FormState>();
    bool saving = false;
    String? failure;
    BookModel? confirmed;
    await showDialogWithControllers<void>(
      context: context,
      controllers: [title, authors, cover],
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, update) => AlertDialog(
          scrollable: true,
          title: const Text('Editar livro manual'),
          content: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: title,
                  enabled: !saving,
                  maxLength: 500,
                  decoration: const InputDecoration(labelText: 'Título'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Informe o título.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: authors,
                  enabled: !saving,
                  decoration: const InputDecoration(
                    labelText: 'Autores',
                    helperText: 'Separe os autores por ponto e vírgula.',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: cover,
                  enabled: !saving,
                  decoration: const InputDecoration(
                    labelText: 'URL da capa (opcional)',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    final uri = Uri.tryParse(value.trim());
                    return uri?.scheme == 'https' && uri!.host.isNotEmpty
                        ? null
                        : 'Use um endereço HTTPS válido.';
                  },
                ),
                if (failure != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(failure!),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      update(() {
                        saving = true;
                        failure = null;
                      });
                      try {
                        final value = await _bookService.updateManualMetadata(
                          _currentBook,
                          title: title.text,
                          authors: authors.text
                              .split(';')
                              .map((author) => author.trim())
                              .where((author) => author.isNotEmpty)
                              .toList(),
                          coverUrl: cover.text.trim(),
                        );
                        confirmed = value;
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } catch (error) {
                        if (dialogContext.mounted) {
                          update(() {
                            saving = false;
                            failure = ErrorHandler.getFriendlyErrorMessage(
                              error,
                              operation: ErrorOperation.saveBook,
                            );
                          });
                        }
                      }
                    },
              child: Text(saving ? 'Salvando…' : 'Salvar'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _isEditingMetadata = false;
      if (confirmed != null) _currentBook = confirmed!;
    });
    if (confirmed != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Livro atualizado.')));
    }
  }

  void _showHistory() => showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Histórico de status'),
      content: SizedBox(
        width: 480,
        height: 300,
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _bookService.streamBookActivity(_currentBook.id),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ContentState(
                title: 'Histórico indisponível',
                message: ErrorHandler.getFriendlyErrorMessage(
                  snapshot.error,
                  operation: ErrorOperation.loadLibrary,
                ),
              );
            }
            if (!snapshot.hasData) {
              return const ContentState(
                title: 'Carregando histórico',
                loading: true,
              );
            }
            if (snapshot.data!.isEmpty) {
              return const ContentState(
                title: 'Nenhuma atividade registrada',
                message: 'Novas mudanças de status aparecerão aqui.',
              );
            }
            return ListView(
              children: [
                const Text(
                  'Até 100 atividades mais recentes. Datas de conclusão são informadas separadamente.',
                ),
                ...snapshot.data!.map(
                  (event) => ListTile(
                    title: Text(
                      event['action'] == 'added'
                          ? 'Adicionado · ${event['status']}'
                          : '${event['beforeStatus']} → ${event['status']}',
                    ),
                    subtitle: Text(
                      event['occurredAt'] is Timestamp
                          ? DateFormat('dd/MM/yyyy HH:mm').format(
                              (event['occurredAt'] as Timestamp).toDate(),
                            )
                          : 'Aguardando confirmação',
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
      ],
    ),
  );

  @override
  void initState() {
    super.initState();
    _currentBook = widget.book;
  }

  void _updateStatus(String newStatus) async {
    if (_isBusy || newStatus == _currentBook.status) {
      return;
    }

    DateTime? finishedDate;
    if (newStatus == 'Lido') {
      setState(() => _isPickingDate = true);
      final pickedDate = await showCompletionDatePicker(context);
      if (!mounted) return;
      setState(() => _isPickingDate = false);
      if (pickedDate == null) {
        return;
      }
      finishedDate = pickedDate;
    }
    setState(() => _isLoading = true);

    final updated = _currentBook.copyWith(
      status: newStatus,
      finishedDate: finishedDate,
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
            backgroundColor: Theme.of(context).colorScheme.primary,
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
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _editFinishedDate() async {
    if (_isBusy) return;
    setState(() => _isPickingDate = true);
    final pickedDate = await showCompletionDatePicker(
      context,
      initialDate: _currentBook.finishedDate,
    );
    if (!mounted) return;
    setState(() => _isPickingDate = false);
    if (pickedDate == null ||
        DateUtils.isSameDay(pickedDate, _currentBook.finishedDate)) {
      return;
    }
    setState(() => _isLoading = true);
    // Corrigir a data não altera o status nem cria nova atividade no feed.
    final updated = _currentBook.copyWith(finishedDate: pickedDate);
    try {
      await _bookService.saveBook(updated);
      if (!mounted) return;
      setState(() {
        _currentBook = updated;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Data de conclusão atualizada!'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível atualizar a data: ${ErrorHandler.getFriendlyErrorMessage(error, operation: ErrorOperation.saveBook)}',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _confirmDelete() async {
    if (_isBusy) return;
    setState(() => _isConfirmingDelete = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Excluir Livro',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.error,
          ),
        ),
        content: Text(
          'Tem certeza de que deseja remover "${_currentBook.title}" da sua estante?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Remover',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
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
    final scheme = Theme.of(context).colorScheme;
    Navigator.pop(context);
    try {
      await service.deleteBook(book.id);
      feedback(
        SnackBar(
          content: Text('"${book.title}" removido com sucesso.'),
          backgroundColor: scheme.primary,
        ),
      );
    } catch (e) {
      feedback(
        SnackBar(
          content: Text(
            'Erro ao remover o livro: ${ErrorHandler.getFriendlyErrorMessage(e, operation: ErrorOperation.deleteBook)}',
          ),
          backgroundColor: scheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
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
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.5),
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
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.12,
                      ),
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
                    child: BookCover(
                      url: _currentBook.coverUrl,
                      placeholderBuilder: (_) => _buildCoverPlaceholder(theme),
                    ),
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
                fontFamily: GoogleFonts.outfit().fontFamily,
                fontWeight: FontWeight.bold,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _currentBook.authors.join(', '),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.textTheme.titleMedium?.color?.withValues(
                  alpha: 0.7,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            // Informações do Livro
            Wrap(
              alignment: WrapAlignment.spaceAround,
              spacing: 16,
              runSpacing: 12,
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
                      if (_currentBook.status == 'Lido')
                        _buildInfoColumn(
                          context,
                          Icons.check_circle_rounded,
                          'Lido em',
                          finishedDateStr ?? 'Data não informada',
                          textColor: Theme.of(context).colorScheme.primary,
                        ),
                    ],
            ),
            const SizedBox(height: 16),

            // Ações de Edição/Alteração de Status
            if (widget.isEditable) ...[
              if (_currentBook.googleBooksId == null &&
                  _currentBook.publishedDate == 'Manual')
                OutlinedButton.icon(
                  onPressed: _isBusy ? null : _editMetadata,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar livro manual'),
                ),
              OutlinedButton.icon(
                onPressed: _isBusy ? null : _showHistory,
                icon: const Icon(Icons.history),
                label: const Text('Histórico de status'),
              ),
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
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildStatusActionButton(
                      context,
                      'Quero Ler',
                      _currentBook.status == 'Quero Ler',
                    ),
                    _buildStatusActionButton(
                      context,
                      'Lendo',
                      _currentBook.status == 'Lendo',
                    ),
                    _buildStatusActionButton(
                      context,
                      'Lido',
                      _currentBook.status == 'Lido',
                    ),
                  ],
                ),
              if (_currentBook.status == 'Lido') ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isBusy ? null : _editFinishedDate,
                  icon: const Icon(Icons.edit_calendar_rounded),
                  label: Text(
                    _currentBook.finishedDate == null
                        ? 'Informar data de conclusão'
                        : 'Editar data de conclusão',
                  ),
                ),
              ],
              const SizedBox(height: 20),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.error,
                    width: 1.2,
                  ),
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
                onPressed: _isBusy ? null : _confirmDelete,
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
            theme.primaryColor.withValues(alpha: 0.3),
            theme.colorScheme.secondary.withValues(alpha: 0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.book_rounded,
          size: 48,
          color: theme.colorScheme.primary,
        ),
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
          style: theme.textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
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
          backgroundColor: _getStatusColor(
            context,
            status,
          ).withValues(alpha: 0.15),
          foregroundColor: _getStatusColor(context, status),
          disabledForegroundColor: _getStatusColor(context, status),
          disabledBackgroundColor: _getStatusColor(
            context,
            status,
          ).withValues(alpha: .15),
          elevation: 0,
          side: BorderSide(color: _getStatusColor(context, status), width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
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
          foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
          side: BorderSide(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: _isBusy ? null : () => _updateStatus(status),
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
        return Theme.of(context).colorScheme.primary;
      case 'Lendo':
        return theme.primaryColor;
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
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
    builder: (sheetContext) => _SharedDetailsGuard(
      book: book,
      editable: isEditable,
      service: bookService ?? BookService(),
      child: BookDetailsSheet(
        book: book,
        isEditable: isEditable,
        bookService: bookService,
        onDeletionFeedback: (snackBar) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(snackBar);
          }
        },
      ),
    ),
  );
}

class _SharedDetailsGuard extends StatelessWidget {
  const _SharedDetailsGuard({
    required this.book,
    required this.editable,
    required this.service,
    required this.child,
  });
  final BookModel book;
  final bool editable;
  final BookService service;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (editable) return child;
    final auth = context.watch<AuthService?>();
    final profile = auth?.currentUserModel;
    const unavailable = SafeArea(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('Este livro não está disponível para consulta.'),
      ),
    );
    if (auth != null && profile?.partnerUid != book.userId) return unavailable;
    return StreamBuilder<BookModel?>(
      key: ValueKey(profile?.relationshipId),
      stream: service.watchSharedBook(book.id),
      builder: (context, snapshot) =>
          snapshot.hasError || snapshot.data == null ? unavailable : child,
    );
  }
}
