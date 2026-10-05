import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../data/models/partner_invitation.dart';
import '../../services/auth_service.dart';
import '../../utils/error_handler.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/reading_surface.dart';

class PartnerInvitationScreen extends StatefulWidget {
  const PartnerInvitationScreen({super.key});
  @override
  State<PartnerInvitationScreen> createState() =>
      _PartnerInvitationScreenState();
}

class _PartnerInvitationScreenState extends State<PartnerInvitationScreen> {
  final _code = TextEditingController();
  AuthService? _auth;
  String? _uid;
  StreamSubscription<PartnerInvitation?>? _ownSubscription;
  StreamSubscription<PartnerInvitation?>? _receivedSubscription;
  Timer? _timer;
  Timer? _loadTimer;
  PartnerInvitation? _own;
  PartnerInvitation? _received;
  String? _error;
  bool _loading = true;
  bool _pending = false;
  bool _consent = false;
  DateTime? _lastLookup;
  int _revision = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthService>();
    final uid = auth.currentUserModel?.uid;
    if (identical(auth, _auth) && uid == _uid) {
      return;
    }
    _revision++;
    _ownSubscription?.cancel();
    _receivedSubscription?.cancel();
    _auth = auth;
    _uid = uid;
    _own = _received = null;
    _code.clear();
    _consent = false;
    _pending = false;
    _lastLookup = null;
    _listenOwn();
    _timer ??= Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _listenOwn() {
    _loadTimer?.cancel();
    _loading = _uid != null;
    _error = null;
    if (_uid == null) {
      return;
    }
    final revision = _revision;
    _loadTimer = Timer(const Duration(seconds: 15), () {
      if (!mounted || revision != _revision || !_loading) return;
      setState(() {
        _loading = false;
        _error =
            'Não foi possível confirmar o convite. Verifique a conexão e tente novamente.';
      });
    });
    try {
      _ownSubscription = _auth!.watchOwnInvitation().listen(
        (invitation) {
          if (!mounted || revision != _revision) {
            return;
          }
          setState(() {
            _own = invitation;
            _loadTimer?.cancel();
            _loading = false;
            _error = null;
          });
        },
        onError: (Object error) {
          if (!mounted || revision != _revision) {
            return;
          }
          setState(() {
            _loading = false;
            _loadTimer?.cancel();
            _error =
                'Não foi possível carregar o convite. Verifique a conexão e tente novamente.';
          });
        },
      );
    } catch (error) {
      _loading = false;
      _error = 'Não foi possível carregar o convite. Tente novamente.';
    }
  }

  Future<void> _retry() async {
    await _ownSubscription?.cancel();
    if (!mounted) {
      return;
    }
    setState(_listenOwn);
  }

