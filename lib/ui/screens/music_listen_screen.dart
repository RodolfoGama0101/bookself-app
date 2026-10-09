import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/music_record.dart';
import '../../data/models/couple_record.dart';
import '../../services/auth_service.dart';
import '../../services/music_listen_service.dart';
import '../../utils/error_handler.dart';
import '../widgets/completion_date_picker.dart';
import '../widgets/content_state.dart';

class MusicListenScreen extends StatefulWidget {
  const MusicListenScreen({
    super.key,
    required this.music,
    required this.service,
  });
  final MusicRecord music;
  final MusicListenService service;
  @override
  State<MusicListenScreen> createState() => _MusicListenScreenState();
}

class _MusicListenScreenState extends State<MusicListenScreen> {
  DateTime? _date;
  String? _id, _error;
  bool _busy = false;
  bool get _current =>
      mounted &&
      context.read<AuthService>().currentUserModel?.uid ==
          widget.music.entry.ownerId;
  Future<void> _save() async {
    if (!_current || _busy || _date == null) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _id ??= widget.service.newId(widget.music.entry.ownerId);
      await widget.service.save(
        widget.music.entry.ownerId,
        widget.music.entry.id,
        _id!,
        coupleDate(_date!),
      );
      if (mounted && _current) {
        Navigator.pop(context, true);
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

  @override
  Widget build(BuildContext context) {
    context.watch<AuthService>();
    if (!_current) {
      return const Scaffold(
        body: ContentState(
          title: 'Sua conta mudou',
          message: 'Volte à Biblioteca.',
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar escuta pessoal')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            widget.music.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(widget.music.artists),
          const SizedBox(height: 16),
          const Text(
            'Esta escuta é privada. Outra escuta, mesmo na mesma data, exige um novo registro. Ouvir um álbum não marca suas faixas.',
          ),
          OutlinedButton.icon(
            onPressed: _busy || _id != null
                ? null
                : () async {
                    final date = await showCompletionDatePicker(
                      context,
                      initialDate: _date,
                      helpText: 'Quando você ouviu?',
                      fieldLabelText: 'Data da escuta',
                    );
                    if (_current && date != null) {
                      setState(() => _date = date);
                    }
                  },
            icon: const Icon(Icons.calendar_month),
            label: Text(
              _date == null ? 'Escolher data da escuta' : coupleDate(_date!),
            ),
          ),
          if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
          if (_id != null && _error != null)
            const Text(
              'Tentar novamente conserva esta escuta e evita duplicatas.',
            ),
          FilledButton(
            onPressed: _busy || _date == null ? null : _save,
            child: Text(
              _busy
                  ? 'Confirmando escuta…'
                  : _id == null
                  ? 'Salvar escuta'
                  : 'Tentar novamente',
            ),
          ),
        ],
      ),
    );
  }
}
