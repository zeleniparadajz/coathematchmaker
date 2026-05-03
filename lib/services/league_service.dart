import 'package:image_picker/image_picker.dart';

import '../models/match.dart';
import '../models/league_settings.dart';
import '../models/player.dart';
import '../models/tournament.dart';
import 'api_client.dart';

class LeagueService {
  LeagueService(this.api);

  final ApiClient api;

  Future<List<Player>> players() async {
    final data = await api.getJson('/api/players');
    return (data['players'] as List).map((item) => Player.fromJson(item)).toList();
  }

  Future<Player> player(String id) async {
    final data = await api.getJson('/api/players/$id');
    return Player.fromJson(data['player']);
  }

  Future<Player> updateMyProfile({
    required String firstName,
    required String lastName,
    required DateTime birthDate,
    required String country,
    String? club,
  }) async {
    final data = await api.patchJson('/api/players/me', {
      'firstName': firstName,
      'lastName': lastName,
      'birthDate': birthDate.toIso8601String(),
      'country': country,
      'club': club ?? '',
    });
    return Player.fromJson(data['player']);
  }

  Future<List<Player>> rankings() async {
    final data = await api.getJson('/api/rankings');
    return (data['rankings'] as List).map((item) => Player.fromJson(item)).toList();
  }

  Future<List<Tournament>> tournaments() async {
    final data = await api.getJson('/api/tournaments');
    return (data['tournaments'] as List)
        .map((item) => Tournament.fromJson(item))
        .toList();
  }

  Future<Tournament> tournament(String id) async {
    final data = await api.getJson('/api/tournaments/$id');
    return Tournament.fromJson(data['tournament']);
  }

  Future<void> registerForTournament(String id) async {
    await api.postJson('/api/tournaments/$id/register');
  }

  Future<Tournament> createTournament({
    required String name,
    required String location,
    required String surface,
    required String category,
    required String format,
    required DateTime startDate,
    required DateTime endDate,
    String status = 'upcoming',
  }) async {
    final data = await api.postJson('/api/tournaments', {
      'name': name,
      'location': location,
      'surface': surface,
      'category': category,
      'format': format,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'status': status,
    });
    return Tournament.fromJson(data['tournament']);
  }

  Future<Tournament> updateTournament({
    required String id,
    required String name,
    required String location,
    required String surface,
    required String category,
    required String format,
    required DateTime startDate,
    required DateTime endDate,
    required String status,
  }) async {
    final data = await api.patchJson('/api/tournaments/$id', {
      'name': name,
      'location': location,
      'surface': surface,
      'category': category,
      'format': format,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'status': status,
    });
    return Tournament.fromJson(data['tournament']);
  }

  Future<void> addTournamentParticipant(String tournamentId, String playerId) async {
    await api.postJson('/api/tournaments/$tournamentId/participants', {'playerId': playerId});
  }

  Future<void> removeTournamentParticipant(String tournamentId, String playerId) async {
    await api.deleteJson('/api/tournaments/$tournamentId/participants/$playerId');
  }

  Future<void> generateTournamentDraw(String tournamentId) async {
    await api.postJson('/api/tournaments/$tournamentId/generate-draw');
  }

  Future<List<TournamentRanking>> tournamentRankings(String id) async {
    final data = await api.getJson('/api/tournaments/$id/rankings');
    return (data['rankings'] as List)
        .map((item) => TournamentRanking.fromJson(item))
        .toList();
  }

  Future<List<TennisMatch>> matches({String? tournamentId}) async {
    final data = await api.getJson(
      '/api/matches',
      tournamentId == null ? null : {'tournament': tournamentId},
    );
    return (data['matches'] as List)
        .map((item) => TennisMatch.fromJson(item))
        .toList();
  }

  Future<List<TennisMatch>> myMatches() async {
    final data = await api.getJson('/api/matches/my');
    return (data['matches'] as List)
        .map((item) => TennisMatch.fromJson(item))
        .toList();
  }

  Future<List<TennisMatch>> pendingMatches() async {
    final data = await api.getJson('/api/matches/pending');
    return (data['matches'] as List)
        .map((item) => TennisMatch.fromJson(item))
        .toList();
  }

  Future<List<TennisMatch>> disputedMatches() async {
    final data = await api.getJson('/api/matches/disputed');
    return (data['matches'] as List)
        .map((item) => TennisMatch.fromJson(item))
        .toList();
  }

  Future<void> challengeMatch({
    required String opponentId,
    String? tournamentId,
    String round = 'Challenge',
  }) async {
    await api.postJson('/api/matches/challenge', {
      'opponentId': opponentId,
      'tournamentId': ?tournamentId,
      'round': round,
    });
  }

  Future<void> acceptMatch(String id) => api.postJson('/api/matches/$id/accept');
  Future<void> rejectMatch(String id) => api.postJson('/api/matches/$id/reject');
  Future<void> confirmResult(String id) => api.postJson('/api/matches/$id/confirm-result');
  Future<void> disputeResult(String id) => api.postJson('/api/matches/$id/dispute');

  Future<void> submitResult({
    required String matchId,
    required String winner,
    required String round,
    required List<SetScore> sets,
  }) async {
    await api.postJson('/api/matches/$matchId/submit-result', {
      'winner': winner,
      'round': round,
      'sets': sets.map((set) => set.toJson()).toList(),
    });
  }

  Future<void> adminResolve({
    required String matchId,
    required String action,
    String? winner,
    List<SetScore>? sets,
    String? note,
  }) async {
    await api.postJson('/api/matches/$matchId/admin-resolve', {
      'action': action,
      'winner': ?winner,
      'sets': ?sets?.map((set) => set.toJson()).toList(),
      'note': ?note,
    });
  }

  Future<LeagueSettings> settings() async {
    final data = await api.getJson('/api/settings');
    return LeagueSettings.fromJson(data['settings']);
  }

  Future<LeagueSettings> updateSettings({
    required int resultEntryDelayMinutes,
    required int matchWinPoints,
    required int tournamentWinPoints,
  }) async {
    final data = await api.patchJson('/api/settings', {
      'resultEntryDelayMinutes': resultEntryDelayMinutes,
      'matchWinPoints': matchWinPoints,
      'tournamentWinPoints': tournamentWinPoints,
    });
    return LeagueSettings.fromJson(data['settings']);
  }

  Future<void> createMatch({
    required String tournament,
    required String player1,
    required String player2,
    required String winner,
    required String round,
    required List<SetScore> sets,
  }) async {
    await api.postJson('/api/matches', {
      'tournament': tournament,
      'player1': player1,
      'player2': player2,
      'winner': winner,
      'round': round,
      'sets': sets.map((set) => set.toJson()).toList(),
      'status': 'confirmed',
    });
  }

  Future<Player> uploadProfileImage(XFile file) async {
    final data = await api.uploadProfileImage(file);
    return Player.fromJson(data['player']);
  }
}
