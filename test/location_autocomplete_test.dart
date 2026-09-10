import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:coathematchmaker/l10n/app_strings.dart';
import 'package:coathematchmaker/models/app_location.dart';
import 'package:coathematchmaker/models/tournament.dart';
import 'package:coathematchmaker/screens/tournaments_screen.dart';
import 'package:coathematchmaker/services/api_client.dart';
import 'package:coathematchmaker/services/league_service.dart';
import 'package:coathematchmaker/services/place_search_controller.dart';
import 'package:coathematchmaker/widgets/location_picker.dart';
import 'locations_test.dart' show host;

const places = [
  {
    'id': 'google-a',
    'displayName': {'text': 'TK Knez'},
    'formattedAddress': 'Podgorica, Crna Gora',
  },
  {
    'id': 'google-b',
    'displayName': {'text': 'Sportski centar Morača'},
    'formattedAddress': 'Podgorica, Crna Gora',
  },
  {
    'id': 'google-c',
    'displayName': {'text': 'Teniska akademija sa veoma dugim nazivom'},
    'formattedAddress': 'Dugačka ulica u Budvi, Crna Gora',
  },
];
const manual = {
  '_id': '123456789012345678901230',
  'name': 'Moj privatni teren',
  'address': 'Budva',
};

http.Response jsonResponse(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

class VenueApi {
  final calls = <http.Request>[];
  final saved = <Map<String, dynamic>>[
    {...manual},
  ];
  int? googleError;
  int? selectionError;
  Map<String, dynamic>? tournamentBody;
  late final api = ApiClient(
    baseUrl: 'https://test.example',
    client: MockClient((request) async {
      calls.add(request);
      final path = request.url.path;
      final body = request.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(request.body) as Map<String, dynamic>;
      if (path == '/api/locations/autocomplete') {
        if (googleError != null) {
          return jsonResponse({
            'message': 'Google Maps pretraga nije podešena na serveru.',
          }, googleError!);
        }
        return jsonResponse({
          'places': body['query'] == 'nothing' ? [] : places,
        });
      }
      if (path == '/api/locations/google') {
        if (selectionError != null) {
          return jsonResponse({
            'message': 'Izabrana lokacija više nije dostupna. Osvježite listu.',
          }, selectionError!);
        }
        final index = places.indexWhere(
          (item) => item['id'] == body['placeId'],
        );
        final id = '12345678901234567890123${index + 1}';
        final venue = {
          '_id': id,
          'name': '',
          'address': '',
          'googleOnly': true,
          'googlePlaceId': body['placeId'],
        };
        if (!saved.any((item) => item['_id'] == id)) saved.add(venue);
        return jsonResponse({
          'location': {...venue, 'googleDetails': places[index]},
        });
      }
      if (path == '/api/locations/resolve') {
        if (googleError != null) return jsonResponse({'places': {}});
        return jsonResponse({
          'places': {
            for (final venue in saved.where(
              (v) =>
                  v['googleOnly'] == true &&
                  (body['ids'] as List).contains(v['_id']),
            ))
              venue['_id']: places.firstWhere(
                (item) => item['id'] == venue['googlePlaceId'],
              ),
          },
        });
      }
      if (path == '/api/locations') {
        if (request.method == 'GET') return jsonResponse({'locations': saved});
        final item = {'_id': '123456789012345678901239', ...body};
        saved.add(item);
        return jsonResponse({'location': item}, 201);
      }
      if (path.startsWith('/api/tournaments')) {
        if (request.method != 'GET') tournamentBody = body;
        return jsonResponse({
          'tournament': {
            '_id': 'tournament',
            ...body,
            'locations': saved
                .where(
                  (v) =>
                      (body['locationIds'] as List? ?? []).contains(v['_id']),
                )
                .toList(),
          },
        });
      }
      return jsonResponse({'message': 'Unexpected test request'}, 404);
    }),
  );
}

Future<void> search(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField).first, query);
  await tester.pump(const Duration(milliseconds: 450));
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester, String id) async {
  final tile = find.byKey(ValueKey('google-place-$id'));
  await tester.scrollUntilVisible(
    tile,
    160,
    scrollable: find
        .descendant(
          of: find.byKey(const Key('location-results')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

Future<void> capture(String name) async {
  if (const bool.fromEnvironment('CAPTURE_LOCATIONS')) {
    await expectLater(
      find.byKey(const Key('capture')),
      matchesGoldenFile(
        '../.local-backups/location-autocomplete-20260910/$name.png',
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_LOCATIONS')) {
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

  for (final locale in AppStrings.supportedLocales) {
    final tr = AppStrings(locale).text;
    for (final width in [320.0, 390.0, 1024.0]) {
      testWidgets(
        'directly selects three Google venues without forms, $locale/$width',
        (tester) async {
          tester.view.physicalSize = Size(width, width == 320 ? 700 : 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final fixture = VenueApi();
          final league = LeagueService(fixture.api);
          LocationSelection? selected;
          await tester.pumpWidget(
            host(
              Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async => selected = await showLocationPicker(
                      context: context,
                      league: league,
                      multiple: true,
                      canManage: true,
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
              locale: locale,
              scale: width == 320 ? 1.5 : 1,
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField), 'Te');
          await tester.pump(const Duration(milliseconds: 500));
          expect(
            fixture.calls.where((r) => r.url.path.endsWith('/autocomplete')),
            isEmpty,
          );
          await search(tester, 'Teniski');
          expect(find.text('Google Maps'), findsOneWidget);
          expect(find.byType(TextFormField), findsNothing);
          expect(
            fixture.calls
                .where((r) => r.url.path.endsWith('/autocomplete'))
                .length,
            1,
          );
          await capture('search-${locale.languageCode}-${width.toInt()}');
          await choose(tester, 'google-a');
          await search(tester, 'Morača');
          await choose(tester, 'google-b');
          await search(tester, 'Budva');
          await choose(tester, 'google-c');
          expect(find.text(tr('Potvrdi izbor ({p0})', [3])), findsOneWidget);
          await capture('selected-${locale.languageCode}-${width.toInt()}');
          await tester.tap(find.text(tr('Potvrdi izbor ({p0})', [3])));
          await tester.pumpAndSettle();
          expect(selected!.locations.map((v) => v.googlePlaceId), [
            'google-a',
            'google-b',
            'google-c',
          ]);
          expect(selected!.locations.first.name, 'TK Knez');
          final requests = fixture.calls
              .where((r) => r.url.path.endsWith('/google'))
              .map((r) => jsonDecode(r.body) as Map<String, dynamic>)
              .toList();
          expect(
            requests.every(
              (body) => body.keys.toSet().difference({
                'placeId',
                'sessionToken',
                'language',
              }).isEmpty,
            ),
            isTrue,
          );
          expect(
            requests.map((body) => body['sessionToken']).toSet().length,
            3,
          );
          expect(
            requests.first['language'],
            locale.languageCode == 'en' ? 'en' : 'sr',
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          fixture.api.close();
        },
      );
    }

    testWidgets(
      'Google outage keeps manual input, custom name and selection available, $locale',
      (tester) async {
        final fixture = VenueApi()..googleError = 503;
        await tester.pumpWidget(
          host(
            LocationPickerScreen(
              league: LeagueService(fixture.api),
              multiple: true,
              canManage: true,
            ),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();
        await search(tester, 'Naš teren iza škole');
        expect(
          find.text(tr('Google Maps pretraga nije podešena na serveru.')),
          findsOneWidget,
        );
        await tester.ensureVisible(find.byKey(const Key('manual-location')));
        await tester.tap(find.byKey(const Key('manual-location')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField).first)
              .controller!
              .text,
          'Naš teren iza škole',
        );
        await tester.enterText(
          find.byType(TextFormField).first,
          'Moj naziv terena',
        );
        await tester.enterText(find.byType(TextFormField).last, 'Moj grad');
        tester.testTextInput.hide();
        await tester.ensureVisible(find.text(tr('Sačuvaj lokaciju')));
        await tester.tap(find.text(tr('Sačuvaj lokaciju')));
        await tester.pumpAndSettle();
        expect(find.text(tr('Potvrdi izbor ({p0})', [1])), findsOneWidget);
        final body = jsonDecode(
          fixture.calls
              .lastWhere(
                (r) => r.url.path == '/api/locations' && r.method == 'POST',
              )
              .body,
        );
        expect(body['name'], 'Moj naziv terena');
        expect(body['address'], 'Moj grad');
        expect(body['googlePlaceId'], isNull);
        await tester.pumpWidget(const SizedBox());
        fixture.api.close();
      },
    );
  }

  testWidgets(
    'debounces, ignores stale responses, clears results and disposes pending work',
    (tester) async {
      final pending = <String, Completer<http.Response>>{};
      final api = ApiClient(
        baseUrl: 'https://test.example',
        client: MockClient((request) {
          final query = jsonDecode(request.body)['query'] as String;
          return (pending[query] = Completer<http.Response>()).future;
        }),
      );
      final controller = PlaceSearchController(LeagueService(api));
      controller.update('Knez');
      await tester.pump(const Duration(milliseconds: 200));
      controller.update('Knez Podgorica');
      await tester.pump(const Duration(milliseconds: 399));
      expect(pending, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      expect(pending.keys, ['Knez Podgorica']);
      controller.update('Budva');
      await tester.pump(const Duration(milliseconds: 400));
      pending['Budva']!.complete(
        jsonResponse({
          'places': [places.last],
        }),
      );
      await tester.pump();
      expect(controller.results.single.id, 'google-c');
      pending['Knez Podgorica']!.complete(
        jsonResponse({
          'places': [places.first],
        }),
      );
      await tester.pump();
      expect(controller.results.single.id, 'google-c');
      controller.update('');
      expect(controller.results, isEmpty);
      expect(controller.loading, isFalse);
      controller.update('cancelled');
      controller.dispose();
      await tester.pump(const Duration(seconds: 1));
      expect(pending.containsKey('cancelled'), isFalse);
      api.close();
    },
  );

  testWidgets('keyboard at 320px does not cover confirmation or overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final fixture = VenueApi();
    await tester.pumpWidget(
      host(
        LocationPickerScreen(
          league: LeagueService(fixture.api),
          multiple: true,
          selected: [AppLocation.fromJson(manual)],
        ),
        scale: 1.5,
      ),
    );
    await tester.pumpAndSettle();
    await search(tester, 'Teniski');
    expect(find.byTooltip('Potvrdi izbor'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.check))
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
    await capture('keyboard-320');
    await tester.pumpWidget(const SizedBox());
    fixture.api.close();
  });

  testWidgets(
    'failed selection is retryable, non-admin can select but cannot add manual records',
    (tester) async {
      final fixture = VenueApi()..selectionError = 400;
      await tester.pumpWidget(
        host(
          LocationPickerScreen(
            league: LeagueService(fixture.api),
            multiple: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await search(tester, 'Teniski');
      await choose(tester, 'google-a');
      expect(find.text('Potvrdi izbor (0)'), findsOneWidget);
      expect(find.byKey(const Key('manual-location')), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Teniski',
      );
      fixture.selectionError = null;
      await choose(tester, 'google-a');
      expect(find.text('Potvrdi izbor (1)'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      fixture.api.close();
    },
  );

  testWidgets('twenty venue limit and removal remain intact', (tester) async {
    final fixture = VenueApi();
    final selected = List.generate(
      20,
      (i) => AppLocation(id: 'id$i', name: 'Saved $i'),
    );
    await tester.pumpWidget(
      host(
        LocationPickerScreen(
          league: LeagueService(fixture.api),
          multiple: true,
          selected: selected,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await search(tester, 'Teniski');
    expect(
      tester
          .widget<ListTile>(find.byKey(const Key('google-place-google-a')))
          .enabled,
      isFalse,
    );
    final chip = tester.widget<InputChip>(
      find.byKey(const Key('selected-location-id0')),
    );
    chip.onDeleted!();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ListTile>(find.byKey(const Key('google-place-google-a')))
          .enabled,
      isTrue,
    );
    await choose(tester, 'google-a');
    expect(find.text('Potvrdi izbor (20)'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    fixture.api.close();
  });

  testWidgets(
    'no Google results still offers manual creation and single mode replaces the previous venue',
    (tester) async {
      final fixture = VenueApi();
      await tester.pumpWidget(
        host(
          LocationPickerScreen(
            league: LeagueService(fixture.api),
            canManage: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await search(tester, 'nothing');
      expect(find.text('Nema rezultata na Google mapama.'), findsOneWidget);
      expect(find.byKey(const Key('manual-location')), findsOneWidget);
      await search(tester, 'Teniski');
      await choose(tester, 'google-a');
      await search(tester, 'Morača');
      await choose(tester, 'google-b');
      final checked = tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .where((tile) => tile.value == true)
          .toList();
      expect(checked, hasLength(1));
      expect(
        checked.single.key,
        const Key('saved-location-123456789012345678901232'),
      );
      await tester.pumpWidget(const SizedBox());
      fixture.api.close();
    },
  );

  test(
    'Google names hydrate for current views without overwriting custom names or saving provider content',
    () async {
      final fixture = VenueApi();
      final league = LeagueService(fixture.api);
      final selected = await league.selectGoogleLocation(
        'google-a',
        'session_token_123456',
      );
      expect(selected.name, 'TK Knez');
      expect(selected.customName, isEmpty);
      expect(fixture.saved.last['name'], isEmpty);
      expect((await league.locations()).last.name, 'TK Knez');
      expect(fixture.saved.last.containsKey('googleDetails'), isFalse);
      fixture.googleError = 503;
      final offline = (await league.locations()).last;
      expect(offline.name, 'Google Maps');
      expect(offline.googlePlaceId, 'google-a');
      final custom = AppLocation.fromJson({
        ...fixture.saved.last,
        'name': 'Sopstveni naziv',
        'address': 'Naša adresa',
        'googleDetails': places.first,
      });
      expect(custom.label, 'Sopstveni naziv, Naša adresa');
      fixture.api.close();
    },
  );

  testWidgets(
    'tournament editor shows individual venues and submits all IDs after adding and removing',
    (tester) async {
      final fixture = VenueApi();
      await tester.pumpWidget(
        host(
          TournamentFormScreen(
            league: LeagueService(fixture.api),
            canManageLocations: true,
            tournament: Tournament.fromJson({
              '_id': 'tournament',
              'name': 'Kup',
              'locations': [manual],
            }),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Izabrano lokacija: 1'));
      await tester.tap(find.text('Izabrano lokacija: 1'));
      await tester.pumpAndSettle();
      await search(tester, 'Knez');
      await choose(tester, 'google-a');
      await search(tester, 'Morača');
      await choose(tester, 'google-b');
      await tester.tap(find.text('Potvrdi izbor (3)'));
      await tester.pumpAndSettle();
      expect(find.text('Izabrano lokacija: 3'), findsOneWidget);
      expect(
        find.byKey(const Key('tournament-location-123456789012345678901231')),
        findsOneWidget,
      );
      final tile = find.byKey(
        const Key('tournament-location-123456789012345678901230'),
      );
      await tester.ensureVisible(tile);
      await tester.tap(
        find.descendant(of: tile, matching: find.byType(IconButton)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Izabrano lokacija: 2'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Sačuvaj turnir'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Sačuvaj turnir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sačuvaj turnir'));
      await tester.pumpAndSettle();
      expect(fixture.tournamentBody!['locationIds'], [
        '123456789012345678901231',
        '123456789012345678901232',
      ]);
      await tester.pumpWidget(const SizedBox());
      fixture.api.close();
    },
  );
}
