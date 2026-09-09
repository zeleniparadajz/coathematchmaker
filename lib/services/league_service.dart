import 'package:image_picker/image_picker.dart';

import '../models/match.dart';
import '../models/app_location.dart';
import '../models/dm.dart';
import '../models/league_settings.dart';
import '../models/player.dart';
import '../models/tournament.dart';
import '../models/round_robin.dart';
import 'api_client.dart';

class LeagueService {
  LeagueService(this.api);

  final ApiClient api;

  Future<List<AppLocation>> locations({bool includeInactive = false}) async {
    final data = await api.getJson('/api/locations', {
      'all': '$includeInactive',
    });
    return (data['locations'] as List)
        .map((item) => AppLocation.fromJson(item))
        .toList();
  }

  Future<List<GooglePlaceResult>> searchPlaces(String query) async {
    final data = await api.postJson('/api/locations/search', {'query': query});
    return (data['places'] as List)
        .map((item) => GooglePlaceResult.fromJson(item))
        .toList();
  }

  Future<AppLocation> saveLocation({
    String? id,
    required String name,
    required String address,
    String? googlePlaceId,
    required bool active,
  }) async {
    final body = {
      'name': name,
      'address': address,
      'googlePlaceId': googlePlaceId,
      'active': active,
    };
    final data = id == null
        ? await api.postJson('/api/locations', body)
        : await api.patchJson('/api/locations/$id', body);
    return AppLocation.fromJson(data['location']);
  }

