import 'player.dart';

class Tournament {
  const Tournament({
    required this.id,
    required this.name,
    required this.discipline,
    required this.location,
    required this.surface,
    required this.category,
    required this.format,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.visibility,
    required this.friendly,
    this.owner,
    this.admins = const [],
    required this.participants,
    this.images = const [],
    this.winner,
  });

  final String id;
  final String name;
  final String discipline;
  final String location;
  final String surface;
  final String category;
  final String format;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final String visibility;
  final bool friendly;
  final Player? owner;
  final List<Player> admins;
  final List<Player> participants;
  final List<String> images;
  final Player? winner;

  bool get isUpcoming => status == 'upcoming';
  bool get isPrivate => visibility == 'private';

  bool canManage(String? playerId, {bool appAdmin = false}) {
    if (appAdmin) return true;
    if (playerId == null) return false;
    return owner?.id == playerId || admins.any((admin) => admin.id == playerId);
  }

  factory Tournament.fromJson(Map<String, dynamic> json) {
    return Tournament(
      id: (json['_id'] ?? json['id']).toString(),
      name: json['name'] ?? '',
      discipline: json['discipline'] ?? 'singles',
      location: json['location'] ?? '',
      surface: json['surface'] ?? 'Hard',
      category: json['category'] ?? '',
      format: json['format'] ?? 'elimination',
      startDate: DateTime.tryParse(json['startDate'] ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(json['endDate'] ?? '') ?? DateTime.now(),
      status: json['status'] ?? 'upcoming',
      visibility: json['visibility'] ?? 'public',
      friendly: json['friendly'] == true,
      owner: json['owner'] is Map<String, dynamic>
          ? Player.fromJson(json['owner'])
          : null,
      admins: (json['admins'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(Player.fromJson)
          .toList(),
      participants: (json['participants'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(Player.fromJson)
          .toList(),
      images: (json['images'] as List? ?? [])
          .map((item) => item.toString())
          .toList(),
      winner: json['winner'] is Map<String, dynamic>
          ? Player.fromJson(json['winner'])
          : null,
    );
  }
}

class TournamentRanking {
  const TournamentRanking({
    required this.player,
    required this.wins,
    required this.losses,
    required this.matchesPlayed,
    required this.points,
  });

  final Player player;
  final int wins;
  final int losses;
  final int matchesPlayed;
  final int points;

  factory TournamentRanking.fromJson(Map<String, dynamic> json) {
    return TournamentRanking(
      player: Player.fromJson(json['player'] ?? <String, dynamic>{}),
      wins: json['wins'] ?? 0,
      losses: json['losses'] ?? 0,
      matchesPlayed: json['matchesPlayed'] ?? 0,
      points: json['points'] ?? 0,
    );
  }
}
