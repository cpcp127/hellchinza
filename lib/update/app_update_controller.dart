import 'dart:io';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app_update_state.dart';

final appUpdateControllerProvider =
StateNotifierProvider<AppUpdateController, AppUpdateState>((ref) {
  return AppUpdateController()..check();
});

class AppUpdateController extends StateNotifier<AppUpdateState> {
  AppUpdateController() : super(const AppUpdateState.initial());

  Future<void> check() async {
    state = state.copyWith(
      isLoading: true,
      status: AppUpdateStatus.checking,
    );

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final remoteConfig = FirebaseRemoteConfig.instance;

      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval:Duration.zero,
      ));

      await remoteConfig.fetchAndActivate();

      final forceEnabled = remoteConfig.getBool('force_update_enabled');

      final minRequiredVersion = Platform.isIOS
          ? remoteConfig.getString('force_update_ios_min_version')
          : remoteConfig.getString('force_update_android_min_version');

      final latestVersion = Platform.isIOS
          ? remoteConfig.getString('latest_ios_version')
          : remoteConfig.getString('latest_android_version');

      final storeUrl = Platform.isIOS
          ? remoteConfig.getString('ios_store_url')
          : remoteConfig.getString('android_store_url');

      final message = remoteConfig.getString('update_message');

      if (forceEnabled &&
          _shouldForceUpdate(currentVersion, minRequiredVersion)) {
        state = state.copyWith(
          isLoading: false,
          status: AppUpdateStatus.forceUpdate,
          currentVersion: currentVersion,
          minRequiredVersion: minRequiredVersion,
          latestVersion: latestVersion,
          message: message,
          storeUrl: storeUrl,
        );
        return;
      }

      if (forceEnabled &&
          _shouldForceUpdate(currentVersion, minRequiredVersion)) {
        state = state.copyWith(
          isLoading: false,
          status: AppUpdateStatus.optionalUpdate,
          currentVersion: currentVersion,
          minRequiredVersion: minRequiredVersion,
          latestVersion: latestVersion,
          message: message,
          storeUrl: storeUrl,
        );
        return;
      }

      state = state.copyWith(
        isLoading: false,
        status: AppUpdateStatus.upToDate,
        currentVersion: currentVersion,
        minRequiredVersion: minRequiredVersion,
        latestVersion: latestVersion,
        message: message,
        storeUrl: storeUrl,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        status: AppUpdateStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  bool _shouldForceUpdate(String current, String required) {
    List<int> parseMajorMinor(String version) {
      final parts = version.split('.');
      final major = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
      final minor = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
      return [major, minor];
    }

    final currentParts = parseMajorMinor(current);
    final requiredParts = parseMajorMinor(required);

    final currentMajor = currentParts[0];
    final currentMinor = currentParts[1];

    final requiredMajor = requiredParts[0];
    final requiredMinor = requiredParts[1];

    if (currentMajor < requiredMajor) return true;
    if (currentMajor > requiredMajor) return false;

    if (currentMinor < requiredMinor) return true;
    return false;
  }
}