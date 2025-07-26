import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:muse_mate/screen/drop_music_screen_youtube.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:muse_mate/screen/management_markers_screen.dart';
import 'package:muse_mate/screen/search_youtube_screen.dart';
import 'package:muse_mate/models/marker_model.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Firebase Auth 인스턴스 추가
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;

  GoogleMapController? mapController;

  // 초기 위도 경도
  LatLng _currentPosition = const LatLng(37.5665, 126.9780);
  bool _isLoading = true;

  // 마커 관리
  final Set<Marker> _markers = {};

  // 현재 선택된 마커 정보
  CustomMarkerInfo? _selectedMarkerInfo;
  bool _showInfoWindow = false;
  LatLng? _infoWindowPosition;

  // 마커 카운터 (고유 ID 생성용)
  int _markerIdCounter = 0;

  // 마커 ID와 소유자 ID를 매핑하는 Map 추가
  final Map<String, String> _markerOwners = {};

  // 현재 선택된 마커 ID 저장
  String? _selectedMarkerId;

  // 범위 관련 변수 추가
  double _searchRadius = 1000.0; // 기본 1km 반경
  final Set<Circle> _circles = {}; // 원 표시를 위한 Set
  bool _showRangeCircle = true; // 범위 원 표시 여부

  // 기존 initState에 원 추가
  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _getCurrentLocation();
    _loadMarkersFromFirestore();
    _addRangeCircle(); // 범위 원 추가
  }

  // 범위 원 추가 메서드
  void _addRangeCircle() {
    if (_showRangeCircle) {
      setState(() {
        _circles.clear();
        _circles.add(
          Circle(
            circleId: const CircleId('searchRange'),
            center: _currentPosition,
            radius: _searchRadius,
            fillColor: Colors.blue.withOpacity(0.1), // 매우 투명한 파란색
            strokeColor: Colors.blue.withOpacity(0.3), // 반투명한 테두리
            strokeWidth: 2,
          ),
        );
      });
    }
  }

  // 현재 사용자 정보 가져오기
  void _getCurrentUser() {
    _currentUser = _auth.currentUser;
    // 사용자가 로그인되어 있지 않으면 로그인 화면으로 이동할 수도 있음
    if (_currentUser == null) {
      // 선택적: 로그인 화면으로 이동하거나 익명 로그인 구현
      // _signInAnonymously(); // 익명 로그인을 구현할 경우
    }
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 위치 서비스가 활성화되어 있는지 확인
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('위치 서비스가 비활성화되어 있습니다. 설정에서 활성화해주세요.')),
      );
      return false;
    }

    // 위치 권한 확인
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // 권한이 없으면 요청
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('위치 권한이 거부되었습니다.')));
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('위치 권한이 영구적으로 거부되었습니다. 설정에서 변경해주세요.')),
      );
      return false;
    }

    return true;
  }

  // 위치가 업데이트될 때 원도 함께 업데이트
  void _getCurrentLocation() async {
    final hasPermission = await _handleLocationPermission();

    if (!hasPermission) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _isLoading = false;

        // 현재 위치에 마커 추가
        _markers.add(
          Marker(
            markerId: const MarkerId('currentLocation'),
            position: _currentPosition,
            infoWindow: const InfoWindow(title: '내 위치', snippet: '현재 위치입니다'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure),
          ),
        );
      });

      // 범위 원 업데이트
      _addRangeCircle();

      // 지도가 이미 생성되었으면 현재 위치로 카메라 이동
      if (mapController != null) {
        mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: _currentPosition, zoom: 15.0),
          ),
        );
      }
    } catch (e) {
      print("위치를 가져오는데 오류가 발생했습니다: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;

    if (!_isLoading) {
      mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentPosition, zoom: 15.0),
        ),
      );
    }

    // Firestore에서 마커 로드
    _loadMarkersFromFirestore();
  }

  // 지도 탭 이벤트 처리
  void _onMapTapped(LatLng position) {
    // 정보 창이 열려 있으면 닫기
    if (_showInfoWindow) {
      setState(() {
        _showInfoWindow = false;
      });
      return;
    }

    // 탭한 위치에 마커 추가를 위한 다이얼로그 표시
    _showAddMarkerDialog(position);
  }

  // 마커 추가 다이얼로그 표시
  void _showAddMarkerDialog(LatLng position) {
    String title = '';
    String description = '';
    String youtubeLink = '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이 위치에 음악 추가'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: '제목'),
                onChanged: (value) {
                  title = value;
                },
              ),
              const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(
                  labelText: '설명',
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                onChanged: (value) {
                  description = value;
                },
              ),
              const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(
                  labelText: '유튜브 링크 (선택사항)',
                  hintText: 'https://www.youtube.com/watch?v=...',
                  prefixIcon: Icon(Icons.music_note),
                ),
                onChanged: (value) {
                  youtubeLink = value;
                },
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.search),
                label: const Text('유튜브에서 음악 검색'),
                onPressed: () async {
                  // 유튜브 검색 화면으로 이동
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SearchYoutubeScreen()),
                  );

                  // 선택한 유튜브 비디오 정보 받아오기
                  if (result != null && result is Map<String, dynamic>) {
                    Navigator.pop(context); // 현재 다이얼로그 닫기

                    // 새 다이얼로그 열기 (선택한 유튜브 정보로 미리 채워진)
                    _showAddMarkerDialogWithYoutube(
                        position,
                        result['videoId'],
                        result['title']
                    );
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              if (title.isNotEmpty) {
                _addCustomMarker(
                  position: position,
                  markerInfo: CustomMarkerInfo(
                    title: title,
                    description: description.isNotEmpty ? description : '설명 없음',
                    youtubeLink: youtubeLink.isNotEmpty ? youtubeLink : null,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('제목을 입력해주세요.')),
                );
                return;
              }
              Navigator.pop(context);
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

// 유튜브 검색 결과로 마커 추가 다이얼로그
  void _showAddMarkerDialogWithYoutube(LatLng position, String videoId, String videoTitle) {
    String title = videoTitle; // 유튜브 제목을 기본값으로 설정
    String description = '';
    String youtubeLink = 'https://www.youtube.com/watch?v=$videoId';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('음악 정보 확인'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 유튜브 썸네일 표시
              Image.network('https://img.youtube.com/vi/$videoId/hqdefault.jpg'),
              const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(labelText: '제목'),
                controller: TextEditingController(text: title),
                onChanged: (value) {
                  title = value;
                },
              ),
              const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(
                  labelText: '설명',
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                onChanged: (value) {
                  description = value;
                },
              ),
              const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(
                  labelText: '유튜브 링크',
                  prefixIcon: Icon(Icons.music_note),
                ),
                controller: TextEditingController(text: youtubeLink),
                readOnly: true, // 링크는 수정 불가
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              if (title.isNotEmpty) {
                _addCustomMarker(
                  position: position,
                  markerInfo: CustomMarkerInfo(
                    title: title,
                    description: description.isNotEmpty ? description : '설명 없음',
                    youtubeLink: youtubeLink,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('제목을 입력해주세요.')),
                );
                return;
              }
              Navigator.pop(context);
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

// 커스텀 마커 추가
  Future<void> _addCustomMarker({
    required LatLng position,
    required CustomMarkerInfo markerInfo,
  }) async {
    // 범위 내에 있는지 확인
    if (!_isMarkerWithinRange(position)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('설정된 범위를 벗어난 위치입니다.')),
      );
      return;
    }

    final String markerId = 'custom_marker_${DateTime.now().millisecondsSinceEpoch}';

    // 기본 마커 아이콘
    BitmapDescriptor markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);

    // 유튜브 링크가 있는 경우 썸네일을 마커 아이콘으로 사용
    if (markerInfo.youtubeLink != null && markerInfo.youtubeLink!.isNotEmpty) {
      // 유튜브 비디오 ID 추출
      String? videoId = extractYoutubeVideoId(markerInfo.youtubeLink);
      if (videoId != null) {
        // 썸네일 URL 생성
        String thumbnailUrl = getYoutubeThumbnailUrl(videoId);

        // 썸네일을 마커 아이콘으로 변환
        markerIcon = await getBitmapDescriptorFromNetworkImage(thumbnailUrl);

        // 썸네일 URL을 마커 정보에 저장
        markerInfo = CustomMarkerInfo(
          title: markerInfo.title,
          description: markerInfo.description,
          imageUrl: thumbnailUrl, // 썸네일 URL 저장
          youtubeLink: markerInfo.youtubeLink,
        );
      }
    }

    final Marker marker = Marker(
      markerId: MarkerId(markerId),
      position: position,
      icon: markerIcon, // 커스텀 아이콘 또는 기본 아이콘
      onTap: () {
        setState(() {
          _selectedMarkerInfo = markerInfo;
          _showInfoWindow = true;
          _infoWindowPosition = position;
        });
      },
    );

    setState(() {
      _markers.add(marker);

      // 마커 추가 후 바로 정보 창 표시
      _selectedMarkerInfo = markerInfo;
      _showInfoWindow = true;
      _infoWindowPosition = position;
    });

    // Firestore에 마커 저장
    _saveMarkerToFirestore(markerId, position, markerInfo);
  }

  // 두 지점 간의 거리 계산 메서드 (미터 단위)
  double _calculateDistance(LatLng start, LatLng end) {
    return Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );
  }

  // 범위 내 마커만 필터링하는 메서드
  bool _isMarkerWithinRange(LatLng markerPosition) {
    double distance = _calculateDistance(_currentPosition, markerPosition);
    return distance <= _searchRadius;
  }

  // Firestore에서 마커 로드 시 범위 내 마커만 표시하도록 수정
  Future<void> _loadMarkersFromFirestore() async {
    try {
      final snapshot = await markersCollection.get();

      setState(() {
        // 현재 위치 마커를 제외한 모든 마커 삭제
        _markers.removeWhere((marker) => marker.markerId.value != 'currentLocation');
        _markerOwners.clear();

        // Firestore에서 가져온 마커 중 범위 내 마커만 추가
        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final markerId = doc.id;
          final double latitude = data['latitude'] ?? 0.0;
          final double longitude = data['longitude'] ?? 0.0;
          final LatLng markerPosition = LatLng(latitude, longitude);
          final String ownerId = data['ownerId'] ?? '';
          final String imageUrl = data['imageUrl'] ?? '';

          // 범위 내에 있는 마커만 추가
          if (_isMarkerWithinRange(markerPosition)) {
            // 소유자 정보 저장
            _markerOwners[markerId] = ownerId;

            Future<void> createMarker() async {
              BitmapDescriptor icon;
              if (imageUrl.isNotEmpty) {
                icon = await getBitmapDescriptorFromNetworkImage(imageUrl);
              } else {
                icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
              }

              setState(() {
                _markers.add(Marker(
                  markerId: MarkerId(markerId),
                  position: markerPosition,
                  icon: icon,
                  onTap: () {
                    setState(() {
                      _selectedMarkerInfo = CustomMarkerInfo(
                        title: data['title'] ?? '',
                        description: data['description'] ?? '',
                        imageUrl: imageUrl,
                        youtubeLink: data['youtubeLink'],
                      );
                      _showInfoWindow = true;
                      _infoWindowPosition = markerPosition;
                      _selectedMarkerId = markerId;
                    });
                  },
                ));
              });
            }

            // 반드시 비동기로 실행
            createMarker();
          }
        }
      });
    } catch (e) {
      print('마커 로드 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('마커 로드 중 오류가 발생했습니다: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 구글 맵
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _currentPosition,
              zoom: 15.0,
            ),
            markers: _markers,
            circles: _circles, // 원 표시 추가
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            onTap: _onMapTapped,
          ),

          // 커스텀 정보 창
          if (_showInfoWindow && _selectedMarkerInfo != null)
            _buildCustomInfoWindow(context),
          // 범위 조절 컨트롤 패널
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.my_location, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '범위: ${(_searchRadius / 1000).toStringAsFixed(1)}km',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 200,
                    child: Slider(
                      value: _searchRadius,
                      min: 100.0, // 최소 100m
                      max: 5000.0, // 최대 5km
                      divisions: 49,
                      label: '${(_searchRadius / 1000).toStringAsFixed(1)}km',
                      onChanged: _updateSearchRadius,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 범위 원 표시/숨김 토글 버튼
                      IconButton(
                        icon: Icon(
                          _showRangeCircle ? Icons.visibility : Icons.visibility_off,
                          size: 20,
                        ),
                        onPressed: _toggleRangeCircle,
                        tooltip: _showRangeCircle ? '범위 원 숨기기' : '범위 원 표시',
                      ),
                      // 빠른 범위 선택 버튼들
                      TextButton(
                        onPressed: () => _updateSearchRadius(500),
                        child: const Text('500m', style: TextStyle(fontSize: 12)),
                      ),
                      TextButton(
                        onPressed: () => _updateSearchRadius(1000),
                        child: const Text('1km', style: TextStyle(fontSize: 12)),
                      ),
                      TextButton(
                        onPressed: () => _updateSearchRadius(2000),
                        child: const Text('2km', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 내 마커 관리 버튼
          Positioned(
            right: 16,
            bottom: 100,
            child: FloatingActionButton(
              heroTag: 'manageMarkers',
              backgroundColor: Colors.purple,
              child: const Icon(Icons.list),
              onPressed: () async {
                // 내 마커 관리 화면으로 이동
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MyMarkersScreen()),
                );

                // 특정 마커 위치로 이동 (선택 사항)
                if (result != null && result is Map<String, dynamic>) {
                  final double lat = result['latitude'];
                  final double lng = result['longitude'];
                  mapController?.animateCamera(
                    CameraUpdate.newLatLng(LatLng(lat, lng)),
                  );
                }

                // 마커 목록 새로고침
                _loadMarkersFromFirestore();
              },
            ),
          ),

          // 새로고침 버튼 추가
          Positioned(
            right: 16,
            bottom: 170,
            child: FloatingActionButton(
              heroTag: 'refresh',
              backgroundColor: Colors.green,
              child: const Icon(Icons.refresh),
              onPressed: () {
                _getCurrentLocation(); // 위치 새로고침
                _loadMarkersFromFirestore(); // 마커 새로고침
              },
            ),
          ),
        ],
      ),
    );
  }

  // 마커 정보 창 위젯 수정 - 소유자만 수정/삭제 버튼 표시
  Widget _buildCustomInfoWindow(BuildContext context) {
    bool isOwner = _currentUser != null &&
        _selectedMarkerId != null &&
        _markerOwners[_selectedMarkerId] == _currentUser!.uid;

    return Positioned(
      right: 20,
      top: 100,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _selectedMarkerInfo!.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    setState(() {
                      _showInfoWindow = false;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_selectedMarkerInfo!.imageUrl.isNotEmpty)
              Container(
                height: 150,
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: NetworkImage(_selectedMarkerInfo!.imageUrl),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            Text(
              _selectedMarkerInfo!.description,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            // 유튜브 링크가 있을 경우 재생 버튼 추가
            if (_selectedMarkerInfo!.youtubeLink != null && _selectedMarkerInfo!.youtubeLink!.isNotEmpty)
              ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('유튜브 재생'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.red,
                ),
                onPressed: () {
                  // 유튜브 동영상 ID 추출
                  String? videoId = extractYoutubeVideoId(_selectedMarkerInfo!.youtubeLink);
                  if (videoId != null) {
                    // 유튜브 플레이어 화면으로 이동
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DropMusicYoutubeScreen(videoId: videoId),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('유효한 유튜브 링크가 아닙니다.')),
                    );
                  }
                },
              ),
            const SizedBox(height: 8),
            // 소유자인 경우에만 수정/삭제 버튼 표시
            if (isOwner)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('수정'),
                    onPressed: () {
                      // 마커 정보 수정 기능 구현
                      _showEditMarkerDialog();
                    },
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.delete),
                    label: const Text('삭제'),
                    onPressed: () {
                      // 마커 삭제 기능 구현
                      _deleteCurrentMarker();
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _showEditMarkerDialog() {
    // 현재 마커 정보 가져오기
    String title = _selectedMarkerInfo!.title;
    String description = _selectedMarkerInfo!.description;
    String youtubeLink = _selectedMarkerInfo!.youtubeLink ?? ''; // 유튜브 링크 가져오기

    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('정보 수정'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(labelText: '제목'),
                    controller: TextEditingController(text: title),
                    onChanged: (value) {
                      title = value;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: '설명',
                      alignLabelWithHint: true,
                    ),
                    controller: TextEditingController(text: description),
                    maxLines: 3,
                    onChanged: (value) {
                      description = value;
                    },
                  ),
                  const SizedBox(height: 10),
                  // 유튜브 링크 수정 필드 추가
                  TextField(
                    decoration: const InputDecoration(
                      labelText: '유튜브 링크 (선택사항)',
                      hintText: 'https://www.youtube.com/watch?v=...',
                      prefixIcon: Icon(Icons.music_note),
                    ),
                    controller: TextEditingController(text: youtubeLink),
                    onChanged: (value) {
                      youtubeLink = value;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () {
                  if (title.isNotEmpty) {
                    setState(() {
                      // 현재 선택된 마커 정보 업데이트
                      _selectedMarkerInfo = CustomMarkerInfo(
                        title: title,
                        description: description.isNotEmpty
                            ? description
                            : '설명 없음',
                        imageUrl: _selectedMarkerInfo!.imageUrl,
                        youtubeLink: youtubeLink.isNotEmpty
                            ? youtubeLink
                            : null, // 유튜브 링크 업데이트
                      );
                    });
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('제목을 입력해주세요.')),
                    );
                  }
                },
                child: const Text('저장'),
              ),
            ],
          ),
    );
  }

