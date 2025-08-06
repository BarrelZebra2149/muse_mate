import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:muse_mate/models/video_model.dart';
import 'package:muse_mate/repository/chatroom_repository.dart';

class MyPlayList extends StatelessWidget {

  MyPlayList({
    super.key,
    required this.roomRef,
    required this.currentVideo,
    required this.onRemove,
  });

  final chatroomRepo = ChatroomRepository();
  final dynamic roomRef;
  VideoModel? currentVideo;
  final void Function(int, VideoModel) onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200, // Fixed height for scrollable playlist
      child: StreamBuilder<DocumentSnapshot>(
        stream: chatroomRepo.getChatroomSnapshot(roomRef),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          dynamic chatroomData = snapshot.data!.data();
          final List playlistRefs = chatroomData['playlist'];

          if (playlistRefs.isEmpty) {
            return const Center(child: Text('재생목록이 비어 있습니다.'));
          }

          return FutureBuilder<List<Map<String, dynamic>>>(
            future: Future.wait(
              chatroomRepo.getPlaylistVideos(playlistRefs)
            ),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final playlistVideos = snapshot.data!;
              
              return ListView.builder(
                itemCount: playlistVideos.length,
                itemBuilder: (context, index) {
                  final video = playlistVideos[index];
                  final isPlaying = video['videoRef'] == currentVideo?.videoRef;
                  return ListTile(
                    tileColor: isPlaying ? Colors.blue.withAlpha(51) : null,
                    title: Text(
                      video['title'] ?? 'Unknown Title',
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () {
                        onRemove(
                          index, 
                          VideoModel(
                            videoId: video['videoId'], 
                            title: video['title'], 
                            videoRef: video['videoRef'])
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
