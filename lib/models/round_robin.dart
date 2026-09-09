class LeagueStanding {
  LeagueStanding.fromJson(Map<String, dynamic> json)
    : playerId = json['playerId'],
      seed = json['seed'],
      played = json['played'],
      wins = json['wins'],
      losses = json['losses'],
      setsWon = json['setsWon'],
      setsLost = json['setsLost'],
      gamesWon = json['gamesWon'],
      gamesLost = json['gamesLost'];
  final String playerId;
  final int seed, played, wins, losses, setsWon, setsLost, gamesWon, gamesLost;
}

class RoundRobinState {
  RoundRobinState.fromJson(Map<String, dynamic> json)
    : standings = (json['standings'] as List)
          .map((v) => LeagueStanding.fromJson(v))
          .toList(),
      seeds = List<String>.from(json['seeds']),
      pairs = (json['pairs'] as List).map((v) => List<String>.from(v)).toList(),
      rankingRules = json['rankingRules'],
      canStart = json['canStart'] == true,
      started = json['started'] == true,
      canAdvance = json['canAdvance'] == true,
      finished = json['finished'] == true,
      needsRepair = json['needsRepair'] == true,
      blockedReason = json['blockedReason'],
      currentRound = json['currentRound'],
      winnerId = json['winnerId'];
  final List<LeagueStanding> standings;
  final List<String> seeds;
  final List<List<String>> pairs;
  final String rankingRules;
  final String? blockedReason, currentRound, winnerId;
  final bool canStart, started, canAdvance, finished, needsRepair;
}
