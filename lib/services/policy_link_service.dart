import 'package:url_launcher/url_launcher.dart';

class PolicyLinkService {
  const PolicyLinkService._();

  static Future<void> openPrivacy() async {
    final uri = Uri.parse('https://hellchinza.web.app/privacy');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      throw Exception('개인정보 처리방침을 열 수 없어요');
    }
  }

  static Future<void> openTerms() async {
    final uri = Uri.parse('https://hellchinza.web.app/terms');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      throw Exception('이용약관을 열 수 없어요');
    }
  }

  static Future<void> openSupport() async {
    final uri = Uri.parse('https://hellchinza.web.app/support');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      throw Exception('고객지원 페이지를 열 수 없어요');
    }
  }
}