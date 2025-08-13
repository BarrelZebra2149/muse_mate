import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:muse_mate/models/marker_model.dart';
import 'package:muse_mate/repository/chatroom_repository.dart';
import 'package:muse_mate/screen/streaming/live_streaming_room_screen.dart';
import 'package:muse_mate/screen/streaming/streaming_music_screen.dart';
import 'package:muse_mate/screen/youtube_search/drop_music_screen_youtube.dart';
import 'package:muse_mate/screen/map/management_markers_screen.dart';
import 'package:muse_mate/screen/map/map_screen_base.dart';
import 'package:muse_mate/screen/youtube_search/search_youtube_screen.dart';
import 'package:muse_mate/service/location_service.dart';
import 'package:muse_mate/service/youtube_service.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

class MapScreenWeb extends MapScreenBase {
  const MapScreenWeb({super.key});

  @override
  State<MapScreenWeb> createState() => _MapScreenWebState();
}

class _MapScreenWebState extends MapScreenBaseState<MapScreenWeb> {
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

  // 지도 탭 이벤트 처리 - 웹 버전
  @override
  void onMapTapped(LatLng position) {
    // 정보 창이 열려 있으면 닫기
    if (showInfoWindow) {
      setState(() {
        showInfoWindow = false;
      });
      return;
    }

    // 클릭한 위치가 원 내부에 있는지 확인
    double distance = LocationService.calculateDistance(
      currentPosition,
      position,
    );

    // 탭한 위치가 원 내부인지 확인
    if (isPointInCircle(position, currentPosition, searchRadius)) {
      // 원 내부에 탭된 경우 마커 추가 다이얼로그 표시
      showAddMarkerDialog(position);
    } else {
      // 원 외부 탭 - 선택적으로 알림 표시
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('설정된 범위를 벗어난 위치입니다.')));
    }
  }

  @override
  Future<void> addCustomMarker({
    required LatLng position,
    required CustomMarkerInfo markerInfo,
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
          selectedMarkerInfo = markerInfo;
          showInfoWindow = true;
          infoWindowPosition = position;
          selectedMarkerId = markerId;
        });
      },
    );

    setState(() {
      markers.add(marker);

      // 마커 추가 후 바로 정보 창 표시
      selectedMarkerInfo = markerInfo;
      showInfoWindow = true;
      infoWindowPosition = position;
    });

    // Firestore에 마커 저장
    try {
      await markerService.saveMarkerToFirestore(markerId, position, markerInfo);
      // 소유자 정보 추가
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

      // 현재 위치 마커를 제외한 모든 마커 삭제
      markers.removeWhere(
            (marker) => marker.markerId.value != 'currentLocation',
      );
      markerOwners.clear();

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
        if (markerService.isMarkerWithinRange(currentPosition, markerPosition, searchRadius)) {
          // 소유자 정보 저장
          markerOwners[markerId] = ownerId;

          Future<void> createMarker() async {
            BitmapDescriptor icon;
            if (imageUrl.isNotEmpty) {
              icon = await YoutubeService.getBitmapDescriptorFromNetworkImage(imageUrl);
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

  @override
  void showAddMarkerDialog(LatLng position) {
    String title = '';
    String description = '';
    String youtubeLink = '';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => PointerInterceptor(
        child: AlertDialog(
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
                    labelText: '유튜브 링크',
                    hintText: '링크 입력',
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
                      MaterialPageRoute(
                        builder: (context) => const SearchYoutubeScreen(),
                      ),
                    );

                    // 선택한 유튜브 비디오 정보 받아오기
                    if (result != null && result is Map<String, dynamic>) {
                      Navigator.pop(context); // 현재 다이얼로그 닫기

                      // 새 다이얼로그 열기 (선택한 유튜브 정보로 미리 채워진)
                      showAddMarkerDialogWithYoutube(
                        position,
                        result['videoId'],
                        result['title'],
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
                  addCustomMarker(
                    position: position,
                    markerInfo: CustomMarkerInfo(
                      title: title,
                      description: description.isNotEmpty
                          ? description
                          : '설명 없음',
                      youtubeLink: youtubeLink.isNotEmpty ? youtubeLink : null,
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
      ),
    );
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
      builder: (context) => PointerInterceptor(
        child: AlertDialog(
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
                      description: description.isNotEmpty
                          ? description
                          : '설명 없음',
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
      ),
    );
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
      LatLng hostLatLng = LatLng(
        hostLocation.latitude,
        hostLocation.longitude,
      );
      if (markerService.isMarkerWithinRange(currentPosition, hostLatLng, searchRadius)) {
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
                  builder: (context) => LiveStreamingRoomScreen(roomRef: chatroom['ref']),
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
                  onTap: onMapTapped,
                ),

          // 범위 조절 컨트롤
          buildRangeControls(),

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

  @override
  Widget buildCustomInfoWindow(BuildContext context) {
    if (!showInfoWindow || selectedMarkerInfo == null) {
      return const SizedBox.shrink();
    }

    // 웹 환경에 맞는 정보창 크기 조정
    return Positioned(
      right: 20,
      top: 100,

      child: PointerInterceptor(
        child: Card(
          elevation: 5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            width: 320, // 정보창 너비 증가
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          showInfoWindow = false;
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      iconSize: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (selectedMarkerInfo!.imageUrl != null &&
                    selectedMarkerInfo!.imageUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      constraints: const BoxConstraints(
                        maxHeight: 180, // 이미지 최대 높이 설정
                      ),
                      child: AspectRatio(
                        aspectRatio: 16 / 9, // 유튜브 썸네일 비율 유지
                        child: Image.network(
                          selectedMarkerInfo!.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 150,
                              color: Colors.grey[300],
                              child: const Center(child: Icon(Icons.error)),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 150,
                              color: Colors.grey[200],
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  selectedMarkerInfo!.description,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                if (selectedMarkerInfo!.youtubeLink != null &&
                    selectedMarkerInfo!.youtubeLink!.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('유튜브에서 재생'),
                      onPressed: () {
                        // 올바른 클래스 이름으로 수정
                        final String? videoId =
                            YoutubeService.extractYoutubeVideoId(
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('유효하지 않은 유튜브 링크입니다')),
                          );
                        }
                      },
                    ),
                  ),
                if (selectedMarkerId != null &&
                    markerOwners.containsKey(selectedMarkerId) &&
                    markerOwners[selectedMarkerId] == currentUser?.uid)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.delete),
                        label: const Text('마커 수정'),
                        onPressed: () async {
                          await showEditMarkerDialog();
                        },
                      ),
                    ),
                  ),
                if (selectedMarkerId != null &&
                    markerOwners.containsKey(selectedMarkerId) &&
                    markerOwners[selectedMarkerId] == currentUser?.uid)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.delete),
                        label: const Text('마커 삭제'),
                        onPressed: () async {
                          await deleteCurrentMarker();
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget buildRangeControls() {
    return Positioned(
      top: 16,
      left: 16,
      child: PointerInterceptor(
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
      ),
    );
  }

  // 범위 원 추가 메서드
  void addRangeCircle() {
    setState(() {
      circles.clear();
      if (showRangeCircle && currentPosition != null) {
        circles.add(
          Circle(
            circleId: const CircleId('searchRange'),
            center: currentPosition,
            radius: searchRadius,
            fillColor: Colors.purple.withOpacity(0.2),
            strokeColor: Colors.purple,
            strokeWidth: 2,
          ),
        );
      }
    });
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

  // 마커 정보 수정 다이얼로그
  Future<void> showEditMarkerDialog() async {
    // 현재 마커 정보 가져오기
    String title = selectedMarkerInfo!.title;
    String description = selectedMarkerInfo!.description;
    String youtubeLink = selectedMarkerInfo!.youtubeLink ?? ''; // 유튜브 링크 가져오기

    showDialog(
      context: context,
      builder: (context) => PointerInterceptor(
        child: AlertDialog(
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
                    labelText: '유튜브 링크',
                    hintText: '링크 입력',
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
              onPressed: () async {
                if (title.isNotEmpty) {
                  final updatedInfo = CustomMarkerInfo(
                    title: title,
                    description: description.isNotEmpty ? description : '설명 없음',
                    imageUrl: selectedMarkerInfo!.imageUrl,
                    youtubeLink: youtubeLink.isNotEmpty ? youtubeLink : null,
                  );

                  setState(() {
                    selectedMarkerInfo = updatedInfo;
                  });

                  // Firestore 업데이트
                  if (selectedMarkerId != null) {
                    try {
                      await markerService.updateMarkerInFirestore(
                        selectedMarkerId!,
                        updatedInfo,
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('마커 업데이트 중 오류가 발생했습니다: $e')),
                      );
                    }
                  }

                  Navigator.pop(context);
                  loadMarkersFromFirestore();
                } else {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('제목을 입력해주세요.')));
                }
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  // 현재 선택된 마커 삭제 - 권한 확인 추가
  Future<void> deleteCurrentMarker() async {
    if (selectedMarkerId == null) return;

    // 선택된 마커의 ID 확인
    String? markerIdToDelete;
    String? markerOwnerId;

    // 현재 표시된 정보창의 마커 찾기
    for (var marker in markers) {
      if (marker.position.latitude == infoWindowPosition!.latitude &&
          marker.position.longitude == infoWindowPosition!.longitude &&
          marker.markerId.value != 'currentLocation') {
        markerIdToDelete = marker.markerId.value;
        markerOwnerId = markerOwners[markerIdToDelete];
        break;
      }
    }

    // 마커가 없거나 소유자가 아니면 삭제 불가
    if (markerIdToDelete == null ||
        currentUser == null ||
        markerOwnerId != currentUser!.uid) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('마커를 삭제할 권한이 없습니다.')));
      return;
    }

    // 삭제 확인 다이얼로그
    showDialog(
      context: context,
      builder: (context) => PointerInterceptor(
        child: AlertDialog(
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
              onPressed: () async {
                setState(() {
                  markers.removeWhere(
                    (marker) => marker.markerId.value == markerIdToDelete,
                  );
                  showInfoWindow = false;
                });

                // Firestore에서도 삭제
                try {
                  await markerService.deleteMarkerFromFirestore(
                    markerIdToDelete!,
                  );

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
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('마커 삭제 중 오류가 발생했습니다: $e')),
                  );
                }
                Navigator.pop(context);
              },
              child: const Text('삭제'),
            ),
          ],
        ),
      ),
    );
  }
}