// 현재 선택된 마커 삭제 - 권한 확인 추가
  void _deleteCurrentMarker() {
    // 선택된 마커의 ID 확인
    String? markerIdToDelete;
    String? markerOwnerId;

    // 현재 표시된 정보창의 마커 찾기
    for (var marker in _markers) {
      if (marker.position.latitude == _infoWindowPosition!.latitude &&
          marker.position.longitude == _infoWindowPosition!.longitude &&
          marker.markerId.value != 'currentLocation') {
        markerIdToDelete = marker.markerId.value;
        markerOwnerId = _markerOwners[markerIdToDelete];
        break;
      }
    }

    // 마커가 없거나 소유자가 아니면 삭제 불가
    if (markerIdToDelete == null ||
        _currentUser == null ||
        markerOwnerId != _currentUser!.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('마커를 삭제할 권한이 없습니다.')),
      );
      return;
    }

    // 삭제 확인 다이얼로그
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('마커 삭제'),
        content: const Text('이 마커를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _markers.removeWhere((marker) => marker.markerId.value == markerIdToDelete);
                _showInfoWindow = false;
              });

              // Firestore에서도 삭제
              _deleteMarkerFromFirestore(markerIdToDelete!);
              Navigator.pop(context);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

// Firestore 콜렉션 참조
  final CollectionReference markersCollection = FirebaseFirestore.instance
      .collection('markers');

