import 'dart:async';

import 'package:bookself_app/data/bible_data.dart';
import 'package:bookself_app/data/models/bible_progress_model.dart';
import 'package:bookself_app/services/bible_service.dart';
import 'package:bookself_app/ui/screens/bible_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_fonts.dart';

class ChapterServiceFake extends BibleService {
  @override
  Stream<BibleProgressModel?> streamSharedBookProgress(
    String uid,
    String name,
  ) => streamBookProgress(uid, name);
  ChapterServiceFake(this.initial);
  final List<int> initial;
  Completer<List<int>> pending = Completer<List<int>>();
  final writes = <({String uid, int? chapter, bool isRead})>[];
  final streams = <String, StreamController<BibleProgressModel?>>{};
  final watches = <String, int>{};
  StreamController<BibleProgressModel?> controller(String uid) =>
      streams.putIfAbsent(uid, () => StreamController.broadcast());
  @override
  Stream<BibleProgressModel?> streamBookProgress(
    String uid,
    String name,
  ) async* {
    watches.update(uid, (watchCount) => watchCount + 1, ifAbsent: () => 1);
    yield BibleProgressModel(
      id: '${uid}_rute',
      userId: uid,
      bookName: name,
      readChapters: uid == 'owner' ? List.of(initial) : [],
      updatedAt: DateTime(2020),
    );
    yield* controller(uid).stream;
  }

  @override
  Future<List<int>> toggleChapter(
    String uid,
    String name,
    int chapter,
    bool isRead,
  ) {
    writes.add((uid: uid, chapter: chapter, isRead: isRead));
    return pending.future;
  }

  @override
  Future<List<int>> markAllChapters(
    String uid,
    String name,
    int total,
    bool isRead,
  ) {
    expect(total, 4);
    writes.add((uid: uid, chapter: null, isRead: isRead));
    return pending.future;
  }

  Future<void> close() async {
    for (final stream in streams.values) {
      await stream.close();
    }
  }
}

final book = BibleData.books.firstWhere((book) => book.name == 'Rute');

Future<void> showChapters(
  WidgetTester tester,
  ChapterServiceFake service, {
  String uid = 'owner',
  String? partner,
  double scale = 1,
  BibleBook? selectedBook,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: BibleBookChaptersScreen(
        book: selectedBook ?? book,
        userId: uid,
        partnerId: partner,
        partnerName: 'Parceiro',
        bibleService: service,
      ),
    ),
  );
  // Também usado ao trocar identidade durante escrita: há animação pendente.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Finder chapter(int number) => find.byKey(ValueKey('bible-chapter-$number'));
