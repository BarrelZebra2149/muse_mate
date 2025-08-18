import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:muse_mate/models/marker_model.dart';
import 'package:muse_mate/models/place_model.dart';
import 'package:muse_mate/repository/chatroom_repository.dart';
import 'package:muse_mate/screen/streaming/live_streaming_room_screen.dart';
import 'package:muse_mate/screen/youtube_search/drop_music_screen_youtube.dart';
import 'package:muse_mate/screen/map/management_markers_screen.dart';
import 'package:muse_mate/screen/map/map_screen_base.dart';
import 'package:muse_mate/screen/youtube_search/search_youtube_screen.dart';
import 'package:muse_mate/service/location_service.dart';
import 'package:muse_mate/service/place_marker_service.dart';
import 'package:muse_mate/service/youtube_service.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:muse_mate/service/google_places_service.dart';
import 'package:muse_mate/widget/place_info_side_panel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:muse_mate/models/marker_model.dart';
import 'package:muse_mate/repository/chatroom_repository.dart';
import 'package:muse_mate/screen/streaming/live_streaming_room_screen.dart';
import 'package:muse_mate/screen/youtube_search/drop_music_screen_youtube.dart';
import 'package:muse_mate/screen/map/map_screen_base.dart';
import 'package:muse_mate/screen/youtube_search/search_youtube_screen.dart';
import 'package:muse_mate/service/location_service.dart';
import 'package:muse_mate/service/youtube_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MapScreenMobile extends MapScreenBase {
  const MapScreenMobile({super.key});

  @override
  State<MapScreenMobile> createState() => _MapScreenMobileState();
}

class _MapScreenMobileState extends MapScreenBaseState<MapScreenMobile> {
  List<PlaceModel> _nearbyPlaces = [];
  final PlaceMarkerService _placeMarkerService = PlaceMarkerService();
  bool _showPlaceMarkers = false; // 토글 기능을 위해 기본값 false
  bool _isLoadingPlaces = false;
  PlaceModel? _selectedPlace;
  bool _showSidePanel = false;

  @override
  void initState() {
    super.initState();
    getCurrentUser();
    getCurrentLocation();
    loadMarkersFromFirestore();
    addRangeCircle();
  }

  @override
  void getCurrentUser() {
    currentUser = auth.currentUser;
  }

  // 모바일에 맞는 범위 원 추가 메서드
  void addRangeCircle() {
    if (showRangeCircle) {
      setState(() {
        circles.clear();
        circles.add(
          Circle(
            circleId: const CircleId('searchRange'),
            center: currentPosition,
            radius: searchRadius,
            fillColor: Colors.blue.withOpacity(0.1),
            strokeColor: Colors.blue.withOpacity(0.3),
            strokeWidth: 2,
          ),
        );
      });
    }
  }

