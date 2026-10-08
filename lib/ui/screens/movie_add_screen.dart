import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/media_model.dart';
import '../../services/auth_service.dart';
import '../../services/movie_catalog.dart';
import '../../services/movie_library_service.dart';
import '../../utils/error_handler.dart';
import '../widgets/content_state.dart';
import '../widgets/book_cover.dart';
import '../widgets/reading_surface.dart';

class MovieAddScreen extends StatefulWidget {
  const MovieAddScreen({super.key, required this.owner, required this.service});
  final String owner;
  final MovieLibraryService service;
  @override
  State<MovieAddScreen> createState() => _MovieAddScreenState();
}

class _MovieAddScreenState extends State<MovieAddScreen> {
  final _query = TextEditingController(),
      _title = TextEditingController(),
      _year = TextEditingController(),
      _cover = TextEditingController();
  final _form = GlobalKey<FormState>();
  final _results = <MovieCatalogItem>[];
  String? _cursor, _searchError, _saveError;
  String _lastQuery = '';
  MovieCatalogItem? _selected;
  CatalogItem? _prepared;
  bool _searching = false, _saving = false, _detailsPending = false;
  int _searchGeneration = 0;
  bool get _current =>
      mounted &&
      context.read<AuthService>().currentUserModel?.uid == widget.owner;

