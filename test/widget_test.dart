import 'package:coathematchmaker/main.dart';
import 'package:coathematchmaker/services/api_client.dart';
import 'package:coathematchmaker/services/app_config_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App starts on auth flow', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final api = ApiClient(
      client: MockClient(
        (_) async => http.Response(
          '{"minSupportedBuild":1,"latestBuild":7,"storeUrl":""}',
          200,
        ),
      ),
    );
    final service = AppConfigService(
      api,
      platform: 'ios',
      packageInfo: () async => PackageInfo(
        appName: 'COA',
        packageName: 'test',
        version: '1.0.2',
        buildNumber: '7',
      ),
    );
    await tester.pumpWidget(CoaMatchmakerApp(api: api, configService: service));
    await tester.pumpAndSettle();
    expect(find.text('Prijava'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    api.close();
  });

  testWidgets(
    'Mandatory gate blocks access and offers recovery when store URL is missing',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final api = ApiClient(
        client: MockClient(
          (_) async => http.Response(
            '{"minSupportedBuild":8,"latestBuild":8,"storeUrl":""}',
            200,
          ),
        ),
      );
      final service = AppConfigService(
        api,
        platform: 'ios',
        packageInfo: () async => PackageInfo(
          appName: 'COA',
          packageName: 'test',
          version: '1.0.2',
          buildNumber: '7',
        ),
      );
      await tester.pumpWidget(
        CoaMatchmakerApp(api: api, configService: service),
      );
      await tester.pumpAndSettle();
      expect(find.text('Vrijeme je za novu verziju'), findsOneWidget);
      await tester.tap(find.text('Ažuriraj aplikaciju'));
      await tester.pumpAndSettle();
      expect(find.text('Otvori App Store'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      api.close();
    },
  );
}
