import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:coathematchmaker/l10n/app_strings.dart';
import 'package:coathematchmaker/models/match.dart';
import 'package:coathematchmaker/models/match_filters.dart';
import 'package:coathematchmaker/models/player.dart';
import 'package:coathematchmaker/screens/matches_screen.dart';
import 'package:coathematchmaker/services/api_client.dart';
import 'package:coathematchmaker/services/auth_service.dart';
import 'package:coathematchmaker/services/league_service.dart';
import 'package:coathematchmaker/theme/app_theme.dart';
import 'support/fixtures.dart';

const longTournament =
    'Kobaja Grande (Sezona 2) - Otvoreno prvenstvo teniskih klubova';
final rows = <Map<String, dynamic>>[
  {
    '_id': 'mine',
    'player1': demoPlayers[0],
    'player2': demoPlayers[1],
    'tournament': {'_id': 't1', 'name': longTournament},
    'status': 'accepted',
    'acceptedAt': '2026-01-01',
    'location': 'SC Morača, Podgorica',
  },
  {
    '_id': 'partner',
    'player1': demoPlayers[1],
    'player2': demoPlayers[2],
    'player1Partner': demoPlayers[3],
    'player2Partner': demoPlayers[0],
    'tournament': {'_id': 't2', 'name': 'Budva Open'},
    'status': 'pending',
    'discipline': 'doubles',
  },
  {
    '_id': 'others',
    'player1': demoPlayers[1],
    'player2': demoPlayers[2],
    'tournament': {'_id': 't2', 'name': 'Budva Open'},
    'status': 'accepted',
    'acceptedAt': '2026-01-01',
  },
  {
    '_id': 'friendly',
    'player1': demoPlayers[1],
    'player2': demoPlayers[2],
    'player1Partner': demoPlayers[0],
    'player2Partner': demoPlayers[3],
    'status': 'confirmed',
    'discipline': 'doubles',
    'friendly': true,
    'winner': demoPlayers[2],
    'sets': [
      {'player1Games': 1, 'player2Games': 6},
      {'player1Games': 2, 'player2Games': 6},
    ],
  },
];

List<TennisMatch> get matches => rows.map(TennisMatch.fromJson).toList();
List<String> ids(MatchFilters filters, {String player = 'me'}) =>
    filters.apply(matches, player).map((m) => m.id).toList();

Widget host(Widget child, String language, {double scale = 1}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  locale: Locale(language),
  supportedLocales: AppStrings.supportedLocales,
  localizationsDelegates: const [
    AppStrings.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: const bool.fromEnvironment('CAPTURE_FILTERS')
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
      key: const ValueKey('filters-capture'),
      child: child!,
    ),
  ),
  home: Scaffold(
    appBar: AppBar(title: Text(language == 'en' ? 'Matches' : 'Mečevi')),
    body: child,
  ),
);