// Firestore에 마커 저장할 때 소유자 ID 추가
  Future<void> _saveMarkerToFirestore(String markerId, LatLng position,
      CustomMarkerInfo info) async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    try {
      await markersCollection.doc(markerId).set({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'title': info.title,
        'description': info.description,
        'imageUrl': info.imageUrl,
        'youtubeLink': info.youtubeLink,
        'createdAt': FieldValue.serverTimestamp(),
        'ownerId': _currentUser!.uid, // 현재 사용자 ID 저장
      });
    } catch (e) {
      print('마커 저장 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('마커 저장 중 오류가 발생했습니다: $e')),
      );
    }
  }

// Firestore에서 마커 데이터 삭제
  Future<void> _deleteMarkerFromFirestore(String markerId) async {
    try {
      await markersCollection.doc(markerId).delete();
    } catch (e) {
      print('마커 삭제 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('마커 삭제 중 오류가 발생했습니다: $e')),
      );
    }
  }

  // 범위 조절 메서드
  void _updateSearchRadius(double newRadius) {
    setState(() {
      _searchRadius = newRadius;
    });
    _addRangeCircle(); // 원 업데이트
    _loadMarkersFromFirestore(); // 마커 다시 로드
  }

  // 범위 원 표시/숨김 토글
  void _toggleRangeCircle() {
    setState(() {
      _showRangeCircle = !_showRangeCircle;
      if (!_showRangeCircle) {
        _circles.clear();
      } else {
        _addRangeCircle();
      }
    });
  }



