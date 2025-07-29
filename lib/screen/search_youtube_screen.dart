import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'drop_music_screen_youtube.dart';
import 'package:muse_mate/config/api_config.dart'; // Import the config file

class SearchYoutubeScreen extends StatefulWidget {
  final void Function(String, String)? onVideoTap;
  const SearchYoutubeScreen({super.key, this.onVideoTap});

  @override
  State<SearchYoutubeScreen> createState() => _SearchYoutubeScreenState();
}

class _SearchYoutubeScreenState extends State<SearchYoutubeScreen> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> results = [];
  bool isLoading = false;

  Future<void> searchYouTube(String query) async {
    setState(() {
      isLoading = true;
      results = [];
    });

    final url = Uri.parse(
      'https://www.googleapis.com/youtube/v3/search'
      '?part=snippet&type=video&videoCategoryId=10&maxResults=10&q=${Uri.encodeComponent(query)}&key=${ApiConfig.youtubeApiKey}',
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final items = data['items'] as List;

      setState(() {
        results = items.map((item) {
          final snippet = item['snippet'];
          final videoId = item['id']['videoId'];
          return {
            'videoId': videoId,
            'title': snippet['title'],
            'thumbnail': snippet['thumbnails']['default']['url'],
          };
        }).toList();
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
      print('검색 실패: ${response.body}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('검색')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: '검색어를 입력하세요',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => searchYouTube(_controller.text),
                ),
              ),
              onSubmitted: (value) => searchYouTube(value),
            ),
            const SizedBox(height: 16),
            if (isLoading)
              const CircularProgressIndicator()
            else
              Expanded(
                child: ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final item = results[index];
                    return ListTile(
                      leading: Image.network(item['thumbnail'] ?? ''),
                      title: Text(item['title'] ?? ''),
                      subtitle: Text('videoId: ${item['videoId']}'),
                      onTap: () {
                        if (widget.onVideoTap != null) {
                          widget.onVideoTap!(item['videoId'], item['title']);
                        }

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DropMusicYoutubeScreen(
                              videoId: item['videoId'],
                            ),
                          ),
                        );

                        Navigator.pop(context, {
                          'videoId': item['videoId'],
                          'title': item['title'],
                          'thumbnail': item['thumbnail'],
                        });
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
