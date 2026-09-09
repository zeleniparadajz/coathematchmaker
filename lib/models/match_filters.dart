import 'match.dart';

class MatchFilters {
  const MatchFilters({
    this.onlyMine = false,
    this.query = '',
    this.status = 'all',
    this.tournament = 'all',
    this.discipline = 'all',
    this.type = 'all',
  });

  final bool onlyMine;
  final String query;
  final String status;
  final String tournament;
  final String discipline;
  final String type;

  int get count => [
    status,
    tournament,
    discipline,
    type,
  ].where((value) => value != 'all').length;

  bool get hasFilters => count > 0 || query.trim().isNotEmpty;

  MatchFilters copyWith({
    bool? onlyMine,
    String? query,
    String? status,
    String? tournament,
    String? discipline,
    String? type,
  }) => MatchFilters(
    onlyMine: onlyMine ?? this.onlyMine,
    query: query ?? this.query,
    status: status ?? this.status,
    tournament: tournament ?? this.tournament,
    discipline: discipline ?? this.discipline,
    type: type ?? this.type,
  );

  List<TennisMatch> apply(Iterable<TennisMatch> matches, String playerId) {
    final terms = _searchText(
      query,
    ).split(RegExp(r'\s+')).where((term) => term.isNotEmpty).toList();
    return matches.where((match) {
      if (onlyMine && !match.includesPlayer(playerId)) return false;
      if (status != 'all' && match.status != status) return false;
      if (tournament == 'none' && match.tournament != null) return false;
      if (tournament != 'all' &&
          tournament != 'none' &&
          match.tournament?.id != tournament) {
        return false;
      }
      if (discipline != 'all' && match.discipline != discipline) return false;
      if (type != 'all' && match.friendly != (type == 'friendly')) return false;
      if (terms.isEmpty) return true;
      final text = _searchText(
        [
          match.team1Name,
          match.team2Name,
          match.tournament?.name ?? '',
          match.location ?? '',
        ].join(' '),
      );
      return terms.every(text.contains);
    }).toList();
  }

  static String _searchText(String value) => value
      .toLowerCase()
      .replaceAll('č', 'c')
      .replaceAll('ć', 'c')
      .replaceAll('š', 's')
      .replaceAll('ž', 'z')
      .replaceAll('đ', 'dj');
}