  @override
  void dispose() {
    _searchGeneration++;
    for (final controller in [_query, _title, _year, _cover]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _search({bool more = false}) async {
    if (!_current || _saving || _prepared != null || (more && _searching)) {
      return;
    }
    final query = more ? _lastQuery : _query.text.trim();
    if (query.isEmpty || (more && _cursor == null)) return;
    final generation = ++_searchGeneration;
    final oldCursor = more ? _cursor : null;
    setState(() {
      _searching = true;
      _searchError = null;
      if (!more) {
        _selected = null;
        _results.clear();
        _cursor = null;
        _lastQuery = query;
      }
    });
    try {
      final page = await widget.service.catalog.search(
        query,
        cursor: oldCursor,
      );
      if (!_current || generation != _searchGeneration) return;
      setState(() {
        final keys = _results.map((item) => item.identity.key).toSet();
        _results.addAll(
          page.items.where((item) => keys.add(item.identity.key)),
        );
        _cursor = page.nextCursor == oldCursor ? null : page.nextCursor;
      });
    } catch (error) {
      if (_current && generation == _searchGeneration) {
        setState(
          () => _searchError = ErrorHandler.getFriendlyErrorMessage(error),
        );
      }
    } finally {
      if (_current && generation == _searchGeneration) {
        setState(() => _searching = false);
      }
    }
  }

  Future<void> _select(MovieCatalogItem item) async {
    if (!_current || _detailsPending || _prepared != null) return;
    final generation = _searchGeneration;
    setState(() {
      _detailsPending = true;
      _searchError = null;
    });
    try {
      final detailed = await widget.service.catalog.details(item.identity);
      if (!_current || generation != _searchGeneration) return;
      if (detailed.identity.key != item.identity.key) {
        throw const FormatException();
      }
      setState(() => _selected = detailed);
    } catch (error) {
      if (_current && generation == _searchGeneration) {
        setState(
          () => _searchError = ErrorHandler.getFriendlyErrorMessage(error),
        );
      }
    } finally {
      if (_current) setState(() => _detailsPending = false);
    }
  }

  Future<void> _save() async {
    if (!_current || _saving || _detailsPending) return;
    if (_prepared == null &&
        _selected == null &&
        !_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      _prepared ??= widget.service.prepare(
        widget.owner,
        _selected?.metadata ??
            MediaMetadata(MediaType.movie, {
              'title': _title.text.trim(),
              'releaseYear': _year.text.trim().isEmpty
                  ? null
                  : int.parse(_year.text.trim()),
              'coverUrl': _cover.text.trim().isEmpty
                  ? null
                  : _cover.text.trim(),
            }),
        identity: _selected?.identity,
      );
      final saved = await widget.service.save(_prepared!);
      if (mounted && _current) Navigator.pop(context, saved);
    } catch (error) {
      if (_current) {
        setState(
          () => _saveError = ErrorHandler.getFriendlyErrorMessage(error),
        );
      }
    } finally {
      if (_current) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (context.watch<AuthService>().currentUserModel?.uid != widget.owner) {
      return const Scaffold(
        body: ContentState(
          title: 'Sua conta mudou',
          message: 'Volte à Biblioteca para continuar.',
        ),
      );
    }
    final locked = _saving || _prepared != null;
    return ReadingPage(
      child: Scaffold(
        appBar: AppBar(title: const Text('Adicionar filme')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextField(
              controller: _query,
              maxLength: 300,
              enabled: widget.service.catalog.available && !locked,
              decoration: const InputDecoration(
                labelText: 'Buscar filme no catálogo',
              ),
              onSubmitted: (_) => _search(),
            ),
            if (!widget.service.catalog.available)
              const Text(
                'O catálogo de filmes está indisponível. Cadastre manualmente abaixo.',
              ),
            if (widget.service.catalog.available)
              FilledButton.icon(
                onPressed: locked ? null : () => _search(),
                icon: const Icon(Icons.search),
                label: const Text('Buscar filmes'),
              ),
            if (_searching || _detailsPending) const LinearProgressIndicator(),
            if (_searchError != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_searchError!, semanticsLabel: _searchError),
              ),
            for (final movie in _results)
              ListTile(
                title: Text(movie.metadata.title),
                subtitle: Text(
                  movie.metadata.toMap()['releaseYear']?.toString() ??
                      'Ano não informado',
                ),
                onTap: locked || _detailsPending ? null : () => _select(movie),
              ),
            if (_cursor != null)
              TextButton(
                onPressed: _searching || locked
                    ? null
                    : () => _search(more: true),
                child: const Text('Carregar mais resultados'),
              ),
            if (_lastQuery.isNotEmpty &&
                !_searching &&
                _searchError == null &&
                _results.isEmpty)
              const Text(
                'Nenhum filme encontrado. Você pode cadastrar manualmente.',
              ),
            const SizedBox(height: 24),
            if (_selected == null) ...[
              Text(
                'Cadastro manual',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Form(
                key: _form,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _title,
                      maxLength: 300,
                      readOnly: locked,
                      decoration: const InputDecoration(
                        labelText: 'Título do filme',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Informe o título.'
                          : null,
                    ),
                    TextFormField(
                      controller: _year,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      readOnly: locked,
                      decoration: const InputDecoration(
                        labelText: 'Ano de lançamento (opcional)',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return null;
                        final year = int.tryParse(value.trim());
                        return year == null || year < 1 || year > 9999
                            ? 'Informe um ano válido.'
                            : null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _cover,
                      readOnly: locked,
                      decoration: const InputDecoration(
                        labelText: 'URL do pôster (opcional)',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return null;
                        final uri = Uri.tryParse(value.trim());
                        return uri == null ||
                                uri.scheme != 'https' ||
                                uri.host.isEmpty ||
                                uri.userInfo.isNotEmpty
                            ? 'Use uma URL HTTPS sem credenciais.'
                            : null;
                      },
                    ),
                  ],
                ),
              ),
            ] else ...[
              SizedBox(
                height: 180,
                child: BookCover(
                  url: _selected!.metadata.toMap()['coverUrl'] as String? ?? '',
                  placeholderBuilder: (_) =>
                      const Icon(Icons.movie_outlined, size: 64),
                ),
              ),
              Text(
                _selected!.metadata.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                _selected!.metadata.toMap()['releaseYear']?.toString() ??
                    'Ano não informado',
              ),
              Text('Referência: ${_selected!.identity.provider}'),
              TextButton(
                onPressed: locked
                    ? null
                    : () => setState(() => _selected = null),
                child: const Text(
                  'Cadastrar manualmente em vez deste resultado',
                ),
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              'O filme será salvo em Quero assistir na sua biblioteca.',
            ),
            if (_saveError != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _saveError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_prepared != null && _saveError != null)
              const Text(
                'A confirmação falhou. Repetir conserva este cadastro e evita duplicatas.',
              ),
            FilledButton(
              onPressed: _saving || _detailsPending ? null : _save,
              child: Text(
                _saving
                    ? 'Salvando filme…'
                    : _prepared != null
                    ? 'Tentar salvar novamente'
                    : 'Salvar filme',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
