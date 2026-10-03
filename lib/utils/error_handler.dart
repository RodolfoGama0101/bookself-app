import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

enum ErrorOperation {
  request,
  initialize,
  restoreSession,
  loadProfile,
  loadPartnerProfile,
  signIn,
  signUp,
  saveProfile,
  signOut,
  resetPassword,
  linkPartner,
  unlinkPartner,
  searchBooks,
  saveBook,
  deleteBook,
  loadLibrary,
  loadFeed,
  loadBibleProgress,
  loadPartnerBibleProgress,
  saveBibleProgress,
  updateName,
  updatePhoto,
  loadBookCover,
  loadTheme,
  saveTheme,
}

/// Transporta somente o status, sem URL, chave, consulta ou corpo da resposta.
class CatalogRequestException implements Exception {
  const CatalogRequestException(this.statusCode);

  final int statusCode;
}

class ErrorHandler {
  static const networkMessage =
      'Não foi possível conectar. Verifique sua conexão e tente novamente.';
  static const timeoutMessage =
      'A conexão demorou mais que o esperado. Tente novamente.';
  static const unexpectedMessage =
      'Ocorreu um problema inesperado. Tente novamente.';
  static const _unavailableMessage =
      'O serviço está temporariamente indisponível. Tente novamente mais tarde.';
  static const _limitMessage =
      'O limite de tentativas foi atingido. Aguarde um pouco e tente novamente.';
  static const _credentialsMessage =
      'E-mail ou senha incorretos. Verifique os dados e tente novamente.';

  static const _authMessages = {
    'invalid-email': 'Informe um e-mail válido.',
    'user-disabled':
        'Esta conta foi desativada. Entre em contato com o suporte.',
    'user-not-found': _credentialsMessage,
    'wrong-password': _credentialsMessage,
    'invalid-credential': _credentialsMessage,
    'invalid-login-credentials': _credentialsMessage,
    'email-already-in-use':
        'Este e-mail já está sendo utilizado por outra conta.',
    'weak-password':
        'A senha não atende aos requisitos. Escolha uma senha mais forte.',
    'operation-not-allowed':
        'Esta ação está indisponível. Tente novamente mais tarde.',
    'network-request-failed': networkMessage,
    'too-many-requests': _limitMessage,
    'quota-exceeded': _limitMessage,
    'requires-recent-login':
        'Entre novamente na sua conta para realizar esta ação.',
    'user-token-expired': 'Sua sessão expirou. Entre novamente para continuar.',
    'invalid-user-token': 'Sua sessão expirou. Entre novamente para continuar.',
  };

  static const _firebaseMessages = {
    'permission-denied': 'Você não tem permissão para realizar esta ação.',
    'unauthenticated': 'Entre novamente na sua conta para realizar esta ação.',
    'unavailable': _unavailableMessage,
    'deadline-exceeded': timeoutMessage,
    'not-found': 'O registro solicitado não foi encontrado.',
    'already-exists': 'Este registro já existe.',
    'failed-precondition':
        'Não foi possível realizar esta ação agora. Tente novamente mais tarde.',
    'resource-exhausted': _limitMessage,
    'aborted': 'Os dados mudaram durante a operação. Tente novamente.',
    'cancelled': 'A operação foi interrompida. Tente novamente.',
    'internal': _unavailableMessage,
    'invalid-argument':
        'Não foi possível enviar os dados. Confira os campos e tente novamente.',
  };

  static const _platformMessages = {
    'camera_access_denied':
        'Permita o acesso à câmera nas configurações do dispositivo.',
    'photo_access_denied':
        'Permita o acesso às fotos nas configurações do dispositivo.',
    'read_external_storage_denied':
        'Permita o acesso às fotos nas configurações do dispositivo.',
    'network_error': networkMessage,
  };

  /// Não consulta message, details, toString ou stack de erros externos.
  static String getFriendlyErrorMessage(
    Object? error, {
    ErrorOperation operation = ErrorOperation.request,
  }) {
    final description = _describe(error);
    _log(description, operation);
    if ((operation == ErrorOperation.loadTheme ||
            operation == ErrorOperation.saveTheme) &&
        error is TimeoutException) {
      return 'A operação demorou mais que o esperado. Tente novamente.';
    }
    if (operation == ErrorOperation.resetPassword &&
        error is FirebaseAuthException &&
        error.code == 'user-not-found') {
      return 'Não foi possível enviar o e-mail de recuperação. Confira o endereço e tente novamente.';
    }
    return description.message;
  }

  static void report(Object? error, {required ErrorOperation operation}) {
    _log(_describe(error), operation);
  }

  static void _log(
    ({String message, String category, String code}) description,
    ErrorOperation operation,
  ) {
    // Apenas identificadores fixos/permitidos; nunca mensagem, URL ou dados pessoais.
    debugPrint(
      '[bookself.error] operation=${operation.name} '
      'category=${description.category} code=${description.code}',
    );
  }

  static ({String message, String category, String code}) _describe(
    Object? error,
  ) {
    if (error is FirebaseAuthException) {
      return (
        message:
            _authMessages[error.code] ??
            'Não foi possível autenticar sua conta. Tente novamente.',
        category: 'auth',
        code: _authMessages.containsKey(error.code) ? error.code : 'unknown',
      );
    }
    if (error is FirebaseException) {
      return (
        message:
            _firebaseMessages[error.code] ??
            'Não foi possível acessar seus dados. Tente novamente.',
        category: 'firebase',
        code: _firebaseMessages.containsKey(error.code)
            ? error.code
            : 'unknown',
      );
    }
    if (error is CatalogRequestException) {
      final status = error.statusCode;
      return (
        message: switch (status) {
          429 => _limitMessage,
          401 || 403 =>
            'A busca está indisponível no momento. Tente novamente mais tarde.',
          404 =>
            'O catálogo não está disponível no momento. Tente novamente mais tarde.',
          >= 500 && <= 599 => _unavailableMessage,
          _ => 'Não foi possível buscar livros. Tente novamente.',
        },
        category: 'catalog',
        code: status >= 400 && status <= 599 ? 'http-$status' : 'unknown',
      );
    }
    if (error is TimeoutException) {
      return (message: timeoutMessage, category: 'network', code: 'timeout');
    }
    if (error is SocketException ||
        error is http.ClientException ||
        error is HandshakeException) {
      return (message: networkMessage, category: 'network', code: 'connection');
    }
    if (error is FormatException || error is TypeError) {
      return (
        message: 'Não foi possível ler os dados recebidos. Tente novamente.',
        category: 'data',
        code: 'invalid-format',
      );
    }
    if (error is PlatformException) {
      return (
        message: _platformMessages[error.code] ?? unexpectedMessage,
        category: 'platform',
        code: _platformMessages.containsKey(error.code)
            ? error.code
            : 'unknown',
      );
    }
    return (message: unexpectedMessage, category: 'unknown', code: 'unknown');
  }
}
