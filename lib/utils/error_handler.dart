import 'package:firebase_auth/firebase_auth.dart';

class ErrorHandler {
  /// Retorna uma mensagem de erro amigável ao usuário em Português
  static String getFriendlyErrorMessage(dynamic error) {
    if (error == null) return 'Ocorreu um erro desconhecido.';

    final message = error.toString().toLowerCase();

    // Firebase Auth Exceptions
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'O formato do e-mail inserido é inválido.';
        case 'user-disabled':
          return 'Este usuário foi desativado. Entre em contato com o suporte.';
        case 'user-not-found':
          return 'Nenhum usuário encontrado com este e-mail.';
        case 'wrong-password':
          return 'Senha incorreta. Tente novamente.';
        case 'email-already-in-use':
          return 'Este e-mail já está sendo utilizado por outra conta.';
        case 'weak-password':
          return 'A senha fornecida é muito fraca. Insira pelo menos 6 caracteres.';
        case 'operation-not-allowed':
          return 'Esta operação não está habilitada.';
        case 'network-request-failed':
          return 'Falha na conexão de rede. Verifique seu acesso à internet.';
        default:
          return error.message ?? 'Erro na autenticação. Tente novamente.';
      }
    }

    // Firestore Exceptions
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Você não tem permissão para realizar esta ação.';
        case 'unavailable':
          return 'O serviço está temporariamente indisponível. Verifique sua conexão.';
        case 'not-found':
          return 'O documento solicitado não foi encontrado.';
        case 'already-exists':
          return 'Este registro já existe.';
        case 'failed-precondition':
          if (message.contains('index')) {
            return 'Erro interno: Esta consulta requer um índice do banco de dados.';
          }
          return 'Pré-condição falhou para esta operação.';
        default:
          return error.message ?? 'Erro no banco de dados. Tente novamente.';
      }
    }

    // Generic Network/FormatException Errors
    if (message.contains('network') || message.contains('socketexception') || message.contains('connection failed')) {
      return 'Erro de conexão. Por favor, verifique se você está conectado à internet.';
    }

    if (message.contains('format-exception') || message.contains('formatexception')) {
      return 'Formato de dados inválido recebido do servidor.';
    }

    if (message.contains('quota') || message.contains('quotaexceeded') || message.contains('rate limit')) {
      return 'Limite de requisições excedido. Por favor, aguarde alguns instantes e tente novamente.';
    }

    // Fallback default message
    return 'Ocorreu um problema inesperado. Detalhes: ${error.toString()}';
  }
}
