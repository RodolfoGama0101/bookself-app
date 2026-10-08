import 'dart:async';
import 'package:bookself_app/data/models/couple_record.dart';
import 'package:bookself_app/data/models/media_model.dart';
import 'package:bookself_app/data/models/user_model.dart';
import 'package:bookself_app/services/auth_service.dart';
import 'package:bookself_app/services/couple_workspace_service.dart';
import 'package:bookself_app/ui/screens/couple_workspace_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'support/test_fonts.dart';

class JointAuth extends ChangeNotifier implements AuthService {
  String uid = 'a';
  bool active = true;
  @override
  UserModel get currentUserModel => UserModel(
    uid: uid,
    name: 'Pessoa fictícia',
    email: 'a@example.test',
    createdAt: DateTime(2020),
    partnerUid: active ? 'b' : null,
    relationshipId: active ? 'relation' : null,
  );
  void change() {
    uid = 'other';
    active = false;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class JointUiService extends CoupleWorkspaceService {
  Completer<void> gate = Completer<void>();
  final creates = <String>[];
  final decisions = <String>[];
  bool withExperience = false;
  @override
  String newId() => 'intention';
  @override
  Stream<List<Map<String, dynamic>>> history(String uid) => Stream.value(
    uid == 'a'
        ? [
            {'id': 'past'},
          ]
        : [],
  );
  @override
  Future<Map<String, dynamic>> relationship(String id) async => {
    'senderName': 'Pessoa A',
    'recipientName': 'Pessoa B',
  };
  @override
  Stream<List<CoupleRecord>> records(
    String id,
    String collection, {
    String? listId,
  }) => Stream.value(
    collection == 'experiences' && withExperience
        ? [
            CoupleRecord('experience', {
              'version': 1,
              'revision': 1,
              'authorId': 'a',
              'participantIds': ['a', 'b'],
              'createdAt': Timestamp.fromDate(DateTime(2020)),
              'occurredOn': '2020-01-01',
              'selection': CoupleSelection(
                type: MediaType.movie,
                title: 'Filme fictício',
              ).toMap(),
              'responses': {
                'a': {'decision': 'confirmed', 'revision': 1},
                'b': {'decision': 'confirmed', 'revision': 1},
              },
            }),
          ]
        : [],
  );
  @override
  Future<void> createList(
    String uid,
    String relation,
    String id,
    String title,
  ) {
    creates.add(id);
    return gate.future;
  }

  @override
  Future<void> respond(
    String uid,
    String relation,
    CoupleRecord record,
    String decision,
  ) {
    decisions.add(decision);
    return gate.future;
  }
}

void main() {
  setUpAll(useBundledTestFonts);
  Future<void> show(
    WidgetTester tester,
    JointAuth auth,
    JointUiService service, {
    bool small = false,
  }) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthService>.value(
        value: auth,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(small ? 2 : 1)),
            child: child!,
          ),
          home: CoupleWorkspaceScreen(service: service),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'lista pequena/texto 2x aguarda confirmação e retry conserva intenção',
    (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = JointAuth(), service = JointUiService();
      await show(tester, auth, service, small: true);
      await tester.scrollUntilVisible(find.text('Nova lista'), 150);
      await Scrollable.ensureVisible(
        tester.element(find.text('Nova lista')),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nova lista'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Próximos momentos');
      await tester.ensureVisible(find.text('Criar'));
      await tester.tap(find.text('Criar'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(service.creates, ['intention']);
      expect(find.text('Alteração confirmada.'), findsNothing);
      service.gate.completeError(StateError('PRIVATE_FIXTURE'));
      await tester.pumpAndSettle();
      expect(find.textContaining('PRIVATE_FIXTURE'), findsNothing);
      service.gate = Completer<void>();
      await tester.ensureVisible(find.text('Repetir alteração'));
      await tester.tap(find.text('Repetir alteração'));
      await tester.pump();
      expect(service.creates, ['intention', 'intention']);
      service.gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Alteração confirmada.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      auth.dispose();
    },
  );
  testWidgets(
    'histórico permite só retirada e troca de conta descarta sucesso tardio',
    (tester) async {
      final auth = JointAuth()..active = false,
          service = JointUiService()..withExperience = true;
      await show(tester, auth, service);
      await tester.tap(find.text('Histórico 1'));
      await tester.pumpAndSettle();
      expect(find.text('Confirmar versão'), findsNothing);
      expect(find.text('Corrigir proposta'), findsNothing);
      expect(
        find.text('1 experiências confirmadas pelos dois'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Retirar minha confirmação'));
      await tester.tap(find.text('Retirar minha confirmação'));
      await tester.pump();
      auth.change();
      await tester.pump();
      service.gate.complete();
      await tester.pumpAndSettle();
      expect(service.decisions, ['withdrawn']);
      expect(find.text('Filme fictício'), findsNothing);
      expect(find.text('Alteração confirmada.'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      auth.dispose();
    },
  );
}
