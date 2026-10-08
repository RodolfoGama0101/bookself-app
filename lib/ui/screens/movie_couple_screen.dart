import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/couple_record.dart';
import '../../data/models/movie_record.dart';
import '../../services/auth_service.dart';
import '../../services/couple_workspace_service.dart';
import '../widgets/content_state.dart';
import '../widgets/completion_date_picker.dart';

class MovieCoupleScreen extends StatefulWidget {
  const MovieCoupleScreen({
    super.key,
    required this.movie,
    required this.relation,
    required this.experience,
    this.service,
  });
  final MovieRecord movie;
  final String relation;
  final bool experience;
  final CoupleWorkspaceService? service;
  @override
  State<MovieCoupleScreen> createState() => _MovieCoupleScreenState();
}

class _MovieCoupleScreenState extends State<MovieCoupleScreen> {
  late final _service = widget.service ?? CoupleWorkspaceService();
  late final _lists = _service.records(widget.relation, 'lists');
  String? _list, _id, _error;
  DateTime? _date;
  bool _consent = false, _busy = false;
  bool get _active {
    if (!mounted) return false;
    final user = context.read<AuthService>().currentUserModel;
    return mounted &&
        user?.uid == widget.movie.entry.ownerId &&
        user?.partnerUid != null &&
        user?.relationshipId == widget.relation;
  }

  Future<void> _save() async {
    if (!_active ||
        _busy ||
        !_consent ||
        (widget.experience ? _date == null : _list == null)) {
      return;
    }
    final id = _id ??= _service.newId();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.experience) {
        await _service.propose(
          widget.movie.entry.ownerId,
          widget.relation,
          id,
          widget.movie.selection,
          _date!,
        );
      } else {
        await _service.addItem(
          widget.movie.entry.ownerId,
          widget.relation,
          _list!,
          id,
          widget.movie.selection,
        );
      }
      if (mounted && _active) Navigator.pop(context, true);
    } catch (_) {
      if (_active) {
        setState(
          () => _error =
              'Não foi possível confirmar. Verifique a conexão e o vínculo e tente novamente.',
        );
      }
    } finally {
      if (_active) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AuthService>();
    if (!_active) {
      return const Scaffold(
        body: ContentState(
          title: 'O vínculo mudou',
          message: 'Volte à Biblioteca. Seu filme pessoal foi preservado.',
        ),
      );
    }
    final locked = _busy || _id != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.experience
              ? 'Propor sessão do casal'
              : 'Adicionar à lista do casal',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            widget.movie.title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(widget.movie.year?.toString() ?? 'Ano não informado'),
          const SizedBox(height: 16),
          const Text(
            'Compartilhar esta seleção envia o título, ano e referência da obra. Seu status e data pessoais continuam independentes.',
          ),
          if (widget.experience) ...[
            const Text(
              'A sessão só fica confirmada após o aceite dos dois em Nós → Listas e experiências. Isso não marca filmes como assistidos.',
            ),
            OutlinedButton.icon(
              onPressed: locked
                  ? null
                  : () async {
                      final picked = await showCompletionDatePicker(
                        context,
                        initialDate: _date,
                        helpText: 'Quando aconteceu a sessão?',
                        fieldLabelText: 'Data da sessão',
                      );
                      if (_active && picked != null) {
                        setState(() => _date = picked);
                      }
                    },
              icon: const Icon(Icons.calendar_month),
              label: Text(
                _date == null
                    ? 'Escolher data da sessão'
                    : '${_date!.day.toString().padLeft(2, '0')}/${_date!.month.toString().padLeft(2, '0')}/${_date!.year}',
              ),
            ),
          ] else
            StreamBuilder<List<CoupleRecord>>(
              stream: _lists,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text(
                    'Não foi possível carregar as listas. Volte e tente novamente.',
                  );
                }
                if (!snapshot.hasData) return const LinearProgressIndicator();
                final lists = snapshot.data!;
                if (lists.isEmpty) {
                  return const Text(
                    'Crie uma lista em Nós → Listas e experiências antes de adicionar um filme.',
                  );
                }
                return Column(
                  children: [
                    for (final list in lists)
                      ListTile(
                        title: Text(list.data['title'] as String),
                        selected: _list == list.id,
                        leading: Icon(
                          _list == list.id ? Icons.check_circle : Icons.list,
                        ),
                        onTap: locked
                            ? null
                            : () => setState(() => _list = list.id),
                      ),
                  ],
                );
              },
            ),
          CheckboxListTile(
            value: _consent,
            onChanged: locked
                ? null
                : (value) => setState(() => _consent = value!),
            title: const Text(
              'Quero compartilhar esta seleção com meu parceiro.',
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          FilledButton(
            onPressed:
                _busy ||
                    !_consent ||
                    (widget.experience ? _date == null : _list == null)
                ? null
                : _save,
            child: Text(
              _busy
                  ? 'Confirmando…'
                  : _id != null
                  ? 'Tentar novamente'
                  : widget.experience
                  ? 'Propor sessão'
                  : 'Adicionar à lista',
            ),
          ),
        ],
      ),
    );
  }
}
