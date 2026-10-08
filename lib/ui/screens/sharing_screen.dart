import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/bible_data.dart';
import '../../data/models/book_model.dart';
import '../../data/models/bible_progress_model.dart';
import '../../services/auth_service.dart';
import '../../services/book_service.dart';
import '../../services/bible_service.dart';
import '../widgets/reading_surface.dart';
import 'partner_blocks_screen.dart';

class SharingScreen extends StatefulWidget {
  const SharingScreen({super.key, this.bookService, this.bibleService});
  final BookService? bookService;
  final BibleService? bibleService;
  @override
  State<SharingScreen> createState() => _SharingScreenState();
}

class _SharingScreenState extends State<SharingScreen> {
  late final _books = widget.bookService ?? BookService();
  late final _bible = widget.bibleService ?? BibleService();
  String? _uid;
  Stream<List<BookModel>>? _bookStream;
  Stream<Map<String, BibleProgressModel>>? _bibleStream;
  Stream<Map<String, String>>? _blockStream;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthService>();
    final uid = auth.currentUserModel?.uid;
    if (uid != _uid) {
      _uid = uid;
      _saving = false;
      _bookStream = uid == null ? null : _books.streamUserBooks(uid);
      _bibleStream = uid == null ? null : _bible.streamAllProgress(uid);
      _blockStream = uid == null ? null : auth.watchBlocks();
    }
  }

  Future<void> _save(Future<void> Function() operation) async {
    if (_saving) return;
    final uid = _uid;
    setState(() => _saving = true);
    var message = 'Compartilhamento atualizado.';
    try {
      await operation();
    } catch (_) {
      message =
          'Não foi possível atualizar. Confira sua conexão e tente novamente.';
    }
    if (!mounted || uid != _uid) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _block(AuthService auth) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bloquear parceiro?'),
        content: const Text(
          'O vínculo será encerrado e novos convites entre vocês ficarão impedidos. Seus registros pessoais serão preservados. Desbloquear não restaura o vínculo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Bloquear'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await _save(() async {
      final error = await auth.blockPartner();
      if (error != null) throw StateError(error);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final uid = _uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Entre novamente para continuar.')),
      );
    }
    return ReadingPage(
      maxWidth: 720,
      child: Scaffold(
        appBar: AppBar(title: const Text('Compartilhamento')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Você escolhe o que seu parceiro pode consultar. Itens ocultos continuam na sua biblioteca, inclusive após um novo vínculo. O compartilhamento vale somente com o vínculo ativo.',
            ),
            const SizedBox(height: 24),
            Text('Livros', style: Theme.of(context).textTheme.titleLarge),
            StreamBuilder<List<BookModel>>(
              key: ValueKey('books/$uid'),
              stream: _bookStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text(
                    'Não foi possível carregar seus livros. Reabra esta tela para tentar novamente.',
                  );
                }
                if (!snapshot.hasData) return const LinearProgressIndicator();
                if (snapshot.data!.isEmpty) {
                  return const Text('Nenhum livro na sua estante.');
                }
                return Column(
                  children: [
                    for (final book in snapshot.data!)
                      SwitchListTile(
                        title: Text(book.title),
                        subtitle: Text(
                          book.isShared
                              ? 'Visível para o parceiro'
                              : 'Somente você',
                        ),
                        value: book.isShared,
                        onChanged: _saving
                            ? null
                            : (value) => _save(
                                () => _books.setVisibility(book.id, value),
                              ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            Text('Bíblia', style: Theme.of(context).textTheme.titleLarge),
            const Text('A escolha vale para todos os capítulos de cada livro.'),
            StreamBuilder<Map<String, BibleProgressModel>>(
              key: ValueKey('bible/$uid'),
              stream: _bibleStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text(
                    'Não foi possível carregar seu progresso. Reabra esta tela para tentar novamente.',
                  );
                }
                if (!snapshot.hasData) return const LinearProgressIndicator();
                return Column(
                  children: [
                    for (final book in BibleData.books)
                      SwitchListTile(
                        title: Text(book.name),
                        value: snapshot.data![book.name]?.isShared ?? true,
                        subtitle: Text(
                          snapshot.data![book.name]?.isShared == false
                              ? 'Somente você'
                              : 'Visível para o parceiro',
                        ),
                        onChanged: _saving
                            ? null
                            : (value) => _save(
                                () =>
                                    _bible.setVisibility(uid, book.name, value),
                              ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            Text('Bloqueios', style: Theme.of(context).textTheme.titleLarge),
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PartnerBlocksScreen(),
                ),
              ),
              icon: const Icon(Icons.people_outline),
              label: const Text('Pessoas e bloqueios'),
            ),
            if (auth.currentUserModel?.partnerUid != null)
              OutlinedButton.icon(
                onPressed: _saving || auth.isLoading
                    ? null
                    : () => _block(auth),
                icon: const Icon(Icons.block),
                label: const Text('Bloquear parceiro'),
              ),
            StreamBuilder<Map<String, String>>(
              key: ValueKey('blocks/$uid'),
              stream: _blockStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text(
                    'Não foi possível carregar bloqueios. Reabra esta tela para tentar novamente.',
                  );
                }
                if (!snapshot.hasData) return const LinearProgressIndicator();
                if (snapshot.data!.isEmpty) {
                  return const Text('Nenhuma pessoa bloqueada.');
                }
                return Column(
                  children: [
                    for (final entry in snapshot.data!.entries)
                      ListTile(
                        title: Text(entry.value),
                        trailing: TextButton(
                          onPressed: _saving
                              ? null
                              : () => _save(() async {
                                  final error = await auth.unblockPartner(
                                    entry.key,
                                  );
                                  if (error != null) throw StateError(error);
                                }),
                          child: const Text('Desbloquear'),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
