import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthCheck{
  static final FirebaseAuth auth = FirebaseAuth.instance;

  static Future<User?> signUp(String uemail, String upass, String fname) async{
    // Let Firebase errors (weak password, email in use, network) propagate to the
    // caller so it can show them; swallowing them here made the button a silent no-op.
    UserCredential userCred = await auth.createUserWithEmailAndPassword(email: uemail, password: upass);
    try{
      fname = fname.split(" ")[0];
      await userCred.user?.updateDisplayName(fname);
    } catch(e){
      debugPrint("Display name update failed: ${e.toString()}");
    }
    return userCred.user;
  }

  static Future<User?> login(String uemail, String upass) async{
    UserCredential userCred = await auth.signInWithEmailAndPassword(email: uemail, password: upass);
    return userCred.user;
  }

  static String getFirebaseAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password. Please try again.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled.';
      case 'weak-password':
        return 'Password must be at least 6 characters long.';
      case 'network-request-failed':
        return 'Network connection failed. Please check your internet connection.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}