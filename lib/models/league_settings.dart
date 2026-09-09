class LeagueSettings {
  const LeagueSettings({
    required this.resultEntryDelayMinutes,
    required this.matchWinPoints,
    required this.tournamentWinPoints,
    this.inactivityDays = 0,
  });

  final int resultEntryDelayMinutes;
  final int matchWinPoints;
  final int tournamentWinPoints;
  final int inactivityDays;

  factory LeagueSettings.fromJson(Map<String, dynamic> json) {
    return LeagueSettings(
      resultEntryDelayMinutes: json['resultEntryDelayMinutes'] ?? 60,
      matchWinPoints: json['matchWinPoints'] ?? 10,
      tournamentWinPoints: json['tournamentWinPoints'] ?? 50,
      inactivityDays: json['inactivityDays'] ?? 0,
    );
  }
}
