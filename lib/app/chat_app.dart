import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:muse_mate/screen/chat_screen.dart';

class MyChatApp extends StatelessWidget {
  const MyChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Show loading screen while checking auth state
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            // User is signed in, navigate to ChatScreen
            return const ChatScreen();
          } else {
            // No user signed in, show error or fallback screen
            return const Scaffold(
              body: Center(child: Text('Failed to sign in')),
            );
          }
        },
      ),
    );
  }
}

Future<User?> signInAnonymously() async {
  try {
    UserCredential userCredential = await FirebaseAuth.instance
        .signInAnonymously();
    return userCredential.user;
  } catch (e) {
    print('Error signing in anonymously: $e');
    return null;
  }
}

class ErrorApp extends StatelessWidget {
  const ErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: Center(child: Text('Error initializing Firebase'))),
    );
  }
}
