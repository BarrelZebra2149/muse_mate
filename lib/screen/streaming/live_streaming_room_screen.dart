//drop_music_screen을 메인으로 chat_screen, search_youtube_screen을 짜붙임.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:muse_mate/screen/chat/chat_screen.dart';
import 'package:muse_mate/screen/streaming/streaming_music_screen.dart';


class LiveStreamingRoomScreen extends StatefulWidget {
  final dynamic roomRef;

  const LiveStreamingRoomScreen({
    super.key,
    required this.roomRef,
  });

  @override
  State<LiveStreamingRoomScreen> createState() => _LiveStreamingRoomScreenState();
}

class _LiveStreamingRoomScreenState extends State<LiveStreamingRoomScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final User? user = FirebaseAuth.instance.currentUser;

  void openChatDrawer() {
    _scaffoldKey.currentState?.openEndDrawer(); // 오른쪽에서 drawer 열기
  }


  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: widget.roomRef.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.data!.exists) {
          // 문서가 없는 경우 현재 화면 dismiss
          Navigator.pop(context);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('호스트가 방을 떠났습니다.')));
          return SizedBox.shrink(); // 빈 위젯 반환
        }
        dynamic roomData = snapshot.data!.data();
        List playlist = roomData['playlist'];

        if (playlist.isEmpty && user?.uid != roomData['hostUserId']) {
          return Scaffold(body: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: 20,
            children: [
              CircularProgressIndicator(),
              Text("호스트가 노래를 선택하는 중 입니다."),
            ],
          ));
        }
        return  Scaffold(
          key: _scaffoldKey,
          endDrawer: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: Drawer(
              child: SafeArea(child: MessageScreen(roomRef: widget.roomRef)),
            ),
          ),
          body: Stack(
            children: [
              StreamingMusicScreen(
                roomRef: widget.roomRef,
              ),
              Positioned(
                top: 40,
                right: 20,
                child: FloatingActionButton(
                  heroTag: 'chat_button_${widget.roomRef}',
                  mini: true,
                  onPressed: openChatDrawer,
                  child: Icon(Icons.chat),
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}