Finder batch(bool isRead) => find.widgetWithText(
  TextButton,
  isRead ? 'Marcar todos' : 'Desmarcar todos',
);
Future<void> act(WidgetTester tester, bool all, bool isRead) =>
    tester.tap(all ? batch(isRead) : chapter(2));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(useBundledTestFonts);

  testWidgets('capítulo anuncia estado e pode ser marcado pelo teclado', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final service = ChapterServiceFake([1]);
    await showChapters(tester, service);
    final read = tester
        .getSemantics(find.bySemanticsLabel('Rute, capítulo 1'))
        .getSemanticsData();
    expect(read.value, 'Lido por você');
    expect(read.flagsCollection.isSelected.toBoolOrNull(), isTrue);
    expect(read.flagsCollection.isButton, isTrue);
    final node = Focus.of(
      tester.element(
        find.descendant(of: chapter(2), matching: find.byType(Container)).first,
      ),
    );
    node.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(service.writes.single.chapter, 2);
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Rute, capítulo 2'))
          .getSemanticsData()
          .value,
      'Não lido por você. Salvando',
    );
    service.pending.complete([1, 2]);
    await tester.pumpAndSettle();
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Rute, capítulo 2'))
          .getSemanticsData()
          .value,
      'Lido por você',
    );
    await tester.pumpWidget(const SizedBox());
    await service.close();
    semantics.dispose();
  });

  for (final all in [false, true]) {
    for (final isRead in [false, true]) {
      final name =
          '${all ? 'lote' : 'capítulo'}: ${isRead ? 'marcar' : 'desmarcar'}';
      final initial = isRead ? [1] : (all ? [1, 2, 3, 4] : [1, 2]);
      final confirmed = isRead
          ? (all ? [1, 2, 3, 4] : [1, 2])
          : (all ? <int>[] : [1]);

      testWidgets(
        '$name aguarda confirmação, bloqueia repetições e permite inverter sem evento do stream',
        (tester) async {
          final service = ChapterServiceFake(initial);
          await showChapters(tester, service);
          final repeated = all
              ? tester.widget<TextButton>(batch(isRead)).onPressed!
              : tester.widget<InkWell>(chapter(2)).onTap!;
          repeated();
          repeated(); // Mesmo antes do próximo frame, não envia outra operação.
          await tester.pump();
          await tester.tap(chapter(3));
          await tester.tap(batch(initial.length != 4));
          expect(service.writes, hasLength(1));
          expect(find.text('Salvando progresso…'), findsOneWidget);
          expect(find.byType(SnackBar), findsNothing);
          expect(
            find.text('Capítulos lidos: ${initial.length} / 4'),
            findsOneWidget,
          );
          expect(tester.widget<InkWell>(chapter(1)).onTap, isNull);

          service.pending.complete(confirmed);
          await tester.pumpAndSettle();
          expect(find.text('Salvando progresso…'), findsNothing);
          expect(
            find.text('Capítulos lidos: ${confirmed.length} / 4'),
            findsOneWidget,
          );
          expect(find.byType(SnackBar), findsOneWidget);
          expect(service.watches['owner'], 1);

          // O stream continua antigo. A confirmação determina a próxima intenção.
          service.pending = Completer<List<int>>();
          await act(tester, all, !isRead);
          await tester.pump();
          expect(service.writes.last.isRead, !isRead);
          service.pending.complete(initial);
          await tester.pumpAndSettle();
          expect(
            find.text('Capítulos lidos: ${initial.length} / 4'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await service.close();
        },
      );

      for (final code in ['permission-denied', 'unavailable']) {
        testWidgets(
          '$name trata $code, mantém estado e permite repetir a mesma intenção',
          (tester) async {
            final service = ChapterServiceFake(initial);
            await showChapters(tester, service);
            await act(tester, all, isRead);
            await tester.pump();
            service.pending.completeError(
              FirebaseException(plugin: 'cloud_firestore', code: code),
            );
            await tester.pumpAndSettle();
            expect(find.byType(SnackBar), findsOneWidget);
            expect(find.textContaining('Capítulo 2 de Rute'), findsNothing);
            expect(
              find.textContaining('Todos os capítulos de Rute'),
              findsNothing,
            );
            expect(
              find.text('Capítulos lidos: ${initial.length} / 4'),
              findsOneWidget,
            );
            expect(
              find.textContaining(
                code == 'permission-denied'
                    ? 'Você não tem permissão'
                    : 'temporariamente indisponível',
              ),
              findsOneWidget,
            );
            expect(tester.widget<InkWell>(chapter(1)).onTap, isNotNull);
            service.pending = Completer<List<int>>();
            await tester.tap(find.text('Tentar novamente'));
            await tester.pump();
            expect(service.writes, hasLength(2));
            expect(service.writes.last, service.writes.first);
            service.pending.complete(confirmed);
            await tester.pumpAndSettle();
            expect(
              find.byKey(const ValueKey('bible-write-error')),
              findsNothing,
            );
            expect(find.byType(SnackBar), findsOneWidget);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
            await service.close();
          },
        );
      }
    }
    for (final fails in [false, true]) {
      testWidgets(
        '${all ? 'lote' : 'capítulo'} descartado durante ${fails ? 'falha' : 'sucesso'} encerra ouvintes e ignora retorno',
        (tester) async {
          final service = ChapterServiceFake([]);
          await showChapters(tester, service, partner: 'partner');
          await act(tester, all, true);
          await tester.pump();
          await tester.pumpWidget(const SizedBox());
          expect(service.controller('owner').hasListener, isFalse);
          expect(service.controller('partner').hasListener, isFalse);
          if (fails) {
            service.pending.completeError(
              FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
            );
          } else {
            service.pending.complete([1, 2, 3, 4]);
          }
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await service.close();
        },
      );
    }
  }

  testWidgets(
    'troca de proprietário ignora confirmação antiga e renova assinatura',
    (tester) async {
      final service = ChapterServiceFake([]);
      await showChapters(tester, service);
      await tester.tap(chapter(2));
      await tester.pump();
      await showChapters(tester, service, uid: 'another');
      expect(service.controller('owner').hasListener, isFalse);
      expect(service.controller('another').hasListener, isTrue);
      service.pending.complete([2]);
      await tester.pumpAndSettle();
      expect(find.text('Capítulos lidos: 0 / 4'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await service.close();
    },
  );

  testWidgets('desvincular parceiro mantém bloqueio da escrita em curso', (
    tester,
  ) async {
    final service = ChapterServiceFake([]);
    await showChapters(tester, service, partner: 'partner');
    await tester.tap(chapter(2));
    await tester.pump();
    await showChapters(tester, service);
    expect(service.controller('partner').hasListener, isFalse);
    expect(service.watches['owner'], 1);
    expect(tester.widget<InkWell>(chapter(2)).onTap, isNull);
    service.pending.complete([2]);
    await tester.pumpAndSettle();
    expect(find.text('Capítulos lidos: 1 / 4'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await service.close();
  });

  testWidgets(
    'erro de leitura impede escrita e nova tentativa não duplica ouvintes',
    (tester) async {
      final service = ChapterServiceFake([]);
      await showChapters(tester, service);
      service
          .controller('owner')
          .addError(
            FirebaseException(
              plugin: 'cloud_firestore',
              code: 'permission-denied',
            ),
          );
      await tester.pumpAndSettle();
      expect(chapter(2), findsNothing);
      expect(
        find.textContaining('Não foi possível carregar seu progresso'),
        findsOneWidget,
      );
      expect(service.writes, isEmpty);
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(service.watches['owner'], 2);
      expect(chapter(2), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await service.close();
    },
  );

  testWidgets(
    'capítulo distante do topo mostra carregamento e erro com nova tentativa visível',
    (tester) async {
      final service = ChapterServiceFake([]);
      final psalms = BibleData.books.firstWhere(
        (book) => book.name == 'Salmos',
      );
      await showChapters(tester, service, selectedBook: psalms);
      await tester.scrollUntilVisible(chapter(100), 500);
      await tester.tap(chapter(100));
      await tester.pump();
      expect(
        find.descendant(
          of: chapter(100),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      service.pending.completeError(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      );
      await tester.pumpAndSettle();
      expect(
        find
            .text('Não foi possível salvar o progresso de Salmos.')
            .hitTestable(),
        findsOneWidget,
      );
      service.pending = Completer<List<int>>();
      await tester.tap(find.text('Repetir'));
      await tester.pump();
      expect(service.writes, hasLength(2));
      expect(service.writes.last.chapter, 100);
      expect(service.writes.last.isRead, isTrue);
      service.pending.complete([100]);
      await tester.pumpAndSettle();
      expect(
        find.text('Capítulo 100 de Salmos marcado como lido.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await service.close();
    },
  );

  testWidgets('tela pequena com texto ampliado permite tratar falha do lote', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = ChapterServiceFake([]);
    await showChapters(tester, service, scale: 2);
    await tester.tap(batch(true));
    await tester.pump();
    service.pending.completeError(
      FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await service.close();
  });
}