// 유튜브 링크에서 비디오 ID 추출
  String? extractYoutubeVideoId(String? url) {
    if (url == null || url.isEmpty) {
      return null;
    }

    // 정규식으로 유튜브 비디오 ID 추출
    RegExp regExp = RegExp(
      r'^.*((youtu.be\/)|(v\/)|(\/u\/\w\/)|(embed\/)|(watch\?))\??v?=?([^#&?]*).*',
      caseSensitive: false,
      multiLine: false,
    );

    Match? match = regExp.firstMatch(url);
    if (match != null && match.groupCount >= 7) {
      String? id = match.group(7);
      if (id != null && id.length == 11) {
        return id;
      }
    }

    return null;
  }
}

// 유튜브 비디오 ID로부터 썸네일 URL을 생성하는 함수
String getYoutubeThumbnailUrl(String? videoId) {
  if (videoId == null || videoId.isEmpty) {
    return '';
  }
  // 고품질 썸네일 URL 반환 (여러 옵션 중 선택 가능)
  // mqdefault: 중간 품질, hqdefault: 고품질, maxresdefault: 최대 품질
  return 'https://img.youtube.com/vi/$videoId/mqdefault.jpg';
}

// 네트워크 이미지 URL에서 BitmapDescriptor 생성
Future<BitmapDescriptor> getBitmapDescriptorFromNetworkImage(String imageUrl) async {
  if (imageUrl.isEmpty) {
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
  }

  try {
    final File file = await DefaultCacheManager().getSingleFile(imageUrl);
    final Uint8List bytes = await file.readAsBytes();

    // 이미지 크기 조정 (마커 크기에 맞게)
    final ui.Codec codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 120,
      targetHeight: 120,
    );
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final ByteData? byteData = await frameInfo.image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData != null) {
      final Uint8List resizedBytes = byteData.buffer.asUint8List();
      return BitmapDescriptor.fromBytes(resizedBytes);
    } else {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
    }
  } catch (e) {
    print('이미지 로드 오류: $e');
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
  }
}