import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/series_record.dart';
import '../../services/auth_service.dart';
import '../../services/series_library_service.dart';
import '../../services/library_query_service.dart';
import '../../utils/error_handler.dart';
import '../widgets/book_cover.dart';
import '../widgets/content_state.dart';
import '../widgets/design_components.dart';
import 'series_add_screen.dart';
import 'series_details_screen.dart';

class SeriesLibraryScreen extends StatefulWidget {
  const SeriesLibraryScreen({
    super.key,
    this.service,
    required this.onBooks,
    this.onBible,
    this.onMovies,
    this.onMusic,
  });
  final SeriesLibraryService? service;
  final VoidCallback onBooks;
  final VoidCallback? onBible;
  final VoidCallback? onMovies;
  final VoidCallback? onMusic;
  @override
  State<SeriesLibraryScreen> createState() => _SeriesLibraryScreenState();
}

class _SeriesLibraryScreenState extends State<SeriesLibraryScreen> {
  late final _service = widget.service ?? SeriesLibraryService();
  final _filter = TextEditingController();
  final _rows = <SeriesRecord>[];
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
    final saved = await Navigator.push<SeriesRecord>(
      context,
      MaterialPageRoute(
        builder: (_) => SeriesAddScreen(owner: owner, service: _service),
      ),
    );
    if (mounted && _owner == owner && saved != null) {
      setState(() => _status = 'all');
      await _load(reset: true);
    }
  }

  Future<void> _details(SeriesRecord series) async {
    final owner = _owner;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SeriesDetailsScreen(series: series, service: _service),
      ),
    );
    if (mounted && _owner == owner) {
      // Releitura do registro mantém páginas/posição e não perde os filtros.
      try {
        final current = await _service.read(
          series.entry.ownerId,
          series.entry.id,
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
          (series) =>
              (_status == 'all' || _status == series.status) &&
              series.title.toLowerCase().contains(
                _filter.text.trim().toLowerCase(),
              ),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Séries')),
      body: ListView(
        key: const PageStorageKey('series-library'),
        padding: const EdgeInsets.all(16),
        children: [
          LibraryDestinations(
            seriesSelected: true,
            onBooks: widget.onBooks,
            onBible: widget.onBible,
            onMovies: widget.onMovies,
            onMusic: widget.onMusic,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _filter,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Filtrar séries carregadas por título',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in {
                'all': 'Todas',
                'in_progress': 'Em andamento',
                'up_to_date': 'Em dia',
                'completed': 'Concluídas',
                'paused': 'Pausadas',
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
                '${_rows.length} carregadas${_total == null ? '' : ' de $_total séries'}',
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () {
                        setState(() {});
                        _load(reset: true);
                      },
                child: const Text('Atualizar séries'),
              ),
            ],
          ),
          if (_busy)
            Semantics(
              liveRegion: true,
              label: 'Carregando séries. Aguarde.',
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
                  ? 'Nenhuma série salva'
                  : 'Nenhuma série corresponde aos filtros',
              message: _rows.isEmpty
                  ? 'Cadastre uma série para acompanhar seus episódios.'
                  : 'A busca considera as séries carregadas.',
              actionLabel: 'Adicionar série',
              onAction: _add,
            ),
          for (final series in filtered)
            Card(
              child: MergeSemantics(
                child: Semantics(
                  button: true,
                  child: ListTile(
                    leading: SizedBox(
                      width: 44,
                      height: 66,
                      child: BookCover(
                        url: series.cover,
                        placeholderBuilder: (_) =>
                            const Icon(Icons.tv_outlined),
                      ),
                    ),
                    title: Text(series.title),
                    subtitle: Text(
                      '${series.year?.toString() ?? 'Ano não informado'} · ${series.statusLabel}',
                    ),
                    onTap: () => _details(series),
                  ),
                ),
              ),
            ),
          if (_next != null) ...[
            const Text(
              'Há mais séries. Carregue as próximas páginas para ampliar os filtros.',
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () {
                      setState(() {});
                      _load();
                    },
              child: const Text('Carregar mais séries'),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add),
            label: const Text('Adicionar série'),
          ),
        ],
      ),
    );
  }
}
