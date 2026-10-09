import 'dart:async';
import 'package:bookself_app/data/models/couple_record.dart';
import 'package:bookself_app/data/models/media_model.dart';
import 'package:bookself_app/services/auth_service.dart';
import 'package:bookself_app/services/couple_activity_service.dart';
import 'package:bookself_app/services/couple_workspace_service.dart';
import 'package:bookself_app/services/library_query_service.dart';
import 'package:bookself_app/ui/screens/couple_activity_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'couple_workspace_ui_test.dart' show JointAuth;
import 'support/profile_firestore_fake.dart';
import 'support/test_fonts.dart';

class ActivityFake extends CoupleActivityService {
  final streams = <MediaType?, StreamController<LibraryPage<CoupleActivity>>>{};
  final more = Completer<LibraryPage<CoupleActivity>>();
  Completer<Map<MediaType, int>>? countsGate;
  StreamController<LibraryPage<CoupleActivity>> controller(MediaType? type) =>
      streams.putIfAbsent(type, () => StreamController.broadcast());
  @override
  Stream<LibraryPage<CoupleActivity>> watch(
    String relation, {
    MediaType? type,
  }) => controller(type).stream;
  @override
  Future<LibraryPage<CoupleActivity>> page(
    String relation, {
    MediaType? type,
    required LibraryCursor after,
  }) => more.future;
  @override
  Future<Map<MediaType, int>> counts(String relation) async =>
      countsGate == null
      ? {for (final type in MediaType.values) type: 42}
      : countsGate!.future;
}

void main() {
  setUpAll(useBundledTestFonts);
  test(
    'projeção acompanha confirmação, correção, retirada e retry sem duplicar',
    () async {
      final db = ProfileFirestoreFake();
      addTearDown(db.close);
      db.documents.addAll({
        'a': {'partnerUid': 'b', 'relationshipId': 'relation'},
        'b': {'partnerUid': 'a', 'relationshipId': 'relation'},
        'partner_invites/relation': {
          'status': 'accepted',
          'senderUid': 'a',
          'recipientUid': 'b',
        },
      });
      final service = CoupleWorkspaceService(firestore: db);
      const path = 'couple_relationships/relation/experiences/session';
      const projection = 'couple_relationships/relation/activity/session';
      CoupleRecord current() => CoupleRecord('session', db.documents[path]!);
      final selection = CoupleSelection(
        type: MediaType.series,
        title: 'Série',
        episode: {'id': 'one', 'season': 1, 'number': 1},
      );
      await service.propose(
        'a',
        'relation',
        'session',
        selection,
        DateTime(2020),
      );
      expect(db.documents[projection]!['confirmed'], isFalse);
      await service.respond('b', 'relation', current(), 'confirmed');
      expect(db.documents[projection]!['confirmed'], isTrue);
      await service.propose(
        'a',
        'relation',
        'session',
        selection,
        DateTime(2021),
      );
      expect(db.documents[projection]!['sourceVersion'], 2);
      await service.propose(
        'a',
        'relation',
        'session',
        selection,
        DateTime(2021),
        previous: current(),
      );
      expect(db.documents[projection]!['confirmed'], isFalse);
      await service.respond('b', 'relation', current(), 'confirmed');
      await service.respond('a', 'relation', current(), 'withdrawn');
      expect(db.documents[projection]!['confirmed'], isFalse);
      expect(
        db.documents.keys.where(
          (k) => k.startsWith('couple_relationships/relation/activity/'),
        ),
        hasLength(1),
      );
      expect(db.documents[projection]!.containsKey('favorite'), isFalse);
    },
  );
  CoupleActivity row(String id, MediaType type) => CoupleActivity(id, {
    'selection': CoupleSelection(
      type: type,
      title: id,
      subtitle: 'Artista',
    ).toMap(),
    'confirmed': true,
    'occurredOn': '2020-01-01',
    'revision': 1,
    'sourceVersion': 2,
    'updatedAt': Timestamp.now(),
  });
  Future<void> show(
    WidgetTester tester,
    ActivityFake service,
    JointAuth auth,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthService>.value(
        value: auth,
        child: MaterialApp(home: CoupleActivityScreen(service: service)),
      ),
    );
    await tester.pump();
  }

  Future<void> tap(WidgetTester tester, String label) async {
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pump();
    if (find.text(label).evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        find.text(label),
        180,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(find.text(label));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(label));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets(
    'totais completos independem da página; filtro descarta página atrasada',
    (tester) async {
      final service = ActivityFake(), auth = JointAuth();
      await show(tester, service, auth);
      service
          .controller(null)
          .add(
            LibraryPage(
              [row('Filme da página', MediaType.movie)],
              LibraryCursor(
                scope: 'joint/relation/all',
                timestamp: Timestamp.now(),
                documentId: 'cursor',
              ),
            ),
          );
      await tester.pumpAndSettle();
      expect(find.text('Filmes: 42'), findsOneWidget);
      await tap(tester, 'Carregar mais atividades');
      await tap(tester, 'Faixas');
      service
          .controller(MediaType.track)
          .add(LibraryPage([row('Faixa atual', MediaType.track)], null));
      await tester.pumpAndSettle();
      service.more.complete(
        LibraryPage([row('Filme atrasado', MediaType.movie)], null),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Faixa atual'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Filme atrasado'), findsNothing);
      expect(find.text('Faixa atual'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      for (final s in service.streams.values) {
        await s.close();
      }
    },
  );
  testWidgets(
    'erro e mudança de vínculo retiram dados e rejeitam contagem tardia',
    (tester) async {
      final service = ActivityFake(), auth = JointAuth();
      service.countsGate = Completer();
      await show(tester, service, auth);
      service
          .controller(null)
          .add(
            LibraryPage([
              row('Seleção privada do casal', MediaType.movie),
            ], null),
          );
      await tester.pumpAndSettle();
      service.controller(null).addError(StateError('offline'));
      await tester.pumpAndSettle();
      service.countsGate!.complete({
        for (final type in MediaType.values) type: 99,
      });
      await tester.pumpAndSettle();
      expect(find.text('Filmes: 99'), findsNothing);
      expect(find.text('Seleção privada do casal'), findsNothing);
      auth.change();
      await tester.pumpAndSettle();
      expect(find.text('Nenhum vínculo consentido ativo'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      for (final s in service.streams.values) {
        await s.close();
      }
    },
  );
}
