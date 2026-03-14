import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../services/ad_service.dart';

class CommonBannerAd extends StatefulWidget {
  const CommonBannerAd({super.key});

  @override
  State<CommonBannerAd> createState() => _CommonBannerAdState();
}

class _CommonBannerAdState extends State<CommonBannerAd> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  AdSize? _adSize;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadBanner();
  }

  Future<void> _loadBanner() async {
    if (_bannerAd != null) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;

    final width = MediaQuery.of(context).size.width.truncate();
    if (width <= 0) return;

    final anchoredSize =
    await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);

    if (anchoredSize == null) return;

    final banner = BannerAd(
      adUnitId: AdService.bannerUnitId,
      size: anchoredSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) return;
          setState(() {
            _bannerAd = ad as BannerAd;
            _adSize = anchoredSize;
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _bannerAd = null;
            _adSize = null;
            _isLoaded = false;
          });
          debugPrint('BannerAd load failed: $error');
        },
      ),
    );

    await banner.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null || _adSize == null) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      top: false,
      child: Center(
        child: SizedBox(
          width: _adSize!.width.toDouble(),
          height: _adSize!.height.toDouble(),
          child: AdWidget(ad: _bannerAd!),
        ),
      ),
    );
  }
}