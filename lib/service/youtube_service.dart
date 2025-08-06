// lib/service/youtube_service.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class YoutubeService {
  // 유튜브 비디오 ID 추출
  static String? extractYoutubeVideoId(String? url) {
    if (url == null || url.isEmpty) return null;

    // 일반 유튜브 URL 패턴
    RegExp regExp1 = RegExp(
      r'^https?:\/\/(?:www\.)?youtube\.com\/watch\?v=([a-zA-Z0-9_-]{11}).*$',
    );
    
    // 짧은 유튜브 URL 패턴
    RegExp regExp2 = RegExp(
      r'^https?:\/\/(?:www\.)?youtu\.be\/([a-zA-Z0-9_-]{11}).*$',
    );

    // 첫 번째 패턴 확인
    Match? match = regExp1.firstMatch(url);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }

    // 두 번째 패턴 확인
    match = regExp2.firstMatch(url);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }

    return null;
  }

  // 유튜브 썸네일 URL 생성
  static String getYoutubeThumbnailUrl(String videoId) {
    return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
  }

  // 네트워크 이미지에서 BitmapDescriptor 생성 (마커 아이콘용)
  static Future<BitmapDescriptor> getBitmapDescriptorFromNetworkImage(
    String imageUrl,
  ) async {
    final File file = await DefaultCacheManager().getSingleFile(imageUrl);
    final Uint8List bytes = await file.readAsBytes();

    // 이미지 크기 조정
    final ui.Codec codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 120,
      targetHeight: 120,
    );
    final ui.FrameInfo fi = await codec.getNextFrame();
    final ByteData? byteData = await fi.image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    final Uint8List resizedBytes = byteData!.buffer.asUint8List();
    return BitmapDescriptor.fromBytes(resizedBytes);
  }
}