Future<AuthService> mount(
  WidgetTester tester, {
  String language = 'sr',
  double scale = 1,
  bool admin = false,
  List<Map<String, dynamic>>? data,
  void Function(String)? onRequest,
}) async {
  final api = ApiClient(
    baseUrl: 'https://fixture.example.test',
    client: MockClient((request) async {
      onRequest?.call(request.url.path);
      return http.Response(
        jsonEncode(
          request.url.path == '/api/settings'
              ? {
                  'settings': {'resultEntryDelayMinutes': 0},
                }
              : {'matches': data ?? rows},
        ),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  );
  final auth = AuthService(api)
    ..currentPlayer = Player.fromJson({
      ...demoPlayers[0],
      'role': admin ? 'admin' : 'player',
    });
  addTearDown(() {
    auth.dispose();
    api.close();
  });
  await tester.pumpWidget(
    host(
      MatchesScreen(league: LeagueService(api), auth: auth),
      language,
      scale: scale,
    ),
  );
  await tester.pumpAndSettle();
  return auth;
}

Future<void> select(
  WidgetTester tester,
  String name,
  String value,
  String label,
) async {
  final field = find.byKey(ValueKey('match-filter-$name-$value'));
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  final option = find.text(label).last;
  await tester.ensureVisible(option);
  await tester.tap(option);
  await tester.pumpAndSettle();
}

void count(WidgetTester tester, int expected, {String language = 'sr'}) =>
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('match-count'))).data,
      '${language == 'en' ? 'Matches' : 'Mečevi'} ($expected)',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_FILTERS')) {
      final data = ByteData.sublistView(
        await File('/System/Library/Fonts/SFNS.ttf').readAsBytes(),
      );
      await (FontLoader('Roboto')..addFont(Future.value(data))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });

  test('All, mine and all four doubles positions; no source-list mutation', () {
    expect(ids(const MatchFilters()), [
      'mine',
      'partner',
      'others',
      'friendly',
    ]);
    expect(ids(const MatchFilters(onlyMine: true)), [
      'mine',
      'partner',
      'friendly',
    ]);
    for (final player in ['me', 'other', 'third', 'fourth']) {
      expect(
        ids(
          const MatchFilters(onlyMine: true, discipline: 'doubles'),
          player: player,
        ),
        ['partner', 'friendly'],
      );
    }
    expect(ids(const MatchFilters(onlyMine: true), player: 'absent'), isEmpty);
    final original = matches;
    final filtered = const MatchFilters().apply(original, 'me');
    filtered.removeLast();
    filtered.sort((a, b) => b.id.compareTo(a.id));
    expect(original.map((m) => m.id), [
      'mine',
      'partner',
      'others',
      'friendly',
    ]);
  });

  test('Status, tournament, type, discipline and search intersect', () {
    expect(ids(const MatchFilters(status: 'pending')), ['partner']);
    expect(ids(const MatchFilters(type: 'competitive')), [
      'mine',
      'partner',
      'others',
    ]);
    expect(ids(const MatchFilters(tournament: 'none')), ['friendly']);
    expect(
      ids(
        const MatchFilters(
          onlyMine: true,
          status: 'pending',
          tournament: 't2',
          discipline: 'doubles',
          type: 'competitive',
          query: 'budva aleksandar',
        ),
      ),
      ['partner'],
    );
    expect(
      ids(
        const MatchFilters(onlyMine: true, status: 'pending', type: 'friendly'),
      ),
      isEmpty,
    );
    expect(ids(const MatchFilters(query: '  MORACA   markovic ')), ['mine']);
    expect(ids(const MatchFilters(query: 'prvenstvo')), ['mine']);
    expect(ids(const MatchFilters(query: 'unknown')), isEmpty);
    expect(const MatchFilters(onlyMine: true).hasFilters, isFalse);
    expect(
      const MatchFilters(
        status: 'pending',
        type: 'friendly',
        query: 'Ana',
      ).count,
      2,
    );
  });

  testWidgets('All / mine switches authorized list without a network reload', (
    tester,
  ) async {
    final requests = <String>[];
    await mount(tester, onRequest: requests.add);
    count(tester, 3);
    expect(requests, ['/api/matches', '/api/settings']);
    await tester.tap(find.text('Svi mečevi'));
    await tester.pumpAndSettle();
    count(tester, 4);
    await tester.tap(find.text('Samo moji'));
    await tester.pumpAndSettle();
    count(tester, 3);
    expect(requests.length, 2);
  });

  testWidgets(
    'Combined filters, cancel, reset, refresh and missing tournament',
    (tester) async {
      final currentRows = [...rows];
      await mount(tester, admin: true, data: currentRows);
      count(tester, 4);
      await tester.tap(find.byKey(const ValueKey('match-filters')));
      await tester.pumpAndSettle();
      await select(tester, 'tournament', 'all', longTournament);
      await select(tester, 'discipline', 'all', 'Singl');
      await tester.ensureVisible(
        find.byKey(const ValueKey('apply-match-filters')),
      );
      await tester.tap(find.byKey(const ValueKey('apply-match-filters')));
      await tester.pumpAndSettle();
      count(tester, 1);
      await tester.tap(find.byKey(const ValueKey('match-filters')));
      await tester.pumpAndSettle();
      await select(tester, 'type', 'all', 'Prijateljski');
      await tester.ensureVisible(find.byTooltip('Zatvori'));
      await tester.tap(find.byTooltip('Zatvori'));
      await tester.pumpAndSettle();
      count(tester, 1);
      currentRows.removeAt(0);
      final refresh = tester
          .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
          .show();
      await tester.pumpAndSettle();
      await refresh;
      count(tester, 0);
      expect(find.text('Nema mečeva za ovaj filter.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('match-filters')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('match-filter-tournament-t1')),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Ukloni filtere').last);
      await tester.tap(find.text('Ukloni filtere').last);
      await tester.tap(find.byKey(const ValueKey('apply-match-filters')));
      await tester.pumpAndSettle();
      count(tester, 3);
    },
  );

  testWidgets('Search empty state clears without changing My selection', (
    tester,
  ) async {
    await mount(tester);
    await tester.enterText(
      find.byKey(const ValueKey('match-search')),
      'moraca',
    );
    await tester.pumpAndSettle();
    count(tester, 1);
    await tester.enterText(find.byKey(const ValueKey('match-search')), 'nema');
    await tester.pumpAndSettle();
    count(tester, 0);
    await tester.tap(find.byKey(const ValueKey('clear-match-filters')));
    await tester.pumpAndSettle();
    count(tester, 3);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('match-search')))
          .controller!
          .text,
      '',
    );
  });

  for (final status in ['accepted', 'waiting_confirmation', 'pending']) {
    testWidgets('Other players cannot manage a $status match in All', (
      tester,
    ) async {
      await mount(
        tester,
        data: [
          {...rows[2], 'status': status, 'resultSubmittedBy': demoPlayers[1]},
        ],
      );
      count(tester, 0);
      await tester.tap(find.text('Svi mečevi'));
      await tester.pumpAndSettle();
      count(tester, 1);
      expect(find.text('Prihvati'), findsNothing);
      expect(find.text('Unesi rezultat'), findsNothing);
      expect(find.text('Potvrdi rezultat'), findsNothing);
      expect(find.text('Ospori rezultat'), findsNothing);
    });
  }

  testWidgets(
    'Challenged doubles partner can accept, submitter cannot self-confirm',
    (tester) async {
      await mount(tester, data: [rows[1]]);
      expect(find.text('Prihvati'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await mount(
        tester,
        data: [
          {
            ...rows[0],
            'status': 'waiting_confirmation',
            'resultSubmittedBy': demoPlayers[0],
          },
        ],
      );
      expect(find.text('Potvrdi rezultat'), findsNothing);
      expect(find.text('Ospori rezultat'), findsNothing);
    },
  );

  for (final language in ['sr', 'en']) {
    for (final (size, scale) in [
      (const Size(390, 844), 1.0),
      (const Size(320, 568), 1.5),
      (const Size(320, 568), 2.0),
    ]) {
      testWidgets('Score and winner use separate rows $language $size $scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final winner = playerJson(
          'other',
          'Pavle Aleksandar',
          lastName: 'Šćekić Petrović Nikolić',
        );
        const fullName = 'Pavle Aleksandar Šćekić Petrović Nikolić';
        await mount(
          tester,
          language: language,
          scale: scale,
          admin: true,
          data: [
            {
              ...rows.last,
              'player1': demoPlayers[0],
              'player2': winner,
              'player1Partner': null,
              'player2Partner': null,
              'discipline': 'singles',
              'friendly': false,
              'winner': winner,
            },
          ],
        );
        final winnerName = find.text(fullName).last;
        await tester.ensureVisible(winnerName);
        await tester.pumpAndSettle();
        final score = tester.getRect(find.text('1-6, 2-6'));
        final total = tester.getRect(find.text('0-2'));
        final name = tester.getRect(winnerName);
        expect(name.top, greaterThan(score.bottom));
        expect(name.top, greaterThan(total.bottom));
        expect(total.left, greaterThanOrEqualTo(score.right));
        final text = tester.widget<Text>(winnerName);
        expect(text.maxLines, isNull);
        expect(text.softWrap, isTrue);
        expect(text.overflow, isNot(TextOverflow.ellipsis));
        final paragraph = tester.renderObject<RenderParagraph>(winnerName);
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(name.left, greaterThanOrEqualTo(0));
        expect(name.right, lessThanOrEqualTo(size.width));
        final trophy = tester.getRect(find.byIcon(Icons.emoji_events).last);
        expect(trophy.right, lessThan(name.left));
        expect(trophy.center.dy, closeTo(name.center.dy, 1));
        expect(
          find.text(
            AppStrings(Locale(language)).text('Upravljanje rezultatom'),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('CAPTURE_FILTERS')) {
          await expectLater(
            find.byKey(const ValueKey('filters-capture')),
            matchesGoldenFile(
              '../.local-backups/score-winner-layout-20260910/$language-${size.width.toInt()}-$scale.png',
            ),
          );
        }
      });
    }

    testWidgets('Inconsistent card score has no winner trophy ($language)', (
      tester,
    ) async {
      await mount(
        tester,
        language: language,
        admin: true,
        data: [
          {...rows.last, 'winner': rows.last['player1']},
        ],
      );
      expect(find.text('1-6, 2-6'), findsOneWidget);
      expect(find.byIcon(Icons.emoji_events), findsNothing);
      expect(tester.takeException(), isNull);
    });

    for (final (size, scale) in [
      (const Size(390, 844), 1.0),
      (const Size(320, 568), 1.5),
    ]) {
      testWidgets('Match filters and long names fit $language $size scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await mount(
          tester,
          language: language,
          scale: scale,
          data: [rows.first],
        );
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('CAPTURE_FILTERS')) {
          await expectLater(
            find.byKey(const ValueKey('filters-capture')),
            matchesGoldenFile(
              '../.local-backups/match-filters-20260909/list-$language-${size.width.toInt()}.png',
            ),
          );
        }
        await tester.tap(find.byKey(const ValueKey('match-filters')));
        await tester.pumpAndSettle();
        await select(tester, 'tournament', 'all', longTournament);
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('CAPTURE_FILTERS')) {
          await expectLater(
            find.byKey(const ValueKey('filters-capture')),
            matchesGoldenFile(
              '../.local-backups/match-filters-20260909/sheet-$language-${size.width.toInt()}.png',
            ),
          );
        }
        await tester.ensureVisible(
          find.byKey(const ValueKey('apply-match-filters')),
        );
        await tester.tap(find.byKey(const ValueKey('apply-match-filters')));
        await tester.pumpAndSettle();
        count(tester, 1, language: language);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
