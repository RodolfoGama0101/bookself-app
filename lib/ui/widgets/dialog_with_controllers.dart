import 'package:flutter/material.dart';

/// Mantém os controladores vivos até o diálogo sair da árvore, inclusive
/// quando fechado pela barreira, pelo botão voltar ou durante uma requisição.
Future<T?> showDialogWithControllers<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  required List<TextEditingController> controllers,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<T>(
    context: context,
    builder: builder,
    themes: InheritedTheme.capture(from: context, to: navigator.context),
  );
  try {
    final result = await navigator.push(route);
    // O resultado de push chega antes do fim da animação de saída.
    await route.completed;
    return result;
  } finally {
    for (final controller in controllers) {
      controller.dispose();
    }
  }
}
