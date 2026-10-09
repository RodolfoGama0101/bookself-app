import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/series_record.dart';
import '../../services/auth_service.dart';
import '../../services/series_sharing_service.dart';
import '../widgets/content_state.dart';
import '../widgets/reading_surface.dart';

class SeriesComparisonScreen extends StatefulWidget {
  const SeriesComparisonScreen({
    super.key,
    required this.series,
    required this.partner,
    required this.relation,
    this.service,
  });
  final SeriesRecord series;
  final String partner, relation;
  final SeriesSharingService? service;
  @override
  State<SeriesComparisonScreen> createState() => _SeriesComparisonScreenState();
}

class _SeriesComparisonScreenState extends State<SeriesComparisonScreen> {
  late final _service = widget.service ?? SeriesSharingService();
  late final _series = _service.series(widget.partner);
  SharedSeries? _selected;
  Stream<List<SeriesEpisode>>? _episodes;
  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUserModel;
    if (user?.uid != widget.series.entry.ownerId ||
        user?.partnerUid != widget.partner ||
        user?.relationshipId != widget.relation) {
      return const Scaffold(
        body: ContentState(
          title: 'O vínculo mudou',
          message: 'Seu progresso pessoal foi preservado.',
        ),
      );
    }
    return ReadingPage(
      child: Scaffold(
        appBar: AppBar(title: const Text('Comparar episódios')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              widget.series.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text(
              'Escolha a série compartilhada pelo parceiro. A comparação mostra somente números e marcações; nenhum título ou sinopse de episódio.',
            ),
            StreamBuilder<List<SharedSeries>>(
              stream: _series,
              builder: (context, s) {
                if (s.hasError) {
                  return const ContentState(
                    title: 'Compartilhamento indisponível',
                    message:
                        'Verifique a conexão e o vínculo. Volte e tente novamente.',
                  );
                }
                if (!s.hasData) return const LinearProgressIndicator();
                if (s.data!.isEmpty) {
                  return const Text(
                    'Nenhuma série compartilhada pelo parceiro.',
                  );
                }
                return Column(
                  children: [
                    for (final item in s.data!)
                      ListTile(
                        title: Text(item.title),
                        selected: _selected?.id == item.id,
                        leading: Icon(
                          _selected?.id == item.id
                              ? Icons.check_circle
                              : Icons.tv_outlined,
                        ),
                        onTap: () => setState(() {
                          _selected = item;
                          _episodes = _service.episodes(
                            widget.partner,
                            item.id,
                          );
                        }),
                      ),
                    if (_selected != null &&
                        s.data!.any((e) => e.id == _selected!.id))
                      StreamBuilder<List<SeriesEpisode>>(
                        key: ValueKey(_selected!.id),
                        stream: _episodes,
                        builder: (context, p) {
                          if (p.hasError) {
                            return const Text(
                              'Progresso indisponível. A série pode ter sido ocultada ou o vínculo encerrado.',
                            );
                          }
                          if (!p.hasData) {
                            return const LinearProgressIndicator();
                          }
                          if (p.data!.isEmpty) {
                            return const Text(
                              'O parceiro ainda não cadastrou episódios.',
                            );
                          }
                          return Column(
                            children: [
                              const Text(
                                'Cadastros manuais são comparados pela numeração escolhida, sem confirmar que sejam a mesma edição.',
                              ),
                              for (final e in p.data!)
                                Builder(
                                  builder: (context) {
                                    final exact =
                                        _selected!.reference ==
                                        widget.series.catalog.identity.key;
                                    final own = widget.series.progress.episodes
                                        .where(
                                          (x) => exact
                                              ? x.id == e.id
                                              : (x.season == e.season &&
                                                    x.number == e.number),
                                        )
                                        .firstOrNull;
                                    return ListTile(
                                      title: Text(e.label),
                                      subtitle: Text(
                                        'Você: ${own == null
                                            ? 'não cadastrado'
                                            : own.watched
                                            ? 'visto'
                                            : 'não visto'} · Parceiro: ${e.watched ? 'visto' : 'não visto'}',
                                      ),
                                    );
                                  },
                                ),
                            ],
                          );
                        },
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
