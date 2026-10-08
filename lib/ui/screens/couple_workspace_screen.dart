import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/couple_record.dart';
import '../../data/models/media_model.dart';
import '../../services/auth_service.dart';
import '../../services/couple_workspace_service.dart';
import '../widgets/content_state.dart';
import '../widgets/completion_date_picker.dart';
import '../widgets/dialog_with_controllers.dart';

class CoupleWorkspaceScreen extends StatefulWidget {
  const CoupleWorkspaceScreen({super.key, this.service});
  final CoupleWorkspaceService? service;
  @override
  State<CoupleWorkspaceScreen> createState() => _CoupleWorkspaceScreenState();
}

class _CoupleWorkspaceScreenState extends State<CoupleWorkspaceScreen> {
  late final _service = widget.service ?? CoupleWorkspaceService();
  String? _selected, _scope, _list;
  bool _busy = false;
  String? _error;
  Future<void> Function()? _retryAction;
  Stream<List<Map<String, dynamic>>>? _history;
  Stream<List<CoupleRecord>>? _lists, _items, _experiences;
  Future<Map<String, dynamic>>? _relationship;
  static const _labels = {
    MediaType.book: 'Livro',
    MediaType.movie: 'Filme',
    MediaType.series: 'Série',
    MediaType.track: 'Faixa',
    MediaType.album: 'Álbum',
  };

  void _select(String id) {
    _selected = id;
    _list = null;
    _items = null;
    _relationship = _service.relationship(id);
    _lists = _service.records(id, 'lists');
    _experiences = _service.records(id, 'experiences');
    _error = null;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final scope = _scope;
    try {
      await action();
      if (mounted && scope == _scope) _retryAction = null;
      if (mounted && scope == _scope) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Alteração confirmada.')));
      }
    } catch (error) {
      if (mounted && scope == _scope) {
        _retryAction = error is CoupleConflict ? null : action;
      }
      if (mounted && scope == _scope) {
        setState(
          () => _error = error is CoupleConflict
              ? 'Outra pessoa alterou este registro. Releia a proposta antes de tentar novamente.'
              : 'Não foi possível confirmar. Verifique a conexão e tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createList(String uid, String relation) async {
    final scope = _scope;
    final title = TextEditingController();
    final result = await showDialogWithControllers<String>(
      context: context,
      controllers: [title],
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Nova lista do casal'),
        content: TextField(
          controller: title,
          maxLength: 150,
          decoration: const InputDecoration(labelText: 'Nome da lista'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (title.text.trim().isNotEmpty) {
                Navigator.pop(context, title.text.trim());
              }
            },
            child: const Text('Criar'),
          ),
        ],
      ),
    );
    if (mounted && result != null && scope == _scope) {
      final id = _service.newId();
      await _run(() => _service.createList(uid, relation, id, result));
    }
  }

