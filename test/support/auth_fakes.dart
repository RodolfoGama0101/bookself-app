import 'dart:async';

import 'package:bookself_app/data/models/user_model.dart';
import 'package:bookself_app/services/user_profile_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeUser extends Fake implements User {
  FakeUser(this.uid, {this.email = 'teste@example.com', this.displayName});

  @override
  final String uid;
  @override
  final String? email;
  @override
  final String? displayName;
}

class FakeCredential extends Fake implements UserCredential {
  FakeCredential(this.user);
  @override
  final User? user;
}

class FakeFirebaseAuth extends Fake implements FirebaseAuth {
  final changes = StreamController<User?>.broadcast();
  User? _currentUser;
  int createCalls = 0;
  int signOutCalls = 0;
  Future<UserCredential> Function()? onSignUp;
  Future<UserCredential> Function()? onSignIn;

  @override
  User? get currentUser => _currentUser;

  @override
  Stream<User?> authStateChanges() => changes.stream;

  void emit(User? user) {
    _currentUser = user;
    changes.add(user);
  }

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    createCalls++;
    if (onSignUp != null) return onSignUp!();
    final user = FakeUser('new-user', email: email);
    emit(user);
    return FakeCredential(user);
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (onSignIn != null) return onSignIn!();
    final user = FakeUser('user', email: email);
    emit(user);
    return FakeCredential(user);
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    emit(null);
  }
}

class FakeUserProfiles extends UserProfileService {
  final streams = <String, StreamController<UserModel?>>{};
  final stored = <String, UserModel>{};
  Future<UserModel> Function(UserModel)? onCreate;
  int createCalls = 0;
  final watchCalls = <String, int>{};

  StreamController<UserModel?> controller(String uid) {
    return streams.putIfAbsent(
      uid,
      () => StreamController<UserModel?>.broadcast(),
    );
  }

  @override
  Stream<UserModel?> watchProfile(String uid) {
    watchCalls.update(uid, (count) => count + 1, ifAbsent: () => 1);
    return controller(uid).stream;
  }

  @override
  Future<UserModel> createIfMissing(UserModel profile) async {
    createCalls++;
    if (onCreate != null) return onCreate!(profile);
    return stored.putIfAbsent(profile.uid, () => profile);
  }

  Future<void> close() async {
    for (final stream in streams.values) {
      await stream.close();
    }
  }
}

UserModel profile(
  String uid, {
  String name = 'Nome preservado',
  String? partnerUid,
}) {
  return UserModel(
    uid: uid,
    name: name,
    email: 'teste@example.com',
    partnerUid: partnerUid,
    photoUrl: 'foto-preservada',
    createdAt: DateTime(2020),
  );
}
