import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coathematchmaker/services/api_client.dart';
import 'package:coathematchmaker/services/app_config_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  PackageInfo info(int build) => PackageInfo(
    appName: 'COA',
    packageName: 'me.coathematchmaker.app',
    version: '1.0.2',
    buildNumber: '$build',
  );
  Map<String, dynamic> policy(int min, int latest, String url) => {
    'minSupportedBuild': min,
    'latestBuild': latest,
    'storeUrl': url,
    'message': 'Update required.',
  };

  test(
    'Reads installed build and uses independent iOS and Android policies',
    () async {
      final requests = <Uri>[];
      final api = ApiClient(
        client: MockClient((request) async {
          requests.add(request.url);
          final ios = request.url.queryParameters['platform'] == 'ios';
          return http.Response(
            jsonEncode(
              ios
                  ? policy(6, 8, 'https://apps.apple.com/app/id123')
                  : policy(
                      10,
                      10,
                      'https://play.google.com/store/apps/details?id=me.coathematchmaker.app',
                    ),
            ),
            200,
          );
        }),
      );
      addTearDown(api.close);
      final ios = await AppConfigService(
        api,
        platform: 'ios',
        packageInfo: () async => info(7),
      ).load();
      final android = await AppConfigService(
        api,
        platform: 'android',
        packageInfo: () async => info(9),
      ).load();
      expect(requests.map((u) => u.queryParameters['build']), ['7', '9']);
      expect(requests.first.queryParameters['version'], '1.0.2');
      expect(ios.updateRequired, false);
      expect(ios.updateAvailable, true);
      expect(android.updateRequired, true);
      expect(ios.storeUri!.host, 'apps.apple.com');
      expect(android.storeUri!.host, 'play.google.com');
    },
  );

  test(
    'Offline cache preserves requirement but re-evaluates after an app upgrade',
    () async {
      var online = true;
      final api = ApiClient(
        client: MockClient((_) async {
          if (!online) throw http.ClientException('offline');
          return http.Response(
            jsonEncode(policy(8, 8, 'https://apps.apple.com/app/id123')),
            200,
          );
        }),
      );
      addTearDown(api.close);
      var build = 7;
      final service = AppConfigService(
        api,
        platform: 'ios',
        packageInfo: () async => info(build),
      );
      expect((await service.load()).updateRequired, true);
      online = false;
      expect((await service.load()).updateRequired, true);
      expect(service.lastCheckUsedCache, true);
      build = 8;
      expect((await service.load()).updateRequired, false);
      expect(
        AppConfigService(
          api,
          platform: 'android',
          packageInfo: () async => info(8),
        ).load(),
        throwsA(isA<ApiException>()),
      );
    },
  );

  test('Invalid build cannot silently bypass update policy', () async {
    final api = ApiClient(
      client: MockClient((_) async => http.Response('{}', 200)),
    );
    addTearDown(api.close);
    final service = AppConfigService(api, packageInfo: () async => info(0));
    expect(service.load(), throwsFormatException);
  });

  test(
    'Latest alone is optional; minimum gates access; links stay platform-specific',
    () {
      AppConfig config(int build, String url) => AppConfig.fromJson(
        policy(6, 8, url),
        platform: 'ios',
        installedBuild: build,
        installedVersion: '1.0.2',
      );
      expect(config(6, '').updateRequired, false);
      expect(config(6, '').updateAvailable, true);
      expect(config(8, '').updateAvailable, false);
      expect(config(5, '').updateRequired, true);
      expect(config(6, 'https://play.google.com/store').storeUri, null);
      expect(config(6, 'https://apps.apple.com.evil.test/').storeUri, null);
    },
  );
}
