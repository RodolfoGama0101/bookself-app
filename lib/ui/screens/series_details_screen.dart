import '../../services/couple_workspace_service.dart';
import 'series_couple_screen.dart';
import 'series_comparison_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/series_record.dart';
import '../../services/auth_service.dart';
import '../../services/media_library_repository.dart';
import '../../services/series_library_service.dart';
import '../../utils/error_handler.dart';
import '../widgets/content_state.dart';
import '../widgets/reading_surface.dart';

class SeriesDetailsScreen extends StatefulWidget {
  const SeriesDetailsScreen({
    super.key,
    required this.series,
    required this.service,
  });
  final SeriesRecord series;
  final SeriesLibraryService service;
  @override
  State<SeriesDetailsScreen> createState() => _SeriesDetailsScreenState();
}

class _SeriesDetailsScreenState extends State<SeriesDetailsScreen> {
  late SeriesRecord _series = widget.series;
  bool _busy = false, _conflict = false;
  String? _error;
  bool? _visible;
  @override
  void initState() {
    super.initState();
    _loadVisibility();
  }

  Future<void> _loadVisibility() async {
    try {
      final value = await widget.service.sharing.visible(
        _series.entry.ownerId,
        _series.entry.id,
      );
      if (_current) setState(() => _visible = value);
    } catch (e) {
      if (_current) {
        setState(() => _error = ErrorHandler.getFriendlyErrorMessage(e));
      }
    }
  }

