import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_environment.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../data/models/user_model.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot>? _currentUserSubscription;
  StreamSubscription<DocumentSnapshot>? _partnerSubscription;
  String? _currentUid;
  String? _partnerUid;
  int _profileRevision = 0;
  int _partnerRevision = 0;
  bool _disposed = false;

  UserModel? _currentUserModel;
  UserModel? get currentUserModel => _currentUserModel;

  UserModel? _partnerUserModel;
  UserModel? get partnerUserModel => _partnerUserModel;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseEnvironment.auth,
      _firestore = firestore ?? FirebaseEnvironment.firestore {
    // Monitora o estado de autenticação do Firebase
    _authSubscription = _auth.authStateChanges().listen(
      (User? user) {
        if (_disposed) return;
        _cancelSubscriptions();
        _currentUid = user?.uid;
        _currentUserModel = null;
        final revision = _profileRevision;
        notifyListeners();
        if (!_disposed && user != null && revision == _profileRevision) {
          _listenToCurrentUser(user.uid);
        }
      },
      onError: (Object error) {
        if (_disposed) return;
        _cancelSubscriptions();
        _currentUid = null;
        _currentUserModel = null;
        notifyListeners();
      },
    );
  }

  void _cancelSubscriptions() {
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
    final revision = ++_profileRevision;
    final subscription = _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen(
          (docSnapshot) {
            if (_disposed ||
                _currentUid != uid ||
                revision != _profileRevision) {
              return;
            }
            if (docSnapshot.exists) {
              _currentUserModel = UserModel.fromFirestore(docSnapshot);
              final partnerUid = _currentUserModel!.partnerUid;
              if (partnerUid != _partnerUid) {
                _cancelPartner();
                if (partnerUid != null) _listenToPartner(partnerUid);
              }
            } else {
              _currentUserModel = null;
              _cancelPartner();
            }
            notifyListeners();
          },
          onError: (error) {
            if (_disposed ||
                _currentUid != uid ||
                revision != _profileRevision) {
              return;
            }
            _currentUserModel = null;
            _cancelPartner();
            notifyListeners();
            debugPrint('Erro ao escutar usuário atual.');
          },
        );
    if (_disposed || _currentUid != uid || revision != _profileRevision) {
      subscription.cancel();
    } else {
      _currentUserSubscription = subscription;
    }
  }

  // Escuta o parceiro em tempo real
  void _listenToPartner(String partnerUid) {
    _partnerUid = partnerUid;
    final revision = ++_partnerRevision;
    final subscription = _firestore
        .collection('users')
        .doc(partnerUid)
        .snapshots()
        .listen(
          (docSnapshot) {
            if (_disposed ||
                _partnerUid != partnerUid ||
                revision != _partnerRevision) {
              return;
            }
            if (docSnapshot.exists) {
              _partnerUserModel = UserModel.fromFirestore(docSnapshot);
              notifyListeners();
            } else {
              _partnerUserModel = null;
              notifyListeners();
            }
          },
          onError: (error) {
            if (_disposed ||
                _partnerUid != partnerUid ||
                revision != _partnerRevision) {
              return;
            }
            _partnerUserModel = null;
            notifyListeners();
            debugPrint('Erro ao escutar parceiro.');
          },
        );
    if (_disposed ||
        _partnerUid != partnerUid ||
        revision != _partnerRevision) {
      subscription.cancel();
    } else {
      _partnerSubscription = subscription;
    }
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _authSubscription?.cancel();
    _authSubscription = null;
    _currentUid = null;
    _currentUserModel = null;
    _cancelSubscriptions();
    super.dispose();
  }

  // Login com E-mail e Senha
  Future<String?> signInWithEmail(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      _isLoading = false;
      notifyListeners();
      return null; // Sucesso
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      if (e is FirebaseAuthException) {
        return e.message ?? 'Erro ao entrar';
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
    _isLoading = true;
    notifyListeners();
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Cria o documento do usuário no Firestore
        UserModel newUser = UserModel(
          uid: credential.user!.uid,
          name: name,
          email: email,
          createdAt: DateTime.now(),
        );

        await _firestore
            .collection('users')
            .doc(newUser.uid)
            .set(newUser.toMap());
      }
      _isLoading = false;
      notifyListeners();
      return null; // Sucesso
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      if (e is FirebaseAuthException) {
        return e.message ?? 'Erro ao cadastrar';
      }
      return 'Erro inesperado: ${e.toString()}';
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
