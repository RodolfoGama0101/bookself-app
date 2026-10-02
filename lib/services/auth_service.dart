import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../data/models/user_model.dart';
import 'user_profile_service.dart';

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
  final FirebaseFirestore? _injectedFirestore;
  FirebaseFirestore get _firestore =>
      _injectedFirestore ?? FirebaseFirestore.instance;
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
  bool get isLoading => _isLoading;

  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    UserProfileService? profiles,
    this.sessionTimeout = const Duration(seconds: 15),
  }) : _auth = auth ?? FirebaseAuth.instance,
       _injectedFirestore = firestore,
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
        _handleAuthError();
      }
    });
    try {
      _authSubscription = _auth.authStateChanges().listen(
        (user) {
          if (!_disposed && revision == _authRevision) _handleAuthUser(user);
        },
        onError: (Object error) {
          if (!_disposed && revision == _authRevision) _handleAuthError();
        },
      );
    } catch (_) {
      _handleAuthError();
    }
  }

  void _handleAuthError() {
    _cancelSubscriptions();
    _currentUserModel = null;
    _sessionState = AuthSessionState.authError;
    _sessionError = 'Não foi possível restaurar sua sessão. Tente novamente.';
    notifyListeners();
  }

  void _handleAuthUser(User? user) {
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
        _handleProfileError();
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
              if (_isCurrentProfile(uid, revision)) _handleProfileError();
            },
          );
    } catch (_) {
      _handleProfileError();
    }
  }

  bool _isCurrentProfile(String uid, int revision) {
    return !_disposed &&
        _sessionUser?.uid == uid &&
        revision == _profileRevision;
  }

  void _handleProfileError() {
    _sessionTimer?.cancel();
    _currentUserModel = null;
    _cancelPartner();
    _sessionState = AuthSessionState.profileError;
    _sessionError =
        'Não foi possível carregar seu perfil. '
        'Verifique sua conexão e tente novamente.';
    notifyListeners();
  }

  void _acceptProfile(UserModel? profile) {
    if (profile != null && profile.uid != _sessionUser?.uid) {
      _handleProfileError();
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
              _partnerUserModel = null;
              notifyListeners();
            },
          );
    } catch (_) {
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
      if (e is FirebaseAuthException) {
        return e.message ?? 'Erro ao entrar';
      }
      if (e is TimeoutException) {
        return 'A conexão demorou mais que o esperado. Tente novamente.';
      }
      return 'Erro inesperado: ${e.toString()}';
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
      if (e is FirebaseAuthException) {
        return e.message ?? 'Erro ao cadastrar';
      }
      return 'Não foi possível criar sua conta. Tente novamente.';
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
    } catch (_) {
      if (_isCurrentProfile(user.uid, revision)) {
        if (_currentUserModel != null) return null;
        _handleProfileError();
        _sessionError =
            'Sua conta já está criada, mas não foi possível salvar '
            'seu perfil. Tente novamente.';
        notifyListeners();
      }
      return 'Não foi possível concluir seu perfil. Tente novamente.';
    }
  }

  // Desconectar (Logout)
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Vincular com parceiro via código (que é o UID do parceiro)
  Future<String?> linkPartner(String partnerCode) async {
    if (partnerCode.trim().isEmpty) return 'O código não pode ser vazio.';
    if (partnerCode.trim() == _currentUserModel?.uid) {
      return 'Você não pode colar o seu próprio código!';
    }

    _isLoading = true;
    notifyListeners();

    try {
      // 1. Verifica se o parceiro existe no Firestore
      DocumentSnapshot partnerDoc = await _firestore
          .collection('users')
          .doc(partnerCode.trim())
          .get();

      if (!partnerDoc.exists) {
        _isLoading = false;
        notifyListeners();
        return 'Parceiro não encontrado. Verifique o código e tente novamente.';
      }

      UserModel partner = UserModel.fromFirestore(partnerDoc);

      // 2. Verifica se o parceiro já tem outro vínculo
      if (partner.partnerUid != null &&
          partner.partnerUid != _currentUserModel?.uid) {
        _isLoading = false;
        notifyListeners();
        return 'Este usuário já está vinculado a outra pessoa.';
      }

      // 3. Atualiza os dois documentos no Firestore (Relação bidirecional)
      WriteBatch batch = _firestore.batch();

      DocumentReference myRef = _firestore
          .collection('users')
          .doc(_currentUserModel!.uid);
      DocumentReference partnerRef = _firestore
          .collection('users')
          .doc(partner.uid);

      batch.update(myRef, {'partnerUid': partner.uid});
      batch.update(partnerRef, {'partnerUid': _currentUserModel!.uid});

      await batch.commit();

      _isLoading = false;
      notifyListeners();
      return null; // Sucesso
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'Erro ao tentar vincular: ${e.toString()}';
    }
  }

  // Desvincular parceiro
  Future<String?> unlinkPartner() async {
    if (_currentUserModel == null || _currentUserModel!.partnerUid == null) {
      return 'Você não possui nenhum vínculo ativo.';
    }

    _isLoading = true;
    notifyListeners();

    try {
      String partnerUid = _currentUserModel!.partnerUid!;
      WriteBatch batch = _firestore.batch();

      DocumentReference myRef = _firestore
          .collection('users')
          .doc(_currentUserModel!.uid);
      DocumentReference partnerRef = _firestore
          .collection('users')
          .doc(partnerUid);

      batch.update(myRef, {'partnerUid': null});
      batch.update(partnerRef, {'partnerUid': null});

      await batch.commit();

      _isLoading = false;
      notifyListeners();
      return null; // Sucesso
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'Erro ao desvincular: ${e.toString()}';
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
      if (e is FirebaseAuthException) {
        return e.message ?? 'Erro ao enviar e-mail de recuperação';
      }
      return 'Erro inesperado: ${e.toString()}';
    }
  }
}
