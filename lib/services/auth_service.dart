import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  FirebaseAuth get _auth => FirebaseAuth.instance;

  // REGISTER
  Future<User?> register(String email, String password) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return result.user;
  }

  // LOGIN
  Future<User?> login(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return result.user;
  }

  // GET TOKEN
  Future<String?> getToken() async {
    return await _auth.currentUser?.getIdToken();
  }

  // LOGOUT
  Future<void> logout() async {
    await _auth.signOut();
  }
}