  Future<List<Player>> players() async {
    final data = await api.getJson('/api/players');
    return (data['players'] as List)
        .map((item) => Player.fromJson(item))
        .toList();
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
    required String sport,
    String? club,
    String? city,
  }) async {
    final data = await api.patchJson('/api/players/me', {
      'firstName': firstName,
      'lastName': lastName,
      'birthDate': birthDate.toIso8601String(),
      'country': country,
      'sport': sport,
      'club': club ?? '',
      'city': city ?? '',
    });
    return Player.fromJson(data['player']);
  }

  Future<Player> updateMyPlayStatus(String playStatus) async {
    final data = await api.patchJson('/api/players/me/play-status', {
      'playStatus': playStatus,
    });
    return Player.fromJson(data['player']);
  }

  Future<List<Player>> rankings() async {
    final data = await api.getJson('/api/rankings');
    return (data['rankings'] as List)
        .map((item) => Player.fromJson(item))
        .toList();
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
    required String discipline,
    required String location,
    List<String>? locationIds,
    required String surface,
    required String category,
    required String format,
    required DateTime startDate,
    required DateTime endDate,
    String visibility = 'public',
    bool friendly = false,
    String status = 'upcoming',
    int knockoutSize = 0,
  }) async {
    final data = await api.postJson('/api/tournaments', {
      'name': name,
      'discipline': discipline,
      'location': location,
      'locationIds': ?locationIds,
      'surface': surface,
      'category': category,
      'format': format,
      'knockoutSize': knockoutSize,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'visibility': visibility,
      'friendly': friendly,
      'status': status,
    });
    return Tournament.fromJson(data['tournament']);
  }

  Future<Tournament> updateTournament({
    required String id,
    required String name,
    required String discipline,
    required String location,
    List<String>? locationIds,
    required String surface,
    required String category,
    required String format,
    required DateTime startDate,
    required DateTime endDate,
    required String status,
    required String visibility,
    required bool friendly,
    int? knockoutSize,
  }) async {
    final data = await api.patchJson('/api/tournaments/$id', {
      'name': name,
      'discipline': discipline,
      'location': location,
      'locationIds': ?locationIds,
      'surface': surface,
      'category': category,
      'format': format,
      'knockoutSize': ?knockoutSize,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'status': status,
      'visibility': visibility,
      'friendly': friendly,
    });
    return Tournament.fromJson(data['tournament']);
  }

  Future<void> addTournamentParticipant(
    String tournamentId,
    String playerId,
  ) async {
    await api.postJson('/api/tournaments/$tournamentId/participants', {
      'playerId': playerId,
    });
  }

  Future<void> addTournamentAdmin(String tournamentId, String playerId) async {
    await api.postJson('/api/tournaments/$tournamentId/admins', {
      'playerId': playerId,
    });
  }

  Future<void> removeTournamentParticipant(
    String tournamentId,
    String playerId,
  ) async {
    await api.deleteJson(
      '/api/tournaments/$tournamentId/participants/$playerId',
    );
  }

  Future<void> generateTournamentDraw(String tournamentId) async {
    await api.postJson('/api/tournaments/$tournamentId/generate-draw');
  }

  Future<RoundRobinState> roundRobin(String id) async {
    final data = await api.getJson('/api/tournaments/$id/round-robin');
    return RoundRobinState.fromJson(data['roundRobin']);
  }

  Future<void> startKnockout(String id, List<String> seeds) async {
    await api.postJson('/api/tournaments/$id/start-knockout', {'seeds': seeds});
  }

  Future<void> advanceKnockout(String id, String round) async {
    await api.postJson('/api/tournaments/$id/advance-round', {'round': round});
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

  Future<List<Conversation>> conversations() async {
    final data = await api.getJson('/api/messages/conversations');
    return (data['conversations'] as List)
        .map((item) => Conversation.fromJson(item))
        .toList();
  }

  Future<int> unreadMessageCount() async {
    final data = await api.getJson('/api/messages/unread-count');
    return data['unreadCount'] ?? 0;
  }

  Future<Conversation> startConversation(String participantId) async {
    final data = await api.postJson('/api/messages/conversations', {
      'participantId': participantId,
    });
    return Conversation.fromJson(data['conversation']);
  }

  Future<List<DirectMessage>> messages(String conversationId) async {
    final data = await api.getJson(
      '/api/messages/conversations/$conversationId/messages',
    );
    return (data['messages'] as List)
        .map((item) => DirectMessage.fromJson(item))
        .toList();
  }

  Future<DirectMessage> sendMessage(String conversationId, String text) async {
    final data = await api.postJson(
      '/api/messages/conversations/$conversationId/messages',
      {'text': text},
    );
    return DirectMessage.fromJson(data['message']);
  }

  Future<void> markConversationRead(String conversationId) async {
    await api.patchJson('/api/messages/conversations/$conversationId/read', {});
  }

  Future<void> challengeMatch({
    required String opponentId,
    String? partnerId,
    String? opponentPartnerId,
    String discipline = 'singles',
    String? tournamentId,
    String round = 'Challenge',
    String? location,
    String? locationId,
    DateTime? scheduledAt,
    bool friendly = false,
  }) async {
    await api.postJson('/api/matches/challenge', {
      'opponentId': opponentId,
      'partnerId': ?partnerId,
      'opponentPartnerId': ?opponentPartnerId,
      'discipline': discipline,
      'tournamentId': ?tournamentId,
      'round': round,
      'location': ?location,
      'locationId': ?locationId,
      'scheduledAt': ?scheduledAt?.toIso8601String(),
      'friendly': friendly,
    });
  }

  Future<void> acceptMatch(String id) =>
      api.postJson('/api/matches/$id/accept');
  Future<void> rejectMatch(String id) =>
      api.postJson('/api/matches/$id/reject');
  Future<void> confirmResult(String id) =>
      api.postJson('/api/matches/$id/confirm-result');
  Future<void> disputeResult(String id) =>
      api.postJson('/api/matches/$id/dispute');

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
    int? inactivityDays,
  }) async {
    final data = await api.patchJson('/api/settings', {
      'resultEntryDelayMinutes': resultEntryDelayMinutes,
      'matchWinPoints': matchWinPoints,
      'tournamentWinPoints': tournamentWinPoints,
      'inactivityDays': ?inactivityDays,
    });
    return LeagueSettings.fromJson(data['settings']);
  }

  Future<void> createMatch({
    required String tournament,
    required String player1,
    required String player2,
    String? player1Partner,
    String? player2Partner,
    String discipline = 'singles',
    required String winner,
    required String round,
    required List<SetScore> sets,
    DateTime? scheduledAt,
  }) async {
    await api.postJson('/api/matches', {
      'tournament': tournament,
      'discipline': discipline,
      'player1': player1,
      'player2': player2,
      'player1Partner': ?player1Partner,
      'player2Partner': ?player2Partner,
      'winner': winner,
      'round': round,
      'scheduledAt': ?scheduledAt?.toIso8601String(),
      'sets': sets.map((set) => set.toJson()).toList(),
      'status': 'confirmed',
    });
  }

  Future<Player> uploadProfileImage(XFile file) async {
    final data = await api.uploadProfileImage(file);
    return Player.fromJson(data['player']);
  }

  Future<TennisMatch> uploadMatchImage(String matchId, XFile file) async {
    final data = await api.uploadImage('/api/matches/$matchId/images', file);
    return TennisMatch.fromJson(data['match']);
  }

  Future<Tournament> uploadTournamentImage(
    String tournamentId,
    XFile file,
  ) async {
    final data = await api.uploadImage(
      '/api/tournaments/$tournamentId/images',
      file,
    );
    return Tournament.fromJson(data['tournament']);
  }
}
