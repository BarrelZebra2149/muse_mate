import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:muse_mate/screen/live_streaming_room_screen.dart';
import 'package:muse_mate/screen/select_first_streaming_music_screen.dart';

class ChatroomListScreen extends StatefulWidget{
  const ChatroomListScreen({super.key});

  @override
  State<StatefulWidget> createState() => _ChatroomListScreenState();
}

class _ChatroomListScreenState extends State<ChatroomListScreen> {
  final User? user = FirebaseAuth.instance.currentUser;

  Future<List<Map<String, dynamic>>> fetchChatRooms() async {
    final firestore = FirebaseFirestore.instance;
    final snapshot = await firestore
        .collection('chatroomList')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  void createChatRoom() async {
  final firestore = FirebaseFirestore.instance;

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

  if (roomName != null && roomName.isNotEmpty) {
    // Firestore에 채팅방 생성
    final docRef = await firestore.collection('chatroomList').add({
      'roomName': roomName,
      'createdAt': FieldValue.serverTimestamp(),
      'hostUserId': user?.uid,
    });

    // 기본 메시지 추가
    await docRef.collection('messages').add({
      'text': '채팅방이 생성되었습니다.',
      'createdAt': FieldValue.serverTimestamp(),
      'userId': 'system',
    });

    // YouTube 검색 화면 띄우기 (검색 결과 선택되면 값 받아옴)
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => const SelectFirstStreamingMusicScreen(),
        fullscreenDialog: true,
      ),
    );

    if (result != null && result['videoId'] != null) {
      final String videoId = result['videoId'];
      FirebaseFirestore.instance
          .collection('chatroomList')
          .doc(docRef.id)
          .update({
            'lastTrackChangedTime':  DateTime.now(),
            'videoID': result['videoId'],
          });
      // LiveStreamingRoomScreen으로 이동
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LiveStreamingRoomScreen(
            chatroomId: docRef.id,
            videoId: videoId,
            userId: user!.uid         
          ),
        ),
      );
    }

    // UI 갱신
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('채팅방이 생성되었습니다!')),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          FutureBuilder<List<Map<String, dynamic>>>(
            future: fetchChatRooms(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(child: Text('No chat rooms found.'));
              }
              final chatRooms = snapshot.data!;
              return Expanded(
                child: ListView.builder(
                  itemCount: chatRooms.length,
                  itemBuilder: (context, index) {
                    final chatRoom = chatRooms[index];
                    return ListTile(
                      title: Text(chatRoom['roomName'] ?? '이름없는 방'),
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LiveStreamingRoomScreen(
                              chatroomId: chatRoom['id'],
                              userId: user!.uid,
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
            }
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
      )
    );
  }
}