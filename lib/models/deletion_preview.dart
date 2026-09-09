class DeletionPreview {
  const DeletionPreview({
    required this.revision,
    required this.matchCount,
    required this.imageCount,
    required this.legacyMatches,
    required this.needsLegacyTournamentAward,
    required this.clearsTournamentWinner,
    this.blockedReason,
  });

  final String revision;
  final int matchCount;
  final int imageCount;
  final String? blockedReason;
  final Map<String, String> legacyMatches;
  final bool needsLegacyTournamentAward;
  final bool clearsTournamentWinner;

  factory DeletionPreview.fromJson(Map<String, dynamic> json) =>
      DeletionPreview(
        revision: json['revision'] as String,
        matchCount: (json['matchCount'] as num).toInt(),
        imageCount: (json['imageCount'] as num).toInt(),
        blockedReason: json['blockedReason'] as String?,
        legacyMatches: {
          for (final item in json['legacyMatches'] as List? ?? [])
            item['id'] as String: item['label'] as String,
        },
        needsLegacyTournamentAward: json['needsLegacyTournamentAward'] == true,
        clearsTournamentWinner: json['clearsTournamentWinner'] == true,
      );
}
