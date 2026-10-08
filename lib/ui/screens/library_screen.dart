import 'package:flutter/material.dart';

import '../../services/bible_service.dart';
import '../../services/book_service.dart';
import 'bible_screen.dart';
import 'bookshelf_screen.dart';
import '../../services/movie_library_service.dart';
import 'movie_library_screen.dart';

/// Bíblia e livros conservam estado enquanto a pessoa troca de destino.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.showBible,
    this.bookService,
    this.bibleService,
    this.onOpenBible,
    this.onCloseBible,
    this.movieService,
  });
  final ValueNotifier<bool> showBible;
  final BookService? bookService;
  final BibleService? bibleService;
  final VoidCallback? onOpenBible;
  final VoidCallback? onCloseBible;
  final MovieLibraryService? movieService;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  bool _movies = false;
  bool get _enabled =>
      MovieLibraryService.enabled || widget.movieService != null;

  void _closeBible() =>
      (widget.onCloseBible ?? () => widget.showBible.value = false)();

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: widget.showBible,
    builder: (context, bible, _) => IndexedStack(
      index: bible
          ? 1
          : _movies && _enabled
          ? 2
          : 0,
      children: [
        BookshelfScreen(
          scope: BookshelfScope.personal,
          bookService: widget.bookService,
          onOpenMovies: _enabled ? () => setState(() => _movies = true) : null,
          onOpenBible:
              widget.onOpenBible ?? () => widget.showBible.value = true,
        ),
        BibleScreen(bibleService: widget.bibleService, onClose: _closeBible),
        if (_enabled)
          MovieLibraryScreen(
            service: widget.movieService,
            onBooks: () => setState(() => _movies = false),
            onBible: widget.onOpenBible ?? () => widget.showBible.value = true,
          ),
      ],
    ),
  );
}
