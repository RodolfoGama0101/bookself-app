import 'dart:async';

import 'package:flutter/material.dart';
import '../widgets/reading_surface.dart';
import 'package:provider/provider.dart';
import '../../data/bible_data.dart';
import '../../services/auth_service.dart';
import '../../services/bible_service.dart';
import '../../data/models/bible_progress_model.dart';
import '../../utils/error_handler.dart';

class BibleScreen extends StatefulWidget {
  const BibleScreen({super.key, this.bibleService});

  final BibleService? bibleService;

  @override
  State<BibleScreen> createState() => _BibleScreenState();
}

class _BibleScreenState extends State<BibleScreen>
    with TickerProviderStateMixin {
  late TabController _testamentTabController;
  late final BibleService _bibleService = widget.bibleService ?? BibleService();

  @override
  void initState() {
    super.initState();
    _testamentTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _testamentTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUserModel;
    final partner = authService.partnerUserModel;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Filtra livros do Antigo e Novo Testamento
    final otBooks = BibleData.books.where((b) => !b.isNewTestament).toList();
    final ntBooks = BibleData.books.where((b) => b.isNewTestament).toList();

    return ReadingPage(
      child: Scaffold(
        appBar: AppBar(
          title: Text('Progresso da Bíblia'),
          bottom: TabBar(
            controller: _testamentTabController,
            tabs: const [
              Tab(text: 'Antigo Testamento'),
              Tab(text: 'Novo Testamento'),
            ],
          ),
        ),
        body: StreamBuilder<Map<String, BibleProgressModel>>(
          stream: _bibleService.streamAllProgress(user.uid),
          builder: (context, userProgressSnapshot) {
            if (userProgressSnapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: SelectableText(
                    'Erro ao carregar progresso da Bíblia: ${ErrorHandler.getFriendlyErrorMessage(userProgressSnapshot.error, operation: ErrorOperation.loadBibleProgress)}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              );
            }

            final userProgress = userProgressSnapshot.data ?? {};

            return StreamBuilder<Map<String, BibleProgressModel>>(
              stream: partner != null
                  ? _bibleService.streamAllProgress(partner.uid)
                  : Stream.value({}),
              builder: (context, partnerProgressSnapshot) {
                if (partnerProgressSnapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: SelectableText(
                        'Erro ao carregar progresso da Bíblia do parceiro: ${ErrorHandler.getFriendlyErrorMessage(partnerProgressSnapshot.error, operation: ErrorOperation.loadPartnerBibleProgress)}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  );
                }

                final partnerProgress = partnerProgressSnapshot.data ?? {};

                return TabBarView(
                  controller: _testamentTabController,
                  children: [
                    _buildBookList(
                      otBooks,
                      user.uid,
                      partner?.uid,
                      userProgress,
                      partnerProgress,
                      partner?.name,
                    ),
                    _buildBookList(
                      ntBooks,
                      user.uid,
                      partner?.uid,
                      userProgress,
                      partnerProgress,
                      partner?.name,
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildBookList(
    List<BibleBook> books,
    String userId,
    String? partnerId,
    Map<String, BibleProgressModel> userProgress,
    Map<String, BibleProgressModel> partnerProgress,
    String? partnerName,
  ) {
    final theme = Theme.of(context);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];

        // Calcula o progresso do Usuário Atual
        final uProg = userProgress[book.name];
        final uReadCount = uProg?.readChapters.length ?? 0;
        final uPercent = book.chapters > 0 ? uReadCount / book.chapters : 0.0;

        // Calcula o progresso do Parceiro
        final pProg = partnerProgress[book.name];
        final pReadCount = pProg?.readChapters.length ?? 0;
        final pPercent = book.chapters > 0 ? pReadCount / book.chapters : 0.0;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BibleBookChaptersScreen(
                    book: book,
                    bibleService: _bibleService,
                    userId: userId,
                    partnerId: partnerId,
                    partnerName: partnerName,
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nome do Livro e número de capítulos
                  _progressLabels(
                    book.name,
                    '${book.chapters} cap.',
                    theme.textTheme.titleMedium,
                    theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),

                  // Barra de Progresso - Usuário Atual
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _progressLabels(
                        'Você',
                        '${(uPercent * 100).toInt()}% ($uReadCount/${book.chapters})',
                        theme.textTheme.bodySmall,
                        theme.textTheme.labelMedium,
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: uPercent,
                          backgroundColor: theme.primaryColor.withValues(
                            alpha: 0.15,
                          ),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.primaryColor,
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),

                  // Barra de Progresso - Parceiro (se houver parceiro vinculado)
                  if (partnerId != null) ...[
                    const SizedBox(height: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _progressLabels(
                          partnerName ?? 'Parceiro',
                          '${(pPercent * 100).toInt()}% ($pReadCount/${book.chapters})',
                          theme.textTheme.bodySmall,
                          theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pPercent,
                            backgroundColor: theme.colorScheme.secondary
                                .withValues(alpha: 0.15),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              theme.colorScheme.secondary,
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _progressLabels(
    String label,
    String value,
    TextStyle? labelStyle,
    TextStyle? valueStyle,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: labelStyle)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(value, textAlign: TextAlign.right, style: valueStyle),
        ),
      ],
    );
  }
}

// TELA DETALHADA DOS CAPÍTULOS DE UM LIVRO BÍBLICO
class BibleBookChaptersScreen extends StatefulWidget {
  final BibleBook book;
  final String userId;
  final String? partnerId;
  final String? partnerName;
  final BibleService? bibleService;

  const BibleBookChaptersScreen({
    super.key,
    required this.book,
    required this.userId,
    this.partnerId,
    this.partnerName,
    this.bibleService,
  });

  @override
  State<BibleBookChaptersScreen> createState() =>
      _BibleBookChaptersScreenState();
}

class _BibleBookChaptersScreenState extends State<BibleBookChaptersScreen> {
  late BibleService _service;
  StreamSubscription<BibleProgressModel?>? _userSubscription;
  StreamSubscription<BibleProgressModel?>? _partnerSubscription;
  List<int> _readChapters = [];
  List<int> _partnerReadChapters = [];
  bool _isLoading = true;
  bool _isSaving = false;
  int? _savingChapter;
  String? _readError;
  String? _partnerError;
  String? _writeError;
  VoidCallback? _retryWrite;
  int _revision = 0;
  int _partnerRevision = 0;

  @override
  void initState() {
    super.initState();
    _bindProgress();
  }

  @override
  void didUpdateWidget(covariant BibleBookChaptersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.book.name != widget.book.name ||
        oldWidget.bibleService != widget.bibleService) {
      _bindProgress();
    } else if (oldWidget.partnerId != widget.partnerId) {
      _bindPartnerProgress();
    }
  }

  void _bindProgress() {
    final revision = ++_revision;
    _userSubscription?.cancel();
    _service = widget.bibleService ?? BibleService();
    _readChapters = [];
    _partnerReadChapters = [];
    _isLoading = true;
    _isSaving = false;
    _savingChapter = null;
    _readError = _partnerError = _writeError = null;
    _retryWrite = null;
    _userSubscription = _service
        .streamBookProgress(widget.userId, widget.book.name)
        .listen(
          (progress) {
            if (!mounted || revision != _revision) return;
            setState(() {
              _readChapters = List.of(progress?.readChapters ?? []);
              _isLoading = false;
              _readError = null;
            });
          },
          onError: (Object error) {
            if (!mounted || revision != _revision) return;
            setState(() {
              _isLoading = false;
              _readError = ErrorHandler.getFriendlyErrorMessage(
                error,
                operation: ErrorOperation.loadBibleProgress,
              );
            });
          },
        );
    _bindPartnerProgress();
  }

  void _bindPartnerProgress() {
    final revision = _revision;
    final partnerRevision = ++_partnerRevision;
    _partnerSubscription?.cancel();
    _partnerReadChapters = [];
    _partnerError = null;
    if (widget.partnerId != null) {
      _partnerSubscription = _service
          .streamBookProgress(widget.partnerId!, widget.book.name)
          .listen(
            (progress) {
              if (!mounted ||
                  revision != _revision ||
                  partnerRevision != _partnerRevision) {
                return;
              }
              setState(() {
                _partnerReadChapters = List.of(progress?.readChapters ?? []);
                _partnerError = null;
              });
            },
            onError: (Object error) {
              if (!mounted ||
                  revision != _revision ||
                  partnerRevision != _partnerRevision) {
                return;
              }
              setState(
                () => _partnerError = ErrorHandler.getFriendlyErrorMessage(
                  error,
                  operation: ErrorOperation.loadPartnerBibleProgress,
                ),
              );
            },
          );
    }
  }

  Future<void> _saveProgress(int? chapter, bool isRead) async {
    if (!mounted || _isLoading || _readError != null || _isSaving) return;
    if (_writeError != null) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
    final revision = _revision;
    final book = widget.book;
    final userId = widget.userId;
    setState(() {
      _isSaving = true;
      _savingChapter = chapter;
      _writeError = null;
      _retryWrite = null;
    });
    try {
      final confirmed = chapter == null
          ? await _service.markAllChapters(
              userId,
              book.name,
              book.chapters,
              isRead,
            )
          : await _service.toggleChapter(userId, book.name, chapter, isRead);
      if (!mounted || revision != _revision) return;
      // Usa a resposta confirmada mesmo se o stream ainda estiver atrasado.
      setState(() => _readChapters = List.of(confirmed));
      final message = chapter == null
          ? (isRead
                ? 'Todos os capítulos de ${book.name} marcados como lidos!'
                : 'Todos os capítulos de ${book.name} desmarcados.')
          : 'Capítulo $chapter de ${book.name} ${isRead ? 'marcado como lido' : 'desmarcado'}.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
    } catch (error) {
      if (!mounted || revision != _revision) return;
      void retry() {
        if (mounted && revision == _revision) {
          _saveProgress(chapter, isRead);
        }
      }

      setState(() {
        _writeError =
            'Não foi possível salvar seu progresso. ${ErrorHandler.getFriendlyErrorMessage(error, operation: ErrorOperation.saveBibleProgress)}';
        _retryWrite = retry;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível salvar o progresso de ${book.name}.'),
          backgroundColor: Theme.of(context).colorScheme.error,
          action: SnackBarAction(label: 'Repetir', onPressed: retry),
        ),
      );
    } finally {
      if (mounted && revision == _revision) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    _partnerSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ReadingPage(
      child: Scaffold(
        appBar: AppBar(title: Text(widget.book.name)),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _readError != null
            ? Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Não foi possível carregar seu progresso. $_readError',
                          textAlign: TextAlign.center,
                        ),
                        TextButton(
                          onPressed: _isSaving
                              ? null
                              : () => setState(_bindProgress),
                          child: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : _buildChapters(theme),
      ),
    );
  }

  Widget _buildChapters(ThemeData theme) {
    final userProgress = _readChapters;
    final partnerProgress = _partnerReadChapters;
    final isAllRead = userProgress.length == widget.book.chapters;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: theme.cardTheme.color?.withValues(alpha: 0.4),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 8,
              children: [
                Text(
                  'Capítulos lidos: ${userProgress.length} / ${widget.book.chapters}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  icon: Icon(
                    isAllRead
                        ? Icons.bookmark_remove_rounded
                        : Icons.bookmark_added_rounded,
                    size: 18,
                  ),
                  label: Text(isAllRead ? 'Desmarcar todos' : 'Marcar todos'),
                  onPressed: _isSaving
                      ? null
                      : () => _saveProgress(null, !isAllRead),
                ),
              ],
            ),
          ),
        ),
        if (_isSaving)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Expanded(child: Text('Salvando progresso…')),
                ],
              ),
            ),
          ),
        if (_writeError != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _writeError!,
                    key: const ValueKey('bible-write-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  TextButton(
                    onPressed: _isSaving ? null : _retryWrite,
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          ),
        if (_partnerError != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Não foi possível carregar o progresso do parceiro. $_partnerError',
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final chapterNum = index + 1;
              final isReadByMe = userProgress.contains(chapterNum);
              final isReadByPartner = partnerProgress.contains(chapterNum);

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  key: ValueKey('bible-chapter-$chapterNum'),
                  onTap: _isSaving
                      ? null
                      : () => _saveProgress(chapterNum, !isReadByMe),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isReadByMe
                          ? theme.primaryColor.withValues(alpha: 0.2)
                          : theme.inputDecorationTheme.fillColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isReadByMe
                            ? theme.primaryColor
                            : theme.primaryColor.withValues(alpha: 0.15),
                        width: isReadByMe ? 1.5 : 1,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Número do Capítulo
                        if (_isSaving && _savingChapter == chapterNum)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Text(
                            '$chapterNum',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isReadByMe
                                  ? theme.primaryColor
                                  : theme.textTheme.bodyMedium?.color,
                            ),
                          ),

                        // Indicador de Leitura do Parceiro (Pequeno coração/círculo no canto)
                        if (isReadByPartner)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Icon(
                              Icons.favorite_rounded,
                              size: 10,
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }, childCount: widget.book.chapters),
          ),
        ),
        if (widget.partnerId != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                runSpacing: 8,
                children: [
                  Icon(Icons.crop_square_rounded, color: theme.primaryColor),
                  const SizedBox(width: 4),
                  Text('Lido por você', style: theme.textTheme.bodySmall),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.favorite_rounded,
                    color: theme.colorScheme.secondary,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Lido por ${widget.partnerName ?? 'Amor'}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