  @override
  Future<void> getCurrentLocation() async {
    final hasPermission = await LocationService.handleLocationPermission(
      context,
    );

    if (!hasPermission) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      final position = await LocationService.getCurrentPosition();
      if (position == null) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      setState(() {
        currentPosition = LatLng(position.latitude, position.longitude);
        isLoading = false;

        // 현재 위치에 마커 추가
        markers.add(
          Marker(
            markerId: const MarkerId('currentLocation'),
            position: currentPosition,
            infoWindow: const InfoWindow(title: '내 위치', snippet: '현재 위치입니다'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure,
            ),
            zIndexInt: -1,
          ),
        );
      });

      // 범위 원 업데이트
      addRangeCircle();

      // 지도가 이미 생성되었으면 현재 위치로 카메라 이동
      if (mapController != null) {
        mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: currentPosition, zoom: 15.0),
          ),
        );
      }
    } catch (e) {
      print("위치를 가져오는데 오류가 발생했습니다: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void onMapCreated(GoogleMapController controller) {
    mapController = controller;

    if (!isLoading) {
      mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: currentPosition, zoom: 15.0),
        ),
      );
    }

    // Firestore에서 마커 로드
    loadMarkersFromFirestore();
  }

  // 지도 탭 이벤트 처리 - 모바일 버전
  @override
  void onMapTapped(LatLng position) {
    // 정보 창이 열려 있으면 닫기
    if (showInfoWindow) {
      setState(() {
        showInfoWindow = false;
      });
      return;
    }

    // 탭한 위치에 마커 추가를 위한 다이얼로그 표시
    showAddMarkerDialog(position);
  }

  // 여기에 모바일 전용 UI 코드 작성
  // ...

  @override
  Future<void> addCustomMarker({
    required LatLng position,
    required CustomMarkerInfo markerInfo,
    bool isPrivate = false,
    String? privatePw,
  }) async {
    // 범위 내에 있는지 확인
    if (!markerService.isMarkerWithinRange(
      currentPosition,
      position,
      searchRadius,
    )) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('설정된 범위를 벗어난 위치입니다.')));
      return;
    }

    final String markerId =
        'custom_marker_${DateTime.now().millisecondsSinceEpoch}';

    // 기본 마커 아이콘
    BitmapDescriptor markerIcon = BitmapDescriptor.defaultMarkerWithHue(
      BitmapDescriptor.hueViolet,
    );

    // 유튜브 링크가 있는 경우 썸네일을 마커 아이콘으로 사용
    if (markerInfo.youtubeLink != null && markerInfo.youtubeLink!.isNotEmpty) {
      // 유튜브 비디오 ID 추출
      String? videoId = YoutubeService.extractYoutubeVideoId(
        markerInfo.youtubeLink,
      );
      if (videoId != null) {
        // 썸네일 URL 생성
        String thumbnailUrl = YoutubeService.getYoutubeThumbnailUrl(videoId);

        // 썸네일을 마커 아이콘으로 변환
        markerIcon = await YoutubeService.getBitmapDescriptorFromNetworkImage(
          thumbnailUrl,
        );

        // 썸네일 URL을 마커 정보에 저장
        markerInfo = CustomMarkerInfo(
          title: markerInfo.title,
          description: markerInfo.description,
          imageUrl: thumbnailUrl,
          youtubeLink: markerInfo.youtubeLink,
        );
      }
    }

    final Marker marker = Marker(
      markerId: MarkerId(markerId),
      position: position,
      icon: markerIcon,
      onTap: () {
        setState(() {
          selectedMarkerInfo = markerInfo;
          showInfoWindow = true;
          infoWindowPosition = position;
          selectedMarkerId = markerId;
        });
      },
    );

    setState(() {
      markers.add(marker);
      selectedMarkerInfo = markerInfo;
      showInfoWindow = true;
      infoWindowPosition = position;
    });

    // Firestore에 마커 저장
    try {
      await markerService.saveMarkerToFirestore(
        markerId,
        position,
        markerInfo,
        isPrivate: isPrivate,
        privatePw: privatePw,
      );
      markerOwners[markerId] = currentUser!.uid;
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('마커 저장 중 오류가 발생했습니다: $e')));
    }
  }

  @override
  Future<void> loadMarkersFromFirestore() async {
    try {
      final docs = await markerService.loadMarkersFromFirestore();

      // 범위 내에 있는 마커만 필터링
      final filteredDocs = docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final double latitude = data['latitude'] ?? 0.0;
        final double longitude = data['longitude'] ?? 0.0;
        final LatLng markerPosition = LatLng(latitude, longitude);
        return markerService.isMarkerWithinRange(
          currentPosition,
          markerPosition,
          searchRadius,
        );
      }).toList();

      // 현재 위치 마커를 제외한 모든 마커 삭제
      final newMarkers = <Marker>{};
      newMarkers.addAll(
        markers.where((marker) => marker.markerId.value == 'currentLocation'),
      );
      markerOwners.clear();

      final newMarkerOwners = <String, String>{};

      // Firestore에서 가져온 마커 중 범위 내 마커만 추가
      for (var doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        final markerId = doc.id;
        final double latitude = data['latitude'] ?? 0.0;
        final double longitude = data['longitude'] ?? 0.0;
        final LatLng markerPosition = LatLng(latitude, longitude);
        final String ownerId = data['ownerId'] ?? '';
        final String imageUrl = data['imageUrl'] ?? '';

        // 범위 내에 있는 마커만 추가
        if (markerService.isMarkerWithinRange(
          currentPosition,
          markerPosition,
          searchRadius,
        )) {
          // 소유자 정보 저장
          markerOwners[markerId] = ownerId;

          Future<void> createMarker() async {
            BitmapDescriptor icon;
            if (imageUrl.isNotEmpty) {
              icon = await YoutubeService.getBitmapDescriptorFromNetworkImage(
                imageUrl,
              );
            } else {
              icon = BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueViolet,
              );
            }

            markers.add(
              Marker(
                markerId: MarkerId(markerId),
                position: markerPosition,
                icon: icon,
                zIndexInt: 0,
                onTap: () {
                  setState(() {
                    selectedMarkerInfo = CustomMarkerInfo(
                      title: data['title'] ?? '',
                      description: data['description'] ?? '',
                      imageUrl: imageUrl,
                      youtubeLink: data['youtubeLink'],
                    );
                    showInfoWindow = true;
                    infoWindowPosition = markerPosition;
                    selectedMarkerId = markerId;
                  });
                },
              ),
            );
          }

          // 반드시 비동기로 실행
          await createMarker();
        }
      }
    } catch (e) {
      print('마커 로드 오류: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('마커 로드 중 오류가 발생했습니다: $e')));
    }

    await addLiveRoomMarkers();
    setState(() {});
  }

  Future<void> _loadNearbyPlaces() async {
    if (_isLoadingPlaces) return; // 중복 호출 방지

    setState(() => _isLoadingPlaces = true);

    try {
      final places = await GooglePlacesService.getNearbyPlaces(
        location: currentPosition,
        radius: searchRadius,
      );

      setState(() {
        _nearbyPlaces = places;
      });

      if (_showPlaceMarkers) {
        await _addPlaceMarkers();
      }

      await _loadExistingPlaceMarkers();
    } catch (e) {
      print('Error loading nearby places: $e');
    } finally {
      setState(() => _isLoadingPlaces = false);
    }
  }

  Future<void> _addPlaceMarkers() async {
    final placeMarkers = <Marker>{};

    for (final place in _nearbyPlaces) {
      final markerPosition = LatLng(place.latitude, place.longitude);

      if (markerService.isMarkerWithinRange(
        currentPosition,
        markerPosition,
        searchRadius,
      )) {
        placeMarkers.add(
          Marker(
            markerId: MarkerId('place_${place.id}'),
            position: LatLng(place.latitude, place.longitude),
            icon: await BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueOrange,
            ),
            onTap: () => _onPlaceMarkerTapped(place),
          ),
        );
      }
    }

    setState(() {
      markers.addAll(placeMarkers);
    });
  }

  Future<void> _loadExistingPlaceMarkers() async {
    try {
      final docs = await _placeMarkerService.getPlaceMarkersInRange(
        center: currentPosition,
        radiusInMeters: searchRadius,
      );

      final musicMarkers = <Marker>{};

      for (final doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        final lat = data['latitude'] ?? 0.0;
        final lng = data['longitude'] ?? 0.0;

        // PlaceModel 생성 시 photoUrl 필드명 수정
        final place = PlaceModel(
          id: data['placeId'] ?? doc.id, // placeId 사용
          name: data['placeName'] ?? '음악이 추가된 장소',
          address: data['placeAddress'] ?? '',
          latitude: lat,
          longitude: lng,
          rating: (data['placeRating'] ?? 0.0).toDouble(),
          photoReference: data['photoReference'], // photoUrl이 아닌 photoReference
          types: (data['types'] as List<dynamic>?)?.cast<String>() ?? [],
        );

        print("name : ");
        print(place.name);

        musicMarkers.add(
          Marker(
            markerId: MarkerId('place_music_${doc.id}'),
            position: LatLng(lat, lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueOrange,
            ),
            onTap: () => _onPlaceMarkerTapped(place),
          ),
        );
      }

      setState(() {
        markers.addAll(musicMarkers);
      });
    } catch (e) {
      print('Place music markers 로딩 오류: $e');
    }
  }

  void _onPlaceMarkerTapped(PlaceModel place) {
    setState(() {
      _selectedPlace = place;
      _showSidePanel = true;
    });

    print("place marker tapped");
  }

  void _closeSidePanel() {
    setState(() {
      _showSidePanel = false;
      _selectedPlace = null;
    });

    print("place marker closed");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 구글 맵
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
                  onMapCreated: onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: currentPosition,
                    zoom: 15.0,
                  ),
                  markers: markers,
                  circles: circles,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  onTap: (LatLng position) {
                    // 지도를 탭하면 사이드 패널 닫기
                    if (_showSidePanel) {
                      _closeSidePanel();
                    }
                    onMapTapped(position);
                  },
                ),

          Positioned(
            top: 200,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'togglePlaces',
              backgroundColor: _showPlaceMarkers ? Colors.blue : Colors.grey,
              onPressed: () async {
                setState(() {
                  _showPlaceMarkers = !_showPlaceMarkers;
                });

                if (_showPlaceMarkers) {
                  if (_nearbyPlaces.isEmpty) {
                    await _loadNearbyPlaces();
                  } else {
                    await _addPlaceMarkers();
                  }
                } else {
                  markers.removeWhere(
                    (marker) => marker.markerId.value.startsWith('place_'),
                  );
                  setState(() {});

                  if (_showSidePanel) {
                    _closeSidePanel();
                  }
                }
              },
              child: _isLoadingPlaces
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.restaurant),
            ),
          ),

          // 범위 조절 컨트롤
          buildRangeControls(),

          if (_showSidePanel && _selectedPlace != null)
            Positioned(
              top: 0,
              right: 0,
              child: PlaceInfoSidePanel(
                place: _selectedPlace!,
                onClose: _closeSidePanel,
                onMusicAdded: (place, title, description, youtubeLink) {
                  _loadExistingPlaceMarkers(); // 마커 새로고침
                },
              ),
            ),

          // 정보 창
          if (showInfoWindow && selectedMarkerInfo != null)
            buildCustomInfoWindow(context),

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
                  MaterialPageRoute(
                    builder: (context) => const MyMarkersScreen(),
                  ),
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
                loadMarkersFromFirestore();
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
                getCurrentLocation(); // 위치 새로고침
                loadMarkersFromFirestore(); // 마커 새로고침
              },
            ),
          ),
        ],
      ),
    );
  }

  // 기존 구현을 그대로 사용
  @override
  Widget buildCustomInfoWindow(BuildContext context) {
    bool isOwner =
        currentUser != null &&
        selectedMarkerId != null &&
        markerOwners[selectedMarkerId] == currentUser!.uid;

    return FutureBuilder<List<DocumentSnapshot>>(
      future: Future.wait([
        markerService.markersCollection.doc(selectedMarkerId).get(),
        markerService.markersCollection
            .doc(selectedMarkerId)
            .collection('granted')
            .doc(currentUser!.uid)
            .get(),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final markerSnap = snapshot.data![0];
        final grantedSnap = snapshot.data![1];

        final markerData = markerSnap.data();
        bool isPrivateMarker = (markerData is Map<String, dynamic>)
            ? (markerData['isPrivate'] ?? false)
            : false;
        bool isAuthorized = grantedSnap.exists;

        // If the marker is private and the user is not the owner and not authorized, show password dialog
        if (isPrivateMarker && !isOwner && !isAuthorized) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            String enteredPassword = '';
            showDialog(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('비공개 마커'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('비밀번호를 입력하세요'),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: '비밀번호',
                        hintText: '마커 비밀번호 입력',
                      ),
                      obscureText: true,
                      onChanged: (value) => enteredPassword = value,
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        showInfoWindow = false;
                      });
                      Navigator.pop(dialogContext);
                    },
                    child: const Text('취소'),
                  ),
                  TextButton(
                    onPressed: () async {
                      final markerDoc = await markerService.markersCollection
                          .doc(selectedMarkerId)
                          .get();
                      final data = markerDoc.data();
                      final correctPassword = (data is Map<String, dynamic>)
                          ? data['privatePw']
                          : null;

                      if (enteredPassword == correctPassword) {
                        // Grant permission
                        await markerService.markersCollection
                            .doc(selectedMarkerId)
                            .collection('granted')
                            .doc(currentUser!.uid)
                            .set({});
                        Navigator.pop(dialogContext);
                        setState(
                          () {},
                        ); // Rebuild to refetch data and show info window
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(content: Text('비밀번호가 올바르지 않습니다.')),
                          );
                        }
                      }
                    },
                    child: const Text('확인'),
                  ),
                ],
              ),
            );
          });
          return const SizedBox.shrink(); // Don't show info window until authorized
        }

        // If the marker is public or the user is the owner or authorized, show the info window
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
                        selectedMarkerInfo!.title,
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
                          showInfoWindow = false;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (selectedMarkerInfo!.imageUrl.isNotEmpty)
                  Container(
                    height: 150,
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: NetworkImage(selectedMarkerInfo!.imageUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                Text(
                  selectedMarkerInfo!.description,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                if (selectedMarkerInfo!.youtubeLink != null &&
                    selectedMarkerInfo!.youtubeLink!.isNotEmpty)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('유튜브 재생'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () {
                      String? videoId = YoutubeService.extractYoutubeVideoId(
                        selectedMarkerInfo!.youtubeLink,
                      );
                      if (videoId != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                DropMusicYoutubeScreen(videoId: videoId),
                          ),
                        );
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('유효한 유튜브 링크가 아닙니다.')),
                          );
                        }
                      }
                    },
                  ),
                const SizedBox(height: 8),
                if (isOwner)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.edit),
                        label: const Text('수정'),
                        onPressed: () {
                          showEditMarkerDialog();
                        },
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.delete),
                        label: const Text('삭제'),
                        onPressed: () {
                          deleteCurrentMarker();
                        },
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void showAddMarkerDialog(LatLng position) {
    String title = '';
    String description = '';
    String youtubeLink = '';
    bool selectedPrivateMode = false;
    String privatePw = '';

    // Create a TextEditingController for the YouTube link TextField
    final youtubeLinkController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('이 위치에 음악 추가'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(labelText: '제목'),
                  onChanged: (value) {
                    setDialogState(() => title = value);
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
                    setDialogState(() => description = value);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller:
                      youtubeLinkController, // Use controller for autocomplete
                  decoration: const InputDecoration(
                    labelText: '유튜브 링크',
                    hintText: '링크 입력',
                    prefixIcon: Icon(Icons.music_note),
                  ),
                  onChanged: (value) {
                    setDialogState(() => youtubeLink = value);
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text('공개'),
                        value: false,
                        groupValue: selectedPrivateMode,
                        onChanged: (value) {
                          setDialogState(() => selectedPrivateMode = value!);
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text('비공개'),
                        value: true,
                        groupValue: selectedPrivateMode,
                        onChanged: (value) {
                          setDialogState(() => selectedPrivateMode = value!);
                        },
                      ),
                    ),
                  ],
                ),
                if (selectedPrivateMode)
                  TextField(
                    decoration: const InputDecoration(
                      labelText: '비밀번호',
                      hintText: '비공개 마커 비밀번호',
                    ),
                    obscureText: true,
                    onChanged: (value) {
                      setDialogState(() => privatePw = value);
                    },
                  ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.search),
                  label: const Text('유튜브에서 음악 검색'),
                  onPressed: () async {
                    // Store the navigator before async operation
                    final navigator = Navigator.of(dialogContext);
                    final result = await Navigator.push<Map<String, dynamic>>(
                      dialogContext,
                      MaterialPageRoute(
                        builder: (_) => SearchYoutubeScreen(
                          onVideoTap: (String videoId, String title) {
                            navigator.pop({'videoId': videoId, 'title': title});
                          },
                        ),
                        fullscreenDialog: true,
                      ),
                    );

                    // Check if the widget is still mounted before proceeding
                    if (!mounted) return;

                    // Update the YouTube link and title, and reflect in TextField
                    if (result != null && result['videoId'] != null) {
                      setDialogState(() {
                        youtubeLink =
                            'https://www.youtube.com/watch?v=${result['videoId']}';
                        title = result['title'];
                        youtubeLinkController.text =
                            youtubeLink; // Update TextField
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                if (title.isNotEmpty) {
                  if (selectedPrivateMode && privatePw.isEmpty) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('비공개 마커는 비밀번호를 입력해야 합니다.'),
                        ),
                      );
                    }
                    return;
                  }
                  addCustomMarker(
                    position: position,
                    markerInfo: CustomMarkerInfo(
                      title: title,
                      description: description.isNotEmpty
                          ? description
                          : '설명 없음',
                      youtubeLink: youtubeLink.isNotEmpty ? youtubeLink : null,
                    ),
                    isPrivate: selectedPrivateMode,
                    privatePw: selectedPrivateMode ? privatePw : null,
                  );
                  Navigator.pop(dialogContext);
                } else if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('제목을 입력해주세요.')));
                }
              },
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      // Dispose of the controller when the dialog is closed
      youtubeLinkController.dispose();
    });
  }

  Future<void> addLiveRoomMarkers() async {
    BitmapDescriptor liveIcon = await BitmapDescriptor.asset(
      ImageConfiguration(size: Size(48, 48)),
      'images/live60.png',
    );

    final chatroomRepo = ChatroomRepository();
    final chatrooms = await chatroomRepo.getChatRooms();

    for (var chatroom in chatrooms) {
      GeoPoint hostLocation = chatroom['hostLocation'];
      LatLng hostLatLng = LatLng(hostLocation.latitude, hostLocation.longitude);
      if (markerService.isMarkerWithinRange(
        currentPosition,
        hostLatLng,
        searchRadius,
      )) {
        markers.add(
          Marker(
            markerId: MarkerId(chatroom['id']),
            position: hostLatLng,
            icon: liveIcon,
            zIndexInt: 1,
            onTap: () async {
              final refresh = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      LiveStreamingRoomScreen(roomRef: chatroom['ref']),
                ),
              );
              if (refresh == true) {
                loadMarkersFromFirestore();
                setState(() {});
              }
            },
          ),
        );
      }
    }
  }

  @override
  Widget buildRangeControls() {
    return Positioned(
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
                  '범위: ${(searchRadius / 1000).toStringAsFixed(1)}km',
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
                value: searchRadius,
                min: 100.0, // 최소 100m
                max: 2000.0, // 최대 2km
                divisions: 49,
                label: '${(searchRadius / 1000).toStringAsFixed(1)}km',
                onChanged: updateSearchRadius,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 범위 원 표시/숨김 토글 버튼
                IconButton(
                  icon: Icon(
                    showRangeCircle ? Icons.visibility : Icons.visibility_off,
                    size: 20,
                  ),
                  onPressed: toggleRangeCircle,
                  tooltip: showRangeCircle ? '범위 원 숨기기' : '범위 원 표시',
                ),
                // 빠른 범위 선택 버튼들
                TextButton(
                  onPressed: () => updateSearchRadius(500),
                  child: const Text('500m', style: TextStyle(fontSize: 12)),
                ),
                TextButton(
                  onPressed: () => updateSearchRadius(1000),
                  child: const Text('1km', style: TextStyle(fontSize: 12)),
                ),
                TextButton(
                  onPressed: () => updateSearchRadius(2000),
                  child: const Text('2km', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 범위 조절 메서드
  void updateSearchRadius(double newRadius) {
    setState(() {
      searchRadius = newRadius;
    });
    addRangeCircle(); // 원 업데이트
    loadMarkersFromFirestore(); // 마커 다시 로드
  }

  // 범위 원 표시/숨김 토글
  void toggleRangeCircle() {
    setState(() {
      showRangeCircle = !showRangeCircle;
      if (!showRangeCircle) {
        circles.clear();
      } else {
        addRangeCircle();
      }
    });
  }

  // 마커 추가 다이얼로그 표시
  Future<void> showEditMarkerDialog() async {
    if (selectedMarkerInfo == null || selectedMarkerId == null) return;

    // Assume markerData is fetched from Firestore with isPrivate and privatePw
    final markerData =
        (await markerService.markersCollection.doc(selectedMarkerId).get())
            .data();
    bool isPrivate = (markerData is Map<String, dynamic>)
        ? (markerData['isPrivate'] ?? false)
        : false;

    if (isPrivate) {
      String enteredPassword = '';
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('비공개 마커'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('비밀번호를 입력하세요'),
              const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(
                  labelText: '비밀번호',
                  hintText: '마커 비밀번호 입력',
                ),
                obscureText: true,
                onChanged: (value) => enteredPassword = value,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                final markerDoc = await markerService.markersCollection
                    .doc(selectedMarkerId)
                    .get();
                final data = markerDoc.data();
                final correctPassword = (data is Map<String, dynamic>)
                    ? data['privatePw']
                    : null;

                if (enteredPassword == correctPassword) {
                  Navigator.pop(context);
                  _showEditMarkerFormDialog();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('비밀번호가 올바르지 않습니다.')),
                  );
                }
              },
              child: const Text('확인'),
            ),
          ],
        ),
      );
    } else {
      _showEditMarkerFormDialog();
    }
  }

  void deleteCurrentMarker() async {
    if (selectedMarkerId == null) return;

    // 마커가 사용자 소유인지 확인
    bool isOwner =
        currentUser != null &&
        markerOwners[selectedMarkerId] == currentUser!.uid;

    if (!isOwner) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('자신이 생성한 마커만 삭제할 수 있습니다.')));
      return;
    }

    // 삭제 확인 다이얼로그
    bool confirmDelete =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('마커 삭제'),
            content: const Text('이 마커를 정말 삭제하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('삭제'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmDelete) return;

    try {
      // Firestore에서 마커 삭제
      await markerService.deleteMarkerFromFirestore(selectedMarkerId!);

      // 로컬 상태 업데이트
      setState(() {
        markers.removeWhere(
          (marker) => marker.markerId.value == selectedMarkerId,
        );
        markerOwners.remove(selectedMarkerId);
        showInfoWindow = false;
        selectedMarkerId = null;
        selectedMarkerInfo = null;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('마커가 삭제되었습니다.')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('마커 삭제 중 오류가 발생했습니다: $e')));
    }
  }

  // 유튜브 검색 결과로 마커 추가 다이얼로그
  void showAddMarkerDialogWithYoutube(
    LatLng position,
    String videoId,
    String videoTitle,
  ) {
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
              Image.network(YoutubeService.getYoutubeThumbnailUrl(videoId)),
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
                addCustomMarker(
                  position: position,
                  markerInfo: CustomMarkerInfo(
                    title: title,
                    description: description.isNotEmpty ? description : '설명 없음',
                    youtubeLink: youtubeLink,
                  ),
                );
              } else {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('제목을 입력해주세요.')));
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

  void _showEditMarkerFormDialog() async {
    String title = selectedMarkerInfo!.title;
    String description = selectedMarkerInfo!.description;
    String youtubeLink = selectedMarkerInfo!.youtubeLink ?? '';
    String privatePw = '';

    // Fetch isPrivate value from Firestore
    bool initialIsPrivate = false;
    final docSnapshot = await markerService.markersCollection
        .doc(selectedMarkerId)
        .get();
    final data = docSnapshot.data();
    if (data != null &&
        (data is Map<String, dynamic>) &&
        data['isPrivate'] != null) {
      initialIsPrivate = data['isPrivate'];
    }

    await showDialog(
      context: context,
      builder: (context) {
        bool isPrivate = initialIsPrivate;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('정보 수정'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(labelText: '제목'),
                    controller: TextEditingController(text: title),
                    onChanged: (value) => title = value,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: '설명',
                      alignLabelWithHint: true,
                    ),
                    controller: TextEditingController(text: description),
                    maxLines: 3,
                    onChanged: (value) => description = value,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: '유튜브 링크',
                      hintText: '링크 입력',
                      prefixIcon: Icon(Icons.music_note),
                    ),
                    controller: TextEditingController(text: youtubeLink),
                    onChanged: (value) => youtubeLink = value,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<bool>(
                          title: const Text('공개'),
                          value: false,
                          groupValue: isPrivate,
                          onChanged: (value) {
                            setDialogState(() => isPrivate = value!);
                          },
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<bool>(
                          title: const Text('비공개'),
                          value: true,
                          groupValue: isPrivate,
                          onChanged: (value) {
                            setDialogState(() => isPrivate = value!);
                          },
                        ),
                      ),
                    ],
                  ),
                  if (isPrivate)
                    TextField(
                      decoration: const InputDecoration(
                        labelText: '비밀번호',
                        hintText: '비공개 마커 비밀번호',
                      ),
                      obscureText: true,
                      onChanged: (value) => privatePw = value,
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () async {
                  if (title.isNotEmpty) {
                    if (isPrivate && privatePw.isEmpty) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('비공개 마커는 비밀번호를 입력해야 합니다.'),
                          ),
                        );
                      }
                      return;
                    }
                    final updatedInfo = CustomMarkerInfo(
                      title: title,
                      description: description.isNotEmpty
                          ? description
                          : '설명 없음',
                      imageUrl: selectedMarkerInfo!.imageUrl,
                      youtubeLink: youtubeLink.isNotEmpty ? youtubeLink : null,
                    );

                    if (mounted) {
                      setState(() {
                        selectedMarkerInfo = updatedInfo;
                      });
                    }

                    if (selectedMarkerId != null) {
                      try {
                        await markerService.updateMarkerInFirestore(
                          selectedMarkerId!,
                          updatedInfo,
                          isPrivate: isPrivate,
                          privatePw: isPrivate ? privatePw : null,
                        );
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('마커 업데이트 중 오류가 발생했습니다: $e')),
                          );
                        }
                      }
                    }

                    if (mounted) {
                      Navigator.pop(dialogContext);
                      loadMarkersFromFirestore();
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('제목을 입력해주세요.')),
                      );
                    }
                  }
                },
                child: const Text('저장'),
              ),
            ],
          ),
        );
      },
    );
  }
}
