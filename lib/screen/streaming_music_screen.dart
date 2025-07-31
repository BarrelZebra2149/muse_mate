// 이 파일은 DropMusicYoutubeScreen을 정의.
// YouTube 동영상 재생, 재생목록 관리, 검색, 재생 컨트롤 기능을 제공.
// youtube_player_iframe 패키지를 사용하여 YouTube 동영상을 임베드, 재생목록 및 컨트롤을 위한 커스텀 위젯을 사용.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:muse_mate/screen/live_streaming_room_screen.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:muse_mate/widgets/circular_progress_player.dart';
import 'package:muse_mate/screen/search_youtube_screen.dart';
import 'package:muse_mate/widgets/my_playlist.dart';

// YouTube 음악 재생 및 재생목록 관리를 위한 메인 화면.
class StreamingMusicScreen extends StatefulWidget {
  const StreamingMusicScreen({
    super.key,
    this.videoId,
    required this.onTrackChanged,
    this.authority,
    this.lastTrackChangedTime,
    this.chatRoomId,
  });

  final String? videoId;
  final void Function(String?) onTrackChanged;
  final String? authority;
  final DateTime? lastTrackChangedTime;
  final String? chatRoomId;

  @override
  State<StreamingMusicScreen> createState() => _StreamingMusicScreenState();
}

class _StreamingMusicScreenState extends State<StreamingMusicScreen> {
  late YoutubePlayerController _controller;
  late String _currentVideoId = '02_46KCr04g';

  // 재생목록은 각 동영상의 videoId와 title을 저장.
  final List<Map<String, dynamic>> _playlist = [
    {'videoId': '02_46KCr04g', 'title': 'zettai koakuma kodei'},
  ];

  double getElapsedSecondsSinceLastTrack() {
    var lastTrackChangedTime = widget.lastTrackChangedTime;

    if (lastTrackChangedTime == null) return 0.0;

    final now = DateTime.now();
    final difference = now.difference(lastTrackChangedTime);
    return difference.inMilliseconds / 1000.0;
  }

  @override
  void initState() {
    print("sms");
    print(widget.videoId);
    super.initState();
    // YouTube 플레이어 컨트롤러를 초기화.
    _controller = YoutubePlayerController(
      params: const YoutubePlayerParams(
        showControls: false,
        mute: false,
        showFullscreenButton: true,
        loop: false,
      ),
    );

    _controller.setFullScreenListener((isFullScreen) {
      print('${isFullScreen ? 'Entered' : 'Exited'} Fullscreen.');
    });

    if (widget.authority == Authority.host.name) {
      // 초기 동영상을 로드.
      if (widget.videoId != null) {
        _currentVideoId = widget.videoId!;
        _controller.loadVideoById(
          videoId: _currentVideoId,
          startSeconds: getElapsedSecondsSinceLastTrack(),
        );
      } else {
        _currentVideoId = _playlist.isNotEmpty
            ? _playlist.first['videoId']
            : '02_46KCr04g';
        _controller.loadVideoById(videoId: _currentVideoId);
      }
    } else {
      if (widget.videoId != null) {
        _controller.loadVideoById(
          videoId: widget.videoId!,
          startSeconds: getElapsedSecondsSinceLastTrack(),
        );
      } else {
        _currentVideoId = _playlist.isNotEmpty
            ? _playlist.first['videoId']
            : '';
        _controller.loadVideoById(videoId: _currentVideoId);
      }
    }

    // 동영상이 끝나면 다음 동영상으로 이동.
    _controller.listen((event) {
      if (event.playerState == PlayerState.ended) {
        _moveToNextVideo();
      }
    });
  }

  // 현재 동영상이 끝나면 재생목록의 다음 동영상으로 이동.
  void _moveToNextVideo() {
    if (_playlist.isEmpty) {
      _currentVideoId = '';
      _controller.pauseVideo();
      return;
    }

    final currentIndex = _playlist.indexWhere(
      (video) => video['videoId'] == _currentVideoId,
    );
    final nextIndex = (currentIndex + 1) % _playlist.length;
    setState(() {
      _currentVideoId = _playlist[nextIndex]['videoId'];
      _controller.loadVideoById(videoId: _currentVideoId);
      widget.onTrackChanged(_currentVideoId);
    });
  }

  // 새로운 동영상을 재생목록에 추가하고, 첫 번째 동영상이면 재생.
  void _onVideoSelected(String newId, String title) {
    setState(() {
      _playlist.add({'videoId': newId, 'title': title});
      if (_playlist.length == 1) {
        _currentVideoId = newId;
        _controller.loadVideoById(videoId: _currentVideoId);
        widget.onTrackChanged(_currentVideoId);
      }
    });
  }

  // 재생목록에서 동영상을 제거합.
  void _removeVideo(int index) {
    setState(() {
      final removedVideoId = _playlist[index]['videoId'];
      _playlist.removeAt(index);
      if (removedVideoId == _currentVideoId && _playlist.isNotEmpty) {
        _currentVideoId = _playlist.first['videoId'];
        _controller.loadVideoById(videoId: _currentVideoId);
        widget.onTrackChanged(_currentVideoId);
      } else if (_playlist.isEmpty) {
        _currentVideoId = '';
        _controller.pauseVideo();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerScaffold(
      controller: _controller,
      builder: (context, player) {
        final customPlayer = Center(
          child: SizedBox(
            height:150,
            width: 300, // 필요 시 너비 줄이기
            child: player,
          ),
        );
        return Scaffold(
          drawer: Drawer(
            // 검색창을 왼쪽 drawer에 넣음
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: SearchYoutubeScreen(onVideoTap: _onVideoSelected),
              ),
            ),
          ),
          appBar: AppBar(
            leading: IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: () async {
                if (widget.authority == 'host') {
                await FirebaseFirestore.instance
                  .collection('chatroomList')
                  .doc(widget.chatRoomId)
                  .delete();
                }
                Navigator.of(context).pop(); // 현재 화면 종료
              },
            ),
            title: const Text('Youtube Player IFrame Demo'),
            actions: const [VideoPlaylistIconButton()],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 750) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              customPlayer,
                              const Controls(),
                              MyPlayList(
                                playlist: _playlist,
                                currentVideoId: _currentVideoId,
                                onRemove: _removeVideo,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }
              // 모바일 레이아웃
              return SingleChildScrollView(
                child: Column(
                  children: [
                    customPlayer,
                    const Controls(),
                    MyPlayList(
                      playlist: _playlist,
                      currentVideoId: _currentVideoId,
                      onRemove: _removeVideo,
                    ),
                    // 검색창은 drawer에서만 띄움
                  ],
                ),
              );
            },
          ),
          floatingActionButton: Builder(
            builder: (context) => FloatingActionButton(
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
              child: Icon(Icons.search),
              tooltip: '동영상 검색',
            ),
          ),
        );
      },
    );
  }
  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }
}

// 재생 컨트롤 및 메타데이터를 위한 위젯.
class Controls extends StatefulWidget {
  ///
  const Controls({super.key});

  @override
  State<Controls> createState() => _ControlsState();
}

class _ControlsState extends State<Controls> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [const CircularProgressPlayerButton()],
      ),
    );
  }

  Widget get _space => const SizedBox(width: 30);
}

/// 앱바에서 재생목록 관련 동작을 위한 아이콘 버튼.
class VideoPlaylistIconButton extends StatelessWidget {
  ///
  const VideoPlaylistIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.ytController;

    return IconButton(
      onPressed: () async {
        controller.pauseVideo();
      },
      icon: const Icon(Icons.playlist_play_sharp),
    );
  }
}
