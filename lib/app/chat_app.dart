import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:muse_mate/screen/chat/chatroom_list.dart';

class LiveRoomScreen extends StatelessWidget {
  const LiveRoomScreen({super.key});

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
            appBar: AppBar(title: const Text('Live Rooms')),
            body: const ChatroomListScreen(),
          );
        } else {
          return Scaffold(
            appBar: AppBar(title: Text('Live Rooms')),
            body: Center(child: Text('Failed to sign in')),
          );
        }
      },
    );
  }
}
