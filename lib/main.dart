import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// import 'package:muse_mate/app/main_app.dart';
import 'package:muse_mate/screen/login_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // await signInAnonymously();
  runApp(const MyApp());
}

// Future<User?> signInAnonymously() async {
//   try {
//     UserCredential userCredential = await FirebaseAuth.instance
//         .signInAnonymously();
//     return userCredential.user;
//   } catch (e) {
//     print('Error signing in anonymously: $e');
//     return null;
//   }
// }
