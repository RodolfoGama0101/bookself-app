import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../data/models/movie_record.dart';
import '../../services/auth_service.dart';
import '../../services/movie_library_service.dart';
import '../../services/library_query_service.dart';
import '../../utils/error_handler.dart';
import '../widgets/book_cover.dart';
import '../widgets/content_state.dart';
import 'movie_add_screen.dart';
import 'movie_details_screen.dart';

class MovieLibraryScreen extends StatefulWidget {
  const MovieLibraryScreen({
    super.key,
    this.service,
    required this.onBooks,
    this.onBible,
  });
  final MovieLibraryService? service;
  final VoidCallback onBooks;
  final VoidCallback? onBible;
  @override
  State<MovieLibraryScreen> createState() => _MovieLibraryScreenState();
}

class _MovieLibraryScreenState extends State<MovieLibraryScreen> {
  late final _service = widget.service ?? MovieLibraryService();
  final _filter = TextEditingController();
  final _rows = <MovieRecord>[];
  String? _owner, _error;
  String _status = 'all';
  LibraryCursor? _next;
  int? _total;
  bool _busy = false;
  int _generation = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final owner = context.watch<AuthService>().currentUserModel?.uid;
    if (owner != _owner) {
      _owner = owner;
      _generation++;
      _rows.clear();
      _next = null;
      _total = null;
      _error = null;
      _busy = false;
      _filter.clear();
      _status = 'all';
      if (owner != null) _load(reset: true);
    }
  }

  bool _valid(String owner, int generation) =>
      mounted &&
      _owner == owner &&
      generation == _generation &&
      context.read<AuthService>().currentUserModel?.uid == owner;
  Future<void> _load({bool reset = false}) async {
    final owner = _owner;
    if (owner == null || _busy || (!reset && _next == null)) return;
    final generation = ++_generation;
    final cursor = reset ? null : _next;
    // didChangeDependencies já está dentro da construção inicial.
    _busy = true;
    _error = null;
    if (reset) {
      _rows.clear();
      _next = null;
      _total = null;
    }
    try {
      final page = await _service.page(owner, after: cursor);
      final count = await _service.count(owner);
      if (!_valid(owner, generation)) return;
      setState(() {
        final ids = _rows.map((row) => row.entry.id).toSet();
        _rows.addAll(page.items.where((row) => ids.add(row.entry.id)));
        _next = page.next;
        _total = count;
      });
    } catch (error) {
      if (_valid(owner, generation)) {
        setState(() => _error = ErrorHandler.getFriendlyErrorMessage(error));
      }
    } finally {
      if (_valid(owner, generation)) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final owner = _owner;
    if (owner == null) return;
    final saved = await Navigator.push<MovieRecord>(
      context,
      MaterialPageRoute(
        builder: (_) => MovieAddScreen(owner: owner, service: _service),
      ),
    );
    if (mounted && _owner == owner && saved != null) {
      setState(() => _status = 'all');
      await _load(reset: true);
    }
  }

  Future<void> _details(MovieRecord movie) async {
    final owner = _owner;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MovieDetailsScreen(movie: movie, service: _service),
      ),
    );
    if (mounted && _owner == owner) {
      // Releitura do registro mantém páginas/posição e não perde os filtros.
      try {
        final current = await _service.read(
          movie.entry.ownerId,
          movie.entry.id,
        );
        if (mounted && _owner == owner) {
          setState(() {
            final index = _rows.indexWhere(
              (row) => row.entry.id == current.entry.id,
            );
            if (index >= 0) _rows[index] = current;
          });
        }
      } catch (error) {
        if (mounted && _owner == owner) {
          setState(() => _error = ErrorHandler.getFriendlyErrorMessage(error));
        }
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    _filter.dispose();
    if (widget.service == null) _service.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _rows
        .where(
          (movie) =>
              (_status == 'all' || (_status == 'watched') == movie.watched) &&
              movie.title.toLowerCase().contains(
                _filter.text.trim().toLowerCase(),
              ),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Filmes')),
      body: ListView(
        key: const PageStorageKey('movie-library'),
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              ActionChip(
                label: const Text('Livros'),
                avatar: const Icon(Icons.library_books_outlined),
                onPressed: widget.onBooks,
              ),
              const Chip(
                label: Text('Filmes'),
                avatar: Icon(Icons.movie_outlined),
              ),
              if (widget.onBible != null)
                ActionChip(
                  label: const Text('Acompanhar Bíblia'),
                  onPressed: widget.onBible,
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _filter,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Filtrar filmes carregados por título',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in {
                'all': 'Todos',
                'planned': 'Quero assistir',
                'watched': 'Assistidos',
              }.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: _status == entry.key,
                  onSelected: (_) => setState(() => _status = entry.key),
                ),
            ],
          ),
          Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${_rows.length} carregados${_total == null ? '' : ' de $_total filmes'}',
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () {
                        setState(() {});
                        _load(reset: true);
                      },
                child: const Text('Atualizar filmes'),
              ),
            ],
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null) ...[
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () {
                      setState(() {});
                      _load(reset: _rows.isEmpty || _next == null);
                    },
              child: const Text('Tentar novamente'),
            ),
          ],
          if (!_busy && _error == null && filtered.isEmpty)
            ContentState(
              title: _rows.isEmpty
                  ? 'Nenhum filme salvo'
                  : 'Nenhum filme corresponde aos filtros',
              message: _rows.isEmpty
                  ? 'Cadastre um filme para acompanhar suas sessões.'
                  : 'A busca considera os filmes carregados.',
              actionLabel: 'Adicionar filme',
              onAction: _add,
            ),
          for (final movie in filtered)
            Card(
              child: ListTile(
                leading: SizedBox(
                  width: 44,
                  height: 66,
                  child: BookCover(
                    url: movie.cover,
                    placeholderBuilder: (_) => const Icon(Icons.movie_outlined),
                  ),
                ),
                title: Text(movie.title),
                subtitle: Text(
                  '${movie.year?.toString() ?? 'Ano não informado'} · ${movie.statusLabel}'
                  '${movie.watchedOn == null ? '' : '\n${DateFormat('dd/MM/yyyy').format(DateTime.parse(movie.watchedOn!))}'}',
                ),
                isThreeLine: movie.watchedOn != null,
                onTap: () => _details(movie),
              ),
            ),
          if (_next != null) ...[
            const Text(
              'Há mais filmes. Carregue as próximas páginas para ampliar os filtros.',
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () {
                      setState(() {});
                      _load();
                    },
              child: const Text('Carregar mais filmes'),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add),
            label: const Text('Adicionar filme'),
          ),
        ],
      ),
    );
  }
}
