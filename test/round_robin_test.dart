import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:coathematchmaker/l10n/app_strings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:coathematchmaker/models/match.dart';
import 'package:coathematchmaker/models/tournament.dart';
import 'package:coathematchmaker/screens/tournaments_screen.dart';
import 'package:coathematchmaker/services/api_client.dart';
import 'package:coathematchmaker/services/league_service.dart';
import 'package:coathematchmaker/theme/app_theme.dart';
import 'package:coathematchmaker/widgets/tournament_phases.dart';
import 'support/fixtures.dart';

Map<String, dynamic> tournamentJson({int size = 4, bool started = false}) => {
  '_id': 'league',
  'name': 'Kobaja Grande (Sezona 2)',
  'format': 'round_robin',
  'discipline': 'singles',
  'knockoutSize': size,
  'status': 'active',
  'location': 'SC Moraca',
  'participants': demoPlayers,
  'drawGeneratedAt': '2026-09-01',
  if (started) 'knockoutStartedAt': '2026-09-09',
};

Map<String, dynamic> stateJson({
  bool started = false,
  bool ready = true,
  bool finished = false,
}) => {
  'standings': [
    for (var i = 0; i < 4; i++)
      {
        'playerId': demoPlayers[i]['_id'],
        'seed': i + 1,
        'played': 3,
        'wins': 3 - i,
        'losses': i,
        'setsWon': 6 - i,
        'setsLost': i,
        'gamesWon': 36 - i * 4,
        'gamesLost': 12 + i * 4,
      },
  ],
  'seeds': demoPlayers.map((p) => p['_id']).toList(),
  'pairs': [
    ['me', 'fourth'],
    ['other', 'third'],
  ],
  'rankingRules':
      'Pobjede; međusobni mečevi; razlika setova; razlika gemova; redoslijed prijave.',
  'canStart': !started && ready,
  'started': started,
  'finished': finished,
  'canAdvance': started && ready && !finished,
  'currentRound': started ? 'SF' : null,
  'winnerId': finished ? 'me' : null,
  'blockedReason': ready
      ? null
      : 'Svi ligaški mečevi moraju imati potvrđen rezultat.',
};

