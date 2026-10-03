import 'dart:async';
import 'dart:io';

import 'package:bookself_app/utils/error_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class UnprintableError implements Exception {
  @override
  String toString() =>
      throw StateError('Não deve consultar a descrição externa');
}

void main() {
  late DebugPrintCallback originalDebugPrint;
  late List<String> logs;
  setUp(() {
    originalDebugPrint = debugPrint;
    logs = [];
    debugPrint = (message, {wrapWidth}) {
      if (message != null) logs.add(message);
    };
  });
  tearDown(() => debugPrint = originalDebugPrint);

  test('variações de credencial inválida têm a mesma orientação', () {
    final messages = [
      for (final code in [
        'invalid-credential',
        'invalid-login-credentials',
        'user-not-found',
        'wrong-password',
      ])
        ErrorHandler.getFriendlyErrorMessage(FirebaseAuthException(code: code)),
    ];
    expect(messages.toSet(), hasLength(1));
    expect(messages.first, contains('E-mail ou senha incorretos'));
  });

  test(
    'autenticação distingue e-mail, senha fraca, limite e sessão expirada',
    () {
      final cases = {
        'invalid-email': 'e-mail válido',
        'weak-password': 'senha mais forte',
        'email-already-in-use': 'outra conta',
        'too-many-requests': 'Aguarde',
        'requires-recent-login': 'Entre novamente',
        'user-token-expired': 'sessão expirou',
        'user-disabled': 'conta foi desativada',
        'operation-not-allowed': 'indisponível',
      };
      for (final entry in cases.entries) {
        expect(
          ErrorHandler.getFriendlyErrorMessage(
            FirebaseAuthException(code: entry.key, message: 'PRIVATE_FIXTURE'),
          ),
          contains(entry.value),
        );
      }
    },
  );

  test(
    'erros do banco orientam ação sem exibir índice ou detalhes técnicos',
    () {
      final cases = {
        'permission-denied': 'não tem permissão',
        'unauthenticated': 'Entre novamente',
        'unavailable': 'temporariamente indisponível',
        'deadline-exceeded': 'demorou',
        'not-found': 'não foi encontrado',
        'already-exists': 'já existe',
        'failed-precondition': 'Tente novamente mais tarde',
        'resource-exhausted': 'Aguarde',
        'aborted': 'Os dados mudaram',
      };
      for (final entry in cases.entries) {
        final message = ErrorHandler.getFriendlyErrorMessage(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: entry.key,
            message: 'index https://example.invalid/PRIVATE_FIXTURE',
          ),
        );
        expect(message, contains(entry.value));
        expect(message, isNot(contains('index')));
      }
    },
  );

  for (final isAuth in [true, false]) {
    test(
      'erro desconhecido ${isAuth ? 'Auth' : 'Firebase'} oculta código e mensagem externos',
      () {
        final error = isAuth
            ? FirebaseAuthException(
                code: 'PRIVATE_FIXTURE',
                message: 'PRIVATE_FIXTURE',
              )
            : FirebaseException(
                plugin: 'PRIVATE_FIXTURE',
                code: 'PRIVATE_FIXTURE',
                message: 'PRIVATE_FIXTURE',
              );
        final message = ErrorHandler.getFriendlyErrorMessage(error);
        expect(message, contains('Tente novamente'));
        expect(message, isNot(contains('PRIVATE_FIXTURE')));
        expect(logs.single, endsWith('code=unknown'));
        expect(logs.single, isNot(contains('PRIVATE_FIXTURE')));
      },
    );
  }

  test('fallback é fixo e nunca chama toString de dados externos', () {
    for (final error in [
      null,
      'PRIVATE_FIXTURE',
      StateError('PRIVATE_FIXTURE'),
      UnprintableError(),
    ]) {
      expect(
        ErrorHandler.getFriendlyErrorMessage(error),
        ErrorHandler.unexpectedMessage,
      );
      expect(logs.last, endsWith('category=unknown code=unknown'));
    }
  });

  test('rede usa tipos concretos e não palavras na descrição', () {
    final errors = [
      const SocketException('PRIVATE_FIXTURE'),
      const HandshakeException('PRIVATE_FIXTURE'),
      http.ClientException(
        'PRIVATE_FIXTURE',
        Uri.parse('https://example.invalid/PRIVATE_FIXTURE'),
      ),
      FirebaseAuthException(
        code: 'network-request-failed',
        message: 'PRIVATE_FIXTURE',
      ),
    ];
    for (final error in errors) {
      expect(
        ErrorHandler.getFriendlyErrorMessage(error),
        ErrorHandler.networkMessage,
      );
    }
    expect(
      ErrorHandler.getFriendlyErrorMessage(
        StateError('network quota format-exception'),
      ),
      ErrorHandler.unexpectedMessage,
    );
  });

  test('timeout descarta texto externo e sugere repetir', () {
    expect(
      ErrorHandler.getFriendlyErrorMessage(TimeoutException('PRIVATE_FIXTURE')),
      ErrorHandler.timeoutMessage,
    );
    expect(logs.single, endsWith('category=network code=timeout'));
  });

  test('conta ausente na recuperação orienta e-mail sem pedir senha', () {
    final message = ErrorHandler.getFriendlyErrorMessage(
      FirebaseAuthException(code: 'user-not-found', message: 'PRIVATE_FIXTURE'),
      operation: ErrorOperation.resetPassword,
    );
    expect(message, contains('Confira o endereço'));
    expect(message, isNot(contains('senha incorreta')));
    expect(message, isNot(contains('PRIVATE_FIXTURE')));
  });

  test('dados inválidos ocultam conteúdo e origem', () {
    final TypeError typeError;
    try {
      final Object value = 123;
      value as String;
      fail('Deveria falhar a conversão');
    } on TypeError catch (error) {
      typeError = error;
    }
    for (final error in [
      const FormatException('PRIVATE_FIXTURE', 'PRIVATE_FIXTURE'),
      typeError,
    ]) {
      expect(
        ErrorHandler.getFriendlyErrorMessage(error),
        contains('ler os dados'),
      );
      expect(logs.last, endsWith('category=data code=invalid-format'));
    }
  });

  test(
    'permissões de câmera/fotos têm orientação sem details da plataforma',
    () {
      for (final code in ['camera_access_denied', 'photo_access_denied']) {
        expect(
          ErrorHandler.getFriendlyErrorMessage(
            PlatformException(
              code: code,
              message: 'PRIVATE_FIXTURE',
              details: 'PRIVATE_FIXTURE',
            ),
          ),
          contains('configurações do dispositivo'),
        );
      }
      expect(
        ErrorHandler.getFriendlyErrorMessage(
          PlatformException(
            code: 'PRIVATE_FIXTURE',
            details: 'PRIVATE_FIXTURE',
          ),
        ),
        ErrorHandler.unexpectedMessage,
      );
      expect(logs.last, endsWith('category=platform code=unknown'));
    },
  );

  test('catálogo diferencia limite, autorização e indisponibilidade', () {
    final cases = {
      429: 'Aguarde',
      403: 'busca está indisponível',
      503: 'temporariamente indisponível',
      404: 'catálogo',
      400: 'buscar livros',
    };
    for (final entry in cases.entries) {
      expect(
        ErrorHandler.getFriendlyErrorMessage(
          CatalogRequestException(entry.key),
        ),
        contains(entry.value),
      );
      expect(logs.last, endsWith('category=catalog code=http-${entry.key}'));
    }
    ErrorHandler.report(
      const CatalogRequestException(-1),
      operation: ErrorOperation.searchBooks,
    );
    expect(logs.last, endsWith('code=unknown'));
  });

  test('diagnóstico registra operação/categoria/código e ignora dados pessoais', () {
    const privateData =
        'PRIVATE_FIXTURE email=teste@example.invalid token=fixture url=https://example.invalid/fixture';
    final errors = [
      FirebaseAuthException(
        code: 'invalid-credential',
        message: privateData,
        email: 'teste@example.invalid',
      ),
      FirebaseException(
        plugin: privateData,
        code: 'permission-denied',
        message: privateData,
      ),
      PlatformException(
        code: privateData,
        message: privateData,
        details: privateData,
        stacktrace: privateData,
      ),
      StateError(privateData),
    ];
    for (final error in errors) {
      ErrorHandler.report(error, operation: ErrorOperation.saveProfile);
    }
    expect(logs, [
      '[bookself.error] operation=saveProfile category=auth code=invalid-credential',
      '[bookself.error] operation=saveProfile category=firebase code=permission-denied',
      '[bookself.error] operation=saveProfile category=platform code=unknown',
      '[bookself.error] operation=saveProfile category=unknown code=unknown',
    ]);
  });
}