  Future<void> _selection(
    String uid,
    String relation, {
    String? listId,
    CoupleRecord? previous,
  }) async {
    final scope = _scope;
    final title = TextEditingController(text: previous?.selection.title);
    final subtitle = TextEditingController(text: previous?.selection.subtitle);
    final season = TextEditingController(
      text: previous?.selection.episode?['season']?.toString(),
    );
    final episode = TextEditingController(
      text: previous?.selection.episode?['number']?.toString(),
    );
    String? dateError;
    var type = previous?.selection.type ?? MediaType.book;
    DateTime? date = previous == null
        ? null
        : DateTime.parse(previous.occurredOn);
    final form = GlobalKey<FormState>();
    final result = await showDialogWithControllers<(CoupleSelection, DateTime?)>(
      context: context,
      controllers: [title, subtitle, season, episode],
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          scrollable: true,
          title: Text(
            listId != null
                ? 'Adicionar seleção'
                : previous == null
                ? 'Propor experiência'
                : 'Corrigir proposta',
          ),
          content: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Esta seleção será visível para os dois e permanecerá no histórico após o término. Não altera nem revela seu progresso pessoal, mesmo se a obra estiver oculta.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<MediaType>(
                  initialValue: type,
                  isExpanded: true,
                  items: [
                    for (final t in MediaType.values)
                      DropdownMenuItem(value: t, child: Text(_labels[t]!)),
                  ],
                  onChanged: (value) => update(() => type = value!),
                  decoration: const InputDecoration(labelText: 'Mídia'),
                ),
                TextFormField(
                  controller: title,
                  maxLength: 300,
                  decoration: const InputDecoration(labelText: 'Título'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Informe o título.'
                      : null,
                ),
                TextFormField(
                  controller: subtitle,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText:
                        'Autor ou artista (opcional para livros, filmes e séries)',
                  ),
                  validator: (v) =>
                      (type == MediaType.track || type == MediaType.album) &&
                          (v == null || v.trim().isEmpty)
                      ? 'Informe o artista.'
                      : null,
                ),
                if (listId == null)
                  if (type == MediaType.series) ...[
                    const Text(
                      'Para um episódio específico, informe temporada e número. O título do episódio não será compartilhado.',
                    ),
                    TextFormField(
                      controller: season,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Temporada (opcional)',
                      ),
                      validator: (v) =>
                          (episode.text.isNotEmpty ||
                                  (v?.isNotEmpty ?? false)) &&
                              (int.tryParse(v ?? '') == null ||
                                  int.parse(v!) < 0)
                          ? 'Informe uma temporada válida.'
                          : null,
                    ),
                    TextFormField(
                      controller: episode,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Número do episódio (opcional)',
                      ),
                      validator: (v) =>
                          (season.text.isNotEmpty ||
                                  (v?.isNotEmpty ?? false)) &&
                              (int.tryParse(v ?? '') == null ||
                                  int.parse(v!) < 1)
                          ? 'Informe um episódio válido.'
                          : null,
                    ),
                  ],
                if (dateError != null)
                  Text(
                    dateError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (listId == null)
                  OutlinedButton(
                    onPressed: () async {
                      final picked = await showCompletionDatePicker(
                        context,
                        initialDate: date,
                        helpText: 'Quando aconteceu a experiência?',
                        fieldLabelText: 'Data da experiência',
                      );
                      if (context.mounted && picked != null) {
                        update(() => date = picked);
                      }
                    },
                    child: Text(
                      date == null
                          ? 'Escolher data da experiência'
                          : 'Data: ${date!.day}/${date!.month}/${date!.year}',
                    ),
                  ),
                if (listId == null)
                  const Text(
                    'Você confirma a proposta ao salvar. Seu parceiro precisa confirmar esta versão separadamente.',
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (listId == null && date == null) {
                  update(() => dateError = 'Escolha a data da experiência.');
                }
                if (form.currentState!.validate() &&
                    (listId != null || date != null)) {
                  Navigator.pop(context, (
                    CoupleSelection(
                      type: type,
                      title: title.text,
                      subtitle: subtitle.text,
                      source: previous?.selection.source ?? 'manual',
                      reference: previous?.selection.reference,
                      episode:
                          type == MediaType.series &&
                              season.text.isNotEmpty &&
                              episode.text.isNotEmpty
                          ? {
                              'id':
                                  previous?.selection.episode?['season'] ==
                                          int.tryParse(season.text) &&
                                      previous?.selection.episode?['number'] ==
                                          int.tryParse(episode.text)
                                  ? previous!.selection.episode!['id']
                                  : _service.newId(),
                              'season': int.parse(season.text),
                              'number': int.parse(episode.text),
                            }
                          : null,
                    ),
                    date,
                  ));
                }
              },
              child: const Text('Compartilhar seleção'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || result == null || scope != _scope) return;
    final id = previous?.id ?? _service.newId();
    await _run(
      () => listId != null
          ? _service.addItem(uid, relation, listId, id, result.$1)
          : _service.propose(
              uid,
              relation,
              id,
              result.$1,
              result.$2!,
              previous: previous,
            ),
    );
  }

