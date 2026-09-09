import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coathematchmaker/l10n/app_strings.dart';
import 'package:coathematchmaker/models/player.dart';
import 'package:coathematchmaker/models/league_settings.dart';
import 'package:coathematchmaker/screens/players_screen.dart';
import 'package:coathematchmaker/screens/settings_screen.dart';
import 'package:coathematchmaker/services/activity_service.dart';
import 'package:coathematchmaker/services/api_client.dart';
import 'package:coathematchmaker/services/auth_service.dart';
import 'package:coathematchmaker/services/league_service.dart';
import 'package:coathematchmaker/theme/app_theme.dart';
import 'package:coathematchmaker/widgets/player_activity.dart';
import 'package:coathematchmaker/widgets/sport_surfaces.dart';
import 'support/fixtures.dart';

Widget host(Widget child, Locale locale, double scale) => MaterialApp(
  debugShowCheckedModeBanner: false,
  locale: locale,
  supportedLocales: AppStrings.supportedLocales,
  localizationsDelegates: const [
    AppStrings.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: const bool.fromEnvironment('CAPTURE_ACTIVITY')
      ? AppTheme.light.copyWith(
          filledButtonTheme: FilledButtonThemeData(
            style: AppTheme.light.filledButtonTheme.style?.copyWith(
              textStyle: const WidgetStatePropertyAll(
                TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w800),
              ),
            ),
          ),
        )
      : AppTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: RepaintBoundary(
      key: const ValueKey('activity-capture'),
      child: child!,
    ),
  ),
  home: child,
);

