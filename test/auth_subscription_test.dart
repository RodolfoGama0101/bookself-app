import 'dart:async';

import 'package:bookself_app/services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

class TestUser extends Fake implements User {
  TestUser(this.uid);
  @override
  final String uid;
}

class TestAuth extends Fake implements FirebaseAuth {
  final changes = StreamController<User?>.broadcast(sync: true);
  final login = Completer<UserCredential>();

  @override
  Stream<User?> authStateChanges() => changes.stream;

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) => login.future;
}

// Os dublês implementam apenas os métodos usados pelo serviço.
class TestFirestore extends Fake implements FirebaseFirestore {
  final feeds = <String, TestFeed>{};

  TestFeed feed(String uid) => feeds.putIfAbsent(uid, TestFeed.new);

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    assert(collectionPath == 'users');
    return TestCollection(this);
  }
}

class TestFeed {
  TestFeed() {
    controller =
        StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast(
          sync: true,
          onListen: () => subscriptions++,
          onCancel: () => cancellations++,
        );
  }
  late final StreamController<DocumentSnapshot<Map<String, dynamic>>>
  controller;
  int subscriptions = 0;
  int cancellations = 0;
}

// ignore: subtype_of_sealed_class
class TestCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  TestCollection(this.store);
  final TestFirestore store;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      TestReference(store, path!);
}

// ignore: subtype_of_sealed_class
class TestReference extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  TestReference(this.store, this.uid);
  final TestFirestore store;
  final String uid;

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => store.feed(uid).controller.stream;
}

// ignore: subtype_of_sealed_class
class TestSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  TestSnapshot(this.id, this.values);
  @override
  final String id;
  final Map<String, dynamic>? values;
  @override
  bool get exists => values != null;
  @override
  Map<String, dynamic>? data() => values;
}

Map<String, dynamic> profile(String uid, {String? partner}) => {
  'uid': uid,
  'name': uid,
  'email': '',
  'partnerUid': partner,
  'createdAt': Timestamp.fromDate(DateTime(2025)),
};

void main() {
  late TestAuth auth;
  late TestFirestore store;
  late AuthService service;
  late bool disposed;

  setUp(() {
    auth = TestAuth();
    store = TestFirestore();
    service = AuthService(auth: auth, firestore: store);
    disposed = false;
  });

  tearDown(() async {
    if (!disposed) service.dispose();
    await auth.changes.close();
    for (final feed in store.feeds.values) {
      await feed.controller.close();
    }
  });

  test('troca de conta e logout limpam estado e cancelam ouvintes', () {
    auth.changes.add(TestUser('a'));
    store
        .feed('a')
        .controller
        .add(TestSnapshot('a', profile('a', partner: 'p')));
    store.feed('p').controller.add(TestSnapshot('p', profile('p')));
    expect(service.partnerUserModel?.uid, 'p');

    auth.changes.add(TestUser('b'));
    expect(service.currentUserModel, isNull);
    expect(service.partnerUserModel, isNull);
    expect(store.feed('a').cancellations, 1);
    expect(store.feed('p').cancellations, 1);
    store
        .feed('a')
        .controller
        .add(TestSnapshot('a', profile('a', partner: 'p')));
    store.feed('p').controller.add(TestSnapshot('p', profile('p')));
    expect(service.currentUserModel, isNull);
    expect(service.partnerUserModel, isNull);
    store.feed('b').controller.add(TestSnapshot('b', profile('b')));
    expect(service.currentUserModel?.uid, 'b');

    auth.changes.add(null);
    expect(service.currentUserModel, isNull);
    expect(service.partnerUserModel, isNull);
    expect(store.feed('b').cancellations, 1);
  });

  test(
    'alterar ou remover parceiro encerra o anterior sem duplicar ouvinte',
    () {
      auth.changes.add(TestUser('a'));
      final current = store.feed('a').controller;
      current.add(TestSnapshot('a', profile('a', partner: 'p')));
      store.feed('p').controller.add(TestSnapshot('p', profile('p')));
      current.add(TestSnapshot('a', profile('a', partner: 'p')));
      expect(store.feed('p').subscriptions, 1);
      current.add(TestSnapshot('a', profile('a', partner: 'q')));
      expect(service.partnerUserModel, isNull);
      expect(store.feed('p').cancellations, 1);
      store.feed('q').controller.add(TestSnapshot('q', profile('q')));
      expect(service.partnerUserModel?.uid, 'q');
      current.add(TestSnapshot('a', profile('a')));
      expect(service.partnerUserModel, isNull);
      expect(store.feed('q').cancellations, 1);
    },
  );

  test('perfil ausente ou com erro limpa o parceiro', () {
    auth.changes.add(TestUser('a'));
    final current = store.feed('a').controller;
    current.add(TestSnapshot('a', profile('a', partner: 'p')));
    store.feed('p').controller.add(TestSnapshot('p', profile('p')));
    current.add(TestSnapshot('a', null));
    expect(service.currentUserModel, isNull);
    expect(service.partnerUserModel, isNull);
    expect(store.feed('p').cancellations, 1);
    current.add(TestSnapshot('a', profile('a', partner: 'p')));
    store.feed('p').controller.add(TestSnapshot('p', profile('p')));
    current.addError(StateError('falha fictícia'));
    expect(service.currentUserModel, isNull);
    expect(service.partnerUserModel, isNull);
    expect(store.feed('p').cancellations, 2);
  });

  test('descarte cancela ouvintes e não notifica ao terminar login', () async {
    auth.changes.add(TestUser('a'));
    store
        .feed('a')
        .controller
        .add(TestSnapshot('a', profile('a', partner: 'p')));
    final operation = service.signInWithEmail('teste@example.com', 'fictícia');
    service.dispose();
    disposed = true;
    expect(auth.changes.hasListener, isFalse);
    expect(store.feed('a').cancellations, 1);
    expect(store.feed('p').cancellations, 1);
    auth.login.completeError(FirebaseAuthException(code: 'invalid-credential'));
    expect(await operation, isNotNull);
  });

  test(
    'descarte agendado por notificação encerra o ouvinte iniciado',
    () async {
      service.addListener(() {
        scheduleMicrotask(() {
          service.dispose();
          disposed = true;
        });
      });
      auth.changes.add(TestUser('a'));
      await Future<void>.delayed(Duration.zero);
      expect(auth.changes.hasListener, isFalse);
      expect(store.feed('a').cancellations, 1);
    },
  );
}
