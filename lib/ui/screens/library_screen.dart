import '../../services/series_library_service.dart';
import 'series_library_screen.dart';
import 'package:flutter/material.dart';

import '../../services/bible_service.dart';
import '../../services/book_service.dart';
import 'bible_screen.dart';
import 'bookshelf_screen.dart';
import '../../services/movie_library_service.dart';
import 'movie_library_screen.dart';
import 'music_library_screen.dart';
import '../../services/music_library_service.dart';

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
    this.musicService,
    this.seriesService,
  });
  final ValueNotifier<bool> showBible;
  final BookService? bookService;
  final BibleService? bibleService;
  final VoidCallback? onOpenBible;
  final VoidCallback? onCloseBible;
  final MovieLibraryService? movieService;
  final MusicLibraryService? musicService;
  final SeriesLibraryService? seriesService;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  int _destination = 0;
  bool get _seriesEnabled =>
      SeriesLibraryService.enabled || widget.seriesService != null;
  bool get _musicEnabled =>
      MusicLibraryService.enabled || widget.musicService != null;
  bool get _enabled =>
      MovieLibraryService.enabled || widget.movieService != null;

  void _closeBible() =>
      (widget.onCloseBible ?? () => widget.showBible.value = false)();

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: widget.showBible,
    builder: (context, bible, _) => IndexedStack(
      index: bible ? 1 : _destination,
      children: [
        BookshelfScreen(
          onOpenSeries: _seriesEnabled
              ? () => setState(() => _destination = 4)
              : null,
          scope: BookshelfScope.personal,
          bookService: widget.bookService,
          onOpenMusic: _musicEnabled
              ? () => setState(() => _destination = 3)
              : null,
          onOpenMovies: _enabled
              ? () => setState(() => _destination = 2)
              : null,
          onOpenBible:
              widget.onOpenBible ?? () => widget.showBible.value = true,
        ),
        BibleScreen(bibleService: widget.bibleService, onClose: _closeBible),
        if (_enabled)
          MovieLibraryScreen(
            onSeries: _seriesEnabled
                ? () => setState(() => _destination = 4)
                : null,
            service: widget.movieService,
            onMusic: _musicEnabled
                ? () => setState(() => _destination = 3)
                : null,
            onBooks: () => setState(() => _destination = 0),
            onBible: widget.onOpenBible ?? () => widget.showBible.value = true,
          )
        else
          const SizedBox.shrink(),
        if (_musicEnabled)
          MusicLibraryScreen(
            onSeries: _seriesEnabled
                ? () => setState(() => _destination = 4)
                : null,
            service: widget.musicService,
            onMovies: _enabled ? () => setState(() => _destination = 2) : null,
            onBooks: () => setState(() => _destination = 0),
            onBible: widget.onOpenBible ?? () => widget.showBible.value = true,
          )
        else
          const SizedBox.shrink(),
        if (_seriesEnabled)
          SeriesLibraryScreen(
            service: widget.seriesService,
            onBooks: () => setState(() => _destination = 0),
            onMusic: _musicEnabled
                ? () => setState(() => _destination = 3)
                : null,
            onBible: widget.onOpenBible ?? () => widget.showBible.value = true,
          ),
      ],
    ),
  );
}
