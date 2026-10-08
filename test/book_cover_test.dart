import 'package:bookself_app/ui/widgets/book_cover.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final url in [
    '',
    ' ',
    'broken',
    'file:///cover.png',
    'https://user:password@example.com/cover',
  ]) {
    testWidgets('capa ausente/inválida usa fallback: $url', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BookCover(
            url: url,
            placeholderBuilder: (_) => const Text('Sem capa'),
          ),
        ),
      );
      expect(find.text('Sem capa'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });
  }
  testWidgets('capa usa HTTPS direto e fallback em carregamento/falha', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BookCover(
          url: 'http://example.com/cover?size=1',
          placeholderBuilder: (_) => const Text('Sem capa'),
        ),
      ),
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.excludeFromSemantics, isTrue);
    expect(
      (image.image as NetworkImage).url,
      'https://example.com/cover?size=1',
    );
    expect(
      (image.image as NetworkImage).webHtmlElementStrategy,
      WebHtmlElementStrategy.fallback,
    );
    expect(find.text('Sem capa'), findsOneWidget);
    // TestWidgetsFlutterBinding responde 400; sem rede nem proxy real.
    await tester.pumpAndSettle();
    expect(find.text('Sem capa'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
