import 'dart:convert';

import 'package:http/http.dart' as http;

import '../feed/domain/naver_place_model.dart';

class NaverLocationService {
  static const _baseUrl =
      'https://openapi.naver.com/v1/search/local.json';

  Future<List<NaverLocalPlace>> search(String query) async {
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'query': query,
        'display': '10',
        'start': '1',
        'sort': 'random',
      },
    );

    final response = await http.get(
      uri,
      headers: {
        'X-Naver-Client-Id': '4NIWQyJHPH175BsrjvBQ',
        'X-Naver-Client-Secret': 'jnEQZJ1kTq',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('네이버 지역 검색 실패');
    }

    final body = jsonDecode(utf8.decode(response.bodyBytes));
    final items = body['items'] as List;

    return items
        .map((e) => NaverLocalPlace.fromJson(e))
        .toList();
  }
}
class NaverCoordinateService {
  static const _baseUrl =
      'https://naveropenapi.apigw.ntruss.com/map-coordinate/v2/convert';

  Future<LatLng> convertTM128ToWGS84({
    required double mapx,
    required double mapy,
  }) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'coords': '$mapx,$mapy',
      'sourcecrs': 'TM128',
      'targetcrs': 'WGS84',
    });

    final response = await http.get(
      uri,
      headers: {
        'X-NCP-APIGW-API-KEY-ID': '4NIWQyJHPH175BsrjvBQ',
        'X-NCP-APIGW-API-KEY': 'jnEQZJ1kTq',
      },
    );

    final body = jsonDecode(response.body);
    final result = body['results'][0];

    return LatLng(
      lat: result['y'], // 위도
      lng: result['x'], // 경도
    );
  }
}

class LatLng {
  final double lat;
  final double lng;
  LatLng({required this.lat, required this.lng});
}
