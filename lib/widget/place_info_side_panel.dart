import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:muse_mate/screen/youtube_search/drop_music_screen_youtube.dart';
import '../models/place_model.dart';
import 'package:muse_mate/service/google_places_service.dart';
import 'package:muse_mate/service/place_marker_service.dart';
import 'package:muse_mate/service/youtube_service.dart';
import 'package:muse_mate/screen/youtube_search/search_youtube_screen.dart';

class PlaceInfoSidePanel extends StatefulWidget {
  final PlaceModel place;
  final VoidCallback onClose;
  final Function(PlaceModel, String, String, String?) onMusicAdded;

  const PlaceInfoSidePanel({
    Key? key,
    required this.place,
    required this.onClose,
    required this.onMusicAdded,
  }) : super(key: key);

  @override
  State<PlaceInfoSidePanel> createState() => _PlaceInfoSidePanelState();
}

class _PlaceInfoSidePanelState extends State<PlaceInfoSidePanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  List<Map<String, dynamic>> _musicList = [];
  bool _isLoadingMusic = false;
  bool _showAddMusicForm = false;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String? _youtubeLink;

  @override
  void initState() {
    super.initState();

    // 슬라이드 애니메이션 설정
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0), // 오른쪽에서 시작
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
    _loadMusicForPlace();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadMusicForPlace() async {
    setState(() => _isLoadingMusic = true);

    try {
      final PlaceMarkerService placeMarkerService = PlaceMarkerService();
      final docs = await FirebaseFirestore.instance
          .collection('place_markers')
          .where('placeId', isEqualTo: widget.place.id)
          .get();

      final musicList = <Map<String, dynamic>>[];

      for (final doc in docs.docs) {
        final data = doc.data();
        data['docId'] = doc.id;
        musicList.add(data);
      }

      setState(() {
        _musicList = musicList;
      });
    } catch (e) {
      print('음악 목록 로딩 오류: $e');
    } finally {
      setState(() => _isLoadingMusic = false);
    }
  }

  Future<void> _closePanel() async {
    await _animationController.reverse();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        width: 400,
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(-2, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            // 헤더
            _buildHeader(),

            // 메인 컨텐츠 (스크롤 가능)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 플레이스 이미지
                    _buildPlaceImage(),

                    const SizedBox(height: 16),

                    // 플레이스 기본 정보
                    _buildPlaceInfo(),

                    const SizedBox(height: 24),

                    // 음악 추가 버튼
                    _buildAddMusicButton(),

                    const SizedBox(height: 16),

                    // 음악 추가 폼 (조건부 표시)
                    if (_showAddMusicForm) _buildAddMusicForm(),

                    const SizedBox(height: 24),

                    // 음악 목록 섹션
                    _buildMusicSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.place, color: Colors.blue, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.place.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: _closePanel,
            icon: const Icon(Icons.close),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceImage() {
    if (widget.place.photoReference == null) {
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.image_not_supported,
          size: 64,
          color: Colors.grey,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        GooglePlacesService.getPhotoUrl(
          widget.place.photoReference!,
          maxWidth: 800,
        ),
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.error,
              size: 64,
              color: Colors.grey,
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlaceInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 주소
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, size: 20, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.place.address,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 평점
          if (widget.place.rating > 0)
            Row(
              children: [
                const Icon(Icons.star, size: 20, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  '${widget.place.rating.toStringAsFixed(1)} ⭐',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

          const SizedBox(height: 12),

          // 카테고리
          if (widget.place.types.isNotEmpty)
            Wrap(
              spacing: 8,
              children: widget.place.types.take(3).map((type) {
                return Chip(
                  label: Text(
                    _translatePlaceType(type),
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: Colors.blue[100],
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildAddMusicButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          setState(() {
            _showAddMusicForm = !_showAddMusicForm;
          });
        },
        icon: Icon(_showAddMusicForm ? Icons.expand_less : Icons.add),
        label: Text(_showAddMusicForm ? '취소' : '이 장소에 음악 추가'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildAddMusicForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: '음악 제목',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.music_note),
            ),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: '설명 (선택사항)',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 2,
          ),

          const SizedBox(height: 12),

          TextField(
            decoration: const InputDecoration(
              labelText: 'YouTube 링크 (선택사항)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.link),
            ),
            onChanged: (value) => _youtubeLink = value.isEmpty ? null : value,
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _showAddMusicForm = false;
                      _titleController.clear();
                      _descriptionController.clear();
                      _youtubeLink = null;
                    });
                  },
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveMusicToPlace,
                  child: const Text('저장'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMusicSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.queue_music, color: Colors.green),
            const SizedBox(width: 8),
            Text(
              '공유된 음악 (${_musicList.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        if (_isLoadingMusic)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_musicList.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Column(
                children: [
                  Icon(Icons.music_off, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text(
                    '아직 공유된 음악이 없습니다.\n첫 번째 음악을 추가해보세요!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _musicList.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _buildMusicCard(_musicList[index]);
            },
          ),
      ],
    );
  }

  Widget _buildMusicCard(Map<String, dynamic> musicData) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 음악 제목과 YouTube 썸네일
          Row(
            children: [
              // YouTube 썸네일 (있는 경우)
              if (musicData['youtubeLink'] != null)
                Container(
                  width: 60,
                  height: 60,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: NetworkImage(
                        YoutubeService.getYoutubeThumbnailUrl(
                          YoutubeService.extractYoutubeVideoId(
                            musicData['youtubeLink'],
                          ) ?? '',
                        ),
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                Container(
                  width: 60,
                  height: 60,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.music_note, color: Colors.grey),
                ),

              // 음악 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      musicData['musicTitle'] ?? '제목 없음',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 4),

                    if (musicData['musicDescription'] != null &&
                        musicData['musicDescription'].toString().isNotEmpty)
                      Text(
                        musicData['musicDescription'],
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 액션 버튼들
          Row(
            children: [
              if (musicData['youtubeLink'] != null)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final videoId = YoutubeService.extractYoutubeVideoId(
                        musicData['youtubeLink'],
                      );
                      if (videoId != null) {
                        // YouTube 플레이어로 이동
                        _playYouTubeVideo(videoId);
                      }
                    },
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('재생'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),

              if (musicData['youtubeLink'] != null) const SizedBox(width: 8),

              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // 상세 정보 보기 또는 공유 기능
                  },
                  icon: const Icon(Icons.info_outline, size: 18),
                  label: const Text('상세'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _saveMusicToPlace() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('음악 제목을 입력해주세요.')),
      );
      return;
    }

    try {
      final placeMarkerService = PlaceMarkerService();
      await placeMarkerService.savePlaceMarker(
        place: widget.place,
        musicTitle: _titleController.text.trim(),
        musicDescription: _descriptionController.text.trim(),
        youtubeLink: _youtubeLink,
      );

      widget.onMusicAdded(
        widget.place,
        _titleController.text.trim(),
        _descriptionController.text.trim(),
        _youtubeLink,
      );

      // 폼 초기화
      setState(() {
        _showAddMusicForm = false;
        _titleController.clear();
        _descriptionController.clear();
        _youtubeLink = null;
      });

      // 음악 목록 새로고침
      await _loadMusicForPlace();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('음악이 추가되었습니다!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    }
  }

  void _playYouTubeVideo(String videoId) {
    // YouTube 플레이어로 이동
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DropMusicYoutubeScreen(videoId: videoId),
      ),
    );
  }

  String _translatePlaceType(String type) {
    const typeMap = {
      'restaurant': '음식점',
      'cafe': '카페',
      'bar': '바',
      'night_club': '클럽',
      'amusement_park': '놀이공원',
      'shopping_mall': '쇼핑몰',
      'store': '상점',
      'food': '음식',
      'establishment': '시설',
    };
    return typeMap[type] ?? type;
  }
}
