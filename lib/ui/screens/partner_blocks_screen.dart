import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../widgets/reading_surface.dart';

class PartnerBlocksScreen extends StatefulWidget {
  const PartnerBlocksScreen({super.key});

  @override
  State<PartnerBlocksScreen> createState() => _PartnerBlocksScreenState();
}

class _PartnerBlocksScreenState extends State<PartnerBlocksScreen> {
  AuthService? _auth;
  String? _uid;
  Stream<Map<String, String>>? _contacts;
  Stream<Map<String, String>>? _blocks;
  bool _pending = false;
  bool _saving = false;
  String? _error;
  int _revision = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthService>();
    final uid = auth.currentUserModel?.uid;
    if (identical(auth, _auth) && uid == _uid) return;
    _auth = auth;
    _uid = uid;
    _reload();
  }

  void _reload() {
    _revision++;
    _pending = false;
    _saving = false;
    _error = null;
    _contacts = _uid == null ? null : _auth!.watchContacts();
    _blocks = _uid == null ? null : _auth!.watchBlocks();
  }

  Future<void> _change(String other, String name, bool blocked) async {
    if (_pending || _auth!.isLoading) return;
    final revision = _revision;
    final relationship = _auth!.currentUserModel?.relationshipId;
    final partner = _auth!.currentUserModel?.partnerUid;
    setState(() => _pending = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(blocked ? 'Desbloquear $name?' : 'Bloquear $name?'),
        content: Text(
          blocked
              ? 'Seu bloqueio será removido. O bloqueio da outra pessoa, se houver, continuará valendo. Para se vincular, vocês precisam de um novo convite.'
              : 'Novos convites entre vocês serão impedidos. Se esta pessoa for seu parceiro atual, o vínculo será encerrado. Seus registros pessoais serão preservados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(blocked ? 'Desbloquear' : 'Bloquear'),
          ),
        ],
      ),
    );
    if (!mounted || revision != _revision) return;
    if (confirmed != true) {
      setState(() => _pending = false);
      return;
    }
    if (partner != _auth!.currentUserModel?.partnerUid ||
        relationship != _auth!.currentUserModel?.relationshipId) {
      setState(() {
        _pending = false;
        _error = 'O vínculo mudou. Confira a pessoa novamente.';
      });
      return;
    }
    String? error;
    setState(() => _saving = true);
    try {
      error = blocked
          ? await _auth!.unblockPartner(other)
          : await _auth!.blockKnownPerson(other);
    } catch (_) {
      error = 'Não foi possível atualizar o bloqueio. Tente novamente.';
    }
    if (!mounted || revision != _revision) return;
    setState(() {
      _pending = false;
      _saving = false;
      _error = error;
    });
    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            blocked
                ? 'Pessoa desbloqueada. Um novo convite é necessário para se vincular.'
                : 'Pessoa bloqueada.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    return ReadingPage(
      maxWidth: 720,
      child: Scaffold(
        appBar: AppBar(title: const Text('Pessoas e bloqueios')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Aqui aparecem pessoas com quem você reservou um convite ou encerrou um vínculo neste app. Apenas você pode consultar esta lista.',
            ),
            const SizedBox(height: 20),
            if (_uid == null)
              const Text('Entre novamente para continuar.')
            else
              StreamBuilder<Map<String, String>>(
                key: ValueKey('contacts/$_uid/$_revision'),
                stream: _contacts,
                builder: (context, contacts) => StreamBuilder<Map<String, String>>(
                  key: ValueKey('blocks/$_uid/$_revision'),
                  stream: _blocks,
                  builder: (context, blocks) {
                    if (contacts.hasError || blocks.hasError) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Não foi possível carregar as pessoas e os bloqueios. Confira sua conexão.',
                          ),
                          TextButton(
                            onPressed: _pending
                                ? null
                                : () => setState(_reload),
                            child: const Text('Tentar novamente'),
                          ),
                        ],
                      );
                    }
                    if (!contacts.hasData || !blocks.hasData) {
                      return const LinearProgressIndicator();
                    }
                    final people = {...contacts.data!, ...blocks.data!};
                    final entries = people.entries.toList()
                      ..sort((a, b) => a.value.compareTo(b.value));
                    if (entries.isEmpty) {
                      return const Text(
                        'Nenhuma pessoa disponível para bloquear.',
                      );
                    }
                    return Column(
                      children: [
                        for (final person in entries)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ReadingSurface(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    person.value,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  Text(
                                    blocks.data!.containsKey(person.key)
                                        ? 'Bloqueada por você'
                                        : 'Pessoa conhecida',
                                  ),
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    onPressed: _pending || auth.isLoading
                                        ? null
                                        : () => _change(
                                            person.key,
                                            person.value,
                                            blocks.data!.containsKey(
                                              person.key,
                                            ),
                                          ),
                                    icon: Icon(
                                      blocks.data!.containsKey(person.key)
                                          ? Icons.lock_open
                                          : Icons.block,
                                    ),
                                    label: Text(
                                      blocks.data!.containsKey(person.key)
                                          ? 'Desbloquear'
                                          : 'Bloquear',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            if (_saving) const LinearProgressIndicator(),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    );
  }
}