LeagueService service(
  Map<String, dynamic> state, {
  void Function(http.Request)? onRequest,
  int? error,
}) => LeagueService(
  ApiClient(
    baseUrl: 'https://fixture.example.test',
    client: MockClient((request) async {
      onRequest?.call(request);
      if (error != null) {
        return http.Response(
          jsonEncode({'message': 'Probajte ponovo.'}),
          error,
        );
      }
      return http.Response(
        jsonEncode({'roundRobin': state, 'tournament': tournamentJson()}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  ),
);

Widget host(
  Widget child, {
  double scale = 1,
  Locale locale = const Locale('sr'),
}) => RepaintBoundary(
  key: const Key('capture-knockout'),
  child: MaterialApp(
    locale: locale,
    supportedLocales: AppStrings.supportedLocales,
    localizationsDelegates: const [
      AppStrings.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    debugShowCheckedModeBanner: false,
    theme: const bool.fromEnvironment('CAPTURE_KNOCKOUT')
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
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: child,
  ),
);

Widget phases(
  LeagueService league, {
  bool started = false,
  bool manager = true,
  VoidCallback? changed,
}) => Scaffold(
  appBar: AppBar(title: const Text('Turnir')),
  body: SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: TournamentPhases(
      tournament: Tournament.fromJson(tournamentJson(started: started)),
      league: league,
      canManage: manager,
      onChanged: changed ?? () {},
      matches: [
        for (final round in ['RR', 'SF'])
          TennisMatch.fromJson({
            '_id': round,
            'player1': demoPlayers[0],
            'player2': demoPlayers[3],
            'round': round,
            'status': 'confirmed',
            'sets': [
              {'player1Games': 6, 'player2Games': 2},
            ],
          }),
      ],
    ),
  ),
);

Future<void> capture(String name) async {
  if (const bool.fromEnvironment('CAPTURE_KNOCKOUT')) {
    await expectLater(
      find.byKey(const Key('capture-knockout')),
      matchesGoldenFile(
        '../.local-backups/round-robin-knockout-20260909/$name.png',
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_KNOCKOUT')) {
      await (FontLoader('Roboto')..addFont(
            File(
              '/System/Library/Fonts/SFNS.ttf',
            ).readAsBytes().then(ByteData.sublistView),
          ))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });

  test(
    'old round-robin stays plain; enabled option has its own display name',
    () {
      final old = Tournament.fromJson({'_id': 'old', 'format': 'round_robin'});
      expect(old.knockoutSize, 0);
      expect(old.knockoutStarted, false);
      expect(old.formatLabel, 'Round-robin');
      expect(
        Tournament.fromJson(tournamentJson()).formatLabel,
        'Round-robin + knockout',
      );
    },
  );

  for (final locale in AppStrings.supportedLocales) {
    final tr = AppStrings(locale).text;
    for (final width in [320.0, 390.0, 1024.0]) {
      testWidgets(
        'league table and knockout preview fit width $width, $locale',
        (tester) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final posts = <http.Request>[];
          await tester.pumpWidget(
            host(
              phases(
                service(
                  stateJson(),
                  onRequest: (r) {
                    if (r.method == 'POST') posts.add(r);
                  },
                ),
              ),
              scale: width == 320 ? 1.4 : 1,
              locale: locale,
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(tr('Tabela lige')), findsOneWidget);
          expect(tester.takeException(), isNull);
          if (locale.languageCode != 'en') {
            await capture('league-${width.toInt()}');
          }
          await tester.ensureVisible(
            find.text(tr('Pregledaj knockout parove')),
          );
          await tester.tap(find.text(tr('Pregledaj knockout parove')));
          await tester.pumpAndSettle();
          expect(find.text(tr('Potvrdi knockout parove')), findsOneWidget);
          expect(posts, isEmpty);
          expect(tester.takeException(), isNull);
          if (locale.languageCode != 'en') {
            await capture('preview-${width.toInt()}');
          }
          await tester.tap(find.text(tr('Odustani')));
          await tester.pumpAndSettle();
          expect(posts, isEmpty);
          await tester.tap(find.text(tr('Pregledaj knockout parove')));
          await tester.pumpAndSettle();
          await tester.tap(find.text(tr('Pokreni knockout')));
          await tester.pumpAndSettle();
          expect(posts.length, 1);
          expect(
            posts.single.url.path,
            '/api/tournaments/league/start-knockout',
          );
          expect(jsonDecode(posts.single.body)['seeds'], [
            'me',
            'other',
            'third',
            'fourth',
          ]);
        },
      );
    }
  }

  testWidgets(
    'incomplete league blocks start and non-admin has no mutation controls',
    (tester) async {
      await tester.pumpWidget(host(phases(service(stateJson(ready: false)))));
      await tester.pumpAndSettle();
      final button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Pregledaj knockout parove'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNull);
      await tester.pumpWidget(
        host(phases(service(stateJson()), manager: false)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pregledaj knockout parove'), findsNothing);
    },
  );

  testWidgets(
    'knockout advances selected round and league remains a separate view',
    (tester) async {
      final posts = <http.Request>[];
      await tester.pumpWidget(
        host(
          phases(
            service(
              stateJson(started: true),
              onRequest: (r) {
                if (r.method == 'POST') posts.add(r);
              },
            ),
            started: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tabela lige'), findsNothing);
      await capture('knockout');
      await tester.tap(find.text('Formiraj narednu rundu'));
      await tester.pumpAndSettle();
      expect(jsonDecode(posts.single.body)['round'], 'SF');
      await tester.tap(find.text('Liga'));
      await tester.pumpAndSettle();
      expect(find.text('Tabela lige'), findsOneWidget);
    },
  );

  testWidgets(
    'existing league edit saves optional knockout size without changing format',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <http.Request>[];
      await tester.pumpWidget(
        host(
          TournamentFormScreen(
            league: service(stateJson(), onRequest: requests.add),
            tournament: Tournament.fromJson(tournamentJson(size: 0)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Knockout završnica').hitTestable(),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Knockout završnica'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Broj učesnika u završnici'));
      await Scrollable.ensureVisible(
        tester.element(find.text('Round-robin + knockout (opciono)')),
        alignment: .1,
      );
      await tester.pumpAndSettle();
      await capture('option');
      expect(find.text('Round-robin + knockout (opciono)'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Sačuvaj turnir').hitTestable(),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sačuvaj turnir'));
      await tester.pumpAndSettle();
      final patch = requests.firstWhere((r) => r.method == 'PATCH');
      expect(jsonDecode(patch.body)['format'], 'round_robin');
      expect(jsonDecode(patch.body)['knockoutSize'], 4);
      expect(tester.takeException(), isNull);
    },
  );
}
