import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import '../repositories/user_repositories.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserRepository _userRepository = UserRepository();

  // Email & Password Sign Up
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user?.updateDisplayName(displayName);
    return credential;
  }

  // Google Sign In
  Future<UserCredential> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) throw Exception('Google sign in cancelled');

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final result = await _auth.signInWithCredential(credential);

    // Create Firestore doc using repository — only if new user
    if (result.additionalUserInfo?.isNewUser == true) {
      final user = UserModel(
        id: result.user!.uid,
        firstName: result.user?.displayName?.split(' ').first ?? '',
        lastName: result.user?.displayName?.split(' ').last ?? '',
        username: '',
        email: result.user?.email ?? '',
        phone: '',
        friends: [],
        preferences: [],
        schedule: {}
      );
      await _userRepository.createUser(user);
    }

    return result;
  }

  // Sign Out
  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _auth.signOut();
  }
}
