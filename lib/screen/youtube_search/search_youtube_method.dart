import 'dart:convert';
import 'package:http/http.dart' as http;

Future<List<Map<String, String>>> searchYouTube(String query, String apiKey) async {
  final url = Uri.parse(
    'https://www.googleapis.com/youtube/v3/search'
    '?part=snippet'
    '&type=video'
    '&maxResults=5'
    '&q=${Uri.encodeComponent(query)}'
    '&key=$apiKey',
  );

  final response = await http.get(url);

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    final items = data['items'] as List;

    // 결과에서 videoId, 제목 추출
    return items.map((item) {
      final id = item['id']['videoId'] as String;
      final title = item['snippet']['title'] as String;
      return {
        'videoId': id,
        'title': title,
      };
    }).toList();
  } else {
    throw Exception('검색 실패: ${response.body}');
  }
}
