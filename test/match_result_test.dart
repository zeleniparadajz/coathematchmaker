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
import 'package:coathematchmaker/screens/matches_screen.dart';
import 'package:coathematchmaker/services/api_client.dart';
import 'package:coathematchmaker/services/league_service.dart';
import 'package:coathematchmaker/theme/app_theme.dart';
import 'support/fixtures.dart';

Map<String, dynamic> matchJson({
  String status = 'disputed',
  bool inconsistent = false,
  bool legacy = false,
}) => {
  '_id': 'match',
  'player1': demoPlayers[0],
  'player2': demoPlayers[1],
  'winner': demoPlayers[inconsistent ? 0 : 1],
  'resultSubmittedBy': demoPlayers[0],
  'status': status,
  'round': 'Challenge',
  'friendly': false,
  if (!legacy) 'statsWinPoints': 10,
  'sets': [
    {'player1Games': 1, 'player2Games': 6},
    {'player1Games': 2, 'player2Games': 6},
  ],
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
  theme: const bool.fromEnvironment('CAPTURE_RESULT')
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
      key: const ValueKey('result-capture'),
      child: child!,
    ),
  ),
  home: child,
);

LeagueService service(List<Map<String, dynamic>> requests, {int error = 0}) =>
    LeagueService(
      ApiClient(
        baseUrl: 'https://fixture.example.test',
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          requests.add(body);
          return http.Response(
            jsonEncode(
              error == 0
                  ? {
                      'match': {
                        ...matchJson(),
                        'status': body['action'] == 'confirm'
                            ? 'confirmed'
                            : 'accepted',
                        'sets': body['action'] == 'confirm' ? body['sets'] : [],
                        'winner': body['action'] == 'confirm'
                            ? demoPlayers.firstWhere(
                                (player) => player['_id'] == body['winner'],
                              )
                            : null,
                      },
                    }
                  : {
                      'message':
                          'Meč je u međuvremenu promijenjen. Osvježite prikaz.',
                    },
            ),
            error == 0 ? 200 : error,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      ),
    );

Future<void> visible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_RESULT')) {
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
  test('result consistency and eligible admin actions', () {
    expect(TennisMatch.fromJson(matchJson()).hasConsistentResult, isTrue);
    expect(
      TennisMatch.fromJson(matchJson(inconsistent: true)).hasConsistentResult,
      isFalse,
    );
    expect(scoreWinnerSide([]), isNull);
    expect(
      scoreWinnerSide([const SetScore(player1Games: 6, player2Games: 6)]),
      isNull,
    );
    expect(
      scoreWinnerSide([
        const SetScore(player1Games: 6, player2Games: 1),
        const SetScore(player1Games: 1, player2Games: 6),
      ]),
      isNull,
    );
    for (final status in ['disputed', 'rejected', 'cancelled']) {
      final match = TennisMatch.fromJson(matchJson(status: status));
      expect(match.canRestoreResult, isTrue);
      expect(match.canReopenResult, isTrue);
    }
    expect(
      TennisMatch.fromJson(matchJson(status: 'confirmed')).canReopenResult,
      isTrue,
    );
    expect(
      TennisMatch.fromJson(matchJson(status: 'confirmed')).canRestoreResult,
      isFalse,
    );
    expect(
      TennisMatch.fromJson(matchJson(status: 'accepted')).canReopenResult,
      isFalse,
    );
  });

  for (final language in ['sr', 'en']) {
    final strings = AppStrings(Locale(language));
    for (final status in ['cancelled', 'rejected', 'disputed']) {
      testWidgets(
        'admin confirms $status using calculated winner, not stale saved winner ($language)',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final requests = <Map<String, dynamic>>[];
          await tester.pumpWidget(
            host(
              AdminResolveScreen(
                league: service(requests),
                match: TennisMatch.fromJson(
                  matchJson(status: status, inconsistent: true),
                ),
              ),
              language,
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.text(strings.text('Pobjednik: {p0}', ['Ana Marković'])),
            findsOneWidget,
          );
          expect(
            find.text(
              strings.text(
                'Pobjednik se ne slaže sa rezultatom setova. Provjerite rezultat.',
              ),
            ),
            findsNothing,
          );
          final confirm = find.widgetWithText(
            FilledButton,
            strings.text('Potvrdi rezultat'),
          );
          await visible(tester, confirm);
          expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
          if (const bool.fromEnvironment('CAPTURE_RESULT')) {
            await expectLater(
              find.byKey(const ValueKey('result-capture')),
              matchesGoldenFile(
                '../.local-backups/admin-score-edit-20260909/confirm-$status-$language.png',
              ),
            );
          }
          await tester.tap(confirm);
          await tester.pumpAndSettle();
          expect(requests.single['action'], 'confirm');
          expect(requests.single['winner'], 'other');
          expect(requests.single['sets'], matchJson()['sets']);
          expect(tester.takeException(), isNull);
        },
      );
    }
    testWidgets(
      'admin edits sets, gets a new automatic winner and cannot confirm ties ($language)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final requests = <Map<String, dynamic>>[];
        await tester.pumpWidget(
          host(
            AdminResolveScreen(
              league: service(requests),
              match: TennisMatch.fromJson(
                matchJson(status: 'cancelled', inconsistent: true),
              ),
            ),
            language,
            scale: 1.3,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(TextButton, strings.text('Uredi setove')),
        );
        await tester.pumpAndSettle();
        if (const bool.fromEnvironment('CAPTURE_RESULT')) {
          await expectLater(
            find.byKey(const ValueKey('result-capture')),
            matchesGoldenFile(
              '../.local-backups/admin-score-edit-20260909/edit-sets-$language.png',
            ),
          );
        }
        final confirm = find.widgetWithText(
          FilledButton,
          strings.text('Potvrdi rezultat'),
        );
        for (var set = 0; set < 2; set++) {
          final plus = find.byKey(ValueKey('set-$set-player-1-plus'));
          await visible(tester, plus);
          for (var i = 0; i < 5 - set; i++) {
            await tester.tap(plus);
            await tester.pump();
          }
          await visible(tester, confirm);
          expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
          final minus = find.byKey(ValueKey('set-$set-player-2-minus'));
          await visible(tester, minus);
          for (var i = 0; i < 5 - set; i++) {
            await tester.tap(minus);
            await tester.pump();
          }
        }
        final add = find.widgetWithText(
          OutlinedButton,
          strings.text('Dodaj set'),
        );
        await visible(tester, add);
        await tester.tap(add);
        await tester.pumpAndSettle();
        await visible(tester, confirm);
        expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
        final remove = find.byTooltip(strings.text('Ukloni set')).last;
        await visible(tester, remove);
        await tester.tap(remove);
        await tester.pumpAndSettle();
        final done = find.widgetWithText(
          TextButton,
          strings.text('Završi uređivanje'),
        );
        await visible(tester, done);
        await tester.tap(done);
        await tester.pumpAndSettle();
        expect(
          find.text(strings.text('Pobjednik: {p0}', ['Marko Marković'])),
          findsOneWidget,
        );
        expect(requests, isEmpty);
        await visible(tester, confirm);
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(requests.single['winner'], 'me');
        expect(requests.single['sets'], [
          {'player1Games': 6, 'player2Games': 1},
          {'player1Games': 6, 'player2Games': 2},
        ]);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'failed admin confirmation keeps score draft and allows retry ($language)',
      (tester) async {
        final requests = <Map<String, dynamic>>[];
        await tester.pumpWidget(
          host(
            AdminResolveScreen(
              league: service(requests, error: 409),
              match: TennisMatch.fromJson(
                matchJson(status: 'cancelled', inconsistent: true),
              ),
            ),
            language,
          ),
        );
        await tester.pumpAndSettle();
        final confirm = find.widgetWithText(
          FilledButton,
          strings.text('Potvrdi rezultat'),
        );
        await visible(tester, confirm);
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(
          find.text(
            strings.text('Meč je u međuvremenu promijenjen. Osvježite prikaz.'),
          ),
          findsOneWidget,
        );
        expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(requests.length, 2);
        expect(requests.first, requests.last);
        expect(requests.first['winner'], 'other');
      },
    );
    testWidgets(
      'score entry computes the winner and sends matching scores ($language)',
      (tester) async {
        tester.view.physicalSize = const Size(390, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final requests = <Map<String, dynamic>>[];
        await tester.pumpWidget(
          host(
            SubmitResultScreen(
              league: service(requests),
              match: TennisMatch.fromJson(matchJson(status: 'accepted')),
            ),
            language,
          ),
        );
        await tester.pumpAndSettle();
        final send = find.widgetWithText(
          FilledButton,
          strings.text('Pošalji na potvrdu'),
        );
        await visible(tester, send);
        expect(tester.widget<FilledButton>(send).onPressed, isNull);
        for (var set = 0; set < 2; set++) {
          for (var side = 1; side <= 2; side++) {
            final plus = find.byKey(ValueKey('set-$set-player-$side-plus'));
            await visible(tester, plus);
            for (var i = 0; i < (side == 1 ? set + 1 : 6); i++) {
              await tester.tap(plus);
              await tester.pump();
            }
          }
        }
        final winner = find.byKey(const ValueKey('result-winner'));
        await visible(tester, winner);
        expect(tester.widget<Text>(winner).data, 'Ana Marković');
        await visible(tester, send);
        expect(tester.widget<FilledButton>(send).onPressed, isNotNull);
        await tester.tap(send);
        await tester.pumpAndSettle();
        expect(requests.single['winner'], 'other');
        expect(requests.single['sets'], matchJson()['sets']);
        expect(tester.takeException(), isNull);
      },
    );

    for (final status in ['disputed', 'rejected', 'cancelled', 'confirmed']) {
      testWidgets('admin reopens $status after confirmation ($language)', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final requests = <Map<String, dynamic>>[];
        await tester.pumpWidget(
          host(
            AdminResolveScreen(
              league: service(requests),
              match: TennisMatch.fromJson(matchJson(status: status)),
            ),
            language,
            scale: 1.3,
          ),
        );
        await tester.pumpAndSettle();
        final reopen = find.widgetWithText(
          OutlinedButton,
          strings.text('Vrati na unos rezultata'),
        );
        await visible(tester, reopen);
        if (const bool.fromEnvironment('CAPTURE_RESULT')) {
          await expectLater(
            find.byKey(const ValueKey('result-capture')),
            matchesGoldenFile(
              '../.local-backups/result-consistency-20260909/admin-$status-$language.png',
            ),
          );
        }
        await tester.tap(reopen);
        await tester.pumpAndSettle();
        expect(requests, isEmpty);
        await tester.tap(
          find.widgetWithText(TextButton, strings.text('Odustani')),
        );
        await tester.pumpAndSettle();
        expect(requests, isEmpty);
        await tester.tap(reopen);
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(FilledButton, strings.text('Vrati')),
        );
        await tester.pumpAndSettle();
        expect(requests.single['action'], 'reopen_result');
        expect(requests.single.containsKey('winner'), isFalse);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
      'legacy confirmed result requires original points ($language)',
      (tester) async {
        final requests = <Map<String, dynamic>>[];
        await tester.pumpWidget(
          host(
            AdminResolveScreen(
              league: service(requests),
              match: TennisMatch.fromJson(
                matchJson(status: 'confirmed', legacy: true),
              ),
            ),
            language,
          ),
        );
        await tester.pumpAndSettle();
        final reopen = find.widgetWithText(
          OutlinedButton,
          strings.text('Vrati na unos rezultata'),
        );
        await visible(tester, reopen);
        await tester.tap(reopen);
        await tester.pumpAndSettle();
        expect(requests, isEmpty);
        expect(find.byType(AlertDialog), findsNothing);
        final input = find.widgetWithText(
          TextFormField,
          strings.text('Ranije dodijeljeni poeni za pobjedu'),
        );
        await visible(tester, input);
        await tester.enterText(input, '15');
        await visible(tester, reopen);
        await tester.tap(reopen);
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(FilledButton, strings.text('Vrati')),
        );
        await tester.pumpAndSettle();
        expect(requests.single['legacyWinPoints'], 15);
      },
    );

    testWidgets(
      'inconsistent result is flagged, without a false trophy ($language)',
      (tester) async {
        final requests = <Map<String, dynamic>>[];
        await tester.pumpWidget(
          host(
            MatchDetailsScreen(
              league: service(requests),
              match: TennisMatch.fromJson(matchJson(inconsistent: true)),
              settings: LeagueSettings.fromJson({}),
              currentPlayerId: 'me',
              isAdmin: true,
            ),
            language,
          ),
        );
        await tester.pumpAndSettle();
        final warning = find.text(
          strings.text(
            'Pobjednik se ne slaže sa rezultatom setova. Provjerite rezultat.',
          ),
        );
        await visible(tester, warning);
        expect(find.byIcon(Icons.emoji_events), findsNothing);
        expect(warning, findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
