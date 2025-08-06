// my_markers_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math'; // min 함수를 위한 임포트
import 'package:muse_mate/models/marker_model.dart';

class MyMarkersScreen extends StatefulWidget {
  const MyMarkersScreen({super.key});

  @override
  State<MyMarkersScreen> createState() => _MyMarkersScreenState();
}

class _MyMarkersScreenState extends State<MyMarkersScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CollectionReference markersCollection = FirebaseFirestore.instance.collection('markers');
  List<MarkerModel> myMarkers = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMyMarkers();
  }

  Future<void> _loadMyMarkers() async {
    setState(() {
      isLoading = true;
    });

    try {
      // 현재 사용자의 마커만 불러오기
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      final snapshot = await markersCollection
          .where('ownerId', isEqualTo: currentUser.uid)
          .get();

      final List<MarkerModel> loadedMarkers = [];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        loadedMarkers.add(MarkerModel.fromFirestore(data, doc.id));
      }

      setState(() {
        myMarkers = loadedMarkers;
        isLoading = false;
      });
    } catch (e) {
      print('마커 로드 오류: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _deleteMarker(String markerId) async {
    try {
      await markersCollection.doc(markerId).delete();
      setState(() {
        myMarkers.removeWhere((marker) => marker.id == markerId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('마커가 삭제되었습니다.')),
      );
    } catch (e) {
      print('마커 삭제 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('마커 삭제 중 오류가 발생했습니다: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 음악 마커 관리'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : myMarkers.isEmpty
              ? const Center(child: Text('등록한 마커가 없습니다.'))
              : ListView.builder(
                  itemCount: myMarkers.length,
                  itemBuilder: (context, index) {
                    final marker = myMarkers[index];
                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      child: ListTile(
                        leading: marker.imageUrl != null && marker.imageUrl!.isNotEmpty
                            ? Image.network(marker.imageUrl!)
                            : const Icon(Icons.music_note, size: 40),
                        title: Text(marker.title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(marker.description),
                            if (marker.youtubeLink != null)
                              Text('유튜브 링크: ${marker.youtubeLink!.substring(0, min(30, marker.youtubeLink!.length))}...'),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('마커 삭제'),
                                content: const Text('이 마커를 삭제하시겠습니까?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('취소'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _deleteMarker(marker.id);
                                    },
                                    child: const Text('삭제'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        onTap: () {
                          // 지도에서 해당 마커 위치로 이동하는 기능 추가 가능
                          Navigator.pop(context, {
                            'latitude': marker.latitude,
                            'longitude': marker.longitude,
                          });
                        },
                      ),
                    );
                  },
                ),
    );
  }
}