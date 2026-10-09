import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../data/models/media_model.dart';
import '../../services/auth_service.dart';
import '../../services/couple_activity_service.dart';
import '../../services/library_query_service.dart';
import '../widgets/content_state.dart';
import '../widgets/reading_surface.dart';

class CoupleActivityScreen extends StatefulWidget {
  const CoupleActivityScreen({super.key, this.service});
  final CoupleActivityService? service;
  @override
  State<CoupleActivityScreen> createState() => _CoupleActivityScreenState();
}

class _CoupleActivityScreenState extends State<CoupleActivityScreen> {
  late final _service = widget.service ?? CoupleActivityService();
  StreamSubscription<LibraryPage<CoupleActivity>>? _subscription;
  final _rows = <CoupleActivity>[];
  MediaType? _type;
  Map<MediaType, int>? _counts;
  LibraryCursor? _next;
  String? _scope, _relation, _error, _countError;
  int _generation = 0, _countGeneration = 0, _pageGeneration = 0;
  bool _loading = true, _more = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.watch<AuthService>().currentUserModel;
    final scope = '${user?.uid}/${user?.partnerUid}/${user?.relationshipId}';
    if (scope != _scope) {
      _scope = scope;
      _relation = user?.partnerUid == null ? null : user?.relationshipId;
      _type = null;
      _listen();
    }
  }

  bool _valid(int generation) => mounted && generation == _generation;
  void _listen() {
    _subscription?.cancel();
    final generation = ++_generation;
    _countGeneration++;
    _rows.clear();
    _next = null;
    _counts = null;
    _error = null;
    _countError = null;
    _loading = _relation != null;
    _more = false;
    final relation = _relation;
    if (relation == null) return;
    _subscription = _service
        .watch(relation, type: _type)
        .listen(
          (page) {
            if (!_valid(generation)) return;
            _pageGeneration++;
            setState(() {
              _rows
                ..clear()
                ..addAll(page.items);
              _next = page.next;
              _loading = false;
              _more = false;
              _error = null;
            });
            _loadCounts(relation, generation);
          },
          onError: (Object error) {
            if (!_valid(generation)) return;
            _countGeneration++;
            _pageGeneration++;
            setState(() {
              _rows.clear();
              _counts = null;
              _next = null;
              _loading = false;
              _more = false;
              _error =
                  'As atividades não estão confirmadas. Verifique a conexão e o vínculo.';
            });
          },
        );
  }

  Future<void> _loadCounts(String relation, int generation) async {
    final countGeneration = ++_countGeneration;
    setState(() {
      _counts = null;
      _countError = null;
    });
    try {
      final counts = await _service.counts(relation);
      if (_valid(generation) && countGeneration == _countGeneration) {
        setState(() => _counts = counts);
      }
    } catch (_) {
      if (_valid(generation) && countGeneration == _countGeneration) {
        setState(
          () => _countError =
              'Totais indisponíveis. Há falha de conexão ou experiências antigas ainda sem índice.',
        );
      }
    }
  }

  Future<void> _loadMore() async {
    if (_more || _next == null || _relation == null) return;
    final generation = _generation,
        pageGeneration = _pageGeneration,
        cursor = _next!;
    setState(() => _more = true);
    try {
      final page = await _service.page(_relation!, type: _type, after: cursor);
      if (!_valid(generation) || pageGeneration != _pageGeneration) return;
      setState(() {
        final ids = _rows.map((e) => e.id).toSet();
        _rows.addAll(page.items.where((e) => ids.add(e.id)));
        _next = page.next;
        _error = null;
      });
    } catch (_) {
      if (_valid(generation) && pageGeneration == _pageGeneration) {
        _countGeneration++;
        setState(() {
          _rows.clear();
          _counts = null;
          _next = null;
          _error =
              'Não foi possível confirmar as atividades. Atualize para tentar novamente.';
        });
      }
    } finally {
      if (_valid(generation) && pageGeneration == _pageGeneration) {
        setState(() => _more = false);
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    _countGeneration++;
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ReadingPage(
    child: Scaffold(
      appBar: AppBar(title: const Text('Atividades do casal')),
      body: _relation == null
          ? const ContentState(
              title: 'Nenhum vínculo consentido ativo',
              message: 'Experiências anteriores continuam no histórico em Nós.',
            )
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  'Experiências confirmadas pelos dois',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Cada experiência conta uma vez na revisão atual. Livros, filmes, episódios, faixas e álbuns têm contagens separadas. Isso não representa progresso pessoal.',
                ),
                if (_countError != null)
                  Semantics(liveRegion: true, child: Text(_countError!)),
                if (_counts != null)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final type in MediaType.values)
                        Chip(
                          label: Text('${mediaLabel(type)}: ${_counts![type]}'),
                        ),
                    ],
                  ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Todas as mídias'),
                      selected: _type == null,
                      onSelected: (_) => setState(() {
                        _type = null;
                        _listen();
                      }),
                    ),
                    for (final type in MediaType.values)
                      ChoiceChip(
                        label: Text(mediaLabel(type)),
                        selected: _type == type,
                        onSelected: (_) => setState(() {
                          _type = type;
                          _listen();
                        }),
                      ),
                  ],
                ),
                TextButton(
                  onPressed: () => setState(_listen),
                  child: const Text('Atualizar atividades'),
                ),
                if (_loading || _more)
                  const LinearProgressIndicator(
                    semanticsLabel: 'Carregando atividades',
                  ),
                if (_error != null)
                  Semantics(liveRegion: true, child: Text(_error!)),
                if (!_loading && _error == null && _rows.isEmpty)
                  const Text('Nenhuma experiência nesta categoria.'),
                for (final row in _rows)
                  Card(
                    child: ListTile(
                      title: Text(row.selection.title),
                      subtitle: Text(
                        '${mediaLabel(row.selection.type)} · ${row.confirmed ? 'Confirmada pelos dois' : 'Aguardando confirmação da revisão atual'}\n${DateFormat('dd/MM/yyyy').format(DateTime.parse(row.occurredOn))}${row.selection.episode == null ? '' : ' · Temporada ${row.selection.episode!['season']}, episódio ${row.selection.episode!['number']}'}',
                      ),
                    ),
                  ),
                if (_next != null)
                  TextButton(
                    onPressed: _more ? null : _loadMore,
                    child: const Text('Carregar mais atividades'),
                  ),
                const SizedBox(height: 16),
                const Text(
                  'A lista mostra a última atualização de cada experiência consentida. Favoritos e escutas pessoais permanecem privados; a ocultação da biblioteca não retira uma seleção compartilhada com consentimento.',
                ),
              ],
            ),
    ),
  );
}
