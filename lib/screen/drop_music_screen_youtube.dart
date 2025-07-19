import 'dart:math';
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:muse_mate/widgets/meta_data_section.dart';
import 'package:muse_mate/widgets/play_pause_button_bar.dart';
import 'package:muse_mate/widgets/player_state_section.dart';
import 'package:muse_mate/widgets/source_input_section.dart';

const List<String> _videoIds = [
  'EY9uI5d3SIo',
  'tcodrIK2P_I',
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

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerScaffold(
      controller: _controller,
      builder: (context, player) {
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
                      child: Column(
                        children: [player, const VideoPositionIndicator()],
                      ),
                    ),
                    const Expanded(
                      flex: 2,
                      child: SingleChildScrollView(child: Controls()),
                    ),
                  ],
                );
              }

              return ListView(
                children: [
                  player,
                  const VideoPositionIndicator(),
                  const Controls(),
                ],
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

class Controls extends StatelessWidget {
  ///
  const Controls({super.key});

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
          const PlayerStateSection(),
          _space,
          CircularProgressPlayerButton(
            progress: 0.3,
            isPlaying: true,
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget get _space => const SizedBox(height: 10);
}

/// 유튜브 로직이 분리된 순수 UI 위젯입니다.
class CircularProgressPlayerButton extends StatelessWidget {
  /// 위젯의 전체 크기
  final double size;

  /// 진행률 (0.0 ~ 1.0)
  final double progress;

  /// 재생중 여부 (아이콘 모양 결정)
  final bool isPlaying;

  /// 버튼을 눌렀을 때 실행될 콜백 함수
  final VoidCallback onPressed;

  const CircularProgressPlayerButton({
    super.key,
    required this.progress,
    required this.isPlaying,
    required this.onPressed,
    this.size = 150.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 원형 진행률을 그리는 CustomPaint
          CustomPaint(
            size: Size.square(size),
            painter: _ProgressArcPainter(
              progress: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.white.withAlpha(51),
              progressColor: const Color(0xFFB3A4EE),
              strokeWidth: 8.0,
            ),
          ),
          // 중앙의 아이콘 버튼
          IconButton(
            onPressed: onPressed,
            icon: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
            ),
            iconSize: size * 0.5,
          ),
        ],
      ),
    );
  }
}

// 원형 진행률을 그리는 CustomPainter
class _ProgressArcPainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  final Color progressColor;
  final double strokeWidth;

  _ProgressArcPainter({
    required this.progress,
    required this.backgroundColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    const startAngle = -pi / 2;
    final sweepAngle = progress * 2 * pi;

    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, backgroundPaint);

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressArcPainter oldDelegate) {
    return progress != oldDelegate.progress;
  }
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

///
class VideoPositionIndicator extends StatelessWidget {
  ///
  const VideoPositionIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.ytController;

    return StreamBuilder<YoutubeVideoState>(
      stream: controller.videoStateStream,
      initialData: const YoutubeVideoState(),
      builder: (context, snapshot) {
        final position = snapshot.data?.position.inMilliseconds ?? 0;
        final duration = controller.metadata.duration.inMilliseconds;

        return LinearProgressIndicator(
          value: duration == 0 ? 0 : position / duration,
          minHeight: 1,
        );
      },
    );
  }
}

///
class VideoPositionSeeker extends StatelessWidget {
  ///
  const VideoPositionSeeker({super.key});

  @override
  Widget build(BuildContext context) {
    var value = 0.0;

    return Row(
      children: [
        const Text('Seek', style: TextStyle(fontWeight: FontWeight.w300)),
        const SizedBox(width: 14),
        Expanded(
          child: StreamBuilder<YoutubeVideoState>(
            stream: context.ytController.videoStateStream,
            initialData: const YoutubeVideoState(),
            builder: (context, snapshot) {
              final position = snapshot.data?.position.inSeconds ?? 0;
              final duration = context.ytController.metadata.duration.inSeconds;

              value = position == 0 || duration == 0 ? 0 : position / duration;

              return StatefulBuilder(
                builder: (context, setState) {
                  return Slider(
                    value: value,
                    onChanged: (positionFraction) {
                      value = positionFraction;
                      setState(() {});

                      context.ytController.seekTo(
                        seconds: (value * duration).toDouble(),
                        allowSeekAhead: true,
                      );
                    },
                    min: 0,
                    max: 1,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
