import 'dart:async';

import 'package:bookself_app/data/models/user_model.dart';
import 'package:bookself_app/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_fakes.dart';

void main() {
  late FakeFirebaseAuth auth;
  late FakeUserProfiles profiles;
  late AuthService service;
  var disposed = false;

  setUp(() {
    auth = FakeFirebaseAuth();
    profiles = FakeUserProfiles();
    service = AuthService(auth: auth, profiles: profiles);
    disposed = false;
  });

  tearDown(() async {
    if (!disposed) service.dispose();
    await auth.changes.close();
    await profiles.close();
  });

  testWidgets('restauração aguarda perfil e não confunde ausência com logout', (
    tester,
  ) async {
    expect(service.sessionState, AuthSessionState.restoring);
    auth.emit(FakeUser('user'));
    await tester.pump();
    expect(service.sessionState, AuthSessionState.loadingProfile);
    expect(service.hasAuthenticatedSession, isTrue);
    expect(service.currentUserModel, isNull);

    profiles.controller('user').add(null);
    await tester.pump();
    expect(service.sessionState, AuthSessionState.missingProfile);
    expect(service.hasAuthenticatedSession, isTrue);

    profiles.controller('user').add(profile('user'));
    await tester.pump();
    expect(service.sessionState, AuthSessionState.ready);
    expect(service.currentUserModel?.name, 'Nome preservado');

    profiles.controller('user').add(null);
    await tester.pump();
    expect(service.sessionState, AuthSessionState.missingProfile);
    expect(service.currentUserModel, isNull);
  });

  testWidgets('erro de leitura é recuperável sem escrita nem novo cadastro', (
    tester,
  ) async {
    auth.emit(FakeUser('user'));
    await tester.pump();
    profiles
        .controller('user')
        .addError(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
            message: 'Erro técnico',
          ),
        );
    await tester.pump();
    expect(service.sessionState, AuthSessionState.profileError);
    expect(service.sessionError, isNot(contains('Erro técnico')));
    expect(service.hasAuthenticatedSession, isTrue);

    service.retryProfile();
    service.retryProfile();
    expect(profiles.watchCalls['user'], 2);
    expect(service.sessionState, AuthSessionState.loadingProfile);
    profiles.controller('user').add(profile('user'));
    await tester.pump();
    expect(service.sessionState, AuthSessionState.ready);
    expect(profiles.createCalls, 0);
    expect(auth.createCalls, 0);
  });

  testWidgets(
    'sessão e perfil sem resposta saem do carregamento após 15 segundos',
    (tester) async {
      // Cria o timer inicial dentro do relógio controlado do teste de widgets.
      service.dispose();
      service = AuthService(auth: auth, profiles: profiles);
      await tester.pump(const Duration(seconds: 15));
      expect(service.sessionState, AuthSessionState.authError);
      service.retrySession();
      auth.emit(FakeUser('user'));
      await tester.pump();
      expect(service.sessionState, AuthSessionState.loadingProfile);
      await tester.pump(const Duration(seconds: 15));
      expect(service.sessionState, AuthSessionState.profileError);
      expect(service.hasAuthenticatedSession, isTrue);

      profiles.controller('user').add(profile('user'));
      await tester.pump();
      expect(service.sessionState, AuthSessionState.ready);
    },
  );

  testWidgets('falha de autenticação oferece nova restauração', (tester) async {
    auth.changes.addError(StateError('Falha técnica'));
    await tester.pump();
    expect(service.sessionState, AuthSessionState.authError);
    service.retrySession();
    auth.emit(null);
    await tester.pump();
    expect(service.sessionState, AuthSessionState.signedOut);
  });

  testWidgets(
    'cadastro parcial mantém sessão e pode concluir perfil sem recriar conta',
    (tester) async {
      profiles.onCreate = (_) async => throw StateError('Escrita rejeitada');
      expect(
        await service.signUpWithEmail('Pessoa', 'teste@example.com', 'senha'),
        isNotNull,
      );
      expect(auth.createCalls, 1);
      expect(service.hasAuthenticatedSession, isTrue);
      expect(service.sessionState, AuthSessionState.profileError);
      expect(service.currentUserModel, isNull);
      expect(service.isLoading, isFalse);

      service.retryProfile();
      profiles.controller('new-user').add(null);
      await tester.pump();
      expect(service.sessionState, AuthSessionState.missingProfile);
      profiles.onCreate = null;
      expect(await service.completeMissingProfile('Pessoa'), isNull);
      expect(service.sessionState, AuthSessionState.ready);
      expect(service.currentUserModel?.name, 'Pessoa');
      expect(auth.createCalls, 1);
    },
  );

  testWidgets(
    'recuperação preserva perfil criado entre a leitura e a escrita',
    (tester) async {
      auth.emit(FakeUser('user'));
      await tester.pump();
      profiles.controller('user').add(null);
      await tester.pump();
      final existing = profile('user', partnerUid: 'partner');
      profiles.stored['user'] = existing;
      expect(await service.completeMissingProfile('Outro nome'), isNull);
      expect(service.currentUserModel, same(existing));
      expect(service.currentUserModel?.photoUrl, 'foto-preservada');
      expect(service.currentUserModel?.partnerUid, 'partner');
      expect(service.currentUserModel?.createdAt, DateTime(2020));
    },
  );

  testWidgets('recuperação aguarda confirmação e bloqueia ações repetidas', (
    tester,
  ) async {
    auth.emit(FakeUser('user'));
    await tester.pump();
    profiles.controller('user').add(null);
    await tester.pump();
    final write = Completer<UserModel>();
    profiles.onCreate = (_) => write.future;
    final completion = service.completeMissingProfile('Pessoa');
    expect(service.isLoading, isTrue);
    expect(service.sessionState, AuthSessionState.missingProfile);
    expect(await service.completeMissingProfile('Pessoa'), isNotNull);
    service.retryProfile();
    expect(profiles.createCalls, 1);
    expect(profiles.watchCalls['user'], 1);
    write.complete(profile('user'));
    expect(await completion, isNull);
    expect(service.sessionState, AuthSessionState.ready);
    expect(service.isLoading, isFalse);
  });

  testWidgets(
    'escrita sem resposta não deixa recuperação ocupada indefinidamente',
    (tester) async {
      auth.emit(FakeUser('user'));
      await tester.pump();
      profiles.controller('user').add(null);
      await tester.pump();
      final write = Completer<UserModel>();
      profiles.onCreate = (_) => write.future;
      final completion = service.completeMissingProfile('Pessoa');
      await tester.pump(const Duration(seconds: 15));
      expect(await completion, isNotNull);
      expect(service.sessionState, AuthSessionState.profileError);
      expect(service.isLoading, isFalse);
      expect(service.currentUserModel, isNull);
      write.complete(profile('user'));
      await tester.pump();
      expect(service.sessionState, AuthSessionState.profileError);
    },
  );

  testWidgets(
    'troca de conta e logout ignoram perfil, parceiro e recuperação antigos',
    (tester) async {
      auth.emit(FakeUser('first'));
      await tester.pump();
      profiles.controller('first').add(profile('first', partnerUid: 'partner'));
      await tester.pump();
      profiles.controller('partner').add(profile('partner'));
      await tester.pump();
      expect(service.partnerUserModel, isNotNull);

      auth.emit(FakeUser('second'));
      await tester.pump();
      expect(service.currentUserModel, isNull);
      expect(service.partnerUserModel, isNull);
      expect(profiles.controller('first').hasListener, isFalse);
      expect(profiles.controller('partner').hasListener, isFalse);
      profiles.controller('first').add(profile('first'));
      profiles.controller('second').add(null);
      await tester.pump();
      final write = Completer<UserModel>();
      profiles.onCreate = (_) => write.future;
      final completion = service.completeMissingProfile('Pessoa');
      await service.signOut();
      await tester.pump();
      write.complete(profile('second'));
      expect(await completion, isNotNull);
      expect(service.sessionState, AuthSessionState.signedOut);
      expect(service.currentUserModel, isNull);
      expect(service.partnerUserModel, isNull);
      expect(profiles.controller('second').hasListener, isFalse);
    },
  );

  testWidgets('descarte cancela ouvintes e ignora conclusão pendente', (
    tester,
  ) async {
    auth.emit(FakeUser('user'));
    await tester.pump();
    profiles.controller('user').add(null);
    await tester.pump();
    final write = Completer<UserModel>();
    profiles.onCreate = (_) => write.future;
    final completion = service.completeMissingProfile('Pessoa');
    service.dispose();
    disposed = true;
    expect(auth.changes.hasListener, isFalse);
    expect(profiles.controller('user').hasListener, isFalse);
    write.complete(profile('user'));
    expect(await completion, isNotNull);
    auth.emit(FakeUser('another'));
    await tester.pump(const Duration(seconds: 15));
    expect(profiles.watchCalls['another'], isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'apresentação pendente/falha não bloqueia sessão; parceiro ausente preserva vínculo sem ler perfil privado',
    (tester) async {
      final publication = Completer<void>();
      service.dispose();
      service = AuthService(auth: auth, profiles: profiles);
      profiles.onPublish = (_) => publication.future;
      auth.emit(FakeUser('user'));
      await tester.pump();
      profiles.controller('user').add(profile('user', partnerUid: 'partner'));
      await tester.pump();
      expect(service.sessionState, AuthSessionState.ready);
      expect(service.partnerUserModel?.uid, 'partner');
      expect(service.partnerUserModel?.isAvailable, isFalse);
      profiles.controller('partner').add(null);
      await tester.pump();
      expect(service.currentUserModel?.partnerUid, 'partner');
      expect(profiles.watchCalls['partner'], isNull);
      publication.completeError(StateError('fixture'));
      await tester.pump();
      expect(service.sessionState, AuthSessionState.ready);
      profiles.controller('partner').add(profile('partner', name: 'Companhia'));
      await tester.pump();
      expect(service.partnerUserModel?.isAvailable, isTrue);
      profiles.controller('partner').addError(StateError('fixture'));
      await tester.pump();
      expect(service.partnerUserModel?.isAvailable, isFalse);
      expect(service.partnerUserModel?.photoUrl, isNull);
      await service.signOut();
      await tester.pump();
      expect(service.partnerUserModel, isNull);
      expect(profiles.controller('partner').hasListener, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('login sem resposta libera o formulário após limite de espera', (
    tester,
  ) async {
    auth.emit(null);
    await tester.pump();
    final signIn = Completer<UserCredential>();
    auth.onSignIn = () => signIn.future;
    final completion = service.signInWithEmail('teste@example.com', 'senha');
    await tester.pump(const Duration(seconds: 15));
    expect(
      await completion,
      'A conexão demorou mais que o esperado. Tente novamente.',
    );
    expect(service.isLoading, isFalse);
    expect(service.sessionState, AuthSessionState.signedOut);
    signIn.complete(FakeCredential(null));
    await tester.pump();
  });

  testWidgets(
    'cadastro concluído após timeout recupera perfil pela sessão, sem recriar conta',
    (tester) async {
      auth.emit(null);
      await tester.pump();
      final signUp = Completer<UserCredential>();
      auth.onSignUp = () => signUp.future;
      final completion = service.signUpWithEmail(
        'Pessoa',
        'teste@example.com',
        'senha',
      );
      await tester.pump(const Duration(seconds: 15));
      expect(await completion, isNotNull);
      expect(service.isLoading, isFalse);
      final user = FakeUser('late-user');
      auth.emit(user);
      signUp.complete(FakeCredential(user));
      await tester.pump();
      profiles.controller('late-user').add(null);
      await tester.pump();
      expect(service.sessionState, AuthSessionState.missingProfile);
      expect(await service.completeMissingProfile('Pessoa'), isNull);
      expect(service.sessionState, AuthSessionState.ready);
      expect(auth.createCalls, 1);
    },
  );

  testWidgets(
    'atualizar perfil não duplica ouvinte e desvincular/descartar encerra parceiros',
    (tester) async {
      auth.emit(FakeUser('user'));
      await tester.pump();
      profiles
          .controller('user')
          .add(profile('user', partnerUid: 'first-partner'));
      await tester.pump();
      profiles.controller('first-partner').add(profile('first-partner'));
      await tester.pump();
      profiles
          .controller('user')
          .add(profile('user', name: 'Novo nome', partnerUid: 'first-partner'));
      await tester.pump();
      expect(profiles.partnerWatchCalls['first-partner'], 1);
      expect(profiles.watchCalls['first-partner'], isNull);

      profiles.controller('user').add(profile('user'));
      await tester.pump();
      expect(service.partnerUserModel, isNull);
      expect(profiles.controller('first-partner').hasListener, isFalse);
      profiles
          .controller('user')
          .add(profile('user', partnerUid: 'second-partner'));
      await tester.pump();
      profiles.controller('second-partner').add(profile('second-partner'));
      await tester.pump();
      service.dispose();
      disposed = true;
      expect(auth.changes.hasListener, isFalse);
      expect(profiles.controller('user').hasListener, isFalse);
      expect(profiles.controller('second-partner').hasListener, isFalse);
    },
  );
}
