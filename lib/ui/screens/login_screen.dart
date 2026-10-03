import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/dialog_with_controllers.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isSignUp = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _submitAuth(AuthService authService) async {
    if (!_formKey.currentState!.validate()) return;

    String? error;
    if (_isSignUp) {
      error = await authService.signUpWithEmail(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text,
      );
    } else {
      error = await authService.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );
    }

    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.redAccent),
      );
    }
  }

  // Diálogo para solicitar e-mail de recuperação de senha
  void _showForgotPasswordDialog(
    BuildContext context,
    AuthService authService,
  ) {
    final emailController = TextEditingController(text: _emailController.text);
    final theme = Theme.of(context);
    final formKey = GlobalKey<FormState>();
    final screenContext = context;

    showDialogWithControllers(
      controllers: [emailController],
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Recuperar Senha'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Insira seu e-mail cadastrado para enviarmos um link de redefinição de senha.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: emailController,
                  label: 'E-mail',
                  hint: 'seuemail@exemplo.com',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Insira seu e-mail';
                    if (!RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(val)) {
                      return 'E-mail inválido';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                if (!screenContext.mounted ||
                    !formKey.currentState!.validate()) {
                  return;
                }

                final email = emailController.text.trim();
                Navigator.pop(context);

                final error = await authService.sendPasswordReset(email);

                if (screenContext.mounted) {
                  if (error != null) {
                    ScaffoldMessenger.of(screenContext).showSnackBar(
                      SnackBar(
                        content: Text(error),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(screenContext).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'E-mail de recuperação enviado com sucesso!',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
              child: Text(
                'Enviar',
                style: TextStyle(
                  color: theme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final theme = Theme.of(context);

    // Tela de Autenticação (Login / Cadastro)
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.menu_book_rounded,
                  size: 80,
                  color: theme.primaryColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'Bookself App',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displayLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Compartilhe suas leituras e progresso da Bíblia com quem você ama.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 36),

                // Campos de Formulário
                if (_isSignUp) ...[
                  CustomTextField(
                    controller: _nameController,
                    label: 'Seu Nome',
                    hint: 'Como quer ser chamado(a)',
                    prefixIcon: Icons.person_outline,
                    validator: (val) =>
                        val == null || val.isEmpty ? 'Insira seu nome' : null,
                  ),
                  const SizedBox(height: 16),
                ],
                CustomTextField(
                  controller: _emailController,
                  label: 'E-mail',
                  hint: 'seuemail@exemplo.com',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Insira seu e-mail';
                    if (!RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(val)) {
                      return 'E-mail inválido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _passwordController,
                  label: 'Senha',
                  hint: 'Sua senha secreta',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: !_showPassword,
                  suffixIcon: _showPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  onSuffixPressed: () {
                    setState(() {
                      _showPassword = !_showPassword;
                    });
                  },
                  validator: (val) => val == null || val.length < 6
                      ? 'A senha deve ter pelo menos 6 caracteres'
                      : null,
                ),
                if (!_isSignUp) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () =>
                          _showForgotPasswordDialog(context, authService),
                      child: const Text('Esqueceu a senha?'),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 24),
                ],

                // Botão de Envio
                CustomButton(
                  text: _isSignUp ? 'Criar Conta' : 'Entrar',
                  isLoading: authService.isLoading,
                  onPressed: () => _submitAuth(authService),
                ),
                const SizedBox(height: 16),

                // Toggle Login / Cadastro
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isSignUp = !_isSignUp;
                      _formKey.currentState?.reset();
                    });
                  },
                  child: Text(
                    _isSignUp
                        ? 'Já tem uma conta? Entre aqui'
                        : 'Não tem conta? Cadastre-se',
                    style: TextStyle(color: theme.primaryColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
