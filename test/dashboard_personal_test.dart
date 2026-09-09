import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:coathematchmaker/models/player.dart';
import 'package:coathematchmaker/screens/dashboard_screen.dart';
import 'package:coathematchmaker/services/api_client.dart';
import 'package:coathematchmaker/services/auth_service.dart';
import 'package:coathematchmaker/services/league_service.dart';
import 'package:coathematchmaker/theme/app_theme.dart';
import 'package:coathematchmaker/widgets/sport_surfaces.dart';
import 'package:coathematchmaker/widgets/stat_card.dart';
import 'support/fixtures.dart';

void main() {
  for (final account in ['me', 'other', 'no-photo']) {
    testWidgets(
      'Dashboard uses the signed-in player photo and complete statistics: $account',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final players = [
          {
            ...playerJson('me', 'Marko'),
            'profileImage': '/uploads/marko.jpg',
            'totalPoints': 220,
            'wins': 12,
            'losses': 4,
            'matchesPlayed': 16,
            'tournamentsWon': 2,
          },
          {
            ...playerJson('other', 'Ana'),
            'profileImage': '/uploads/ana.jpg',
            'totalPoints': 350,
            'wins': 18,
            'losses': 3,
            'matchesPlayed': 21,
            'tournamentsWon': 3,
          },
          {
            ...playerJson('no-photo', 'Petar'),
            'totalPoints': 50,
            'wins': 5,
            'losses': 1,
            'matchesPlayed': 6,
            'tournamentsWon': 0,
          },
        ];
        final expected = Player.fromJson(
          players.firstWhere((p) => p['_id'] == account),
        );
        final api = ApiClient(
          baseUrl: 'https://fixture.example.test',
          client: MockClient((request) async {
            final data = switch (request.url.path) {
              '/api/players' => {'players': players},
              '/api/rankings' => {'rankings': players.reversed.toList()},
              '/api/tournaments' => {
                'tournaments': [
                  {
                    '_id': 'mine',
                    'name': 'My tournament',
                    'status': 'active',
                    'participants': [
                      players.firstWhere((p) => p['_id'] == account),
                    ],
                  },
                  {
                    '_id': 'another',
                    'name': 'Another tournament',
                    'status': 'upcoming',
                    'participants': [],
                  },
                ],
              },
              _ => {'matches': []},
            };
            return http.Response(
              jsonEncode(data),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        );
        // Session data is deliberately stale; the dashboard must use the current API record.
        final auth = AuthService(api)
          ..currentPlayer = Player.fromJson(playerJson(account, 'Old'));
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: DashboardScreen(
                auth: auth,
                api: api,
                league: LeagueService(api),
              ),
            ),
          ),
        );
        // Verify data binding without waiting for real image-cache I/O in a widget test.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        final overview = find.byKey(
          const ValueKey('dashboard-personal-overview'),
        );
        expect(
          find.descendant(of: overview, matching: find.text(expected.fullName)),
          findsOneWidget,
        );
        for (final value in [
          '${expected.totalPoints}',
          '${expected.wins}',
          '${expected.losses}',
        ]) {
          expect(
            find.descendant(of: overview, matching: find.text(value)),
            findsOneWidget,
          );
        }
        for (final label in ['Poeni', 'Pobjede', 'Porazi']) {
          expect(
            find.descendant(of: overview, matching: find.text(label)),
            findsOneWidget,
          );
        }
        final photo = find.byKey(const ValueKey('dashboard-profile-photo'));
        if (expected.profileImage == null) {
          expect(photo, findsNothing);
          expect(
            find.descendant(of: overview, matching: find.text('PM')),
            findsOneWidget,
          );
        } else {
          expect(
            tester.widget<CachedNetworkImage>(photo).imageUrl,
            api.imageUrl(expected.profileImage),
          );
        }
        expect(find.byType(SportPhoto), findsNothing);
        expect(find.text('Igraj danas'), findsNothing);
        final stats = {
          for (final card in tester.widgetList<StatCard>(find.byType(StatCard)))
            card.label: card.value,
        };
        expect(stats, {
          'Igrača': '3',
          'Moji turniri': '1',
          'Moji mečevi': '${expected.matchesPlayed}',
          'Titule': '${expected.tournamentsWon}',
        });
        await tester.pumpWidget(const SizedBox());
        auth.dispose();
        api.close();
      },
    );
  }
}
