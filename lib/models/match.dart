import 'player.dart';
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
    required this.player1,
    required this.player2,
    required this.sets,
    required this.round,
    required this.status,
    this.acceptedAt,
    this.resultSubmittedBy,
    this.winner,
  });

  final String id;
  final Tournament? tournament;
  final Player player1;
  final Player player2;
  final List<SetScore> sets;
  final Player? winner;
  final String round;
  final String status;
  final DateTime? acceptedAt;
  final Player? resultSubmittedBy;

  String get scoreText =>
      sets.map((set) => '${set.player1Games}-${set.player2Games}').join(', ');

  factory TennisMatch.fromJson(Map<String, dynamic> json) {
    return TennisMatch(
      id: (json['_id'] ?? json['id']).toString(),
      tournament: json['tournament'] is Map<String, dynamic>
          ? Tournament.fromJson(json['tournament'])
          : null,
      player1: Player.fromJson(json['player1'] ?? <String, dynamic>{}),
      player2: Player.fromJson(json['player2'] ?? <String, dynamic>{}),
      sets: (json['sets'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(SetScore.fromJson)
          .toList(),
      winner: json['winner'] is Map<String, dynamic>
          ? Player.fromJson(json['winner'])
          : null,
      round: json['round'] ?? '',
      status: json['status'] ?? 'pending',
      acceptedAt: DateTime.tryParse(json['acceptedAt'] ?? ''),
      resultSubmittedBy: json['resultSubmittedBy'] is Map<String, dynamic>
          ? Player.fromJson(json['resultSubmittedBy'])
          : null,
    );
  }
}
