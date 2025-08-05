import 'package:flutter/material.dart';

class MyPlayList extends StatelessWidget {
  const MyPlayList({
    super.key,
    required this.playlist,
    required this.currentVideoId,
    required this.onRemove,
  });

  final List<Map<String, dynamic>> playlist;
  final String currentVideoId;
  final void Function(int) onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200, // Fixed height for scrollable playlist
      child: ListView.builder(
        itemCount: playlist.length,
        itemBuilder: (context, index) {
          final video = playlist[index];
          final isPlaying = video['videoId'] == currentVideoId;
          return ListTile(
            tileColor: isPlaying ? Colors.blue.withAlpha(51) : null,
            title: Text(
              video['title'] ?? 'Unknown Title',
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: () => onRemove(index),
            ),
          );
        },
      ),
    );
  }
}
