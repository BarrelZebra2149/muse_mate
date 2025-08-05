//drop_music_screen을 메인으로 chat_screen, search_youtube_screen을 짜붙임.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:muse_mate/screen/chat/chat_screen.dart';
import 'package:muse_mate/screen/streaming/streaming_music_screen.dart';

enum Authority { host, user }

class LiveStreamingRoomScreen extends StatefulWidget {
  final String chatroomId;
  final String userId;
  final String? videoId;

  const LiveStreamingRoomScreen({
    super.key,
    required this.chatroomId,
    required this.userId,
    this.videoId
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

  void _receiveLastTrackChangedTime() async {
    final doc = await FirebaseFirestore.instance
        .collection('chatroomList')
        .doc(widget.chatroomId)
        .get();

    final data = doc.data();
    final field = data?['lastTrackChangedTime'];

    if (field is Timestamp) {
      lastTrackChangedTime = field.toDate();
    } else if (field is String) {
      lastTrackChangedTime = DateTime.tryParse(field);
    }

    // 기본값 적용
    lastTrackChangedTime ??= DateTime.now();
    setState(() {});
  }

  void _receiveVideoId() async {
    final doc = await FirebaseFirestore.instance
        .collection('chatroomList')
        .doc(widget.chatroomId)
        .get();

    final data = doc.data();
    final field = data?['videoID'];

    if (field is String) {
      videoId = field;
    } else {
      videoId = field?.toString();
    }

    // 기본값 적용
    videoId ??= widget.videoId;
    setState(() {}); // 값 변경 후 UI 갱신
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

  Future<void> _initAuthority() async {
    final hostId = await fetchHostUserId(widget.chatroomId);
    final auth = (hostId == widget.userId)
        ? Authority.host.name
        : Authority.user.name;

    setState(() {
      authority = auth;
    });
  }

  void openChatDrawer() {
    _scaffoldKey.currentState?.openEndDrawer(); // 오른쪽에서 drawer 열기
  }

  @override
  void initState() {
    super.initState();
    _initAuthority();
    _receiveLastTrackChangedTime();
    _receiveVideoId();
  }

  @override
  Widget build(BuildContext context) {
     if (videoId == null || lastTrackChangedTime == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return  Scaffold(
      key: _scaffoldKey,
      endDrawer: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: Drawer(
          child: MessageScreen(chatroomId: widget.chatroomId),
        ),
      ),
      body: Stack(
        children: [
          StreamingMusicScreen(
            videoId: videoId!,
            onTrackChanged: _onTrackChanged,
            authority: authority,
            lastTrackChangedTime: lastTrackChangedTime!,
            chatRoomId: widget.chatroomId,
          ),
          Positioned(
            top: 40,
            right: 20,
            child: FloatingActionButton(
              heroTag: 'chat_button_${widget.chatroomId}',
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