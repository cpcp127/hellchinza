import 'package:html_unescape/html_unescape.dart';

class NaverLocalPlace {
  final String title;
  final String address;
  final String roadAddress;
  final double mapx; // 경도
  final double mapy; // 위도

  NaverLocalPlace({
    required this.title,
    required this.address,
    required this.roadAddress,
    required this.mapx,
    required this.mapy,
  });

  factory NaverLocalPlace.fromJson(Map<String, dynamic> json) {
    return NaverLocalPlace(
      title: decodeNaverHtml(json['title']),
      address: json['address'],
      roadAddress: json['roadAddress'],
      mapx: double.parse(json['mapx']),
      mapy: double.parse(json['mapy']),
    );
  }

static  String decodeNaverHtml(String text) {
    // 1. HTML 태그 제거 (<b> 등)
    final noTag = text.replaceAll(RegExp(r'<[^>]*>'), '');

    // 2. HTML 엔티티 디코딩
    return HtmlUnescape().convert(noTag);
  }
}
