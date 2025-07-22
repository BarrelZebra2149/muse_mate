import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SearchYoutubeScreen extends StatefulWidget {
  const SearchYoutubeScreen({super.key, required this.onVideoTap});
  final void Function(String) onVideoTap;

  @override
  State<SearchYoutubeScreen> createState() => _SearchYoutubeScreenState();
}

class _SearchYoutubeScreenState extends State<SearchYoutubeScreen> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> results = [];
  bool isLoading = false;
  String? videoId;

  final String apiKey = 'AIzaSyCruYkrDJ7pmSk6A6ZIgHutgHaiKxGu4vc'; // 당신의 YOUTUBE API 키를 여기에 입력하세요.

  Future<void> searchYouTube(String query) async {
    setState(() {
      isLoading = true;
      results = [];
    });

    final url = Uri.parse(
      'https://www.googleapis.com/youtube/v3/search'
      '?part=snippet&type=video&videoCategoryId=10&maxResults=10&q=${Uri.encodeComponent(query)}&key=$apiKey',
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
      appBar: AppBar(title: Text('검색')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: '검색어를 입력하세요',
                suffixIcon: IconButton(
                  icon: Icon(Icons.search),
                  onPressed: () => searchYouTube(_controller.text),
                ),
              ),
              onSubmitted: (value) => searchYouTube(value),
            ),
            const SizedBox(height: 16),
            if (isLoading)
              CircularProgressIndicator()
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
                      widget.onVideoTap(item['videoId']);
                    }
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
