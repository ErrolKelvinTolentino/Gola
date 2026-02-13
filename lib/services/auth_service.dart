import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 🔐 Register
  Future<User?> register(String email, String password) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return userCredential.user;
  }

  // 🔓 Login
  Future<User?> login(String email, String password) async {
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
}
