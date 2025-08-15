import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/place_model.dart';
import 'location_service.dart';

class PlaceMarkerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _placeMarkersCollection =>
      _firestore.collection('place_markers');

  User? get currentUser => _auth.currentUser;

  Future<void> savePlaceMarker({
    required PlaceModel place,
    required String musicTitle,
    required String musicDescription,
    String? youtubeLink,
  }) async {
    if (currentUser == null) throw Exception('User not authenticated');

    final markerId = '${place.id}_${currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}';

    await _placeMarkersCollection.doc(markerId).set({
      'placeId': place.id,
      'placeName': place.name,
      'placeAddress': place.address,
      'latitude': place.latitude,
      'longitude': place.longitude,
      'placeRating': place.rating,
      'photoReference': place.photoReference,
      'types': place.types,
      'musicTitle': musicTitle,
      'musicDescription': musicDescription,
      'youtubeLink': youtubeLink,
      'ownerId': currentUser!.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<DocumentSnapshot>> getPlaceMarkersInRange({
    required LatLng center,
    required double radiusInMeters,
  }) async {
    try {
      final snapshot = await _placeMarkersCollection.get();

      return snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final lat = data['latitude'] ?? 0.0;
        final lng = data['longitude'] ?? 0.0;

        final distance = LocationService.calculateDistance(
            center, LatLng(lat, lng)
        );

        return distance <= radiusInMeters;
      }).toList();
    } catch (e) {
      print('Place markers 로딩 오류: $e');
      return [];
    }
  }

  Future<void> deletePlaceMarker(String markerId) async {
    await _placeMarkersCollection.doc(markerId).delete();
  }
}
