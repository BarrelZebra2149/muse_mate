import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:muse_mate/models/video_model.dart';
import 'package:muse_mate/repository/chatroom_repository.dart';
import 'package:muse_mate/screen/streaming/live_streaming_room_screen.dart';
import 'package:muse_mate/screen/youtube_search/search_youtube_screen.dart';

class ChatroomListScreen extends StatefulWidget {
  const ChatroomListScreen({super.key});

  @override
  State<StatefulWidget> createState() => _ChatroomListState();
}


class _ChatroomListState extends State<ChatroomListScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final chatroomRepo = ChatroomRepository();


  void createChatRoom() async {
    String? roomName = await showDialog<String>(
      context: context,
      builder: (context) {
        TextEditingController controller = TextEditingController();
        return AlertDialog(
          title: Text('채팅방 이름 입력'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: '방 이름'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, controller.text.trim());
              },
              child: Text('확인'),
            ),
          ],
        );
      },
    );


    // Firestore에 채팅방 생성
    if (roomName != null && roomName.isNotEmpty) {
      final roomRef = await chatroomRepo.addChatroom(roomName, user!);

      // YouTube 검색 화면 띄우기 (검색 결과 선택되면 값 받아옴)
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (_) => SearchYoutubeScreen(
            onVideoTap: (String videoId, String title) {
              Navigator.pop(context, 
                {'videoId': videoId, 
                'title': title}
              );
            },
          ),
          fullscreenDialog: true,
        ),
      );

      if (result != null && result['videoId'] != null) {
        final VideoModel video = VideoModel(
          videoId: result['videoId'], 
          title: result['title'], 
          videoRef: ''
        );
        
        await chatroomRepo.addToPlaylist(video, roomRef);

        // LiveStreamingRoomScreen으로 이동
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LiveStreamingRoomScreen(
              roomRef: roomRef,
            ),
          ),
        );
      }

      // UI 갱신
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('채팅방이 생성되었습니다!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            StreamBuilder<QuerySnapshot>(
              stream: chatroomRepo.getChatroomListSnapshot(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
                
                final chatRoomDocs = snapshot.data!.docs;
                if (chatRoomDocs.isEmpty) {
                  return Center(child: Text('No chat rooms found.'));
                }
        
                return Expanded(
                  child: ListView.builder(
                    itemCount: chatRoomDocs.length,
                    itemBuilder: (context, index) {
                      final chatRoomDoc = chatRoomDocs[index];
                      final chatRoomData = chatRoomDoc.data() as Map<String, dynamic>;;
                      chatRoomData['ref'] = chatRoomDoc.reference;
        
                      return ListTile(
                        title: Text(chatRoomData['roomName'] ?? '이름없는 방'),
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LiveStreamingRoomScreen(
                                roomRef: chatRoomData['ref'],
                              ),
                            ),
                          );
                          // LiveStreamingRoomScreen에서 pop(context, true) 했을 경우
                          if (result == true) {
                            setState(() {});
                          }
                        },
                      );
                    },
                  ),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: ElevatedButton(
                onPressed: () {
                  createChatRoom();
                },
                child: Text('방 만들기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
