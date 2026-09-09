import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:coathematchmaker/l10n/app_strings.dart';
import 'package:coathematchmaker/models/league_settings.dart';
import 'package:coathematchmaker/models/match.dart';
import 'package:coathematchmaker/screens/deletion_screen.dart';
import 'package:coathematchmaker/screens/matches_screen.dart';
import 'package:coathematchmaker/services/api_client.dart';
import 'package:coathematchmaker/services/league_service.dart';
import 'package:coathematchmaker/theme/app_theme.dart';
import 'support/fixtures.dart';

const title = 'Kobaja Grande (Sezona 2) - Otvoreno prvenstvo teniskih klubova';
Map<String, dynamic> preview({bool legacy = false, bool blocked = false}) => {
  'revision': 'a' * 64,
  'matchCount': 12,
  'imageCount': 5,
  'legacyMatches': legacy
      ? [
          {'id': 'old', 'label': 'Luka Vojvodić - Pavle Šćekić'},
        ]
      : [],
  'needsLegacyTournamentAward': legacy,
  'blockedReason': blocked
      ? 'Meč je dio formiranog žrijeba ili utiče na kasnije runde. Možete ispraviti rezultat ili obrisati cijeli turnir sa svim mečevima.'
      : null,
};

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
  theme: const bool.fromEnvironment('CAPTURE_DELETION')
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
      key: const ValueKey('deletion-capture'),
      child: child!,
    ),
  ),
  home: child,
);

