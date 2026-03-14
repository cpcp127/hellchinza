import 'dart:io';

class AdService {
  const AdService._();

  // 테스트 중에는 true
  static const bool isTest = true;

  static String get bannerUnitId {
    if (isTest) {
      if (Platform.isAndroid) {
        return 'ca-app-pub-7927140902377756/9020492626';
      }
      if (Platform.isIOS) {
        return 'ca-app-pub-7927140902377756/5526267452';
      }
    } else {
      // TODO: 나중에 실제 배너 광고 ID로 교체
      if (Platform.isAndroid) {
        return 'ca-app-pub-7927140902377756/9020492626';
      }
      if (Platform.isIOS) {
        return 'ca-app-pub-7927140902377756/5526267452';
      }
    }

    throw UnsupportedError('지원하지 않는 플랫폼입니다.');
  }
}