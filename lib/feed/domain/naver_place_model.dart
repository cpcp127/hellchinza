import 'package:html_unescape/html_unescape.dart';

class NaverLocalPlace {
  final String title;
  final String address;
  final String roadAddress;
  final double mapx;
  final double mapy;

  NaverLocalPlace({
    required this.title,
    required this.address,
    required this.roadAddress,
    required this.mapx,
    required this.mapy,
  });

  factory NaverLocalPlace.fromJson(Map<String, dynamic> json) {
    return NaverLocalPlace(
      title: decodeNaverHtml((json['title'] ?? '') as String),
      address: (json['address'] ?? '') as String,
      roadAddress: (json['roadAddress'] ?? '') as String,
      mapx: double.parse((json['mapx'] ?? '0').toString()),
      mapy: double.parse((json['mapy'] ?? '0').toString()),
    );
  }

  static String decodeNaverHtml(String text) {
    final noTag = text.replaceAll(RegExp(r'<[^>]*>'), '');
    return HtmlUnescape().convert(noTag);
  }
}