LeagueService service(
  List<Map<String, dynamic>> requests, {
  bool legacy = false,
  bool blocked = false,
  int error = 0,
  Completer<void>? hold,
}) {
  final api = ApiClient(
    baseUrl: 'https://fixture.example.test',
    client: MockClient((request) async {
      if (request.method == 'DELETE') {
        requests.add({
          'path': request.url.path,
          ...jsonDecode(request.body) as Map<String, dynamic>,
        });
        if (hold != null) await hold.future;
        return http.Response(
          jsonEncode(
            error == 0
                ? {'deleted': true}
                : {
                    'message': error == 409
                        ? 'Podaci su promijenjeni. Ponovo otvorite potvrdu brisanja.'
                        : 'Greška na serveru. Pokušajte ponovo.',
                  },
          ),
          error == 0 ? 200 : error,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response(
        jsonEncode({'preview': preview(legacy: legacy, blocked: blocked)}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  );
  addTearDown(api.close);
  return LeagueService(api);
}

Future<void> visible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_DELETION')) {
      final data = ByteData.sublistView(
        await File('/System/Library/Fonts/SFNS.ttf').readAsBytes(),
      );
      await (FontLoader('Roboto')..addFont(Future.value(data))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });

  for (final tournament in [false, true]) {
    testWidgets(
      'Explicit confirmation and success navigation: tournament=$tournament',
      (tester) async {
        final requests = <Map<String, dynamic>>[];
        final league = service(requests);
        bool? result;
        await tester.pumpWidget(
          host(
            Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DeletionScreen(
                          league: league,
                          id: 'target',
                          title: title,
                          tournament: tournament,
                        ),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
            'en',
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await visible(tester, find.byKey(const ValueKey('delete-permanently')));
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey('delete-permanently')),
              )
              .onPressed,
          isNull,
        );
        expect(requests, isEmpty);
        await tester.tap(find.byKey(const ValueKey('delete-confirmation')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('delete-permanently')));
        await tester.pumpAndSettle();
        expect(
          requests.single['path'],
          '/api/${tournament ? 'tournaments' : 'matches'}/target',
        );
        expect(requests.single['revision'], 'a' * 64);
        expect(result, true);
        expect(find.text('Open'), findsOneWidget);
      },
    );
  }

  testWidgets('Legacy points are required and an error preserves the draft', (
    tester,
  ) async {
    final requests = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      host(
        DeletionScreen(
          league: service(requests, legacy: true, error: 500),
          id: 'target',
          title: title,
          tournament: true,
        ),
        'en',
      ),
    );
    await tester.pumpAndSettle();
    await visible(tester, find.byKey(const ValueKey('delete-confirmation')));
    await tester.tap(find.byKey(const ValueKey('delete-confirmation')));
    await visible(tester, find.byKey(const ValueKey('delete-permanently')));
    await tester.tap(find.byKey(const ValueKey('delete-permanently')));
    await tester.pumpAndSettle();
    expect(requests, isEmpty);
    await visible(tester, find.byKey(const ValueKey('delete-points-old')));
    await tester.enterText(
      find.byKey(const ValueKey('delete-points-old')),
      '17',
    );
    await visible(tester, find.byKey(const ValueKey('delete-legacy-award')));
    await tester.tap(find.byKey(const ValueKey('delete-legacy-award')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes').last);
    await tester.pumpAndSettle();
    await visible(
      tester,
      find.byKey(const ValueKey('delete-tournament-points')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('delete-tournament-points')),
      '50',
    );
    await visible(tester, find.byKey(const ValueKey('delete-permanently')));
    await tester.tap(find.byKey(const ValueKey('delete-permanently')));
    await tester.pumpAndSettle();
    expect(requests.single['legacyMatchPoints'], {'old': 17});
    expect(requests.single['legacyTournamentAwardApplied'], true);
    expect(requests.single['legacyTournamentPoints'], 50);
    expect(find.byType(DeletionScreen), findsOneWidget);
    await visible(tester, find.byKey(const ValueKey('delete-points-old')));
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('delete-points-old')),
          )
          .controller!
          .text,
      '17',
    );
  });

  testWidgets('Blocked draw never offers deletion', (tester) async {
    final requests = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      host(
        DeletionScreen(
          league: service(requests, blocked: true),
          id: 'target',
          title: title,
          tournament: false,
        ),
        'en',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('delete-permanently')), findsNothing);
    expect(find.textContaining('generated draw'), findsOneWidget);
    expect(requests, isEmpty);
  });

  testWidgets('Pending deletion prevents a duplicate request', (tester) async {
    final requests = <Map<String, dynamic>>[];
    final hold = Completer<void>();
    await tester.pumpWidget(
      host(
        DeletionScreen(
          league: service(requests, hold: hold, error: 500),
          id: 'target',
          title: title,
          tournament: false,
        ),
        'en',
      ),
    );
    await tester.pumpAndSettle();
    await visible(tester, find.byKey(const ValueKey('delete-confirmation')));
    await tester.tap(find.byKey(const ValueKey('delete-confirmation')));
    await visible(tester, find.byKey(const ValueKey('delete-permanently')));
    await tester.tap(find.byKey(const ValueKey('delete-permanently')));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('delete-permanently')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const ValueKey('delete-confirmation')),
          )
          .onChanged,
      isNull,
    );
    expect(requests.length, 1);
    hold.complete();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('delete-permanently')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('Stale preview must refresh and be confirmed again', (
    tester,
  ) async {
    final requests = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      host(
        DeletionScreen(
          league: service(requests, error: 409),
          id: 'target',
          title: title,
          tournament: false,
        ),
        'en',
      ),
    );
    await tester.pumpAndSettle();
    await visible(tester, find.byKey(const ValueKey('delete-confirmation')));
    await tester.tap(find.byKey(const ValueKey('delete-confirmation')));
    await visible(tester, find.byKey(const ValueKey('delete-permanently')));
    await tester.tap(find.byKey(const ValueKey('delete-permanently')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('delete-permanently')),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Refresh preview'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const ValueKey('delete-confirmation')),
          )
          .value,
      false,
    );
    expect(requests.length, 1);
  });

  for (final admin in [false, true]) {
    testWidgets('Match delete action is admin-only: $admin', (tester) async {
      final league = service([]);
      await tester.pumpWidget(
        host(
          MatchDetailsScreen(
            league: league,
            match: TennisMatch.fromJson({
              '_id': 'match',
              'player1': demoPlayers[0],
              'player2': demoPlayers[1],
            }),
            settings: LeagueSettings.fromJson({}),
            currentPlayerId: 'me',
            isAdmin: admin,
          ),
          'en',
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byTooltip('Delete match'),
        admin ? findsOneWidget : findsNothing,
      );
    });
  }

  for (final language in ['sr', 'en']) {
    for (final (size, scale) in [
      (const Size(390, 844), 1.0),
      (const Size(320, 568), 1.5),
    ]) {
      testWidgets('Deletion fits $language $size with text $scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          host(
            DeletionScreen(
              league: service([]),
              id: 'target',
              title: title,
              tournament: true,
            ),
            language,
            scale: scale,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('CAPTURE_DELETION')) {
          await expectLater(
            find.byKey(const ValueKey('deletion-capture')),
            matchesGoldenFile(
              '../.local-backups/deletion-20260909/delete-$language-${size.width.toInt()}.png',
            ),
          );
        }
        await visible(
          tester,
          find.byKey(const ValueKey('delete-confirmation')),
        );
        await tester.tap(find.byKey(const ValueKey('delete-confirmation')));
        await visible(tester, find.byKey(const ValueKey('delete-permanently')));
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey('delete-permanently')),
              )
              .onPressed,
          isNotNull,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
