//drop_music_screen을 메인으로 chat_screen, search_youtube_screen을 짜붙임.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:muse_mate/screen/chat_screen.dart';
import 'package:muse_mate/screen/drop_music_screen_youtube.dart';

enum Authority { host, user }

class LiveStreamingRoomScreen extends StatefulWidget {
  final String chatroomId;
  final String userId;

  const LiveStreamingRoomScreen({
    super.key,
    required this.chatroomId,
    required this.userId,
  });

  @override
  State<LiveStreamingRoomScreen> createState() => _LiveStreamingRoomScreenState();
}

class _LiveStreamingRoomScreenState extends State<LiveStreamingRoomScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  var authority = '';
  DateTime? lastTrackChangedTime;
  String? videoId;

  void _onTrackChanged(String? newVideoId) {
    setState(() {
      lastTrackChangedTime = DateTime.now();
    });
    print('Track changed at $lastTrackChangedTime: $newVideoId');
    _sendLastTrackChangedTime(newVideoId!);
  }

  void _sendLastTrackChangedTime(String newVideoId) {
    FirebaseFirestore.instance
        .collection('chatroomList')
        .doc(widget.chatroomId)
        .update({
          'lastTrackChangedTime': lastTrackChangedTime,
          'videoID': newVideoId,
        });
  }

  Future<DateTime?> _receiveLastTrackChangedTime() async {
    final doc = await FirebaseFirestore.instance
        .collection('chatroomList')
        .doc(widget.chatroomId)
        .get();

    if (!doc.exists) return null;

    final data = doc.data();
    if (data == null || !data.containsKey('lastTrackChangedTime')) return null;

    final field = data['lastTrackChangedTime'];

    if (field is Timestamp) {
      return field.toDate();
    } else if (field is String) {
      return DateTime.tryParse(field);
    }

    return null;
  }

  Future<String?> _receiveVideoId() async {
    final doc = await FirebaseFirestore.instance
        .collection('chatroomList')
        .doc(widget.chatroomId)
        .get();

    if (!doc.exists) return null;

    final data = doc.data();
    if (data == null || !data.containsKey('videoId')) return null;

    final field = data['videoId'];
    if (field is String) {
      return field;
    } else {
      return field?.toString();
    }
  }

  Future<String?> fetchHostUserId(String roomId) async {
    final doc = await FirebaseFirestore.instance
        .collection('chatroomList')
        .doc(roomId)
        .get();

    if (doc.exists) {
      return doc.data()?['hostUserId'] as String?;
    } else {
      return null; // 문서가 없을 경우
    }
  }

  @override
  void initState() {
    super.initState();
    _initAuthority();

    //if(authority == Authority.user){
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initData();
      });
    //}
   
  }

  Future<void> _initData() async {
    final time = await _receiveLastTrackChangedTime();
    final vid = await _receiveVideoId();

    if (!mounted) return;

    setState(() {
      lastTrackChangedTime = time;
      videoId = vid;
    });
 }

  Future<void> _initAuthority() async {
    final hostId = await fetchHostUserId(widget.chatroomId);

    setState(() {
      authority = (hostId == widget.userId)
          ? Authority.host.name
          : Authority.user.name;
    });
  }

  void openChatDrawer() {
    _scaffoldKey.currentState?.openEndDrawer(); // 오른쪽에서 drawer 열기
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: Drawer(
          child: MessageScreen(chatroomId: widget.chatroomId),
        ),
      ),
      body: Stack(
        children: [
          DropMusicYoutubeScreen(
            videoId: videoId,
            onTrackChanged: _onTrackChanged,
            authority: authority,
            lastTrackChangedTime: lastTrackChangedTime,
          ), // 메인 화면
          Positioned(
            top: 40,
            right: 20,
            child: FloatingActionButton(
              mini: true,
              onPressed: openChatDrawer,
              child: Icon(Icons.chat),
            ),
          ),
        ],
      ),
    );
  }
}