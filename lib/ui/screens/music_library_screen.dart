import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/media_model.dart';
import '../../data/models/music_record.dart';
import '../../services/auth_service.dart';
import '../../services/music_library_service.dart';
import '../../services/library_query_service.dart';
import '../../utils/error_handler.dart';
import '../widgets/book_cover.dart';
import '../widgets/content_state.dart';
import '../widgets/design_components.dart';
import 'music_add_screen.dart';
import 'music_details_screen.dart';

class MusicLibraryScreen extends StatefulWidget {
  const MusicLibraryScreen({
    super.key,
    this.service,
    required this.onBooks,
    this.onBible,
    this.onMovies,
  });
  final MusicLibraryService? service;
  final VoidCallback onBooks;
  final VoidCallback? onBible;
  final VoidCallback? onMovies;
  @override
  State<MusicLibraryScreen> createState() => _MusicLibraryScreenState();
}

class _MusicLibraryScreenState extends State<MusicLibraryScreen> {
  late final _service = widget.service ?? MusicLibraryService();
  final _filter = TextEditingController();
  final _rows = <MusicRecord>[];
  String? _owner, _error;
  MediaType _type = MediaType.track;
  bool _favorites = false;
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
      _type = MediaType.track;
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
      final page = await _service.page(owner, type: _type, after: cursor);
      final count = await _service.count(owner, _type);
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
    final saved = await Navigator.push<MusicRecord>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MusicAddScreen(owner: owner, service: _service, type: _type),
      ),
    );
    if (mounted && _owner == owner && saved != null) {
      await _load(reset: true);
    }
  }

  Future<void> _details(MusicRecord music) async {
    final owner = _owner;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MusicDetailsScreen(music: music, service: _service),
      ),
    );
    if (mounted && _owner == owner) {
      // Releitura do registro mantém páginas/posição e não perde os filtros.
      try {
        final current = await _service.read(
          music.entry.ownerId,
          music.entry.id,
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
          (music) =>
              (!_favorites || music.entry.favorite) &&
              '${music.title} ${music.artists}'.toLowerCase().contains(
                _filter.text.trim().toLowerCase(),
              ),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Música')),
      body: ListView(
        key: const PageStorageKey('music-library'),
        padding: const EdgeInsets.all(16),
        children: [
          LibraryDestinations(
            musicSelected: true,
            onBooks: widget.onBooks,
            onBible: widget.onBible,
            onMovies: widget.onMovies,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _filter,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Filtrar seleções carregadas por título ou artista',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('Favoritos'),
                selected: _favorites,
                onSelected: (value) => setState(() => _favorites = value),
              ),
              for (final type in [MediaType.track, MediaType.album])
                ChoiceChip(
                  label: Text(type == MediaType.track ? 'Faixas' : 'Álbuns'),
                  selected: _type == type,
                  onSelected: _busy
                      ? null
                      : (_) {
                          setState(() => _type = type);
                          _load(reset: true);
                        },
                ),
            ],
          ),
          Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Carregadas: ${_rows.length}${_total == null ? '' : ' · Total: $_total'}',
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () {
                        setState(() {});
                        _load(reset: true);
                      },
                child: const Text('Atualizar seleções'),
              ),
            ],
          ),
          if (_busy)
            Semantics(
              liveRegion: true,
              label: 'Carregando seleções. Aguarde.',
              child: const LinearProgressIndicator(),
            ),
          if (_error != null) ...[
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
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
                  ? 'Nenhuma seleção salva'
                  : 'Nenhuma seleção corresponde aos filtros',
              message: _rows.isEmpty
                  ? 'Cadastre uma faixa ou álbum para organizar suas músicas.'
                  : 'A busca considera as seleções carregadas.',
              actionLabel: 'Adicionar seleção',
              onAction: _add,
            ),
          for (final music in filtered)
            Card(
              child: MergeSemantics(
                child: Semantics(
                  button: true,
                  child: ListTile(
                    leading: SizedBox(
                      width: 44,
                      height: 66,
                      child: BookCover(
                        url: music.cover,
                        placeholderBuilder: (_) =>
                            const Icon(Icons.music_note_outlined),
                      ),
                    ),
                    title: Text(music.title),
                    trailing: music.entry.favorite
                        ? const Icon(Icons.favorite, semanticLabel: 'Favorito')
                        : null,
                    subtitle: Text(
                      '${music.artists} · ${music.typeLabel}${music.version == null ? '' : ' · ${music.version}'}',
                    ),
                    onTap: () => _details(music),
                  ),
                ),
              ),
            ),
          if (_next != null) ...[
            const Text(
              'Há mais seleções. Carregue as próximas páginas para ampliar os filtros.',
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () {
                      setState(() {});
                      _load();
                    },
              child: const Text('Carregar mais seleções'),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add),
            label: const Text('Adicionar seleção'),
          ),
        ],
      ),
    );
  }
}
