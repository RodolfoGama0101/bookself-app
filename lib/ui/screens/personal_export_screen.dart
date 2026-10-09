import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/personal_export_service.dart';
import '../widgets/reading_surface.dart';

class PersonalExportScreen extends StatefulWidget {
  const PersonalExportScreen({super.key, this.service});
  final PersonalExportService? service;
  @override
  State<PersonalExportScreen> createState() => _PersonalExportScreenState();
}

class _PersonalExportScreenState extends State<PersonalExportScreen> {
  late final _service = widget.service ?? PersonalExportService();
  String? _json, _owner, _error;
  bool _busy = false;
  int _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = context.watch<AuthService>().currentUserModel?.uid;
    if (uid != _owner) {
      _owner = uid;
      _json = null;
      _error = null;
      _busy = false;
      _generation++;
    }
  }

  bool _valid(String owner, int generation) =>
      mounted &&
      _owner == owner &&
      _generation == generation &&
      context.read<AuthService>().currentUserModel?.uid == owner;

  Future<void> _generate() async {
    final owner = _owner;
    if (_busy || owner == null) return;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _json = null;
      _error = null;
    });
    try {
      final json = await _service.export(owner);
      if (_valid(owner, generation)) setState(() => _json = json);
    } catch (_) {
      if (_valid(owner, generation)) {
        setState(
          () => _error =
              'Não foi possível gerar a cópia. Confira a conexão e tente novamente.',
        );
      }
    } finally {
      if (_valid(owner, generation)) setState(() => _busy = false);
    }
  }

  Future<void> _copy() async {
    final owner = _owner, json = _json;
    final generation = _generation;
    if (owner == null || json == null || !_valid(owner, generation)) return;
    try {
      await Clipboard.setData(ClipboardData(text: json));
      if (mounted && _valid(owner, generation)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cópia enviada à área de transferência. Salve em um arquivo privado.',
            ),
          ),
        );
      }
    } catch (_) {
      if (_valid(owner, generation)) {
        setState(() => _error = 'Não foi possível copiar. Tente novamente.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => ReadingPage(
    maxWidth: 720,
    child: Scaffold(
      appBar: AppBar(title: const Text('Cópia dos meus dados')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Gere uma cópia pessoal em JSON do perfil, livros, progresso bíblico e biblioteca de filmes. Ela pode conter seu e-mail e foto. Guarde em local privado.',
          ),
          const SizedBox(height: 16),
          const Text(
            'Esta cópia é parcial: não inclui convites, bloqueios, atividades dos livros, listas ou experiências do casal. Não é um backup restaurável. Não altera nem exclui dados. Evite editar sua biblioteca durante a geração.',
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy || _owner == null ? null : _generate,
            child: Text(_busy ? 'Gerando cópia…' : 'Gerar cópia pessoal'),
          ),
          if (_busy)
            Semantics(
              label: 'Gerando cópia pessoal',
              liveRegion: true,
              child: LinearProgressIndicator(),
            ),
          if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
          if (_json != null) ...[
            Semantics(
              liveRegion: true,
              child: Text('Cópia pronta. Copie e salve como arquivo JSON.'),
            ),
            OutlinedButton.icon(
              onPressed: _copy,
              icon: const Icon(Icons.copy),
              label: const Text('Copiar JSON pessoal'),
            ),
            const Text(
              'A área de transferência pode ser acessada por outros aplicativos. Limpe-a depois de salvar.',
            ),
          ],
        ],
      ),
    ),
  );
}
