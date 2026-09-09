import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:coathematchmaker/l10n/app_strings.dart';
import 'package:coathematchmaker/l10n/english.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coathematchmaker/main.dart';
import 'package:coathematchmaker/screens/messages_screen.dart';
import 'package:coathematchmaker/screens/players_screen.dart';
import 'package:coathematchmaker/services/auth_service.dart';
import 'package:coathematchmaker/services/league_service.dart';
import 'package:coathematchmaker/theme/app_theme.dart';
import 'support/fixtures.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Inbox refresh never triggers the parent refresh feedback loop', (
    tester,
  ) async {
    var requests = 0;
    var tick = 0;
    final api = fixtureApi(
      onRequest: (uri) {
        if (uri.path == '/api/messages/conversations') requests++;
      },
    );
    final auth = AuthService(api)..currentPlayer = demoPlayer;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (_, setParent) => MessagesScreen(
            league: LeagueService(api),
            api: api,
            auth: auth,
            refreshTick: tick,
            onChanged: () => setParent(() => tick++),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(requests, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(requests, 1);
    expect(tick, 0);
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();
    expect(requests, 2);
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
    api.close();
  });

  for (final locale in AppStrings.supportedLocales) {
    for (final (size, textScale) in [
      (const Size(320, 568), 1.0),
      (const Size(390, 844), 1.0),
      (const Size(1024, 1366), 1.0),
      (const Size(320, 568), 1.5),
    ]) {
      testWidgets(
        'Five-tab shell and all main screens fit at $size, text $textScale, $locale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final api = fixtureApi();
          final auth = AuthService(api)..currentPlayer = demoPlayer;
          await tester.pumpWidget(
            MaterialApp(
              locale: locale,
              supportedLocales: AppStrings.supportedLocales,
              localizationsDelegates: const [
                AppStrings.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              theme: AppTheme.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
              home: MainShell(auth: auth, api: api, league: LeagueService(api)),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(NavigationDestination), findsNWidgets(5));
          for (final label in [
            'Igrači',
            'Turniri',
            'Mečevi',
            'Rang-lista',
            'Početna',
          ]) {
            await tester.tap(
              find.descendant(
                of: find.byType(NavigationBar),
                matching: find.text(AppStrings(locale).text(label)),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.byType(MainShell), findsOneWidget);
            if (locale.languageCode == 'en') {
              for (final widget in tester.widgetList<Text>(find.byType(Text))) {
                final source = widget.data;
                if (source != null && englishMessages.containsKey(source)) {
                  expect(
                    englishMessages[source],
                    source,
                    reason: 'Untranslated text on $label: $source',
                  );
                }
              }
            }
          }
          await tester.pumpWidget(const SizedBox());
          auth.dispose();
          api.close();
        },
      );
    }

    testWidgets(
      'Player profile and statistics fit with enlarged text, $locale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = fixtureApi();
        final auth = AuthService(api)..currentPlayer = demoPlayer;
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            supportedLocales: AppStrings.supportedLocales,
            localizationsDelegates: const [
              AppStrings.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: PlayerProfileScreen(
              playerId: 'other',
              api: api,
              auth: auth,
              league: LeagueService(api),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Ana Marković'), findsOneWidget);
        await tester.drag(find.byType(ListView).first, const Offset(0, -550));
        await tester.pumpAndSettle();
        expect(find.text(AppStrings(locale).text('Poeni')), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        auth.dispose();
        api.close();
      },
    );
  }
}
