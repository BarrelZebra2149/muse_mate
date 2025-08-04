// lib/screen/map_screen.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:muse_mate/screen/map_screen_mobile.dart';
import 'package:muse_mate/screen/map_screen_web.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 플랫폼 감지하여 적절한 구현체로 라우팅
    if (kIsWeb) {
      return const MapScreenWeb();
    } else {
      return const MapScreenMobile();
    }
  }
}