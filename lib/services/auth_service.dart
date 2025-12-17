import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<UserCredential> register(String email, String password) {
    return _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> login(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> logout() => _auth.signOut();

  Future<void> saveGender(String email, String gender) async {
    // Try to save to Firestore under user's uid if available, fallback to Hive
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': user.email,
          'gender': gender,
        }, SetOptions(merge: true));
        await Hive.openBox('auth');
        final box = Hive.box('auth');
        await box.put('currentUser', user.email);
        return;
      } catch (_) {}
    }

    await Hive.openBox('auth');
    final box = Hive.box('auth');
    final users = box.get('users', defaultValue: <String, Map>{}) as Map;
    final Map<String, dynamic> newUsers = Map<String, dynamic>.from(users);
    newUsers[email] = {
      'gender': gender,
    };
    await box.put('users', newUsers);
    await box.put('currentUser', email);
  }

  Future<String?> getGender(String email) async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data();
          if (data != null && data['gender'] != null) return data['gender'] as String;
        }
      } catch (_) {}
    }

    await Hive.openBox('auth');
    final box = Hive.box('auth');
    final users = box.get('users', defaultValue: <String, Map>{}) as Map;
    final userData = users[email] as Map?;
    return userData != null ? userData['gender'] as String? : null;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      try {
        await user.sendEmailVerification();
      } catch (e) {
        throw Exception('Failed to send verification email: $e');
      }
    }
  }

  Future<bool> isEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }
}