  Widget _records(
    Stream<List<CoupleRecord>>? stream,
    Widget Function(List<CoupleRecord>) builder,
  ) => StreamBuilder<List<CoupleRecord>>(
    stream: stream,
    key: ValueKey(stream),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Text(
          'Conteúdo indisponível. Use Atualizar para tentar novamente.',
        );
      }
      if (!snapshot.hasData) {
        return const ContentState(
          title: 'Carregando conteúdo conjunto',
          loading: true,
        );
      }
      return builder(snapshot.data!);
    },
  );

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUserModel;
    if (user == null) {
      return const ContentState(title: 'Carregando conta', loading: true);
    }
    final scope = '${user.uid}/${user.partnerUid}/${user.relationshipId}';
    if (_scope != scope) {
      _retryAction = null;
      _error = null;
      _scope = scope;
      _selected = null;
      _lists = null;
      _items = null;
      _experiences = null;
      _history = _service.history(user.uid);
      if (user.relationshipId != null) _select(user.relationshipId!);
    }
    final relation = _selected;
    final active =
        relation != null &&
        relation == user.relationshipId &&
        user.partnerUid != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Listas e experiências'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _busy
                ? null
                : () => setState(() {
                    _history = _service.history(user.uid);
                    if (relation != null) _select(relation);
                  }),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_busy) const LinearProgressIndicator(),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _history,
              key: ValueKey(_history),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text(
                    'Histórico indisponível. Tente atualizar com conexão.',
                  );
                }
                final ids = {
                  if (user.relationshipId != null) user.relationshipId!,
                  ...?snapshot.data?.map((r) => r['id'] as String),
                };
                return Wrap(
                  spacing: 8,
                  children: [
                    for (final id in ids)
                      ChoiceChip(
                        label: Text(
                          id == user.relationshipId
                              ? 'Vínculo atual'
                              : 'Histórico ${ids.toList().indexOf(id) + 1}',
                        ),
                        selected: relation == id,
                        onSelected: _busy
                            ? null
                            : (_) => setState(() => _select(id)),
                      ),
                  ],
                );
              },
            ),
            if (_retryAction != null)
              TextButton(
                onPressed: _busy ? null : () => _run(_retryAction!),
                child: const Text('Repetir alteração'),
              ),
            if (relation == null)
              const Text(
                'Um convite aceito habilita listas e experiências. Seus vínculos anteriores com conteúdo conjunto aparecem aqui.',
              ),
            if (relation != null)
              FutureBuilder<Map<String, dynamic>>(
                future: _relationship,
                key: ValueKey(_relationship),
                builder: (context, snapshot) => snapshot.hasData
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          '${snapshot.data!['senderName']} e ${snapshot.data!['recipientName']} · ${active ? "vínculo atual" : "histórico: somente leitura e retirada da própria confirmação"}',
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            if (relation != null) ...[
              Text(
                'Listas do casal',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (active)
                TextButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _createList(user.uid, relation),
                  icon: const Icon(Icons.add),
                  label: const Text('Nova lista'),
                ),
              _records(
                _lists,
                (rows) => Column(
                  children: [
                    if (rows.isEmpty) const Text('Nenhuma lista criada.'),
                    for (final row in rows)
                      ListTile(
                        title: Text(row.data['title']),
                        subtitle: Text(
                          row.author == user.uid
                              ? 'Criada por você'
                              : 'Criada pelo parceiro',
                        ),
                        selected: _list == row.id,
                        onTap: () => setState(() {
                          _list = row.id;
                          _items = _service.records(
                            relation,
                            'items',
                            listId: row.id,
                          );
                        }),
                      ),
                  ],
                ),
              ),
              if (_list != null) ...[
                if (active)
                  TextButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _selection(user.uid, relation, listId: _list),
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar seleção à lista'),
                  ),
                _records(
                  _items,
                  (rows) => Column(
                    children: [
                      if (rows.where((r) => r.data['removed'] != true).isEmpty)
                        const Text('Lista vazia.'),
                      for (final row in rows.where(
                        (r) => r.data['removed'] != true,
                      ))
                        ListTile(
                          title: Text(row.selection.title),
                          subtitle: Text(
                            '${_labels[row.selection.type]} · ${row.selection.subtitle}\nIncluída ${row.author == user.uid ? "por você" : "pelo parceiro"}',
                          ),
                          trailing: active
                              ? IconButton(
                                  tooltip: 'Retirar seleção',
                                  onPressed: _busy
                                      ? null
                                      : () => _run(
                                          () => _service.removeItem(
                                            user.uid,
                                            relation,
                                            _list!,
                                            row,
                                          ),
                                        ),
                                  icon: const Icon(Icons.remove_circle_outline),
                                )
                              : null,
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                'Experiências',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (active)
                TextButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _selection(user.uid, relation),
                  icon: const Icon(Icons.add),
                  label: const Text('Propor experiência'),
                ),
              _records(
                _experiences,
                (rows) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${rows.where((r) => r.confirmed).length} experiências confirmadas pelos dois',
                    ),
                    if (rows.isEmpty)
                      const Text('Nenhuma experiência proposta.'),
                    for (final row in rows)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row.selection.title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                '${_labels[row.selection.type]} · ${row.occurredOn.split('-').reversed.join('/')} · versão ${row.revision}',
                              ),
                              if (row.selection.episode != null)
                                Text(
                                  'Temporada ${row.selection.episode!['season']} · episódio ${row.selection.episode!['number']}',
                                ),
                              Text(
                                row.author == user.uid
                                    ? 'Proposta por você'
                                    : 'Proposta pelo parceiro',
                              ),
                              Text(
                                row.confirmed
                                    ? 'Confirmada pelos dois'
                                    : 'Ainda sem duas confirmações desta versão',
                              ),
                              Text(
                                row.responses[user.uid]?['revision'] !=
                                        row.revision
                                    ? 'Sua resposta: pendente para esta versão'
                                    : 'Sua resposta: ${switch (row.responses[user.uid]?['decision']) {
                                        'confirmed' => 'confirmada',
                                        'declined' => 'recusada',
                                        'withdrawn' => 'retirada',
                                        _ => 'pendente',
                                      }}',
                              ),
                              Wrap(
                                spacing: 8,
                                children: [
                                  if (active) ...[
                                    TextButton(
                                      onPressed: _busy
                                          ? null
                                          : () => _run(
                                              () => _service.respond(
                                                user.uid,
                                                relation,
                                                row,
                                                'confirmed',
                                              ),
                                            ),
                                      child: const Text('Confirmar versão'),
                                    ),
                                    TextButton(
                                      onPressed: _busy
                                          ? null
                                          : () => _run(
                                              () => _service.respond(
                                                user.uid,
                                                relation,
                                                row,
                                                'declined',
                                              ),
                                            ),
                                      child: const Text('Recusar'),
                                    ),
                                  ],
                                  TextButton(
                                    onPressed: _busy
                                        ? null
                                        : () => _run(
                                            () => _service.respond(
                                              user.uid,
                                              relation,
                                              row,
                                              'withdrawn',
                                            ),
                                          ),
                                    child: const Text(
                                      'Retirar minha confirmação',
                                    ),
                                  ),
                                  if (active && row.author == user.uid)
                                    TextButton(
                                      onPressed: _busy
                                          ? null
                                          : () => _selection(
                                              user.uid,
                                              relation,
                                              previous: row,
                                            ),
                                      child: const Text('Corrigir proposta'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
