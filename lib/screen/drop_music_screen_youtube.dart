import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:muse_mate/widgets/meta_data_section.dart';
import 'package:muse_mate/widgets/play_pause_button_bar.dart';
import 'package:muse_mate/widgets/source_input_section.dart';
import 'package:muse_mate/widgets/circular_progress_player.dart';
import 'package:muse_mate/screen/search_youtube_screen.dart';
import 'package:muse_mate/widgets/video_position_seeker.dart';

const List<String> _videoIds = [
  'EY9uI5d3SIo',
  'bautietoaBo',
  'H5v3kku4y6Q',
  'nPt8bK2gbaU',
  'K18cpp_-gP8',
  'iLnmTe5Q2Qw',
  '_WoCV4c6XOE',
  'KmzdUe0RSJo',
  '6jZDSSZZxjQ',
  'p2lYr3vM_1w',
  '7QUtEmBT_-w',
  '34_PXCzGw1M',
];

class DropMusicYoutubeScreen extends StatefulWidget {
  const DropMusicYoutubeScreen({super.key, this.videoId});
  final String? videoId;
  @override
  State<DropMusicYoutubeScreen> createState() => _DropMusicYoutubeScreenState();
}

class _DropMusicYoutubeScreenState extends State<DropMusicYoutubeScreen> {
  late YoutubePlayerController _controller;
  late String _currentVideoId;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      params: const YoutubePlayerParams(
        showControls: true,
        mute: false,
        showFullscreenButton: true,
        loop: false,
      ),
    );

    _controller.setFullScreenListener((isFullScreen) {
      print('${isFullScreen ? 'Entered' : 'Exited'} Fullscreen.');
    });

    if (widget.videoId != null) {
      _controller.loadVideoById(videoId: widget.videoId!);
    } else {
      _controller.loadPlaylist(
        list: _videoIds,
        listType: ListType.playlist,
        startSeconds: 0,
      );
    }
  }

  void _onVideoSelected(String newId) {
    setState(() {
      _currentVideoId = newId;
      print(_currentVideoId);
       _controller.loadVideoById(videoId: _currentVideoId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerScaffold(
      controller: _controller,
      builder: (context, player) {
        final invisiblePlayer = SizedBox(
          height: 0.1,
          width: 0.1,
          child: player,
        );

        return Scaffold(
          appBar: AppBar(
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
                              invisiblePlayer,
                              const CircularProgressPlayerButton(),
                              const Controls(),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: SizedBox(
                            height:
                                constraints.maxHeight -
                                kToolbarHeight -
                                MediaQuery.of(context).padding.top,
                            child: SearchYoutubeScreen(onVideoTap: _onVideoSelected),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }

              return SingleChildScrollView(
                child: Column(
                  children: [
                    invisiblePlayer,
                    const CircularProgressPlayerButton(),
                    const Controls(),
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.4,
                      child: SearchYoutubeScreen(onVideoTap: _onVideoSelected),
                    ),
                  ],
                ),
              );
            },
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MetaDataSection(),
          _space,
          const SourceInputSection(),
          _space,
          PlayPauseButtonBar(),
          _space,
          const VideoPositionSeeker(),
          _space,
        ],
      ),
    );
  }

  Widget get _space => const SizedBox(height: 10);
}

///
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
