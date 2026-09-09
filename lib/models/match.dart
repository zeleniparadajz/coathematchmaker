import 'player.dart';
import 'app_location.dart';
import 'tournament.dart';

class SetScore {
  const SetScore({required this.player1Games, required this.player2Games});

  final int player1Games;
  final int player2Games;

  factory SetScore.fromJson(Map<String, dynamic> json) {
    return SetScore(
      player1Games: json['player1Games'] ?? 0,
      player2Games: json['player2Games'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'player1Games': player1Games,
    'player2Games': player2Games,
  };
}

class TennisMatch {
  const TennisMatch({
    required this.id,
    required this.tournament,
    required this.discipline,
    required this.player1,
    required this.player2,
    required this.sets,
    required this.round,
    required this.status,
    required this.friendly,
    this.location,
    this.venue,
    this.scheduledAt,
    this.createdAt,
    this.images = const [],
    this.player1Partner,
    this.player2Partner,
    this.acceptedAt,
    this.resultSubmittedBy,
    this.winner,
  });

  final String id;
  final Tournament? tournament;
  final String discipline;
  final Player player1;
  final Player player2;
  final Player? player1Partner;
  final Player? player2Partner;
  final List<SetScore> sets;
  final Player? winner;
  final String round;
  final String status;
  final bool friendly;
  final String? location;
  final AppLocation? venue;
  final DateTime? scheduledAt;
  final DateTime? createdAt;
  final List<String> images;
  final DateTime? acceptedAt;
  final Player? resultSubmittedBy;

  String get scoreText =>
      sets.map((set) => '${set.player1Games}-${set.player2Games}').join(', ');

  bool get isDoubles => discipline == 'doubles';

  String get team1Name => player1Partner == null
      ? player1.fullName
      : '${player1.fullName} / ${player1Partner!.fullName}';

  String get team2Name => player2Partner == null
      ? player2.fullName
      : '${player2.fullName} / ${player2Partner!.fullName}';

  factory TennisMatch.fromJson(Map<String, dynamic> json) {
    final venue = json['venue'] is Map<String, dynamic>
        ? AppLocation.fromJson(json['venue'])
        : null;
    return TennisMatch(
      id: (json['_id'] ?? json['id']).toString(),
      tournament: json['tournament'] is Map<String, dynamic>
          ? Tournament.fromJson(json['tournament'])
          : null,
      discipline: json['discipline'] ?? 'singles',
      player1: Player.fromJson(json['player1'] ?? <String, dynamic>{}),
      player2: Player.fromJson(json['player2'] ?? <String, dynamic>{}),
      player1Partner: json['player1Partner'] is Map<String, dynamic>
          ? Player.fromJson(json['player1Partner'])
          : null,
      player2Partner: json['player2Partner'] is Map<String, dynamic>
          ? Player.fromJson(json['player2Partner'])
          : null,
      sets: (json['sets'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(SetScore.fromJson)
          .toList(),
      winner: json['winner'] is Map<String, dynamic>
          ? Player.fromJson(json['winner'])
          : null,
      round: json['round'] ?? '',
      status: json['status'] ?? 'pending',
      friendly: json['friendly'] == true,
      location: venue?.label ?? json['location'],
      venue: venue,
      scheduledAt: DateTime.tryParse(json['scheduledAt'] ?? ''),
      createdAt: DateTime.tryParse(json['createdAt'] ?? ''),
      images: (json['images'] as List? ?? [])
          .map((item) => item.toString())
          .toList(),
      acceptedAt: DateTime.tryParse(json['acceptedAt'] ?? ''),
      resultSubmittedBy: json['resultSubmittedBy'] is Map<String, dynamic>
          ? Player.fromJson(json['resultSubmittedBy'])
          : null,
    );
  }
}
