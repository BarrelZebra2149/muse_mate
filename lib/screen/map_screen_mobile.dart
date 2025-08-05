import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:muse_mate/models/marker_model.dart';
import 'package:muse_mate/screen/drop_music_screen_youtube.dart';
import 'package:muse_mate/screen/map_screen_base.dart';
import 'package:muse_mate/screen/search_youtube_screen.dart';
import 'package:muse_mate/service/location_service.dart';
import 'package:muse_mate/service/youtube_service.dart';

class MapScreenMobile extends MapScreenBase {
  const MapScreenMobile({super.key});

  @override
  State<MapScreenMobile> createState() => _MapScreenMobileState();
}

class _MapScreenMobileState extends MapScreenBaseState<MapScreenMobile> {
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
    final hasPermission = await LocationService.handleLocationPermission(context);

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
  Future<void> addCustomMarker({required LatLng position, required CustomMarkerInfo markerInfo}) async {
    // 범위 내에 있는지 확인
    if (!markerService.isMarkerWithinRange(currentPosition, position, searchRadius)) {
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
      String? videoId = YoutubeService.extractYoutubeVideoId(markerInfo.youtubeLink);
      if (videoId != null) {
        // 썸네일 URL 생성
        String thumbnailUrl = YoutubeService.getYoutubeThumbnailUrl(videoId);

        // 썸네일을 마커 아이콘으로 변환
        markerIcon = await YoutubeService.getBitmapDescriptorFromNetworkImage(thumbnailUrl);

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('마커 저장 중 오류가 발생했습니다: $e')),
      );
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
        currentPosition, markerPosition, searchRadius
      );
    }).toList();
    
    // 현재 위치 마커를 제외한 모든 마커 삭제
    final newMarkers = <Marker>{};
    newMarkers.addAll(
      markers.where((marker) => marker.markerId.value == 'currentLocation')
    );
    
    final newMarkerOwners = <String, String>{};
    
    // 모든 마커 아이콘을 병렬로 로드
    final markerFutures = filteredDocs.map((doc) async {
      final data = doc.data() as Map<String, dynamic>;
      final markerId = doc.id;
      final double latitude = data['latitude'] ?? 0.0;
      final double longitude = data['longitude'] ?? 0.0;
      final LatLng markerPosition = LatLng(latitude, longitude);
      final String ownerId = data['ownerId'] ?? '';
      final String imageUrl = data['imageUrl'] ?? '';
      
      // 소유자 정보 저장
      newMarkerOwners[markerId] = ownerId;
      
      // 마커 아이콘 생성
      BitmapDescriptor icon;
      if (imageUrl.isNotEmpty) {
        icon = await YoutubeService.getBitmapDescriptorFromNetworkImage(imageUrl);
      } else {
        icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
      }
      
      return Marker(
        markerId: MarkerId(markerId),
        position: markerPosition,
        icon: icon,
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
      );
    }).toList();
    
    // 모든 마커가 생성될 때까지 기다림
    final loadedMarkers = await Future.wait(markerFutures);
    
    // 한 번에 상태 업데이트
    setState(() {
      newMarkers.addAll(loadedMarkers);
      markers = newMarkers;
      markerOwners.clear();
      markerOwners.addAll(newMarkerOwners);
    });
  } catch (e) {
    print('마커 로드 오류: $e');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('마커 로드 중 오류가 발생했습니다: $e')));
  }
}

  @override
  void showAddMarkerDialog(LatLng position) {
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
                    description: description.isNotEmpty ? description : '설명 없음',
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
    );
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
            // 유튜브 링크가 있을 경우 재생 버튼 추가
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
                  // 유튜브 동영상 ID 추출
                  String? videoId = YoutubeService.extractYoutubeVideoId(
                    selectedMarkerInfo!.youtubeLink,
                  );
                  if (videoId != null) {
                    // 유튜브 플레이어 화면으로 이동
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            DropMusicYoutubeScreen(videoId: videoId),
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
                      showEditMarkerDialog();
                    },
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.delete),
                    label: const Text('삭제'),
                    onPressed: () {
                      // 마커 삭제 기능 구현
                      deleteCurrentMarker();
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
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
                    showRangeCircle
                        ? Icons.visibility
                        : Icons.visibility_off,
                    size: 20,
                  ),
                  onPressed: toggleRangeCircle,
                  tooltip: showRangeCircle ? '범위 원 숨기기' : '범위 원 표시',
                ),
                // 빠른 범위 선택 버튼들
                TextButton(
                  onPressed: () => updateSearchRadius(500),
                  child: const Text(
                    '500m',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: () => updateSearchRadius(1000),
                  child: const Text(
                    '1km',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: () => updateSearchRadius(2000),
                  child: const Text(
                    '2km',
                    style: TextStyle(fontSize: 12),
                  ),
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
  void showEditMarkerDialog() {
    // 현재 마커 정보 가져오기
    String title = selectedMarkerInfo!.title;
    String description = selectedMarkerInfo!.description;
    String youtubeLink = selectedMarkerInfo!.youtubeLink ?? ''; // 유튜브 링크 가져오기

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
    );
  }

  void deleteCurrentMarker() async {
    if (selectedMarkerId == null) return;

    // 마커가 사용자 소유인지 확인
    bool isOwner = currentUser != null &&
        markerOwners[selectedMarkerId] == currentUser!.uid;

    if (!isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('자신이 생성한 마커만 삭제할 수 있습니다.')),
      );
      return;
    }

    // 삭제 확인 다이얼로그
    bool confirmDelete = await showDialog(
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
    ) ?? false;

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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('마커가 삭제되었습니다.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('마커 삭제 중 오류가 발생했습니다: $e')),
      );
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
              Image.network(
                YoutubeService.getYoutubeThumbnailUrl(videoId),
              ),
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
}