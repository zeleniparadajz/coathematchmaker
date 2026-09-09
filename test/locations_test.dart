import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:coathematchmaker/l10n/app_strings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:coathematchmaker/models/tournament.dart';
import 'package:coathematchmaker/models/app_location.dart';
import 'package:coathematchmaker/screens/locations_screen.dart';
import 'package:coathematchmaker/screens/tournaments_screen.dart';
import 'package:coathematchmaker/services/api_client.dart';
import 'package:coathematchmaker/services/auth_service.dart';
import 'package:coathematchmaker/services/league_service.dart';
import 'package:coathematchmaker/services/maps_service.dart';
import 'package:coathematchmaker/theme/app_theme.dart';
import 'package:coathematchmaker/widgets/location_picker.dart';
import 'package:coathematchmaker/widgets/map_location_card.dart';
import 'package:coathematchmaker/widgets/sport_surfaces.dart';
import 'support/fixtures.dart';

const venues = [
  {
    '_id': '123456789012345678901234',
    'name': 'Teniski klub Budva',
    'address': 'Budva',
    'googlePlaceId': 'place-a',
  },
  {
    '_id': '123456789012345678901235',
    'name': 'Sportski centar sa dugackim nazivom terena',
    'address': 'Podgorica',
  },
];

ApiClient locationApi({
  void Function(http.Request)? onRequest,
  int? searchError,
}) => ApiClient(
  baseUrl: 'https://test.example',
  client: MockClient((request) async {
    onRequest?.call(request);
    if (request.url.path == '/api/locations/search') {
      return http.Response(
        jsonEncode(
          searchError == null
              ? {
                  'places': [
                    {
                      'id': 'place-a',
                      'displayName': {'text': 'Google naziv'},
                      'formattedAddress': 'Adresa iz pretrage',
                    },
                  ],
                }
              : {'message': 'Google Maps pretraga nije podešena na serveru.'},
        ),
        searchError ?? 200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    if (request.method == 'POST' || request.method == 'PATCH') {
      return http.Response(
        jsonEncode({
          'location': {'_id': venues.first['_id'], ...jsonDecode(request.body)},
        }),
        201,
      );
    }
    return http.Response(jsonEncode({'locations': venues}), 200);
  }),
);

Widget host(
  Widget child, {
  double scale = 1,
  Locale locale = const Locale('sr'),
}) => RepaintBoundary(
  key: const Key('capture'),
  child: MaterialApp(
    locale: locale,
    supportedLocales: AppStrings.supportedLocales,
    localizationsDelegates: const [
      AppStrings.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: const bool.fromEnvironment('CAPTURE_LOCATIONS')
        ? AppTheme.light.copyWith(
            textTheme: AppTheme.light.textTheme.apply(fontFamily: 'Roboto'),
            primaryTextTheme: AppTheme.light.primaryTextTheme.apply(
              fontFamily: 'Roboto',
            ),
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

Future<void> capture(String name) async {
  if (const bool.fromEnvironment('CAPTURE_LOCATIONS')) {
    await expectLater(
      find.byKey(const Key('capture')),
      matchesGoldenFile('../.local-backups/locations-20260909/$name.png'),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_LOCATIONS')) {
      final text = FontLoader('Roboto')
        ..addFont(
          File(
            '/System/Library/Fonts/SFNS.ttf',
          ).readAsBytes().then((data) => ByteData.sublistView(data)),
        );
      await text.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    }
  });
  test(
    'location model preserves old tournaments and encodes exact Maps place',
    () {
      final old = Tournament.fromJson({
        '_id': 'old',
        'location': 'Stari teren',
      });
      expect(old.locations, isEmpty);
      expect(old.locationLabel, 'Stari teren');
      final current = Tournament.fromJson({
        '_id': 'new',
        'location': 'old snapshot',
        'locations': venues,
      });
      expect(current.locations.length, 2);
      expect(current.locationLabel, contains('Podgorica'));
      final uri = MapsService.googleMapsUri('Klub & teren', 'place-a');
      expect(uri.host, 'www.google.com');
      expect(uri.queryParameters['query_place_id'], 'place-a');
      expect(uri.queryParameters['query'], 'Klub & teren');
    },
  );

  test(
    'tournament service sends location IDs, not Google result contents',
    () async {
      Map<String, dynamic>? sent;
      final api = ApiClient(
        baseUrl: 'https://test.example',
        client: MockClient((request) async {
          sent = jsonDecode(request.body);
          return http.Response(
            jsonEncode({
              'tournament': {'_id': 'new', ...sent!},
            }),
            201,
          );
        }),
      );
      await LeagueService(api).createTournament(
        name: 'Cup',
        discipline: 'singles',
        location: 'A; B',
        locationIds: venues.map((v) => v['_id']!).toList(),
        surface: 'Hard',
        category: 'Open',
        format: 'elimination',
        startDate: DateTime(2026),
        endDate: DateTime(2026, 2),
      );
      expect(sent!['locationIds'], venues.map((v) => v['_id']).toList());
      expect(sent!.containsKey('googlePlaceId'), isFalse);
      api.close();
    },
  );

  for (final (size, scale) in [
    (const Size(320, 568), 1.5),
    (const Size(390, 844), 1.0),
    (const Size(1024, 1366), 1.0),
  ]) {
    testWidgets(
      'multi-location choice wraps and survives filtering at $size/$scale',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = locationApi();
        LocationSelection? selection;
        await tester.pumpWidget(
          host(
            Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () async => selection = await showLocationPicker(
                      context: context,
                      league: LeagueService(api),
                      multiple: true,
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
            scale: scale,
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(venues.first['name']!));
        await tester.pumpAndSettle();
        await tester.tap(find.text(venues.last['name']!));
        await tester.pumpAndSettle();
        expect(find.text('Potvrdi izbor (2)'), findsOneWidget);
        expect(find.byTooltip('Dodaj lokaciju'), findsNothing);
        await capture('picker-${size.width.toInt()}');
        await tester.enterText(find.byType(TextField), 'Budva');
        await tester.pumpAndSettle();
        expect(find.text(venues.last['name']!), findsNothing);
        await tester.tap(find.text('Potvrdi izbor (2)'));
        await tester.pumpAndSettle();
        expect(
          selection!.locations.map((v) => v.id),
          venues.map((v) => v['_id']),
        );
        await tester.pumpWidget(const SizedBox());
        api.close();
      },
    );
  }

  for (final locale in AppStrings.supportedLocales) {
    final tr = AppStrings(locale).text;
    testWidgets(
      'admin links Google place without persisting Google name/address, $locale',
      (tester) async {
        var searches = 0;
        Map<String, dynamic>? saved;
        final api = locationApi(
          onRequest: (request) {
            if (request.url.path.endsWith('/search')) searches++;
            if (request.method == 'POST' &&
                request.url.path == '/api/locations') {
              saved = jsonDecode(request.body);
            }
          },
        );
        await tester.pumpWidget(
          host(LocationEditScreen(league: LeagueService(api)), locale: locale),
        );
        await tester.enterText(
          find.byType(TextFormField).first,
          'Moj teniski klub',
        );
        await tester.enterText(find.byType(TextFormField).last, 'Moja adresa');
        await tester.tap(find.text(tr('Pronađi na Google mapama')));
        await tester.pumpAndSettle();
        expect(searches, 0);
        await tester.tap(find.byTooltip(tr('Pretraži')));
        await tester.pumpAndSettle();
        expect(searches, 1);
        expect(find.text('Google Maps'), findsOneWidget);
        if (locale.languageCode != 'en') await capture('google-search');
        await tester.tap(find.text('Google naziv'));
        await tester.pumpAndSettle();
        expect(find.text('Moj teniski klub'), findsOneWidget);
        expect(find.text('Google naziv'), findsNothing);
        await tester.ensureVisible(find.text(tr('Sačuvaj lokaciju')));
        await tester.tap(find.text(tr('Sačuvaj lokaciju')));
        await tester.pumpAndSettle();
        expect(saved, {
          'name': 'Moj teniski klub',
          'address': 'Moja adresa',
          'googlePlaceId': 'place-a',
          'active': true,
        });
        await tester.pumpWidget(const SizedBox());
        api.close();
      },
    );

    testWidgets(
      'missing Maps key is shown without preventing manual location creation, $locale',
      (tester) async {
        final api = locationApi(searchError: 503);
        await tester.pumpWidget(
          host(
            GooglePlaceSearchScreen(
              league: LeagueService(api),
              initialQuery: 'Budva',
            ),
            locale: locale,
          ),
        );
        await tester.tap(find.byTooltip(tr('Pretraži')));
        await tester.pumpAndSettle();
        expect(
          find.text(tr('Google Maps pretraga nije podešena na serveru.')),
          findsOneWidget,
        );
        expect(find.byType(LinearProgressIndicator), findsNothing);
        await tester.pumpWidget(const SizedBox());
        api.close();
      },
    );
  }

  testWidgets('legacy selection and single-venue matches remain supported', (
    tester,
  ) async {
    final api = locationApi();
    await tester.pumpWidget(
      host(
        LocationPickerScreen(league: LeagueService(api), legacy: 'Stari teren'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CheckboxListTile>(find.byType(CheckboxListTile).first)
          .value,
      isTrue,
    );
    await tester.tap(find.text(venues.first['name']!));
    await tester.pumpAndSettle();
    await tester.tap(find.text(venues.last['name']!));
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .where((v) => v.value == true)
          .length,
      1,
    );
    await tester.pumpWidget(const SizedBox());
    api.close();
  });

  testWidgets('admin editor renames and deactivates a venue at 320px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Map<String, dynamic>? saved;
    final api = locationApi(
      onRequest: (request) {
        if (request.method == 'PATCH') saved = jsonDecode(request.body);
      },
    );
    await tester.pumpWidget(
      host(
        LocationEditScreen(
          league: LeagueService(api),
          location: AppLocation.fromJson(venues.first),
        ),
        scale: 1.5,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'Teniski klub novi naziv',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await capture('admin-editor');
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.scrollUntilVisible(
      find.text('Sačuvaj lokaciju'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sačuvaj lokaciju'));
    await tester.pumpAndSettle();
    expect(saved!['name'], 'Teniski klub novi naziv');
    expect(saved!['active'], isFalse);
    expect(saved!['googlePlaceId'], 'place-a');
    await tester.pumpWidget(const SizedBox());
    api.close();
  });

  testWidgets(
    'long title is not limited to two lines and map labels fit enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = fixtureApi();
      final auth = AuthService(api)..currentPlayer = demoPlayer;
      await tester.pumpWidget(
        host(
          SportBackdrop(
            child: TournamentsScreen(
              league: LeagueService(api),
              api: api,
              auth: auth,
            ),
          ),
          scale: 1.5,
        ),
      );
      await tester.pumpAndSettle();
      final title = tester.widget<Text>(
        find.text('Otvoreno prvenstvo teniskih klubova'),
      );
      expect(title.maxLines, isNull);
      expect(title.overflow, isNot(TextOverflow.ellipsis));
      if (const bool.fromEnvironment('CAPTURE_LOCATIONS')) {
        await tester.runAsync(
          () => precacheImage(
            const AssetImage(tennisEditorialAsset),
            tester.element(find.byType(TournamentsScreen)),
          ),
        );
        await tester.pumpAndSettle();
      }
      await capture('long-tournament');
      await tester.pumpWidget(
        host(
          const Scaffold(
            body: MapLocationCard(
              location:
                  'Sportski centar sa dugackim nazivom, Bulevar u Podgorici',
            ),
          ),
          scale: 1.5,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
      api.close();
    },
  );
}
