// lib/screen/map_screen_base.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:muse_mate/models/marker_model.dart';
import 'package:muse_mate/service/location_service.dart';
import 'package:muse_mate/service/marker_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract class MapScreenBase extends StatefulWidget {
  const MapScreenBase({super.key});
}

abstract class MapScreenBaseState<T extends MapScreenBase> extends State<T> {
  // 공통 서비스 인스턴스
  final MarkerService markerService = MarkerService();
  final FirebaseAuth auth = FirebaseAuth.instance;

  // 공통 상태 변수
  User? currentUser;
  GoogleMapController? mapController;
  LatLng currentPosition = const LatLng(37.5665, 126.9780);
  bool isLoading = true;
  Set<Marker> markers = {};
  CustomMarkerInfo? selectedMarkerInfo;
  bool showInfoWindow = false;
  LatLng? infoWindowPosition;
  Map<String, String> markerOwners = {};
  String? selectedMarkerId;
  double searchRadius = 1000.0;
  Set<Circle> circles = {};
  bool showRangeCircle = true;

  // 공통 메서드 선언
  void getCurrentUser();
  Future<void> getCurrentLocation();
  void onMapCreated(GoogleMapController controller);
  Future<void> loadMarkersFromFirestore();
  Future<void> addCustomMarker({
    required LatLng position,
    required CustomMarkerInfo markerInfo,
  });

  // 모든 자식 클래스에서 구현해야 하는 추상 메서드
  void onMapTapped(LatLng position);
  void showAddMarkerDialog(LatLng position);

  // 공통 UI 구성 요소 메서드
  Widget buildCustomInfoWindow(BuildContext context);
  Widget buildRangeControls();

  // 이 메서드를 MapScreenBaseState 클래스에 추가
  bool isPointInCircle(LatLng point, LatLng center, double radius) {
    double distance = LocationService.calculateDistance(center, point);
    return distance <= radius;
  }
}