Future<void> capture(String name) async {
  if (const bool.fromEnvironment('CAPTURE_ACTIVITY')) {
    await expectLater(
      find.byKey(const ValueKey('activity-capture')),
      matchesGoldenFile('../.local-backups/activity-20260909/$name.png'),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_ACTIVITY')) {
      final data = ByteData.sublistView(
        await File('/System/Library/Fonts/SFNS.ttf').readAsBytes(),
      );
      for (final family in [
        'Roboto',
        'Avenir Next',
        'Avenir Next Rounded',
        'SF Pro Display',
        'SF Pro Text',
      ]) {
        await (FontLoader(family)..addFont(Future.value(data))).load();
      }
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });

  test(
    'legacy player timestamps stay unknown and inactivity is not account suspension',
    () {
      expect(demoPlayer.lastActiveAt, isNull);
      expect(LeagueSettings.fromJson({}).inactivityDays, 0);
      final player = Player.fromJson({
        ...demoPlayers.first,
        'lastActiveAt': '2026-09-01T12:30:00Z',
        'playStatus': 'unavailable',
        'playStatusSource': 'inactivity',
      });
      expect(player.lastActiveAt, DateTime.utc(2026, 9, 1, 12, 30));
      expect(player.active, isTrue);
      expect(player.isAvailableForMatch, isFalse);
      expect(player.unavailableDueToInactivity, isTrue);
      expect(
        Player.fromJson({
          ...demoPlayers.first,
          'lastActiveAt': 'invalid',
        }).lastActiveAt,
        isNull,
      );
    },
  );

  testWidgets(
    'heartbeats run only for a signed-in foreground session and retry offline',
    (tester) async {
      var calls = 0;
      var online = false;
      final api = ApiClient(
        client: MockClient((request) async {
          if (request.url.path == '/api/players/me/activity') {
            calls++;
            if (!online) throw http.ClientException('offline');
            expect(request.method, 'POST');
            expect(jsonDecode(request.body), isEmpty);
          }
          return http.Response(
            jsonEncode({'player': demoPlayers.first}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      )..token = 'test';
      final auth = AuthService(api)..currentPlayer = demoPlayer;
      final tracker = AppActivityTracker(auth);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      tracker.start();
      tracker.start();
      await tester.pump();
      expect(calls, 1);
      online = true;
      await tester.pump(const Duration(minutes: 1));
      expect(calls, 2);
      await auth.refreshMe();
      await tester.pump();
      expect(calls, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(minutes: 10));
      expect(calls, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(calls, 3);
      await auth.logout();
      await tester.pump(const Duration(minutes: 2));
      expect(calls, 3);
      tracker.dispose();
      await tester.pump(const Duration(minutes: 2));
      expect(calls, 3);
      auth.dispose();
      api.close();
    },
  );

  for (final locale in AppStrings.supportedLocales) {
    final tr = AppStrings(locale).text;
    for (final (size, scale) in [
      (const Size(320, 740), 1.4),
      (const Size(390, 844), 1.0),
      (const Size(1024, 1000), 1.0),
    ]) {
      testWidgets(
        'admin inactivity settings validate, save and disable at $size/$locale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var settings = <String, dynamic>{
            'resultEntryDelayMinutes': 60,
            'matchWinPoints': 10,
            'tournamentWinPoints': 50,
            'inactivityDays': 0,
          };
          final writes = <Map<String, dynamic>>[];
          final api = ApiClient(
            client: MockClient((request) async {
              if (request.method == 'PATCH') {
                writes.add(jsonDecode(request.body));
                settings = {...settings, ...writes.last};
              }
              return http.Response(
                jsonEncode({'settings': settings, 'matches': []}),
                200,
              );
            }),
          );
          await tester.pumpWidget(
            host(
              Scaffold(body: SettingsScreen(league: LeagueService(api))),
              locale,
              scale,
            ),
          );
          await tester.pumpAndSettle();
          final toggle = find.byKey(const ValueKey('auto-unavailable'));
          expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
          await tester.ensureVisible(toggle);
          await tester.tap(toggle);
          await tester.pumpAndSettle();
          final days = find.byType(TextFormField).last;
          await tester.ensureVisible(days);
          await tester.enterText(days, '0');
          await tester.ensureVisible(find.text(tr('Sačuvaj podešavanja')));
          await tester.tap(find.text(tr('Sačuvaj podešavanja')));
          await tester.pumpAndSettle();
          expect(writes, isEmpty);
          expect(
            find.text(tr('Unesi cijeli broj od 1 do 365.')),
            findsOneWidget,
          );
          await tester.ensureVisible(days);
          await tester.enterText(days, '7');
          await tester.ensureVisible(find.text(tr('Sačuvaj podešavanja')));
          await tester.tap(find.text(tr('Sačuvaj podešavanja')));
          await tester.pumpAndSettle();
          expect(writes.single, {
            'resultEntryDelayMinutes': 60,
            'matchWinPoints': 10,
            'tournamentWinPoints': 50,
            'inactivityDays': 7,
          });
          expect(
            tester
                .widget<TextFormField>(find.byType(TextFormField).last)
                .controller!
                .text,
            '7',
          );
          await tester.ensureVisible(toggle);
          await tester.pumpAndSettle();
          await capture(
            'settings-${locale.languageCode}-${size.width.toInt()}',
          );
          await tester.tap(toggle);
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text(tr('Sačuvaj podešavanja')));
          await tester.tap(find.text(tr('Sačuvaj podešavanja')));
          await tester.pumpAndSettle();
          expect(writes.last['inactivityDays'], 0);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          api.close();
        },
      );
    }

    testWidgets(
      'activity is visible in player cards, compact list and profile in $locale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final player = {
          ...demoPlayers[1],
          'lastActiveAt': DateTime(
            2026,
            9,
            1,
            12,
            30,
          ).toUtc().toIso8601String(),
          'playStatus': 'unavailable',
          'playStatusSource': 'inactivity',
        };
        final api = ApiClient(
          client: MockClient(
            (request) async => http.Response(
              jsonEncode({
                'players': [player],
                'player': player,
                'settings': {},
                'matches': [],
                'tournaments': [],
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            ),
          ),
        );
        final auth = AuthService(api)..currentPlayer = demoPlayer;
        final league = LeagueService(api);
        await tester.pumpWidget(
          host(
            Scaffold(
              body: PlayersScreen(api: api, auth: auth, league: league),
            ),
            locale,
            1.4,
          ),
        );
        await tester.pumpAndSettle();
        final expected = tr('Posljednja aktivnost: {p0}', [
          '01.09.2026. 12:30',
        ]);
        expect(find.text(expected), findsOneWidget);
        expect(
          tester
              .getRect(find.byKey(const ValueKey('player-card-avatar:other')))
              .bottom,
          lessThanOrEqualTo(tester.getRect(find.text('Ana Marković')).top),
        );
        if (const bool.fromEnvironment('CAPTURE_ACTIVITY')) {
          await tester.runAsync(
            () => precacheImage(
              const AssetImage(tennisEditorialAsset),
              tester.element(find.byType(PlayersScreen)),
            ),
          );
          await tester.pumpAndSettle();
        }
        await capture('players-${locale.languageCode}');
        await tester.tap(find.byTooltip(tr('Sažeta lista')));
        await tester.pumpAndSettle();
        expect(find.text(expected), findsOneWidget);
        await capture('players-list-${locale.languageCode}');
        await tester.pumpWidget(
          host(
            PlayerProfileScreen(
              playerId: 'other',
              league: league,
              api: api,
              auth: auth,
            ),
            locale,
            1.4,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(PlayerActivity), findsOneWidget);
        expect(find.text(expected), findsOneWidget);
        expect(find.text(tr('Nedostupan zbog neaktivnosti')), findsOneWidget);
        expect(find.text(tr('Izazovi na meč')), findsNothing);
        await capture('profile-${locale.languageCode}');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        auth.dispose();
        api.close();
      },
    );
  }
}
