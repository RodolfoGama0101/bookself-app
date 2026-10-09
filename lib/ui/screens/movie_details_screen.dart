import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../data/models/movie_record.dart';
import '../../data/models/couple_record.dart';
import '../../services/auth_service.dart';
import '../../services/movie_library_service.dart';
import '../../services/media_library_repository.dart';
import '../../services/couple_workspace_service.dart';
import '../../utils/error_handler.dart';
import '../widgets/book_cover.dart';
import '../widgets/content_state.dart';
import '../widgets/completion_date_picker.dart';
import '../widgets/reading_surface.dart';
import 'movie_couple_screen.dart';

class MovieDetailsScreen extends StatefulWidget {
  const MovieDetailsScreen({
    super.key,
    required this.movie,
    required this.service,
    this.coupleService,
  });
  final MovieRecord movie;
  final MovieLibraryService service;
  final CoupleWorkspaceService? coupleService;
  @override
  State<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen> {
  late MovieRecord _movie = widget.movie;
  bool _busy = false;
  String? _error;
  bool _conflict = false;
  bool get _current =>
      mounted &&
      context.read<AuthService>().currentUserModel?.uid == _movie.entry.ownerId;
  Future<void> _update(bool watched, String? date) async {
    if (!_current || _busy || _conflict) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await widget.service.update(
        _movie,
        watched: watched,
        date: date,
      );
      if (!mounted || !_current) return;
      setState(() => _movie = saved);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Filme atualizado.')));
    } on MediaRevisionConflict {
      if (_current) {
        setState(() {
          _conflict = true;
          _error =
              'Este filme mudou em outra sessão. Recarregue antes de escolher novamente.';
        });
      }
    } catch (error) {
      if (_current) {
        setState(() => _error = ErrorHandler.getFriendlyErrorMessage(error));
      }
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  Future<void> _reload() async {
    if (!_current || _busy) return;
    setState(() => _busy = true);
    try {
      final saved = await widget.service.read(
        _movie.entry.ownerId,
        _movie.entry.id,
      );
      if (_current) {
        setState(() {
          _movie = saved;
          _conflict = false;
          _error = null;
        });
      }
    } catch (error) {
      if (_current) {
        setState(() => _error = ErrorHandler.getFriendlyErrorMessage(error));
      }
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  Future<void> _date() async {
    final picked = await showCompletionDatePicker(
      context,
      initialDate: _movie.watchedOn == null
          ? null
          : DateTime.parse(_movie.watchedOn!),
      helpText: 'Quando você assistiu ao filme?',
      fieldLabelText: 'Data da sessão',
    );
    if (!_current || picked == null) return;
    await _update(true, coupleDate(picked));
  }

  Future<void> _share(bool experience) async {
    final relation = context
        .read<AuthService>()
        .currentUserModel
        ?.relationshipId;
    if (relation == null || !_current || _busy) return;
    final shared = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MovieCoupleScreen(
          movie: _movie,
          relation: relation,
          experience: experience,
          service: widget.coupleService,
        ),
      ),
    );
    if (mounted &&
        _current &&
        shared == true &&
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

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUserModel;
    if (user?.uid != _movie.entry.ownerId) {
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
    return ReadingPage(
      maxWidth: 680,
      child: Scaffold(
        appBar: AppBar(title: const Text('Detalhes do filme')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            SizedBox(
              height: 220,
              child: BookCover(
                url: _movie.cover,
                placeholderBuilder: (_) =>
                    const Icon(Icons.movie_outlined, size: 72),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _movie.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(_movie.year?.toString() ?? 'Ano não informado'),
            Text(
              _movie.catalog.identity.isManual
                  ? 'Cadastro manual'
                  : 'Catálogo: ${_movie.catalog.identity.provider}',
            ),
            const SizedBox(height: 16),
            Text(
              _movie.statusLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              _movie.watchedOn == null
                  ? 'Data da sessão não informada'
                  : 'Assistido em ${DateFormat('dd/MM/yyyy').format(DateTime.parse(_movie.watchedOn!))}',
            ),
            Text(
              'Incluído em ${DateFormat('dd/MM/yyyy').format(_movie.entry.createdAt.toLocal())}',
            ),
            if (_busy)
              Semantics(
                liveRegion: true,
                label: 'Atualizando filme. Aguarde.',
                child: const LinearProgressIndicator(),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
            if (_conflict)
              FilledButton(
                onPressed: _busy ? null : _reload,
                child: const Text('Recarregar filme'),
              ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton(
                  onPressed: _busy || _conflict || !_movie.watched
                      ? null
                      : () => _update(false, null),
                  child: const Text('Quero assistir'),
                ),
                FilledButton(
                  onPressed: _busy || _conflict || _movie.watched
                      ? null
                      : () => _update(true, null),
                  child: const Text('Marcar como assistido'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy || _conflict ? null : _date,
                  icon: const Icon(Icons.calendar_month),
                  label: Text(
                    _movie.watchedOn == null
                        ? 'Informar data da sessão'
                        : 'Editar data da sessão',
                  ),
                ),
                if (_movie.watchedOn != null)
                  TextButton(
                    onPressed: _busy || _conflict
                        ? null
                        : () => _update(true, null),
                    child: const Text('Limpar data da sessão'),
                  ),
              ],
            ),
            if (canShare) ...[
              const Divider(height: 40),
              Text(
                'Com o casal',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Text(
                'Escolha compartilhar esta obra em uma lista ou propor uma sessão. As bibliotecas pessoais permanecem independentes.',
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _share(false),
                icon: const Icon(Icons.playlist_add),
                label: const Text('Adicionar à lista do casal'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _share(true),
                icon: const Icon(Icons.favorite_border),
                label: const Text('Propor sessão do casal'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
