import 'dart:convert';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/env.dart';
import 'api_client.dart';

class AppConfig {
  const AppConfig({
    required this.platform,
    required this.installedBuild,
    required this.installedVersion,
    required this.minSupportedBuild,
    required this.latestBuild,
    required this.storeUrl,
    required this.message,
    this.messageEn,
  });

  final String platform;
  final int installedBuild;
  final String installedVersion;
  final int minSupportedBuild;
  final int latestBuild;
  final String storeUrl;
  final String message;
  final String? messageEn;

  bool get updateRequired => installedBuild < minSupportedBuild;
  bool get updateAvailable => installedBuild < latestBuild;
  String get storeName => platform == 'ios' ? 'App Store' : 'Google Play';
  Uri? get storeUri {
    final uri = Uri.tryParse(storeUrl);
    if (uri == null || uri.scheme != 'https') return null;
    final host = platform == 'ios' ? 'apps.apple.com' : 'play.google.com';
    return uri.host == host ? uri : null;
  }

  factory AppConfig.fromJson(
    Map<String, dynamic> json, {
    required String platform,
    required int installedBuild,
    required String installedVersion,
  }) {
    int parseBuild(Object? value) {
      final parsed = int.tryParse('$value');
      if (parsed == null || parsed < 1) {
        throw const FormatException('Neispravan broj verzije na serveru.');
      }
      return parsed;
    }

    final minimum = parseBuild(json['minSupportedBuild']);
    final latest = parseBuild(json['latestBuild']);
    return AppConfig(
      platform: platform,
      installedBuild: installedBuild,
      installedVersion: installedVersion,
      minSupportedBuild: minimum,
      latestBuild: latest < minimum ? minimum : latest,
      storeUrl:
          (json['storeUrl'] ??
                  (platform == 'ios'
                      ? json['appStoreUrl']
                      : json['playStoreUrl']) ??
                  json['playStoreUrl'] ??
                  '')
              .toString(),
      message:
          json['message']?.toString() ?? 'Dostupna je nova verzija aplikacije.',
      messageEn: switch (json['messageEn']) {
        String value when value.trim().isNotEmpty => value,
        _ => null,
      },
    );
  }
}

class AppConfigService {
  AppConfigService(
    this.api, {
    Future<PackageInfo> Function()? packageInfo,
    String? platform,
  }) : _packageInfo = packageInfo ?? PackageInfo.fromPlatform,
       platform = platform ?? Env.platform;
  final ApiClient api;
  final String platform;
  final Future<PackageInfo> Function() _packageInfo;
  bool lastCheckUsedCache = false;

  Future<AppConfig> load() async {
    final info = await _packageInfo();
    final build = int.tryParse(info.buildNumber);
    if (build == null || build < 1) {
      throw const FormatException('Nije moguće pročitati verziju aplikacije.');
    }
    final prefs = await SharedPreferences.getInstance();
    final key = 'app_config:${api.baseUrl}:$platform';
    try {
      final data = await api.getJson('/api/app-config', {
        'build': '$build',
        'version': info.version,
        'platform': platform,
      });
      final config = AppConfig.fromJson(
        data,
        platform: platform,
        installedBuild: build,
        installedVersion: info.version,
      );
      await prefs.setString(key, jsonEncode(data));
      lastCheckUsedCache = false;
      return config;
    } catch (_) {
      final cached = prefs.getString(key);
      if (cached == null) rethrow;
      lastCheckUsedCache = true;
      return AppConfig.fromJson(
        jsonDecode(cached) as Map<String, dynamic>,
        platform: platform,
        installedBuild: build,
        installedVersion: info.version,
      );
    }
  }
}
