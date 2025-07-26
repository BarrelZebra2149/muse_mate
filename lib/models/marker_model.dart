import 'package:cloud_firestore/cloud_firestore.dart';

class MarkerModel {
  final String id;
  final double latitude;
  final double longitude;
  final String title;
  final String description;
  final String? imageUrl;
  final String? markerImageUrl;
  final String? youtubeLink;
  final String ownerId;

  MarkerModel({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.title,
    required this.description,
    this.imageUrl,
    this.markerImageUrl,
    this.youtubeLink,
    required this.ownerId,
  });

  factory MarkerModel.fromFirestore(Map<String, dynamic> data, String id) {
    return MarkerModel(
      id: id,
      latitude: data['latitude'] ?? 0.0,
      longitude: data['longitude'] ?? 0.0,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'],
      markerImageUrl: data['markerImageUrl'],
      youtubeLink: data['youtubeLink'],
      ownerId: data['ownerId'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'markerImageUrl': markerImageUrl,
      'youtubeLink': youtubeLink,
      'ownerId': ownerId,
    };
  }
}

class CustomMarkerInfo {
  final String title;
  final String description;
  final String imageUrl;
  final String? youtubeLink; // 유튜브 링크 필드 추가

  CustomMarkerInfo({
    required this.title,
    required this.description,
    this.imageUrl = '',
    this.youtubeLink, // 기본값은 null
  });
}