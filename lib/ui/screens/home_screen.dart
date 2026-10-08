import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/book_service.dart';
import '../../services/book_page_controller.dart';
import '../../data/models/book_model.dart';
import '../widgets/book_card.dart';
import '../widgets/reading_surface.dart';
import 'search_screen.dart';
import 'profile_screen.dart';
import '../../utils/error_handler.dart';
import '../widgets/book_details_sheet.dart';
import 'dart:convert';
import '../widgets/content_state.dart';
import 'bible_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.bookService,
    this.onOpenBible,
    this.paginated = false,
  });

  final BookService? bookService;
  final VoidCallback? onOpenBible;
  final bool paginated;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final BookService _bookService = widget.bookService ?? BookService();
  Stream<List<BookModel>>? _feed;
  String? _feedScope;
  int _retry = 0;
  BookPageController? _page;
  int _requestRevision = 0;
  bool get _usePages =>
      widget.paginated ||
      (widget.bookService == null && BookService.paginationEnabled);
  Stream<List<BookModel>> _pagedFeed(
    String uid,
    String? partner,
    String scope,
    int revision,
  ) async* {
    final start = await _bookService.feedStart(uid, partner);
    if (!mounted || _feedScope != scope || revision != _requestRevision) return;
    final page = _bookService.pagedBooks(
      uid,
      partner: partner,
      feed: true,
      since: start ?? DateTime(9999),
    );
    _page = page;
    yield* page.asStream();
  }

  @override
  void dispose() {
    _page?.dispose();
    super.dispose();
  }

  String? _cachedUserPhotoUrl;
  MemoryImage? _cachedUserAvatarImage;
  String? _cachedPartnerPhotoUrl;
  MemoryImage? _cachedPartnerAvatarImage;

  ImageProvider? _getAvatarImage(String? photoUrl, bool isPartner) {
    if (photoUrl == null || photoUrl.isEmpty) return null;
    if (photoUrl.startsWith('data:image/')) {
      if (isPartner) {
        if (_cachedPartnerPhotoUrl == photoUrl &&
            _cachedPartnerAvatarImage != null) {
          return _cachedPartnerAvatarImage;
        }
        _cachedPartnerPhotoUrl = photoUrl;
        final base64String = photoUrl.split(',').last;
        _cachedPartnerAvatarImage = MemoryImage(base64Decode(base64String));
        return _cachedPartnerAvatarImage;
      } else {
        if (_cachedUserPhotoUrl == photoUrl && _cachedUserAvatarImage != null) {
          return _cachedUserAvatarImage;
        }
        _cachedUserPhotoUrl = photoUrl;
        final base64String = photoUrl.split(',').last;
        _cachedUserAvatarImage = MemoryImage(base64Decode(base64String));
        return _cachedUserAvatarImage;
      }
    }
    return NetworkImage(photoUrl);
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUserModel;
    final partner = authService.partnerUserModel;
    if (partner == null || !partner.isAvailable) {
      _cachedPartnerPhotoUrl = null;
      _cachedPartnerAvatarImage = null;
    }
    final theme = Theme.of(context);

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final bookService = _bookService;
    final scope = '${user.uid}/${user.partnerUid}/${user.relationshipId}';
    if (_feedScope != scope) {
      _page?.dispose();
      _page = null;
      _feedScope = scope;
      _feed = _usePages
          ? _pagedFeed(user.uid, user.partnerUid, scope, ++_requestRevision)
          : bookService.streamCoupleFeed(user.uid, user.partnerUid);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Início')),
      body: StreamBuilder<List<BookModel>>(
        key: ValueKey('$scope/$_retry'),
        stream: _feed,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ContentState(
              title: 'Não foi possível carregar suas leituras',
              message: ErrorHandler.getFriendlyErrorMessage(
                snapshot.error,
                operation: ErrorOperation.loadFeed,
              ),
              icon: Icons.cloud_off_outlined,
              actionLabel: 'Tentar novamente',
              onAction: () => setState(() {
                _feedScope = null;
                _retry++;
              }),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting ||
              (_usePages && _page?.busy == true && _page!.items.isEmpty)) {
            return const ContentState(
              title: 'Carregando suas leituras',
              loading: true,
            );
          }

          final books = snapshot.data ?? [];
          final activities = books.where((b) => b.feedVisible).toList();

          // Estatísticas do mês e ano atual
          final now = DateTime.now();
          final months = [
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
          final currentMonthName = months[now.month - 1];

          // Mês atual
          final userReadThisMonth = _usePages
              ? _page!.counts['${user.uid}/month'] ?? 0
              : books
                    .where(
                      (b) =>
                          b.userId == user.uid &&
                          b.status == 'Lido' &&
                          b.finishedDate != null &&
                          b.finishedDate!.month == now.month &&
                          b.finishedDate!.year == now.year,
                    )
                    .length;

          final partnerReadThisMonth = _usePages
              ? _page!.counts['${user.partnerUid}/month'] ?? 0
              : books
                    .where(
                      (b) =>
                          partner != null &&
                          b.userId == partner.uid &&
                          b.status == 'Lido' &&
                          b.finishedDate != null &&
                          b.finishedDate!.month == now.month &&
                          b.finishedDate!.year == now.year,
                    )
                    .length;

          // Ano atual
          final userReadThisYear = _usePages
              ? _page!.counts['${user.uid}/year'] ?? 0
              : books
                    .where(
                      (b) =>
                          b.userId == user.uid &&
                          b.status == 'Lido' &&
                          b.finishedDate != null &&
                          b.finishedDate!.year == now.year,
                    )
                    .length;

          final partnerReadThisYear = _usePages
              ? _page!.counts['${user.partnerUid}/year'] ?? 0
              : books
                    .where(
                      (b) =>
                          partner != null &&
                          b.userId == partner.uid &&
                          b.status == 'Lido' &&
                          b.finishedDate != null &&
                          b.finishedDate!.year == now.year,
                    )
                    .length;

          return CustomScrollView(
            slivers: [
              if (_usePages)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Wrap(
                      spacing: 12,
                      children: [
                        TextButton(
                          onPressed: _page!.busy ? null : () => _page!.start(),
                          child: const Text('Atualizar atividades'),
                        ),
                        if (_page!.hasMore)
                          TextButton(
                            onPressed: _page!.busy
                                ? null
                                : () => _page!.loadMore(),
                            child: Text(
                              _page!.busy
                                  ? 'Carregando…'
                                  : 'Carregar mais atividades',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Olá, ${user.name.split(' ').first}.',
                        style: theme.textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Acompanhe suas leituras e as de quem lê com você.',
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 24),
                      ReadingSurface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              partner == null
                                  ? 'Suas leituras em $currentMonthName'
                                  : 'Nossas leituras em $currentMonthName',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 20),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final mine = _readingSummary(
                                  context,
                                  name: 'Você',
                                  photo: _getAvatarImage(user.photoUrl, false),
                                  month: userReadThisMonth,
                                  year: userReadThisYear,
                                  currentYear: now.year,
                                );
                                final theirs = partner == null
                                    ? null
                                    : _readingSummary(
                                        context,
                                        name: partner.name,
                                        photo: _getAvatarImage(
                                          partner.photoUrl,
                                          true,
                                        ),
                                        month: partnerReadThisMonth,
                                        year: partnerReadThisYear,
                                        currentYear: now.year,
                                      );
                                if (theirs == null) return mine;
                                if (constraints.maxWidth < 450 ||
                                    MediaQuery.textScalerOf(context).scale(14) >
                                        21) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      mine,
                                      const SizedBox(height: 16),
                                      theirs,
                                    ],
                                  );
                                }
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: mine),
                                    const SizedBox(width: 24),
                                    Expanded(child: theirs),
                                  ],
                                );
                              },
                            ),
                            if (partner == null) ...[
                              const SizedBox(height: 20),
                              Text(
                                'Você também pode acompanhar as leituras do seu parceiro.',
                                style: theme.textTheme.bodyMedium,
                              ),
                              TextButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ReadingPage(
                                      maxWidth: 720,
                                      child: ProfileScreen(),
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.favorite_border_rounded),
                                label: const Text('Vincular parceiro'),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SearchScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Adicionar livro'),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            widget.onOpenBible ??
                            () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const BibleScreen(),
                              ),
                            ),
                        icon: const Icon(Icons.menu_book_outlined),
                        label: const Text('Acompanhar Bíblia'),
                      ),
                    ],
                  ),
                ),
              ),

              // Título da Seção do Feed
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 20.0,
                    top: 16.0,
                    bottom: 8.0,
                  ),
                  child: Text(
                    partner == null
                        ? 'Suas atividades recentes'
                        : 'Atividades do casal',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontFamily: GoogleFonts.outfit().fontFamily,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),

              // Lista de Atividades do Feed
              if (activities.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.library_books_outlined,
                            size: 48,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Nenhuma leitura registrada ainda.\nAdicione livros na Biblioteca para começar!',
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
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final book = activities[index];
                    final isMe = book.userId == user.uid;
                    final authorName = isMe
                        ? 'Você'
                        : (partner?.name ?? 'Parceiro');

                    // Determina o texto de ação com base no status do livro
                    String actionText = '';
                    IconData actionIcon;
                    Color actionColor;

                    switch (book.activityStatus) {
                      case 'Lido':
                        actionText = 'concluiu a leitura de';
                        actionIcon = Icons.check_circle_rounded;
                        actionColor = theme.primaryColor;
                        break;
                      case 'Lendo':
                        actionText = 'começou a ler';
                        actionIcon = Icons.chrome_reader_mode_rounded;
                        actionColor = theme.primaryColor;
                        break;
                      default:
                        actionText = 'quer ler';
                        actionIcon = Icons.bookmark_add_rounded;
                        actionColor = theme.colorScheme.onSurfaceVariant;
                    }
                    if (book.activityAction == 'added') {
                      actionText = 'adicionou à biblioteca';
                      actionIcon = Icons.library_add_outlined;
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 4.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Linha do feed indicando a ação
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 8.0,
                              bottom: 4.0,
                              top: 4.0,
                            ),
                            child: Row(
                              children: [
                                Icon(actionIcon, size: 16, color: actionColor),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(fontSize: 13),
                                      children: [
                                        TextSpan(
                                          text: authorName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        TextSpan(text: ' $actionText '),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Card do Livro do Feed
                          BookCard(
                            book: book,
                            onTap: () =>
                                showBookDetailsSheet(context, book, isMe),
                          ),
                          const Divider(
                            height: 16,
                            thickness: 0.5,
                            indent: 8,
                            endIndent: 8,
                          ),
                        ],
                      ),
                    );
                  }, childCount: activities.length),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _readingSummary(
    BuildContext context, {
    required String name,
    required ImageProvider? photo,
    required int month,
    required int year,
    required int currentYear,
  }) {
    final theme = Theme.of(context);
    final identity = Row(
      children: [
        CircleAvatar(
          backgroundColor: theme.primaryColor.withValues(alpha: .15),
          backgroundImage: photo,
          child: photo == null
              ? Text(name.isEmpty ? '?' : name.substring(0, 1).toUpperCase())
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(name, style: theme.textTheme.titleMedium)),
      ],
    );
    final monthly = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$month ${month == 1 ? 'livro lido' : 'livros lidos'}',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: theme.primaryColor,
          ),
        ),
        Text('no mês', style: theme.textTheme.bodyMedium),
      ],
    );
    final annual = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$year ${year == 1 ? 'livro lido' : 'livros lidos'}',
          style: theme.textTheme.titleMedium,
        ),
        Text('no ano de $currentYear', style: theme.textTheme.bodyMedium),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 600 &&
            MediaQuery.textScalerOf(context).scale(14) <= 21) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: identity),
              const SizedBox(width: 24),
              Expanded(child: monthly),
              const SizedBox(width: 24),
              Expanded(child: annual),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            identity,
            const SizedBox(height: 16),
            monthly,
            const SizedBox(height: 12),
            annual,
          ],
        );
      },
    );
  }
}
