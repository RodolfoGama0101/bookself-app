import 'dart:async';

import 'package:bookself_app/services/auth_service.dart';
import 'package:bookself_app/utils/error_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/auth_fakes.dart';

class ErrorTestAuth extends FakeFirebaseAuth {
  Object? resetFailure;

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    ActionCodeSettings? actionCodeSettings,
  }) async {
    if (resetFailure != null) throw resetFailure!;
  }
}

class FailingFirestore extends Fake implements FirebaseFirestore {
  Object failure = StateError('PRIVATE_FIXTURE');

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      throw failure;

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async => throw failure;

  @override
  WriteBatch batch() => throw failure;
}

void main() {
  late ErrorTestAuth auth;
  late FakeUserProfiles profiles;
  late FailingFirestore database;
  late AuthService service;

  setUp(() {
    auth = ErrorTestAuth();
    profiles = FakeUserProfiles();
    database = FailingFirestore();
    service = AuthService(auth: auth, profiles: profiles, firestore: database);
  });
  tearDown(() async {
    service.dispose();
    await auth.changes.close();
    await profiles.close();
  });

  final failures = {
    'credencial inválida': (
      FirebaseAuthException(
        code: 'invalid-credential',
        message: 'PRIVATE_FIXTURE',
      ),
      'E-mail ou senha incorretos',
    ),
    'código novo do provedor': (
      FirebaseAuthException(
        code: 'PRIVATE_FIXTURE',
        message: 'PRIVATE_FIXTURE',
      ),
      'autenticar sua conta',
    ),
    'falha desconhecida': (
      StateError('PRIVATE_FIXTURE'),
      ErrorHandler.unexpectedMessage,
    ),
    'timeout': (
      TimeoutException('PRIVATE_FIXTURE'),
      ErrorHandler.timeoutMessage,
    ),
    'rede': (
      http.ClientException('PRIVATE_FIXTURE'),
      ErrorHandler.networkMessage,
    ),
  };

  for (final flow in ['login', 'cadastro', 'recuperação']) {
    for (final entry in failures.entries) {
      testWidgets(
        '$flow traduz ${entry.key} sem expor detalhes e libera carregamento',
        (tester) async {
          final (failure, expected) = entry.value;
          auth.onSignIn = () async => throw failure;
          auth.onSignUp = () async => throw failure;
          auth.resetFailure = failure;
          final message = switch (flow) {
            'login' => await service.signInWithEmail(
              'teste@example.com',
              'fixture',
            ),
            'cadastro' => await service.signUpWithEmail(
              'Pessoa',
              'teste@example.com',
              'fixture',
            ),
            _ => await service.sendPasswordReset('teste@example.com'),
          };
          expect(message, contains(expected));
          expect(message, isNot(contains('PRIVATE_FIXTURE')));
          expect(service.isLoading, isFalse);
          expect(profiles.createCalls, 0);
        },
      );
    }
  }

  for (final unlink in [false, true]) {
    for (final code in [
      'permission-denied',
      'unavailable',
      'PRIVATE_FIXTURE',
    ]) {
      testWidgets(
        '${unlink ? 'desvinculação' : 'vínculo'} traduz $code sem escrita remota',
        (tester) async {
          auth.emit(FakeUser('owner'));
          await tester.pump();
          profiles
              .controller('owner')
              .add(profile('owner', partnerUid: unlink ? 'partner' : null));
          await tester.pump();
          database.failure = FirebaseException(
            plugin: 'cloud_firestore',
            code: code,
            message: 'PRIVATE_FIXTURE',
          );
          final message = unlink
              ? await service.unlinkPartner()
              : await service.acceptInvitation(
                  '11111111111111111111111111111111',
                );
          expect(
            message,
            contains(switch (code) {
              'permission-denied' => 'não tem permissão',
              'unavailable' => 'temporariamente indisponível',
              _ => 'acessar seus dados',
            }),
          );
          expect(message, isNot(contains('PRIVATE_FIXTURE')));
          expect(service.isLoading, isFalse);
        },
      );
    }
  }

  testWidgets(
    'leitura de perfil mostra permissão sem sugerir apenas falha de rede',
    (tester) async {
      auth.emit(FakeUser('owner'));
      await tester.pump();
      profiles
          .controller('owner')
          .addError(
            FirebaseException(
              plugin: 'cloud_firestore',
              code: 'permission-denied',
              message: 'PRIVATE_FIXTURE',
            ),
          );
      await tester.pump();
      expect(service.sessionState, AuthSessionState.profileError);
      expect(service.sessionError, contains('não tem permissão'));
      expect(service.sessionError, isNot(contains('PRIVATE_FIXTURE')));
    },
  );

  testWidgets(
    'cadastro parcial mantém conta e recuperação com orientação de permissão',
    (tester) async {
      profiles.onCreate = (_) async => throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'PRIVATE_FIXTURE',
      );
      final message = await service.signUpWithEmail(
        'Pessoa',
        'teste@example.com',
        'fixture',
      );
      await tester.pump();
      expect(service.hasAuthenticatedSession, isTrue);
      expect(service.sessionState, AuthSessionState.profileError);
      expect(service.sessionError, contains('Sua conta já está criada'));
      expect(service.sessionError, contains('não tem permissão'));
      expect(message, contains('não tem permissão'));
      expect(message, isNot(contains('PRIVATE_FIXTURE')));
    },
  );
}
