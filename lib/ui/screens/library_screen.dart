import 'package:flutter/material.dart';

import '../../services/bible_service.dart';
import '../../services/book_service.dart';
import 'bible_screen.dart';
import 'bookshelf_screen.dart';

/// Bíblia e livros conservam estado enquanto a pessoa troca de destino.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({
    super.key,
    required this.showBible,
    this.bookService,
    this.bibleService,
    this.onOpenBible,
    this.onCloseBible,
  });
  final ValueNotifier<bool> showBible;
  final BookService? bookService;
  final BibleService? bibleService;
  final VoidCallback? onOpenBible;
  final VoidCallback? onCloseBible;

  void _closeBible() => (onCloseBible ?? () => showBible.value = false)();

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: showBible,
    builder: (context, bible, _) => IndexedStack(
      index: bible ? 1 : 0,
      children: [
        BookshelfScreen(
          scope: BookshelfScope.personal,
          bookService: bookService,
          onOpenBible: onOpenBible ?? () => showBible.value = true,
        ),
        BibleScreen(bibleService: bibleService, onClose: _closeBible),
      ],
    ),
  );
}
