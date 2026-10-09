import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/music_record.dart';
import '../../services/auth_service.dart';
import '../../services/music_library_service.dart';
import '../widgets/book_cover.dart';
import '../widgets/content_state.dart';
import '../widgets/reading_surface.dart';
import '../../services/music_listen_service.dart';
import '../../services/library_query_service.dart';
import '../../services/media_library_repository.dart';
import '../../utils/error_handler.dart';
import 'music_listen_screen.dart';
import 'music_couple_screen.dart';
import '../../services/couple_workspace_service.dart';

class MusicDetailsScreen extends StatefulWidget {
  const MusicDetailsScreen({
    super.key,
    required this.music,
    required this.service,
    this.listenService,
    this.coupleService,
  });
  final MusicRecord music;
  final MusicLibraryService service;
  final MusicListenService? listenService;
  final CoupleWorkspaceService? coupleService;
  @override
  State<MusicDetailsScreen> createState() => _MusicDetailsScreenState();
}

class _MusicDetailsScreenState extends State<MusicDetailsScreen> {
  late MusicRecord _music = widget.music;
  late final _listens = widget.listenService ?? MusicListenService();
  final _history = <MusicListen>[];
  LibraryCursor? _next;
  bool _busy = false, _loading = false, _loaded = false, _conflict = false;
  String? _error;
  Future<void> _favorite() async {
    if (!_current || _busy || _conflict) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await widget.service.favorite(
        _music,
        !_music.entry.favorite,
      );
      if (_current) {
        setState(() => _music = saved);
      }
    } catch (error) {
      if (_current) {
        setState(() {
          _conflict = error is MediaRevisionConflict;
          _error = ErrorHandler.getFriendlyErrorMessage(error);
        });
      }
    } finally {
      if (_current) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _reload() async {
    if (!_current || _busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final saved = await widget.service.read(
        _music.entry.ownerId,
        _music.entry.id,
      );
      if (_current) {
        setState(() {
          _music = saved;
          _conflict = false;
          _error = null;
        });
      }
    } catch (error) {
      if (_current) {
        setState(() => _error = ErrorHandler.getFriendlyErrorMessage(error));
      }
    } finally {
      if (_current) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (!_current || _loading) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _history.clear();
        _next = null;
        _loaded = false;
      }
    });
    try {
      final page = await _listens.page(
        _music.entry.ownerId,
        _music.entry.id,
        after: reset ? null : _next,
      );
      if (_current) {
        setState(() {
          final ids = _history.map((r) => r.id).toSet();
          _history.addAll(page.items.where((r) => ids.add(r.id)));
          _next = page.next;
          _loaded = true;
        });
      }
    } catch (error) {
      if (_current) {
        setState(() => _error = ErrorHandler.getFriendlyErrorMessage(error));
      }
    } finally {
      if (_current) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _listen() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MusicListenScreen(music: _music, service: _listens),
      ),
    );
    if (_current && saved == true) {
      await _load(reset: true);
    }
  }

  Future<void> _share(bool experience) async {
    final relation = context
        .read<AuthService>()
        .currentUserModel
        ?.relationshipId;
    if (relation == null || !_current || _busy) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MusicCoupleScreen(
          music: _music,
          relation: relation,
          experience: experience,
          service: widget.coupleService,
        ),
      ),
    );
    if (mounted &&
        _current &&
        saved == true &&
        context.read<AuthService>().currentUserModel?.relationshipId ==
            relation) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            experience
                ? 'Proposta enviada. O parceiro precisa confirmar em Nós.'
                : 'Seleção adicionada à lista.',
          ),
        ),
      );
    }
  }

  bool get _current =>
      mounted &&
      context.read<AuthService>().currentUserModel?.uid == _music.entry.ownerId;
  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUserModel;
    if (!_current) {
      return const Scaffold(
        body: ContentState(
          title: 'Sua conta mudou',
          message: 'Volte à Biblioteca para continuar.',
        ),
      );
    }
    final canShare =
        user?.partnerUid != null &&
        user?.relationshipId != null &&
        (widget.coupleService != null || CoupleWorkspaceService.enabled);
    final data = _music.catalog.metadata.toMap();
    return ReadingPage(
      maxWidth: 680,
      child: Scaffold(
        appBar: AppBar(title: Text('Detalhes · ${_music.typeLabel}')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            SizedBox(
              height: 180,
              child: BookCover(
                url: _music.cover,
                placeholderBuilder: (_) =>
                    const Icon(Icons.music_note_outlined, size: 64),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _music.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              _music.artists,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (_music.version != null)
              Text('Versão/edição: ${_music.version}'),
            if (data['albumTitle'] != null)
              Text('Álbum: ${data['albumTitle']}'),
            if (data['releaseYear'] != null)
              Text('Lançamento: ${data['releaseYear']}'),
            if (data['durationMs'] != null)
              Text(
                'Duração: ${Duration(milliseconds: data['durationMs'] as int).inSeconds} segundos',
              ),
            Text(
              _music.catalog.identity.isManual
                  ? 'Cadastro manual'
                  : 'Catálogo: ${_music.catalog.identity.provider}',
            ),
            const SizedBox(height: 16),
            if (_busy || _loading) const LinearProgressIndicator(),
            if (_error != null)
              Semantics(liveRegion: true, child: Text(_error!)),
            if (_conflict)
              FilledButton(
                onPressed: _busy ? null : _reload,
                child: const Text('Recarregar seleção'),
              ),
            OutlinedButton.icon(
              onPressed: _busy || _conflict ? null : _favorite,
              icon: Icon(
                _music.entry.favorite ? Icons.favorite : Icons.favorite_border,
              ),
              label: Text(
                _music.entry.favorite ? 'Remover dos favoritos' : 'Favoritar',
              ),
            ),
            const Text(
              'Favoritos e escutas são privados, inclusive para o parceiro.',
            ),
            FilledButton.icon(
              onPressed: _busy ? null : _listen,
              icon: const Icon(Icons.headphones),
              label: const Text('Registrar escuta pessoal'),
            ),
            TextButton(
              onPressed: _loading ? null : () => _load(reset: true),
              child: const Text('Atualizar minhas escutas'),
            ),
            if (_loaded && _history.isEmpty)
              const Text('Nenhuma escuta registrada.'),
            for (final listen in _history)
              ListTile(
                leading: const Icon(Icons.headphones),
                title: Text('Escuta em ${listen.date}'),
              ),
            if (_next != null)
              TextButton(
                onPressed: _loading ? null : _load,
                child: const Text('Carregar mais escutas'),
              ),
            if (canShare) ...[
              const Divider(height: 40),
              Text(
                'Com o casal',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Text(
                'Compartilhe uma descoberta na lista ou proponha um momento musical. Favoritos e escutas pessoais permanecem privados.',
              ),
              OutlinedButton(
                onPressed: _busy ? null : () => _share(false),
                child: const Text('Adicionar à lista do casal'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : () => _share(true),
                child: const Text('Propor momento musical'),
              ),
            ],
            const Text(
              'Salvar uma faixa ou álbum não registra uma escuta. As faixas de um álbum são independentes.',
            ),
          ],
        ),
      ),
    );
  }
}
