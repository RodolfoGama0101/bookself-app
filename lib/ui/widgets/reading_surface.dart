import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Granulação estática em destaques, sem imagens nem animação contínua.
class ReadingSurface extends StatelessWidget {
  const ReadingSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: ColoredBox(
        color: scheme.surface,
        child: CustomPaint(
          painter: _GrainPainter(scheme.onSurface.withValues(alpha: .025)),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  const _GrainPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(17);
    final paint = Paint()..color = color;
    for (var i = 0; i < (size.width * size.height / 90).floor(); i++) {
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
        .7,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_GrainPainter oldDelegate) => oldDelegate.color != color;
}

/// Limita linhas na web preservando altura e rolagem do Scaffold.
class ReadingPage extends StatelessWidget {
  const ReadingPage({super.key, required this.child, this.maxWidth = 1000});
  final Widget child;
  final double maxWidth;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).scaffoldBackgroundColor,
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    ),
  );
}
