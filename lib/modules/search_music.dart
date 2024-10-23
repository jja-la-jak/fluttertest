import 'package:http/http.dart' as http;
import 'dart:convert';

Future<List<Music>> searchMusic(String query, {String type = 'title'}) async {
  // URL 인코딩 수정
  final encodedQuery = Uri.encodeQueryComponent(query);

  final response = await http.get(
    Uri.parse('https://gnumusic.shop/api/musics?query=$encodedQuery&type=$type'),
    headers: {
      'Content-Type': 'application/json; charset=UTF-8',
      'Accept': 'application/json',
      // headers: {'Authorization': 'Bearer $accessToken'},
    },
  );

  if (response.statusCode == 200) {
    final decodedBody = utf8.decode(response.bodyBytes);
    final jsonResponse = jsonDecode(decodedBody);

    if (jsonResponse['isSuccess']) {
      final musicList = jsonResponse['result'] as List;
      return musicList.map((music) => Music.fromJson(music)).toList();
    } else {
      print('Error Code: ${jsonResponse['code']}, Message: ${jsonResponse['message']}');
      throw Exception('API 에러: ${jsonResponse['message']}');
    }
  } else {
    print('HTTP Status Code: ${response.statusCode}');
    throw Exception('HTTP 에러: ${response.statusCode}');
  }
}

class Music {
  final int id;
  final String title;
  final String artist;
  final String url;
  final int viewCount;

  Music({
    required this.id,
    required this.title,
    required this.artist,
    required this.url,
    required this.viewCount
  });

  factory Music.fromJson(Map<String, dynamic> json) {
    return Music(
      id: json['id'],
      title: json['title'],
      artist: json['artist'],
      url: json['url'],
      viewCount: json['viewCount'],
    );
  }
}