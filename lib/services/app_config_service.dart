import '../config/env.dart';
import 'api_client.dart';

class AppConfig {
  const AppConfig({
    required this.updateRequired,
    required this.message,
    required this.playStoreUrl,
    required this.minSupportedBuild,
    required this.latestBuild,
  });

  final bool updateRequired;
  final String message;
  final String playStoreUrl;
  final int minSupportedBuild;
  final int latestBuild;

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      updateRequired: json['updateRequired'] == true,
      message:
          json['message']?.toString() ?? 'Nova verzija aplikacije je obavezna.',
      playStoreUrl: json['playStoreUrl']?.toString() ?? '',
      minSupportedBuild: json['minSupportedBuild'] ?? 1,
      latestBuild: json['latestBuild'] ?? 1,
    );
  }
}

class AppConfigService {
  AppConfigService(this.api);

  final ApiClient api;

  Future<AppConfig> load() async {
    final data = await api.getJson('/api/app-config', {
      'build': Env.appBuildNumber.toString(),
    });
    return AppConfig.fromJson(data);
  }
}
