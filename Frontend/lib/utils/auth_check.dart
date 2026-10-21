import 'package:firebase_auth/firebase_auth.dart';

class AuthCheck{
  static final FirebaseAuth auth = FirebaseAuth.instance;

  static Future<User?> signUp(String uemail, String upass, String fname) async{
    // Let Firebase errors (weak password, email in use, network) propagate to the
    // caller so it can show them; swallowing them here made the button a silent no-op.
    UserCredential userCred = await auth.createUserWithEmailAndPassword(email: uemail, password: upass);
    try{
      fname = fname.split(" ")[0];
      await userCred.user?.updateDisplayName(fname);
    } catch(e){ print("Display name update failed: ${e.toString()}"); }
    return userCred.user;
  }

  static Future<User?> login(String uemail, String upass) async{
    try{
      UserCredential userCred = await auth.signInWithEmailAndPassword(email: uemail, password: upass);
      return userCred.user;
    } catch(e){ print("Signup Error ${e.toString()}"); }
  }
}