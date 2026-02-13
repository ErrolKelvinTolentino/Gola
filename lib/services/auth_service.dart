import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 🔐 Register
  Future<User?> register(String email, String password, String username) async {
    final normalized = _normalizeUsername(username);
    final usernameRef = _db.collection('usernames').doc(normalized);

    final existing = await usernameRef.get();
    if (existing.exists) {
      throw Exception('Username already taken.');
    }

    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(usernameRef);
        if (snapshot.exists) {
          throw Exception('Username already taken.');
        }
        transaction.set(usernameRef, {
          'uid': userCredential.user?.uid,
          'email': email,
          'username': normalized,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      await userCredential.user?.updateDisplayName(normalized);
    } catch (error) {
      await userCredential.user?.delete();
      rethrow;
    }

    return userCredential.user;
  }

  // 🔓 Login
  Future<User?> login(String identifier, String password) async {
    final trimmed = identifier.trim();

    if (trimmed.contains('@')) {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: trimmed,
        password: password,
      );
      return userCredential.user;
    }

    final normalized = _normalizeUsername(trimmed);
    final snapshot = await _db.collection('usernames').doc(normalized).get();
    if (!snapshot.exists) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No account found for this username.',
      );
    }

    final email = snapshot.data()?['email'] as String?;
    if (email == null || email.isEmpty) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No account found for this username.',
      );
    }

    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return userCredential.user;
  }

  // 🚪 Logout
  Future<void> logout() async {
    await _auth.signOut();
  }

  // 👀 Auth state
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  String _normalizeUsername(String username) => username.trim().toLowerCase();
}
