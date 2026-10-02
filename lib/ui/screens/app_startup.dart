import 'package:flutter/material.dart';

import '../theme.dart';

/// Mantém serviços dependentes da inicialização fora da árvore até o sucesso.
class AppStartup extends StatefulWidget {
  const AppStartup({
    super.key,
    required this.initialize,
    required this.readyBuilder,
  });

  final Future<void> Function() initialize;
  final WidgetBuilder readyBuilder;

  @override
  State<AppStartup> createState() => _AppStartupState();
}

enum _StartupStatus { loading, ready, failed }

class _AppStartupState extends State<AppStartup> {
  _StartupStatus _status = _StartupStatus.loading;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    var status = _StartupStatus.ready;
    try {
      await widget.initialize();
    } catch (_) {
      status = _StartupStatus.failed;
    }
    if (!mounted) return;
    setState(() => _status = status);
  }

  void _retry() {
    if (_status != _StartupStatus.failed) return;
    setState(() {
      _status = _StartupStatus.loading;
    });
    _initialize();
  }

  @override
  Widget build(BuildContext context) {
    if (_status == _StartupStatus.ready) {
      return widget.readyBuilder(context);
    }

    final hasFailed = _status == _StartupStatus.failed;
    // A tela inicial usa fontes locais para continuar disponível sem rede.
    return MaterialApp(
      title: 'Bookself App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppTheme.darkPrimary,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: AppTheme.darkBg,
      ),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasFailed) ...[
                    const Icon(Icons.cloud_off_outlined, size: 48),
                    const SizedBox(height: 24),
                    const Text(
                      'Não foi possível abrir o aplicativo',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Verifique sua conexão e tente novamente. '
                      'Se o problema continuar, tente mais tarde.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _retry,
                      child: const Text('Tentar novamente'),
                    ),
                  ] else ...[
                    const CircularProgressIndicator(
                      semanticsLabel: 'Abrindo o aplicativo',
                    ),
                    const SizedBox(height: 24),
                    const Text('Abrindo o aplicativo…'),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
