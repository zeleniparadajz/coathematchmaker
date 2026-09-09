import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:coathematchmaker/models/player.dart';
import 'package:coathematchmaker/services/api_client.dart';

Map<String, dynamic> playerJson(
  String id,
  String firstName, {
  String lastName = 'Marković',
}) => {
  '_id': id,
  'firstName': firstName,
  'lastName': lastName,
  'email': '$id@example.test',
  'birthDate': '1995-01-01',
  'country': 'Montenegro',
  'city': 'Budva',
  'club': 'Teniski klub',
  'sport': 'tennis',
  'active': true,
  'playStatus': 'available',
  'role': 'player',
  'totalPoints': 20,
  'wins': 2,
  'losses': 1,
  'matchesPlayed': 3,
  'tournamentsWon': 0,
};

final demoPlayers = [
  playerJson('me', 'Marko'),
  playerJson('other', 'Ana'),
  playerJson('third', 'Aleksandar', lastName: 'Petrović Nikolić'),
  playerJson('fourth', 'Milica'),
];
Player get demoPlayer => Player.fromJson(demoPlayers.first);

ApiClient fixtureApi({void Function(Uri)? onRequest}) => ApiClient(
  baseUrl: 'https://fixture.example.test',
  client: MockClient((request) async {
    onRequest?.call(request.url);
    final response = switch (request.url.path) {
      '/api/players' => {'players': demoPlayers},
      '/api/players/other' => {'player': demoPlayers[1]},
      '/api/rankings' => {'rankings': demoPlayers.reversed.toList()},
      '/api/auth/me' => {'player': demoPlayers.first},
      '/api/settings' => {
        'settings': {
          'resultEntryDelayMinutes': 60,
          'matchWinPoints': 10,
          'tournamentWinPoints': 50,
        },
      },
      '/api/tournaments' => {
        'tournaments': [
          {
            '_id': 'tournament',
            'name': 'Otvoreno prvenstvo teniskih klubova',
            'location': 'Budva, Crna Gora',
            'surface': 'Hard',
            'category': 'Open',
            'status': 'upcoming',
            'format': 'elimination',
            'participants': demoPlayers,
          },
        ],
      },
      '/api/messages/unread-count' => {'unreadCount': 0},
      '/api/messages/conversations' => {'conversations': []},
      _ => {'matches': []},
    };
    return http.Response(
      jsonEncode(response),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }),
);
