import 'dart:math';
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class CircularProgressPlayerButton extends StatelessWidget {
  final double size;
  const CircularProgressPlayerButton({super.key, this.size = 150.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: StreamBuilder<YoutubeVideoState>(
        stream: context.ytController.videoStateStream,
        initialData: const YoutubeVideoState(),
        builder: (context, snapshot) {
          final position = snapshot.data?.position.inMilliseconds ?? 0;
          final duration =
              context.ytController.metadata.duration.inMilliseconds;
          return Stack(
            alignment: Alignment.center,
            children: [
              // 원형 진행률을 그리는 CustomPaint
              CustomPaint(
                size: Size.square(size),
                painter: _ProgressArcPainter(
                  progress: duration > 0 ? position / duration : 0,
                  backgroundColor: Colors.black.withAlpha(30),
                  progressColor: const Color(0xFFB3A4EE),
                  strokeWidth: 8.0,
                ),
              ),
              // 중앙의 아이콘 버튼
              YoutubeValueBuilder(
                builder: (context, value) => GestureDetector(
                  onTap: () {
                    value.playerState == PlayerState.playing
                        ? context.ytController.pauseVideo()
                        : context.ytController.playVideo();
                  },
                  child: CircleAvatar(
                    backgroundColor: Colors.black,
                    radius: size * 0.25,
                    child: Icon(
                      value.playerState == PlayerState.playing
                          ? Icons.pause
                          : Icons.play_arrow,
                      color: Colors.white,
                      size: size * 0.5,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
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
