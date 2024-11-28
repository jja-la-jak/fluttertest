import 'package:flutter_project/config/environment.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_project/service/music_service.dart';

Future<List<Music>> searchMusic(String query, {String type = 'string'}) async {
  // URL 인코딩 수정
  final encodedQuery = Uri.encodeQueryComponent(query);

  final response = await http.get(
    Uri.parse('${Environment.apiUrl}/musics?query=$encodedQuery&type=$type'),
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

Future<List<Music>> performSearch(
    BuildContext context,
    TextEditingController controller,
    void Function(bool) setLoading,
    ) async {
  final query = controller.text;
  if (query.isEmpty) return [];

  setLoading(true);

  try {
    final results = await searchMusic(query);
    setLoading(false);
    return results;
  } catch (e) {
    setLoading(false);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('검색 중 오류가 발생했습니다: $e')),
      );
    }
    return [];
  }
}