  Future<void> _share(bool experience, [SeriesEpisode? episode]) async {
    final user = context.read<AuthService>().currentUserModel;
    if (!_current || user?.relationshipId == null || _busy) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SeriesCoupleScreen(
          series: _series,
          episode: episode,
          relation: user!.relationshipId!,
          experience: experience,
        ),
      ),
    );
  }

  final _season = TextEditingController(text: '1'),
      _number = TextEditingController(text: '1');
  SeriesEpisode? _prepared;
  bool get _current =>
      mounted &&
      context.read<AuthService>().currentUserModel?.uid ==
          _series.entry.ownerId;
  @override
  void dispose() {
    _season.dispose();
    _number.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (!_current || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      final latest = await widget.service.read(
        _series.entry.ownerId,
        _series.entry.id,
      );
      if (_current) {
        setState(() {
          _series = latest;
          _conflict = false;
          _prepared = null;
        });
      }
    } on MediaRevisionConflict {
      if (_current) {
        setState(() {
          _conflict = true;
          _error =
              'O progresso mudou em outra sessão. Recarregue antes de tentar novamente.';
        });
      }
    } catch (e) {
      if (_current) {
        setState(() => _error = ErrorHandler.getFriendlyErrorMessage(e));
      }
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  Future<void> _configure({bool? complete, bool? ended, bool? paused}) => _run(
    () => widget.service.progress.configure(
      _series.entry.ownerId,
      _series.entry.id,
      _series.progress,
      complete: complete ?? _series.progress.complete,
      ended: ended ?? _series.progress.ended,
      paused: paused ?? _series.progress.paused,
    ),
  );
  Future<void> _add() => _run(() async {
    if (_series.progress.episodes.length >= 500) {
      throw const FormatException('Limite de episódios');
    }
    _prepared ??= SeriesEpisode(
      id: widget.service.progress.newEpisodeId(),
      season: int.parse(_season.text),
      number: int.parse(_number.text),
      available: true,
    );
    if (_series.progress.episodes.any(
      (e) => e.season == _prepared!.season && e.number == _prepared!.number,
    )) {
      _prepared = null;
      throw const FormatException('Número já cadastrado');
    }
    await widget.service.progress.saveEpisode(
      _series.entry.ownerId,
      _series.entry.id,
      _prepared!,
      watched: false,
    );
  });
  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUserModel;
    if (user?.uid != _series.entry.ownerId) {
      return const Scaffold(
        body: ContentState(
          title: 'Sua conta mudou',
          message: 'Volte à Biblioteca para continuar.',
        ),
      );
    }
    final disabled = _busy || _conflict;
    return ReadingPage(
      child: Scaffold(
        appBar: AppBar(title: Text(_series.title)),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              _series.statusLabel,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            const Text(
              'Especiais são opcionais. Episódios futuros não contam como disponíveis. Marcar aqui muda somente seu progresso.',
            ),
            if (_busy)
              const LinearProgressIndicator(
                semanticsLabel: 'Salvando progresso',
              ),
            if (_error != null)
              Semantics(liveRegion: true, child: Text(_error!)),
            TextButton(
              onPressed: _busy
                  ? null
                  : () async {
                      await _run(() async {});
                      await _loadVisibility();
                    },
              child: const Text('Recarregar progresso'),
            ),
            if (_visible != null)
              SwitchListTile(
                title: const Text('Compartilhar nome e progresso da série'),
                subtitle: const Text(
                  'Somente o parceiro do vínculo consentido atual pode consultar. Ocultar retira o acesso.',
                ),
                value: _visible!,
                onChanged: disabled
                    ? null
                    : (v) async {
                        await _run(
                          () => widget.service.sharing.setVisible(_series, v),
                        );
                        await _loadVisibility();
                      },
              ),
            if (user?.partnerUid != null && user?.relationshipId != null)
              OutlinedButton.icon(
                icon: const Icon(Icons.compare_arrows),
                label: const Text('Comparar episódios'),
                onPressed: _busy
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SeriesComparisonScreen(
                            series: _series,
                            partner: user!.partnerUid!,
                            relation: user.relationshipId!,
                            service: widget.service.sharing,
                          ),
                        ),
                      ),
              ),
            if (CoupleWorkspaceService.enabled &&
                user?.partnerUid != null &&
                user?.relationshipId != null)
              OutlinedButton(
                onPressed: _busy ? null : () => _share(false),
                child: const Text('Adicionar à lista do casal'),
              ),
            SwitchListTile(
              title: const Text('Pausar série'),
              value: _series.progress.paused,
              onChanged: disabled ? null : (v) => _configure(paused: v),
            ),
            SwitchListTile(
              title: const Text('Lista de episódios completa'),
              subtitle: const Text(
                'Inclui todos os episódios regulares conhecidos, inclusive futuros.',
              ),
              value: _series.progress.complete,
              onChanged: disabled ? null : (v) => _configure(complete: v),
            ),
            SwitchListTile(
              title: const Text('Produção encerrada'),
              value: _series.progress.ended,
              onChanged: disabled ? null : (v) => _configure(ended: v),
            ),
            for (final e in _series.progress.episodes) ...[
              CheckboxListTile(
                title: Text(e.label),
                value: e.watched,
                subtitle: Text(
                  e.released(DateTime.now())
                      ? (e.season == 0 ? 'Especial opcional' : 'Disponível')
                      : 'Disponibilidade não confirmada ou futura',
                ),
                onChanged: disabled || !e.released(DateTime.now())
                    ? null
                    : (v) => _run(
                        () => widget.service.progress.saveEpisode(
                          _series.entry.ownerId,
                          _series.entry.id,
                          e,
                          watched: v!,
                        ),
                      ),
              ),
              if (CoupleWorkspaceService.enabled &&
                  user?.partnerUid != null &&
                  user?.relationshipId != null &&
                  e.released(DateTime.now()))
                TextButton(
                  onPressed: _busy ? null : () => _share(true, e),
                  child: Text(
                    'Propor sessão: temporada ${e.season}, episódio ${e.number}',
                  ),
                ),
            ],
            const SizedBox(height: 24),
            Text(
              'Adicionar episódio disponível',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text(
              'Use temporada 0 para especiais. Informe apenas episódios já disponíveis.',
            ),
            TextField(
              controller: _season,
              enabled: !disabled && _prepared == null,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Temporada'),
            ),
            TextField(
              controller: _number,
              enabled: !disabled && _prepared == null,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Número do episódio',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: disabled ? null : _add,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar episódio'),
            ),
          ],
        ),
      ),
    );
  }
}