  Future<void> _run(
    Future<String?> Function() action, {
    String? success,
  }) async {
    if (_pending || _auth!.isLoading) {
      return;
    }
    final revision = _revision;
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      final error = await action();
      if (!mounted || revision != _revision) {
        return;
      }
      setState(() {
        _error = error;
        if (error == null) {
          _consent = false;
        }
      });
      if (error == null && success != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (error) {
      if (mounted && revision == _revision) {
        setState(() {
          _error = ErrorHandler.getFriendlyErrorMessage(
            error,
            operation: ErrorOperation.linkPartner,
          );
        });
      }
    } finally {
      if (mounted && revision == _revision) {
        setState(() {
          _pending = false;
        });
      }
    }
  }

  Future<String?> _lookup() async {
    final code = _code.text.trim();
    if (!PartnerInvitation.validCode(code)) {
      return 'Informe um código de convite válido.';
    }
    if (_lastLookup != null &&
        DateTime.now().difference(_lastLookup!) < const Duration(seconds: 5)) {
      return 'Aguarde alguns segundos antes de consultar outro código.';
    }
    _lastLookup = DateTime.now();
    final revision = _revision;
    final result = await _auth!.claimInvitation(code);
    if (!mounted || revision != _revision || result.error != null) {
      return result.error;
    }
    await _receivedSubscription?.cancel();
    if (!mounted || revision != _revision) {
      return null;
    }
    setState(() {
      _received = result.value;
      _consent = false;
    });
    _receivedSubscription = _auth!
        .watchInvitation(code)
        .listen(
          (invitation) {
            if (!mounted || revision != _revision) {
              return;
            }
            setState(() {
              _received = invitation;
            });
          },
          onError: (Object error) {
            if (!mounted || revision != _revision) {
              return;
            }
            setState(() {
              _received = null;
              _error =
                  'Convite indisponível. Confira o código e tente novamente.';
            });
          },
        );
    return null;
  }

  Future<void> _copy(String code) async {
    final revision = _revision;
    try {
      await Clipboard.setData(ClipboardData(text: code));
      if (!mounted || revision != _revision) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Convite copiado. Envie somente à pessoa que você quer convidar.',
          ),
        ),
      );
    } catch (error) {
      if (mounted && revision == _revision) {
        setState(() {
          _error = 'Não foi possível copiar. Selecione o código para copiá-lo.';
        });
      }
    }
  }

  @override
  void dispose() {
    _revision++;
    _timer?.cancel();
    _loadTimer?.cancel();
    _ownSubscription?.cancel();
    _receivedSubscription?.cancel();
    _code.dispose();
    super.dispose();
  }

  Widget _person(String name, String? photo) {
    ImageProvider? image;
    try {
      if (photo != null && photo.isNotEmpty) {
        image = photo.startsWith('data:image/')
            ? MemoryImage(base64Decode(photo.split(',').last))
            : NetworkImage(photo);
      }
    } catch (_) {
      image = null;
    }
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          foregroundImage: image,
          onForegroundImageError: image == null ? null : (_, _) {},
          child: const Icon(Icons.person_outline),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(name, style: Theme.of(context).textTheme.titleMedium),
        ),
      ],
    );
  }

  Widget _consentPanel(bool enabled) => ReadingSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'O que vocês vão compartilhar',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        const Text(
          'Após o aceite, vocês poderão consultar as estantes e o progresso da Bíblia um do outro, incluindo registros existentes. Cada pessoa continua responsável por editar somente seus próprios registros.',
        ),
        const SizedBox(height: 12),
        const Text(
          'Nome e foto identificam o casal. E-mail e dados privados da conta não são compartilhados. Você pode encerrar o vínculo no Perfil e manter seus registros pessoais.',
        ),
        const SizedBox(height: 12),
        const Text(
          'A ocultação por item será disponibilizada em uma próxima etapa. Nesta versão, o aceite compartilha toda a estante e o progresso da Bíblia.',
        ),
        Material(
          type: MaterialType.transparency,
          child: CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _consent,
            onChanged: enabled
                ? (value) => setState(() {
                    _consent = value ?? false;
                  })
                : null,
            title: const Text('Li e concordo com esse compartilhamento.'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ),
      ],
    ),
  );

  String _status(PartnerInvitation invitation) {
    final profile = _auth?.currentUserModel;
    if (invitation.status == 'pending' &&
        profile != null &&
        ((invitation.senderUid == profile.uid &&
                invitation.senderEpoch != profile.coupleEpoch) ||
            (invitation.recipientUid == profile.uid &&
                invitation.recipientEpoch != profile.coupleEpoch))) {
      return 'Convite indisponível';
    }
    if (invitation.status == 'pending') {
      return invitation.isPendingAt(DateTime.now())
          ? 'Aguardando resposta'
          : 'Convite expirado';
    }
    return {
      'accepted': 'Convite aceito',
      'declined': 'Convite recusado',
      'cancelled': 'Convite cancelado',
    }[invitation.status]!;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final linked = auth.currentUserModel?.partnerUid != null;
    final enabled = !_pending && !auth.isLoading && _uid != null && !linked;
    final incoming = _received;
    final validIncoming =
        (incoming?.isPendingAt(DateTime.now()) ?? false) &&
        _status(incoming!) != 'Convite indisponível';
    return ReadingPage(
      maxWidth: 720,
      child: Scaffold(
        appBar: AppBar(title: const Text('Convites do casal')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Compartilhar começa com um convite',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            const Text(
              'O convite vale por 7 dias. Enviar ou consultar um código não libera acesso aos seus registros.',
            ),
            if (_uid == null) const Text('Entre novamente para continuar.'),
            if (linked)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Você já possui um vínculo ativo. Para encerrá-lo, volte ao Perfil.',
                ),
              ),
            const SizedBox(height: 24),
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              TextButton(
                onPressed: _pending ? null : _retry,
                child: const Text('Tentar carregar novamente'),
              ),
            ],
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (_own != null)
              ReadingSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Convite enviado · ${_status(_own!)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    if (_own!.recipientName != null)
                      _person(_own!.recipientName!, _own!.recipientPhotoUrl),
                    if (_own!.isPendingAt(DateTime.now())) ...[
                      SelectableText(_own!.code),
                      Text(
                        'Válido até ${_own!.expiresAt.day.toString().padLeft(2, '0')}/${_own!.expiresAt.month.toString().padLeft(2, '0')}/${_own!.expiresAt.year}.',
                      ),
                      TextButton.icon(
                        onPressed: _pending ? null : () => _copy(_own!.code),
                        icon: const Icon(Icons.copy),
                        label: const Text('Copiar convite'),
                      ),
                    ],
                    if (_own!.status == 'pending')
                      TextButton(
                        onPressed: _pending
                            ? null
                            : () => _run(
                                () => auth.finishInvitation(
                                  _own!.code,
                                  cancel: true,
                                ),
                                success: 'Convite cancelado.',
                              ),
                        child: const Text('Cancelar convite'),
                      ),
                  ],
                ),
              ),
            if (!linked && !_loading) ...[
              const SizedBox(height: 24),
              Text(
                'Receber um convite',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              const Text(
                'Ao consultar, este convite será reservado para você e seu nome e foto serão apresentados ao remetente. Confira quem convidou antes de aceitar.',
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _code,
                label: 'Código de convite',
                hint: 'Cole o código recebido',
                prefixIcon: Icons.key_outlined,
              ),
              const SizedBox(height: 12),
              CustomButton(
                text: 'Consultar convite',
                onPressed: enabled ? () => _run(_lookup) : null,
              ),
              if (incoming != null) ...[
                const SizedBox(height: 24),
                _person(incoming.senderName, incoming.senderPhotoUrl),
                Text(_status(incoming)),
              ],
              const SizedBox(height: 24),
              _consentPanel(enabled),
              const SizedBox(height: 16),
              if (validIncoming) ...[
                CustomButton(
                  text: 'Aceitar convite',
                  onPressed: enabled && _consent
                      ? () => _run(
                          () => auth.acceptInvitation(incoming.code),
                          success: 'Convite aceito. Vínculo confirmado.',
                        )
                      : null,
                ),
                TextButton(
                  onPressed: enabled
                      ? () => _run(
                          () => auth.finishInvitation(
                            incoming.code,
                            cancel: false,
                          ),
                          success: 'Convite recusado.',
                        )
                      : null,
                  child: const Text('Recusar convite'),
                ),
              ] else if (_own == null || !_own!.isPendingAt(DateTime.now()))
                CustomButton(
                  text: 'Criar convite',
                  onPressed: enabled && _consent
                      ? () => _run(
                          () async => (await auth.createInvitation()).error,
                          success:
                              'Convite criado. Copie o código para enviar.',
                        )
                      : null,
                ),
            ],
            if (_pending)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
