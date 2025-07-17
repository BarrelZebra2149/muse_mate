import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:muse_mate/screen/chat_screen.dart';

class LiveChatScreen extends StatelessWidget {
  const LiveChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Live Chat')),
            body: const MessageScreen(),
          );
        } else {
          return Scaffold(
            appBar: AppBar(title: Text('Live Chat')),
            body: Center(child: Text('Failed to sign in')),
          );
        }
      },
    );
  }
}
