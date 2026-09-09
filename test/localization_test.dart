import 'dart:convert';
import 'dart:io';
import 'package:coathematchmaker/l10n/app_language.dart';
import 'package:coathematchmaker/l10n/app_strings.dart';
import 'package:coathematchmaker/l10n/english.dart';
import 'package:coathematchmaker/main.dart';
import 'package:coathematchmaker/screens/profile_screen.dart';
import 'package:coathematchmaker/services/api_client.dart';
import 'package:coathematchmaker/services/app_config_service.dart';
import 'package:coathematchmaker/services/auth_service.dart';
import 'package:coathematchmaker/services/league_service.dart';
import 'package:coathematchmaker/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_LANGUAGES')) {
      final fontData = ByteData.sublistView(
        await File('/System/Library/Fonts/SFNS.ttf').readAsBytes(),
      );
      for (final family in [
        'Roboto',
        'Ahem',
        'Avenir Next Rounded',
        'Avenir Next',
        'SF Pro Display',
        'SF Pro Text',
      ]) {
        await (FontLoader(family)..addFont(Future.value(fontData))).load();
      }
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });

  test('MNE preserves every source string and the requested spellings', () {
    const strings = AppStrings(Locale('sr'));
    for (final source in englishMessages.keys) {
      expect(strings.text(source), source);
    }
    expect(strings.text('Sledeći meč'), 'Sledeći meč');
    expect(strings.text('redoslijed'), 'redoslijed');
  });

  test(
    'English templates retain every argument without translating user data',
    () {
      final placeholder = RegExp(r'\{p\d+\}');
      for (final entry in englishMessages.entries) {
        expect(
          placeholder.allMatches(entry.value).map((m) => m[0]).toSet(),
          placeholder.allMatches(entry.key).map((m) => m[0]).toSet(),
          reason: entry.key,
        );
        expect(entry.value.trim(), isNotEmpty);
      }
      const strings = AppStrings(Locale('en'));
      expect(
        strings.text('Zdravo, {p0}', ['Početna {p1}']),
        'Hello, Početna {p1}',
      );
      expect(
        strings.text('Otvoreno prvenstvo teniskih klubova'),
        'Otvoreno prvenstvo teniskih klubova',
      );
      expect(strings.text('Sledeći meč'), 'Next match');
    },
  );

  test(
    'current and legacy backend errors translate, including dynamic limits',
    () {
      const en = AppStrings(Locale('en'));
      const mne = AppStrings(Locale('sr'));
      expect(
        en.serverMessage('Google Maps pretraga nije podesena na serveru.'),
        'Google Maps search has not been configured on the server.',
      );
      expect(
        en.serverMessage('Invalid email or password'),
        'Invalid email or password.',
      );
      expect(
        mne.serverMessage('Email adresa ili lozinka nisu ispravne.'),
        'Email adresa ili lozinka nisu ispravne.',
      );
      expect(
        en.serverMessage('Veličina slike mora biti manja od 8 MB.'),
        'The image must be smaller than 8 MB.',
      );
      expect(
        en.serverMessage('Unos rezultata biće dostupan za 12 min.'),
        'Result entry will be available in 12 min.',
      );
      expect(
        en.serverMessage('Nepoznata serverska poruka'),
        'Something went wrong. Please try again.',
      );
    },
  );

  test('language persists locally and signing out does not reset it', () async {
    final controller = AppLanguageController();
    await controller.restore();
    expect(controller.language, AppLanguage.mne);
    await controller.select(AppLanguage.eng);
    final api = fixtureApi();
    final auth = AuthService(api);
    await auth.logout();
    final restored = AppLanguageController();
    await restored.restore();
    expect(restored.language, AppLanguage.eng);
    expect(restored.language.locale.languageCode, 'en');
    restored.dispose();
    controller.dispose();
    auth.dispose();
    api.close();
  });

  test('unknown saved languages fall back to MNE', () async {
    SharedPreferences.setMockInitialValues({'app_language': 'unsupported'});
    final controller = AppLanguageController();
    await controller.restore();
    expect(controller.language, AppLanguage.mne);
    controller.dispose();
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('profile selector and forms fit both languages at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = AppLanguageController();
      final api = fixtureApi();
      final auth = AuthService(api)..currentPlayer = demoPlayer;
      await tester.pumpWidget(
        AppLanguageScope(
          controller: controller,
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: controller.language.locale,
              supportedLocales: AppStrings.supportedLocales,
              localizationsDelegates: const [
                AppStrings.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              theme: const bool.fromEnvironment('CAPTURE_LANGUAGES')
                  ? AppTheme.light.copyWith(
                      filledButtonTheme: FilledButtonThemeData(
                        style: AppTheme.light.filledButtonTheme.style?.copyWith(
                          textStyle: const WidgetStatePropertyAll(
                            TextStyle(
                              fontFamily: 'Roboto',
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    )
                  : AppTheme.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(width == 320 ? 1.5 : 1),
                ),
                child: RepaintBoundary(
                  key: const ValueKey('profile-capture'),
                  child: child!,
                ),
              ),
              home: ProfileScreen(
                auth: auth,
                league: LeagueService(api),
                api: api,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final language in AppLanguage.values) {
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('profile-language')),
          -250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(language.label));
        await tester.pumpAndSettle();
        expect(controller.language, language);
        expect(
          find.text(AppStrings(language.locale).text('Jezik aplikacije')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('CAPTURE_LANGUAGES')) {
          await Scrollable.ensureVisible(
            tester.element(
              find.text(AppStrings(language.locale).text('Jezik aplikacije')),
            ),
            alignment: .05,
          );
          await tester.pumpAndSettle();
          await expectLater(
            find.byKey(const ValueKey('profile-capture')),
            matchesGoldenFile(
              '../.local-backups/languages-20260909/profile-${language.code}-${width.toInt()}.png',
            ),
          );
        }
        await tester.drag(find.byType(ListView), const Offset(0, -450));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('CAPTURE_LANGUAGES')) {
          await expectLater(
            find.byKey(const ValueKey('profile-capture')),
            matchesGoldenFile(
              '../.local-backups/languages-20260909/profile-form-${language.code}-${width.toInt()}.png',
            ),
          );
        }
      }
      final firstName = find.byType(TextFormField).first;
      await tester.ensureVisible(firstName);
      await tester.enterText(firstName, '');
      tester.state<FormState>(find.byType(Form)).validate();
      await tester.pumpAndSettle();
      expect(find.text('Required field'), findsOneWidget);
      await controller.select(AppLanguage.mne);
      await tester.pumpAndSettle();
      expect(find.text('Obavezno polje'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      auth.dispose();
      api.close();
    });
  }

  testWidgets(
    'profile language changes live, preserves edits and survives restart',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({'jwt_token': 'fixture-token'});
      var writes = 0;
      final api = ApiClient(
        baseUrl: 'https://fixture.example.test',
        client: MockClient((request) async {
          if (request.method != 'GET' &&
              request.url.path != '/api/players/me/activity') {
            writes++;
          }
          final response = switch (request.url.path) {
            '/api/app-config' => {'minSupportedBuild': 1, 'latestBuild': 7},
            '/api/auth/me' => {'player': demoPlayers.first},
            '/api/players' || '/api/rankings' => {
              'players': demoPlayers,
              'rankings': demoPlayers,
            },
            '/api/messages/unread-count' => {'unreadCount': 0},
            _ => {'matches': [], 'tournaments': []},
          };
          return http.Response(
            jsonEncode(response),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final config = AppConfigService(
        api,
        platform: 'ios',
        packageInfo: () async => PackageInfo(
          appName: 'COA',
          packageName: 'test',
          version: '1.0.2',
          buildNumber: '7',
        ),
      );
      Widget app() => RepaintBoundary(
        key: const ValueKey('language-capture'),
        child: CoaMatchmakerApp(api: api, configService: config),
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Profil i podešavanja'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Moj profil').last);
      await tester.pumpAndSettle();
      final firstName = find.byType(TextFormField).first;
      await tester.ensureVisible(firstName);
      await tester.enterText(firstName, 'Početna {p0}');
      await tester.ensureVisible(
        find.byKey(const ValueKey('profile-language')),
      );
      await tester.tap(find.text('ENG'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text('App language'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(firstName).controller!.text,
        'Početna {p0}',
      );
      expect(writes, 0);
      expect(
        (await SharedPreferences.getInstance()).getString('app_language'),
        'en',
      );
      if (const bool.fromEnvironment('CAPTURE_LANGUAGES')) {
        await expectLater(
          find.byKey(const ValueKey('language-capture')),
          matchesGoldenFile(
            '../.local-backups/languages-20260909/profile-eng.png',
          ),
        );
      }
      await tester.tap(find.text('MNE'));
      await tester.pumpAndSettle();
      expect(find.text('Jezik aplikacije'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(firstName).controller!.text,
        'Početna {p0}',
      );
      if (const bool.fromEnvironment('CAPTURE_LANGUAGES')) {
        await expectLater(
          find.byKey(const ValueKey('language-capture')),
          matchesGoldenFile(
            '../.local-backups/languages-20260909/profile-mne.png',
          ),
        );
      }
      await tester.tap(find.text('ENG'));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(ProfileScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsWidgets);
      expect(find.byTooltip('Profile and settings'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsWidgets);
      expect(find.byTooltip('Profile and settings'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.close();
    },
  );
}
