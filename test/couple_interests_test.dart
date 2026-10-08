import 'package:bookself_app/data/models/couple_record.dart';
import 'package:bookself_app/data/models/media_model.dart';
import 'package:bookself_app/services/couple_interests.dart';
import 'package:bookself_app/ui/widgets/couple_interests.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CoupleRecord item(
  String id,
  String author,
  String title, {
  bool removed = false,
  MediaType type = MediaType.book,
  String subtitle = '',
  String? reference,
  String source = 'manual',
}) => CoupleRecord(id, {
  'authorId': author,
  'removed': removed,
  'selection': CoupleSelection(
    type: type,
    title: title,
    subtitle: subtitle,
    reference: reference,
    source: source,
  ).toMap(),
});

void main() {
  test(
    'autoria dos dois necessária; removidos, terceiros e duplicatas excluídos',
    () {
      final result = commonCoupleSelections(
        [
          item('1', 'a', ' Uma   obra '),
          item('2', 'b', 'uma obra'),
          item('3', 'a', 'uma obra'),
          item('4', 'a', 'Só minha'),
          item('5', 'a', 'Retirada'),
          item('6', 'b', 'Retirada', removed: true),
          item('7', 'a', 'Terceiro'),
          item('8', 'c', 'Terceiro'),
        ],
        'a',
        'b',
      );
      expect(result.map((r) => r.title), ['Uma   obra']);
      expect(commonCoupleSelections([], 'a', 'a'), isEmpty);
    },
  );
  test('mídia, artista, origem e referência diferentes não se misturam', () {
    expect(
      commonCoupleSelections(
        [
          item('1', 'a', 'Título'),
          item('2', 'b', 'Título', type: MediaType.movie),
          item('3', 'a', 'Som', type: MediaType.track, subtitle: 'A'),
          item('4', 'b', 'Som', type: MediaType.track, subtitle: 'B'),
          item('5', 'a', 'Edição', reference: 'provider:1', source: 'catalog'),
          item('6', 'b', 'Edição', reference: 'provider:2', source: 'catalog'),
          item('7', 'a', 'Origem'),
          item('8', 'b', 'Origem', source: 'library'),
        ],
        'a',
        'b',
      ),
      isEmpty,
    );
  });
  testWidgets(
    'escolha explícita e revogação retiram opção; layout pequeno 2x',
    (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Future<void> show(List<CoupleRecord> rows) => tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: CoupleInterests(rows: rows, uid: 'a', partnerUid: 'b'),
              ),
            ),
          ),
        ),
      );
      await show([
        item('1', 'a', 'A'),
        item('2', 'b', 'A'),
        item('3', 'a', 'B'),
        item('4', 'b', 'B'),
      ]);
      expect(find.textContaining('Opção 1 de 2: Livro: A'), findsOneWidget);
      await tester.ensureVisible(find.text('Destacar próxima opção'));
      await tester.tap(find.text('Destacar próxima opção'));
      await tester.pump();
      expect(find.textContaining('Opção 2 de 2: Livro: B'), findsOneWidget);
      await show([]);
      expect(find.textContaining('Ainda não há coincidências'), findsOneWidget);
      expect(find.textContaining('Opção 2'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
