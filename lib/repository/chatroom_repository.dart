import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:muse_mate/models/video_model.dart';

class ChatroomRepository {
  // firestore 컬렉션 이름
  final String chatrooms = 'chatroomList';
  final String chatroomMessages = 'messages';
  final String songs = 'songs';

  final FirebaseFirestore firestore = FirebaseFirestore.instance;


  Stream<QuerySnapshot<Map<String, dynamic>>> getChatroomListSnapshot() {
    return firestore.collection(chatrooms)
              .orderBy('createdAt', descending: true)
              .snapshots();
  }

  // 전체 채팅방 가져오기
  Future<List<Map<String, dynamic>>> getChatRooms() async {
    // 생성 최신순으로 가져오기
    final snapshot = await firestore
        .collection(chatrooms)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['ref'] = doc.reference;
      return data;
    }).toList();
  }

  // 채팅방 생성
  Future<dynamic> addChatroom(String roomName, User host) async {
    final roomRef = await firestore.collection(chatrooms).add({
      'roomName': roomName,
      'createdAt': FieldValue.serverTimestamp(),
      'hostUserId': host.uid,
      'playlist': [],
    });

    // 기본 메시지 추가
    await roomRef.collection(chatroomMessages).add({
      'text': '채팅방이 생성되었습니다.',
      'createdAt': FieldValue.serverTimestamp(),
      'userId': 'system',
    });

    return roomRef;
  }

  // 호스트라면 방 삭제 가능
  Future<void> deleteChatroomIfHost(DocumentReference roomRef) async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      print('current user is null');
      return;
    }
    dynamic snapshot = await roomRef.get();
    dynamic chatroomData = snapshot.data();
    
    if (currentUser.uid == chatroomData['hostUserId']) {
      final batch = firestore.batch();

      try {
        final messagesSnapshot = await roomRef.collection(chatroomMessages).get();
        for (final doc in messagesSnapshot.docs) {
          batch.delete(doc.reference);
        }

        final songsSnapshot = await roomRef.collection(songs).get();
        for (final doc in songsSnapshot.docs) {
          batch.delete(doc.reference);
        }

        batch.delete(roomRef);

        await batch.commit();
      }
      catch (e) {
        print('문서 삭제 중 오류 발생 : $e');
      }
    }
  }


  // 문서 id가 chatRoomId인 채팅방 문서 snapshot 가져오기
  Stream<DocumentSnapshot<Map<String, dynamic>>> getChatroomSnapshot(
    dynamic roomRef,
  ) {
    return roomRef.snapshots();
  }

  // 현재 재생중인 비디오 정보 가져오기
  Future<VideoModel?> getNowPlayingVideo(dynamic roomRef) async {
    final chatroom = await roomRef.get();
    final chatroomData = chatroom.data();

    List playlist = chatroomData?['playlist'];

    if (playlist.isEmpty) {
      return null;
    }

    final videoRef = playlist.first;

    final video = await (videoRef as DocumentReference).get();
    final videoData = video.data() as Map<String, dynamic>;

    return VideoModel(
      videoId: videoData['videoId'],
      title: videoData['title'],
      videoRef: videoRef,
    );
  }

  // 플레이리스트 가져오기
  List<Future<Map<String, dynamic>>> getPlaylistVideos(
    List<dynamic> playlistRefs,
  ) {
    return playlistRefs.map((videoRef) async {
      final videoDoc = await (videoRef).get();
      final video = videoDoc.data() as Map<String, dynamic>?;
      return {
        'videoRef': videoRef,
        'title': video?['title'] ?? 'Unknown Title',
        'videoId': video?['videoId'] ?? '',
      };
    }).toList();
  }

  Future<VideoModel?> playNextVideo(
    VideoModel? currentVideo,
    dynamic roomRef,
  ) async {
    if (currentVideo != null) {
      dynamic videoRef = currentVideo.videoRef;
      DocumentSnapshot video = await videoRef.get();

      // 이미 삭제되었는지 검사
      if (video.exists) {
        try {
          videoRef.delete();

          final snapshot = await roomRef.get();
          dynamic chatroomData = snapshot.data();
          List playlist = chatroomData['playlist'];

          playlist.removeAt(0);
          roomRef.update({
            'lastTrackChangedTime': DateTime.now(),
            'playlist': playlist,
          });

          return getVideo(playlist.first);
        } catch (e) {
          print("error deleting document: $e");
        }
      }
    }
    return getNowPlayingVideo(roomRef);
  }


  Future<VideoModel> getVideo(DocumentReference videoRef) async {
    DocumentSnapshot snapshot = await videoRef.get();

    dynamic video = snapshot.data();
    String videoId = video['videoId'];
    String title = video['title'];

    return VideoModel(videoId: videoId, title: title, videoRef: videoRef);
  }


  Future<double> getElapsedSecondsSinceLastTrack(dynamic roomRef) async {
    dynamic snapshot = await roomRef.get();

    dynamic chatroomData = snapshot.data();
    DateTime lastTrackChangedTime = chatroomData['lastTrackChangedTime']
        .toDate();

    final now = DateTime.now();
    final difference = now.difference(lastTrackChangedTime);

    return difference.inMilliseconds / 1000.0;
  }

  // 플레이리스트에 비디오 추가
  Future<int> addToPlaylist(
    VideoModel video,
    DocumentReference roomRef,
  ) async {
    // songs 컬렉션에 선택된 비디오의 id와 제목 저장
    final videoRef = await roomRef.collection(songs).add({
      'videoId': video.videoId,
      'title': video.title,
    });

    // chatroom 문서에 갱신할 새로운 데이터
    Map<String, dynamic> updateData = {
      'playlist': FieldValue.arrayUnion([videoRef]),
    };

    // 기존데이터. playlist에 아직 비디오가 없는 경우 시작시간을 갱신
    dynamic snapshot = await roomRef.get();
    dynamic roomData = snapshot.data();
    List playlist = roomData['playlist'];

    if (playlist.isEmpty) {
      updateData['lastTrackChangedTime'] = DateTime.now();
    }

    await roomRef.update(updateData);

    return playlist.length + 1;
  }

  Future<void> deleteFromPlaylist(
    VideoModel video,
    int index,
    DocumentReference roomRef,
  ) async {
    final snapshot = await roomRef.get();
    dynamic chatroomData = snapshot.data();

    // 두 명의 사용자가 동시에 삭제 수행 시 잘못된 동영상을 제거하지 않도록 문서id로 더블체크.
    List playlist = chatroomData['playlist'];
    if (playlist.isEmpty || playlist[index] != video.videoRef) return;

    // playlist 필드(array)에서 해당 레퍼런스 삭제, songs 컬렉션에서 해당 문서 삭제
    playlist.removeAt(index);
    await roomRef.update({'playlist': playlist});
    await (video.videoRef as DocumentReference).delete();
  }


  void addMessage(String message, dynamic roomRef) {
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null){
      roomRef.collection(chatroomMessages).add({
        'text': message,
        'createdAt': FieldValue.serverTimestamp(),
        'userId': currentUser.uid,
      });
    }
  }

}
