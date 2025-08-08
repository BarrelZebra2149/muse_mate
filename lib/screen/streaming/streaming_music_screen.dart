// 이 파일은 DropMusicYoutubeScreen을 정의.
// YouTube 동영상 재생, 재생목록 관리, 검색, 재생 컨트롤 기능을 제공.
// youtube_player_iframe 패키지를 사용하여 YouTube 동영상을 임베드, 재생목록 및 컨트롤을 위한 커스텀 위젯을 사용.

import 'package:flutter/material.dart';
import 'package:muse_mate/models/video_model.dart';
import 'package:muse_mate/repository/chatroom_repository.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:muse_mate/screen/streaming/circular_progress_player.dart';
import 'package:muse_mate/screen/youtube_search/search_youtube_screen.dart';
import 'package:muse_mate/screen/streaming/my_playlist.dart';

// YouTube 음악 재생 및 재생목록 관리를 위한 메인 화면.
class StreamingMusicScreen extends StatefulWidget {
  const StreamingMusicScreen({super.key, required this.roomRef});

  final dynamic roomRef;

  @override
  State<StreamingMusicScreen> createState() => _StreamingMusicScreenState();
}

class _StreamingMusicScreenState extends State<StreamingMusicScreen> {
  late YoutubePlayerController _controller;
  VideoModel? _currentVideo;
  final chatroomRepo = ChatroomRepository();

  // 초기 동영상을 로드.
  loadVideo() async {
    _currentVideo = await chatroomRepo.getNowPlayingVideo(widget.roomRef);
    if (_currentVideo == null) {
      setState(() {}); // 로딩 인디케이터 표시용
      return;
    }

    final elapsedSeconds = await chatroomRepo.getElapsedSecondsSinceLastTrack(
      widget.roomRef,
    );

    if (_currentVideo?.videoId != '') {
      _controller.loadVideoById(
        videoId: _currentVideo!.videoId,
        startSeconds: elapsedSeconds,
      );
    }
    setState(() {});
  }

  @override
  void initState() {
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

    loadVideo();

    // 동영상이 끝나면 다음 동영상으로 이동.
    _controller.listen((event) {
      if (event.playerState == PlayerState.ended) {
        _moveToNextVideo();
      }
    });
  }

  // 현재 동영상이 끝나면 재생목록의 다음 동영상으로 이동.
  void _moveToNextVideo() async {
    _currentVideo = await chatroomRepo.playNextVideo(
      _currentVideo,
      widget.roomRef,
    );
    setState(() {}); // playlist에 현재 곡 반영하기 위해.

    if (_currentVideo != null) {
      _controller.loadVideoById(videoId: _currentVideo!.videoId);
    } else {
      _controller.pauseVideo();
    }
  }

  // 새로운 동영상을 재생목록에 추가하고, 첫 번째 동영상이면 재생.
  void _onVideoSelected(VideoModel video) async {
    int playlistCount = await chatroomRepo.addToPlaylist(video, widget.roomRef);

    // 선택한 동영상이 플레이리스트의 첫번째일때.
    if (playlistCount == 1) {
      _currentVideo = await chatroomRepo.getNowPlayingVideo(widget.roomRef);
      _controller.loadVideoById(videoId: _currentVideo!.videoId);
      setState(() {});
    }
  }

  // 재생목록에서 동영상을 제거함.
  void _removeVideo(int index, VideoModel video) async {
    if (video.videoRef == _currentVideo?.videoRef) {
      _moveToNextVideo();
      setState(() {});
      return;
    }

    await chatroomRepo.deleteFromPlaylist(video, index, widget.roomRef);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerScaffold(
      controller: _controller,
      builder: (context, player) {
        final customPlayer = Center(
          child: SizedBox(
            height: 150,
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
                child: SearchYoutubeScreen(
                  onVideoTap: (id, title) {
                    _onVideoSelected(
                      VideoModel(videoId: id, title: title, videoRef: ''),
                    );
                    Navigator.of(context).pop(); // 검색 후 drawer 닫기
                  },
                ),
              ),
            ),
          ),
          appBar: AppBar(
            leading: IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: () async {
                chatroomRepo.deleteChatroomIfHost(widget.roomRef);
                Navigator.of(context).pop(); // 현재 화면 종료
              },
            ),
            title: const Text('Youtube Player IFrame Demo'),
            actions: const [VideoPlaylistIconButton()],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                customPlayer,
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Controls(),
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: FloatingActionButton(
                        mini: true,
                        onPressed: () {
                          loadVideo(); // 현재 방의 동영상 싱크 맞추기
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('싱크 맞추기 완료')),
                          );
                        },
                        child: Icon(Icons.refresh),
                        tooltip: '라이브 방 싱크 맞추기',
                      ),
                    ),
                  ],
                ),
                MyPlayList(
                  roomRef: widget.roomRef,
                  currentVideo: _currentVideo,
                  onRemove: _removeVideo,
                ),
              ],
            ),
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
}

// 앱바에서 재생목록 관련 동작을 위한 아이콘 버튼.
class VideoPlaylistIconButton extends StatelessWidget {
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
