import 'package:flutter/material.dart';

/// Estado legível e rolável mesmo em uma tela pequena com texto ampliado.
class ContentState extends StatelessWidget {
  const ContentState({
    super.key,
    required this.title,
    this.message,
    this.loading = false,
    this.icon = Icons.library_books_outlined,
    this.actionLabel,
    this.onAction,
  });
  final String title;
  final String? message;
  final bool loading;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0,
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Semantics(
              liveRegion: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (loading)
                    const CircularProgressIndicator()
                  else
                    Icon(
                      icon,
                      size: 40,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 8),
                    Text(message!, textAlign: TextAlign.center),
                  ],
                  if (onAction != null && actionLabel != null) ...[
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: onAction,
                      child: Text(actionLabel!),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
