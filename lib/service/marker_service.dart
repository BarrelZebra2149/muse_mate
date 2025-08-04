// lib/service/marker_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:muse_mate/models/marker_model.dart';
import 'package:muse_mate/service/youtube_service.dart';
import 'package:muse_mate/service/location_service.dart';

class MarkerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Firestore 컬렉션 참조
  CollectionReference get markersCollection => 
      _firestore.collection('markers');
  
  // 현재 사용자 가져오기
  User? get currentUser => _auth.currentUser;

  // 마커가 범위 내에 있는지 확인
  bool isMarkerWithinRange(LatLng currentPosition, LatLng markerPosition, double searchRadius) {
    double distance = LocationService.calculateDistance(currentPosition, markerPosition);
    return distance <= searchRadius;
  }

  // Firestore에서 마커 로드
  Future<List<DocumentSnapshot>> loadMarkersFromFirestore() async {
    try {
      final snapshot = await markersCollection.get();
      return snapshot.docs;
    } catch (e) {
      print('마커 로드 오류: $e');
      throw e;
    }
  }

  // Firestore에 마커 저장
  Future<void> saveMarkerToFirestore(
    String markerId,
    LatLng position,
    CustomMarkerInfo info,
  ) async {
    if (currentUser == null) {
      throw Exception('로그인이 필요합니다');
    }

    try {
      await markersCollection.doc(markerId).set({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'title': info.title,
        'description': info.description,
        'imageUrl': info.imageUrl,
        'youtubeLink': info.youtubeLink,
        'ownerId': currentUser!.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('마커 저장 오류: $e');
      throw e;
    }
  }

  // Firestore에서 마커 삭제
  Future<void> deleteMarkerFromFirestore(String markerId) async {
    try {
      await markersCollection.doc(markerId).delete();
    } catch (e) {
      print('마커 삭제 오류: $e');
      throw e;
    }
  }

  // Firestore에서 마커 업데이트
  Future<void> updateMarkerInFirestore(
    String markerId,
    CustomMarkerInfo info,
  ) async {
    try {
      await markersCollection.doc(markerId).update({
        'title': info.title,
        'description': info.description,
        'youtubeLink': info.youtubeLink,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('마커 업데이트 오류: $e');
      throw e;
    }
  }

  // 특정 사용자의 마커만 가져오기
  Future<List<DocumentSnapshot>> getUserMarkers() async {
    if (currentUser == null) {
      throw Exception('로그인이 필요합니다');
    }

    try {
      final snapshot = await markersCollection
          .where('ownerId', isEqualTo: currentUser!.uid)
          .get();
      return snapshot.docs;
    } catch (e) {
      print('사용자 마커 로드 오류: $e');
      throw e;
    }
  }
}