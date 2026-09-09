import 'package:coathematchmaker/main.dart';
import 'package:coathematchmaker/l10n/app_strings.dart';
import 'package:coathematchmaker/services/api_client.dart';
import 'package:coathematchmaker/services/app_config_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final language in ['mne', 'en']) {
    final tr = AppStrings(Locale(language == 'en' ? 'en' : 'sr')).text;
    testWidgets('App starts on auth flow, $language', (tester) async {
      tester.view.physicalSize = const Size(320, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({'app_language': language});
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
      await tester.pumpWidget(
        CoaMatchmakerApp(api: api, configService: service),
      );
      await tester.pumpAndSettle();
      expect(find.text(tr('Prijava')), findsWidgets);
      expect(find.text(tr('Lozinka')), findsOneWidget);
      await tester.ensureVisible(find.text(tr('Zaboravljena lozinka?')));
      await tester.tap(find.text(tr('Zaboravljena lozinka?')));
      await tester.pumpAndSettle();
      expect(find.text(tr('Promjena lozinke')), findsOneWidget);
      expect(find.text(tr('Pošalji link')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.close();
    });

    testWidgets(
      'Mandatory gate blocks access and offers recovery when store URL is missing, $language',
      (tester) async {
        SharedPreferences.setMockInitialValues({'app_language': language});
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
        expect(find.text(tr('Vrijeme je za novu verziju')), findsOneWidget);
        expect(
          find.text(
            language == 'en'
                ? tr(
                    'Nova verzija aplikacije je obavezna. Ažuriraj COA The Matchmaker.',
                  )
                : 'Dostupna je nova verzija aplikacije.',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text(tr('Ažuriraj aplikaciju')));
        await tester.pumpAndSettle();
        expect(find.text(tr('Otvori {p0}', ['App Store'])), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        api.close();
      },
    );
  }
}
