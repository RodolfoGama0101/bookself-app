import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../data/models/user_model.dart';
import 'user_profile_service.dart';
import 'partner_service.dart';
import 'firebase_environment.dart';
import '../utils/error_handler.dart';

enum AuthSessionState {
  restoring,
  signedOut,
  loadingProfile,
  ready,
  missingProfile,
  profileError,
  authError,
}

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth;
  final PartnerService _partners;
  final UserProfileService _profiles;
  final Duration sessionTimeout;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<UserModel?>? _currentUserSubscription;
  StreamSubscription<UserModel?>? _partnerSubscription;
  Timer? _sessionTimer;
  int _authRevision = 0;
  int _profileRevision = 0;
  int _partnerRevision = 0;
  bool _disposed = false;
  User? _sessionUser;
  String? _partnerUid;
  String _profileNameSuggestion = '';
  String get profileNameSuggestion => _profileNameSuggestion;
  bool get hasAuthenticatedSession => _sessionUser != null;
  AuthSessionState _sessionState = AuthSessionState.restoring;
  AuthSessionState get sessionState => _sessionState;
  String? _sessionError;
  String? get sessionError => _sessionError;

  UserModel? _currentUserModel;
  UserModel? get currentUserModel => _currentUserModel;

  UserModel? _partnerUserModel;
  UserModel? get partnerUserModel => _partnerUserModel;

  bool _isLoading = false;
  bool _partnerOperationPending = false;
  int _partnerOperationRevision = 0;
  bool get isLoading => _isLoading || _partnerOperationPending;

  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    UserProfileService? profiles,
    PartnerService? partners,
    this.sessionTimeout = const Duration(seconds: 15),
  }) : _auth = auth ?? FirebaseEnvironment.auth,
       _partners = partners ?? PartnerService(firestore: firestore),
       _profiles = profiles ?? UserProfileService(firestore: firestore) {
    _listenToAuth();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  void _listenToAuth() {
    final revision = ++_authRevision;
    _authSubscription?.cancel();
    _sessionTimer?.cancel();
    _sessionState = AuthSessionState.restoring;
    _sessionError = null;
    _sessionTimer = Timer(sessionTimeout, () {
      if (!_disposed &&
          revision == _authRevision &&
          _sessionState == AuthSessionState.restoring) {
        _handleAuthError(TimeoutException(''));
      }
    });
    try {
      _authSubscription = _auth.authStateChanges().listen(
        (user) {
          if (!_disposed && revision == _authRevision) _handleAuthUser(user);
        },
        onError: (Object error) {
          if (!_disposed && revision == _authRevision) _handleAuthError(error);
        },
      );
    } catch (error) {
      _handleAuthError(error);
    }
  }

  void _handleAuthError(Object error) {
    _partnerOperationRevision++;
    _partnerOperationPending = false;
    _cancelSubscriptions();
    _currentUserModel = null;
    _sessionState = AuthSessionState.authError;
    _sessionError =
        'Não foi possível restaurar sua sessão. '
        '${ErrorHandler.getFriendlyErrorMessage(error, operation: ErrorOperation.restoreSession)}';
    notifyListeners();
  }

  void _handleAuthUser(User? user) {
    _partnerOperationRevision++;
    _partnerOperationPending = false;
    _cancelSubscriptions();
    _sessionUser = user;
    _currentUserModel = null;
    _sessionError = null;
    _profileNameSuggestion = user?.displayName ?? '';
    if (user == null) {
      _sessionState = AuthSessionState.signedOut;
      notifyListeners();
    } else {
      _listenToCurrentUser(user.uid);
    }
  }

  void _cancelSubscriptions() {
    _sessionTimer?.cancel();
    _profileRevision++;
    _currentUserSubscription?.cancel();
    _currentUserSubscription = null;
    _cancelPartner();
  }

  void _cancelPartner() {
    _partnerRevision++;
    _partnerSubscription?.cancel();
    _partnerSubscription = null;
    _partnerUid = null;
    _partnerUserModel = null;
  }

  // Escuta o usuário atual e se houver alteração de parceiro, escuta o parceiro também
  void _listenToCurrentUser(String uid) {
    _currentUserSubscription?.cancel();
    final revision = ++_profileRevision;
    _currentUserModel = null;
    _cancelPartner();
    _sessionState = AuthSessionState.loadingProfile;
    _sessionError = null;
    _sessionTimer?.cancel();
    _sessionTimer = Timer(sessionTimeout, () {
      if (_isCurrentProfile(uid, revision) &&
          _sessionState == AuthSessionState.loadingProfile) {
        _handleProfileError(TimeoutException(''));
      }
    });
    notifyListeners();
    try {
      _currentUserSubscription = _profiles
          .watchProfile(uid)
          .listen(
            (profile) {
              if (_isCurrentProfile(uid, revision)) _acceptProfile(profile);
            },
            onError: (Object error) {
              if (_isCurrentProfile(uid, revision)) _handleProfileError(error);
            },
          );
    } catch (error) {
      _handleProfileError(error);
    }
  }

  bool _isCurrentProfile(String uid, int revision) {
    return !_disposed &&
        _sessionUser?.uid == uid &&
        revision == _profileRevision;
  }

  String _handleProfileError(
    Object error, {
    ErrorOperation operation = ErrorOperation.loadProfile,
  }) {
    _sessionTimer?.cancel();
    _currentUserModel = null;
    _cancelPartner();
    _sessionState = AuthSessionState.profileError;
    final message = ErrorHandler.getFriendlyErrorMessage(
      error,
      operation: operation,
    );
    _sessionError = 'Não foi possível carregar seu perfil. $message';
    notifyListeners();
    return message;
  }

  void _acceptProfile(UserModel? profile) {
    if (profile != null && profile.uid != _sessionUser?.uid) {
      _handleProfileError(const FormatException());
      return;
    }
    _sessionTimer?.cancel();
    _currentUserModel = profile;
    _sessionError = null;
    _sessionState = profile == null
        ? AuthSessionState.missingProfile
        : AuthSessionState.ready;
    if (profile?.partnerUid != _partnerUid) {
      _cancelPartner();
      if (profile?.partnerUid != null) _listenToPartner(profile!.partnerUid!);
    }
    notifyListeners();
  }

  void retryProfile() {
    if (_disposed || _isLoading || _sessionUser == null) return;
    if (_sessionState != AuthSessionState.profileError &&
        _sessionState != AuthSessionState.missingProfile) {
      return;
    }
    _listenToCurrentUser(_sessionUser!.uid);
  }

  void retrySession() {
    if (_disposed || _sessionState != AuthSessionState.authError) return;
    _listenToAuth();
    notifyListeners();
  }

  // Escuta o parceiro em tempo real
  void _listenToPartner(String partnerUid) {
    _partnerUid = partnerUid;
    final revision = ++_partnerRevision;
    try {
      _partnerSubscription = _profiles
          .watchProfile(partnerUid)
          .listen(
            (profile) {
              if (_disposed || revision != _partnerRevision) return;
              _partnerUserModel = profile;
              notifyListeners();
            },
            onError: (Object error) {
              if (_disposed || revision != _partnerRevision) return;
              ErrorHandler.report(
                error,
                operation: ErrorOperation.loadPartnerProfile,
              );
              _partnerUserModel = null;
              notifyListeners();
            },
          );
    } catch (error) {
      ErrorHandler.report(error, operation: ErrorOperation.loadPartnerProfile);
      _partnerUserModel = null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _authRevision++;
    _authSubscription?.cancel();
    _cancelSubscriptions();
    super.dispose();
  }

  // Login com E-mail e Senha
  Future<String?> signInWithEmail(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _auth
          .signInWithEmailAndPassword(email: email, password: password)
          .timeout(sessionTimeout);
      _isLoading = false;
      notifyListeners();
      return null; // Sucesso
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return ErrorHandler.getFriendlyErrorMessage(
        e,
        operation: ErrorOperation.signIn,
      );
    }
  }

  // Registro com E-mail, Senha e Nome
  Future<String?> signUpWithEmail(
    String name,
    String email,
    String password,
  ) async {
    if (_isLoading) return 'Aguarde a operação atual terminar.';
    _isLoading = true;
    notifyListeners();
    try {
      UserCredential credential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password)
          .timeout(sessionTimeout);

      final user = credential.user;
      if (user == null) {
        return 'Não foi possível concluir o cadastro. Tente novamente.';
      }
      if (_disposed || _auth.currentUser?.uid != user.uid) {
        return 'A sessão mudou. Entre novamente para continuar.';
      }
      if (_sessionUser?.uid != user.uid) _handleAuthUser(user);
      _profileNameSuggestion = name.trim();
      return await _createMissingProfile(user, name);
    } catch (e) {
      return ErrorHandler.getFriendlyErrorMessage(
        e,
        operation: ErrorOperation.signUp,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> completeMissingProfile(String name) async {
    final user = _sessionUser;
    if (_disposed || user == null || _auth.currentUser?.uid != user.uid) {
      return 'Entre novamente para continuar.';
    }
    if (_isLoading) return 'Aguarde a operação atual terminar.';
    if (_sessionState != AuthSessionState.missingProfile) {
      return 'Verifique seu perfil novamente antes de continuar.';
    }
    if (name.trim().isEmpty) return 'Informe seu nome.';
    _isLoading = true;
    _profileNameSuggestion = name.trim();
    notifyListeners();
    try {
      return await _createMissingProfile(user, name);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> _createMissingProfile(User user, String name) async {
    final revision = _profileRevision;
    if (name.trim().isEmpty || user.email == null) {
      return 'Não foi possível concluir seu perfil. Verifique seu nome e sua conta.';
    }
    try {
      final profile = await _profiles
          .createIfMissing(
            UserModel(
              uid: user.uid,
              name: name.trim(),
              email: user.email!,
              createdAt: DateTime.now(),
            ),
          )
          .timeout(sessionTimeout);
      if (!_isCurrentProfile(user.uid, revision)) {
        return 'A sessão mudou. Entre novamente para continuar.';
      }
      _acceptProfile(profile);
      return null;
    } catch (error) {
      final current = _isCurrentProfile(user.uid, revision);
      if (current && _currentUserModel != null) return null;
      final message = current
          ? _handleProfileError(error, operation: ErrorOperation.saveProfile)
          : ErrorHandler.getFriendlyErrorMessage(
              error,
              operation: ErrorOperation.saveProfile,
            );
      if (_isCurrentProfile(user.uid, revision)) {
        _sessionError =
            'Sua conta já está criada, mas não foi possível salvar '
            'seu perfil. $message';
        notifyListeners();
      }
      return 'Não foi possível concluir seu perfil. $message';
    }
  }

  // Desconectar (Logout)
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // O lote e as regras verificam ambas as contas sem ler o destinatário.
  Future<String?> linkPartner(String partnerCode) async {
    final code = partnerCode.trim();
    if (code.isEmpty) return 'O código não pode ser vazio.';
    if (code == _currentUserModel?.uid) {
      return 'Você não pode colar o seu próprio código!';
    }
    if (_currentUserModel?.partnerUid != null) {
      return 'Desvincule a conta atual antes de criar outro vínculo.';
    }
    return _changePartner(code, linking: true);
  }

  Future<String?> unlinkPartner() async {
    final partnerUid = _currentUserModel?.partnerUid;
    if (partnerUid == null) return 'Você não possui nenhum vínculo ativo.';
    return _changePartner(partnerUid, linking: false);
  }

  Future<String?> _changePartner(
    String partnerUid, {
    required bool linking,
  }) async {
    final uid = _currentUserModel?.uid;
    if (_disposed ||
        uid == null ||
        _auth.currentUser?.uid != uid ||
        _sessionState != AuthSessionState.ready) {
      return 'Entre novamente para continuar.';
    }
    if (isLoading) return 'Aguarde a operação atual terminar.';
    final revision = ++_partnerOperationRevision;
    _partnerOperationPending = true;
    notifyListeners();
    try {
      if (linking) {
        await _partners.link(uid, partnerUid);
      } else {
        await _partners.unlink(uid, partnerUid);
      }
      if (_disposed ||
          revision != _partnerOperationRevision ||
          _auth.currentUser?.uid != uid) {
        return 'A sessão mudou. Entre novamente para continuar.';
      }
      return null;
    } catch (error) {
      return ErrorHandler.getFriendlyErrorMessage(
        error,
        operation: linking
            ? ErrorOperation.linkPartner
            : ErrorOperation.unlinkPartner,
      );
    } finally {
      if (!_disposed && revision == _partnerOperationRevision) {
        _partnerOperationPending = false;
        notifyListeners();
      }
    }
  }

  // Envia e-mail de recuperação de senha
  Future<String?> sendPasswordReset(String email) async {
    if (email.trim().isEmpty) return 'O e-mail não pode ser vazio.';
    _isLoading = true;
    notifyListeners();
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      _isLoading = false;
      notifyListeners();
      return null; // Sucesso
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return ErrorHandler.getFriendlyErrorMessage(
        e,
        operation: ErrorOperation.resetPassword,
      );
    }
  }
}
