import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';

class SessionGate extends StatelessWidget {
  const SessionGate({
    super.key,
    required this.signedOutBuilder,
    required this.readyBuilder,
  });

  final WidgetBuilder signedOutBuilder;
  final WidgetBuilder readyBuilder;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    switch (auth.sessionState) {
      case AuthSessionState.signedOut:
        return signedOutBuilder(context);
      case AuthSessionState.ready:
        return readyBuilder(context);
      case AuthSessionState.missingProfile:
        return const _CompleteProfileScreen();
      case AuthSessionState.restoring:
      case AuthSessionState.loadingProfile:
      case AuthSessionState.profileError:
      case AuthSessionState.authError:
        final loading =
            auth.sessionState == AuthSessionState.restoring ||
            auth.sessionState == AuthSessionState.loadingProfile;
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (loading) ...[
                      const CircularProgressIndicator(
                        semanticsLabel: 'Carregando sua conta',
                      ),
                      const SizedBox(height: 24),
                      Text(
                        auth.sessionState == AuthSessionState.restoring
                            ? 'Restaurando sua sessão…'
                            : 'Carregando seu perfil…',
                      ),
                    ] else ...[
                      const Icon(Icons.cloud_off_outlined, size: 48),
                      const SizedBox(height: 24),
                      Text(
                        auth.sessionError ??
                            'Não foi possível carregar sua conta.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: auth.isLoading
                            ? null
                            : () {
                                if (auth.sessionState ==
                                    AuthSessionState.authError) {
                                  auth.retrySession();
                                } else {
                                  auth.retryProfile();
                                }
                              },
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                    if (auth.hasAuthenticatedSession) ...[
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: auth.isLoading
                            ? null
                            : () => _signOut(context, auth),
                        child: const Text('Sair'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
    }
  }
}

Future<void> _signOut(BuildContext context, AuthService auth) async {
  try {
    await auth.signOut();
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Não foi possível sair. Tente novamente.')),
    );
  }
}

class _CompleteProfileScreen extends StatefulWidget {
  const _CompleteProfileScreen();

  @override
  State<_CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<_CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: context.read<AuthService>().profileNameSuggestion,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save(AuthService auth) async {
    if (!_formKey.currentState!.validate()) return;
    final error = await auth.completeMissingProfile(_nameController.text);
    if (!mounted || error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Vamos concluir seu perfil',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Sua conta já está criada. Informe seu nome para acessar sua biblioteca.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nameController,
                      enabled: !auth.isLoading,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Seu nome'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Informe seu nome.'
                          : null,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: auth.isLoading ? null : () => _save(auth),
                      child: auth.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                semanticsLabel: 'Salvando seu perfil',
                              ),
                            )
                          : const Text('Salvar perfil'),
                    ),
                    TextButton(
                      onPressed: auth.isLoading ? null : auth.retryProfile,
                      child: const Text('Verificar novamente'),
                    ),
                    TextButton(
                      onPressed: auth.isLoading
                          ? null
                          : () => _signOut(context, auth),
                      child: const Text('Sair'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
