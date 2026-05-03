class LeagueSettings {
  const LeagueSettings({
    required this.resultEntryDelayMinutes,
    required this.matchWinPoints,
    required this.tournamentWinPoints,
  });

  final int resultEntryDelayMinutes;
  final int matchWinPoints;
  final int tournamentWinPoints;

  factory LeagueSettings.fromJson(Map<String, dynamic> json) {
    return LeagueSettings(
      resultEntryDelayMinutes: json['resultEntryDelayMinutes'] ?? 60,
      matchWinPoints: json['matchWinPoints'] ?? 10,
      tournamentWinPoints: json['tournamentWinPoints'] ?? 50,
    );
  }
}
