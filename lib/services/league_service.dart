import 'package:image_picker/image_picker.dart';

import '../models/match.dart';
import '../models/deletion_preview.dart';
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

  // Resolve Google-only references for the current response, never persistent storage.
  Future<void> _resolveLocationDetails(Map<String, dynamic> data) async {
    final venues = <String, List<Map<String, dynamic>>>{};
    void visit(dynamic value) {
      if (value is Map<String, dynamic>) {
        if (value['googleOnly'] == true &&
            value['_id'] is String &&
            value['googleDetails'] == null) {
          venues.putIfAbsent(value['_id'], () => []).add(value);
        }
        for (final child in value.values) {
          visit(child);
        }
      } else if (value is List) {
        for (final child in value) {
          visit(child);
        }
      }
    }

    visit(data);
    final ids = venues.keys.toList();
    for (var offset = 0; offset < ids.length; offset += 20) {
      try {
        final batch = ids.skip(offset).take(20).toList();
        final resolved = await api.postJson('/api/locations/resolve', {
          'ids': batch,
        });
        for (final entry
            in (resolved['places'] as Map<String, dynamic>? ?? {}).entries) {
          for (final venue in venues[entry.key] ?? <Map<String, dynamic>>[]) {
            venue['googleDetails'] = entry.value;
          }
        }
      } on ApiException {
        /* Keep custom labels and Maps links available offline. */
      }
    }
  }

  Future<DeletionPreview> deletionPreview(
    String id, {
    required bool tournament,
  }) async {
    final data = await api.getJson(
      '/api/${tournament ? 'tournaments' : 'matches'}/$id/deletion-preview',
    );
    return DeletionPreview.fromJson(data['preview']);
  }

  Future<void> deleteCompetition(
    String id, {
    required bool tournament,
    required String revision,
    Map<String, int> legacyMatchPoints = const {},
    bool? legacyTournamentAwardApplied,
    int? legacyTournamentPoints,
  }) async {
    await api.deleteJson('/api/${tournament ? 'tournaments' : 'matches'}/$id', {
      'revision': revision,
      'legacyMatchPoints': legacyMatchPoints,
      'legacyTournamentAwardApplied': ?legacyTournamentAwardApplied,
      'legacyTournamentPoints': ?legacyTournamentPoints,
    });
  }

  Future<List<AppLocation>> locations({bool includeInactive = false}) async {
    final data = await api.getJson('/api/locations', {
      'all': '$includeInactive',
    });
    await _resolveLocationDetails(data);
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

  Future<List<GooglePlaceResult>> autocompletePlaces(
    String query,
    String sessionToken, {
    String language = 'sr',
  }) async {
    final data = await api.postJson('/api/locations/autocomplete', {
      'query': query,
      'sessionToken': sessionToken,
      'language': language,
    });
    return (data['places'] as List)
        .map((item) => GooglePlaceResult.fromJson(item))
        .toList();
  }

  Future<GooglePlaceResult> placeDetails(
    String placeId,
    String sessionToken, {
    String language = 'sr',
  }) async {
    final data = await api.postJson('/api/locations/details', {
      'placeId': placeId,
      'sessionToken': sessionToken,
      'language': language,
    });
    return GooglePlaceResult.fromJson(data['place']);
  }

  Future<AppLocation> selectGoogleLocation(
    String placeId,
    String sessionToken, {
    String language = 'sr',
  }) async {
    final data = await api.postJson('/api/locations/google', {
      'placeId': placeId,
      'sessionToken': sessionToken,
      'language': language,
    });
    return AppLocation.fromJson(data['location']);
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
    await _resolveLocationDetails(data);
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
    await _resolveLocationDetails(data);
    return (data['tournaments'] as List)
        .map((item) => Tournament.fromJson(item))
        .toList();
  }

  Future<Tournament> tournament(String id) async {
    final data = await api.getJson('/api/tournaments/$id');
    await _resolveLocationDetails(data);
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
    await _resolveLocationDetails(data);
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
    await _resolveLocationDetails(data);
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
    await _resolveLocationDetails(data);
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
    await _resolveLocationDetails(data);
    return (data['matches'] as List)
        .map((item) => TennisMatch.fromJson(item))
        .toList();
  }

  Future<List<TennisMatch>> myMatches() async {
    final data = await api.getJson('/api/matches/my');
    await _resolveLocationDetails(data);
    return (data['matches'] as List)
        .map((item) => TennisMatch.fromJson(item))
        .toList();
  }

  Future<List<TennisMatch>> pendingMatches() async {
    final data = await api.getJson('/api/matches/pending');
    await _resolveLocationDetails(data);
    return (data['matches'] as List)
        .map((item) => TennisMatch.fromJson(item))
        .toList();
  }

  Future<List<TennisMatch>> disputedMatches() async {
    final data = await api.getJson('/api/matches/disputed');
    await _resolveLocationDetails(data);
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

  Future<TennisMatch> adminResolve({
    required String matchId,
    required String action,
    String? winner,
    List<SetScore>? sets,
    String? note,
    int? legacyWinPoints,
  }) async {
    final data = await api.postJson('/api/matches/$matchId/admin-resolve', {
      'action': action,
      'winner': ?winner,
      'sets': ?sets?.map((set) => set.toJson()).toList(),
      'note': ?note,
      'legacyWinPoints': ?legacyWinPoints,
    });
    await _resolveLocationDetails(data);
    return TennisMatch.fromJson(data['match']);
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
    await _resolveLocationDetails(data);
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
    await _resolveLocationDetails(data);
    return Tournament.fromJson(data['tournament']);
  }
}
