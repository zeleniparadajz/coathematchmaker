import 'package:flutter/material.dart';

import '../models/player.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/league_service.dart';
import '../theme/app_theme.dart';
import '../widgets/player_avatar.dart';
import 'players_screen.dart';

class RankingsScreen extends StatefulWidget {
  const RankingsScreen({
    super.key,
    required this.league,
    required this.api,
    required this.auth,
    this.refreshTick = 0,
  });

  final LeagueService league;
  final ApiClient api;
  final AuthService auth;
  final int refreshTick;

  @override
  State<RankingsScreen> createState() => _RankingsScreenState();
}

class _RankingsScreenState extends State<RankingsScreen> {
  late Future<List<Player>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.league.rankings();
  }

  @override
  void didUpdateWidget(covariant RankingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) {
      setState(() {
        _future = widget.league.rankings();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Player>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rankings = [...snapshot.data!]..sort(_comparePlayers);

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _future = widget.league.rankings();
            });
            await _future;
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: rankings.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.lime,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.court.withValues(alpha: .18),
                        blurRadius: 22,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          color: AppTheme.court,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.leaderboard,
                          color: AppTheme.ink,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rang lista',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }
              final rankingIndex = index - 1;
              final player = rankings[rankingIndex];
              return _RankingPlayerCard(
                player: player,
                rank: rankingIndex + 1,
                api: widget.api,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PlayerProfileScreen(
                      playerId: player.id,
                      league: widget.league,
                      api: widget.api,
                      auth: widget.auth,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _RankingPlayerCard extends StatelessWidget {
  const _RankingPlayerCard({
    required this.player,
    required this.rank,
    required this.api,
    required this.onTap,
  });

  final Player player;
  final int rank;
  final ApiClient api;
  final VoidCallback onTap;

  static const _gradients = [
    [Color(0xFF6EC6FF), Color(0xFF7B8CFF)],
    [Color(0xFFFFB15F), Color(0xFFFF8A45)],
    [Color(0xFFFF5B8F), Color(0xFFE94C78)],
    [Color(0xFFB45DFF), Color(0xFF726CFF)],
  ];

  @override
  Widget build(BuildContext context) {
    final colors = _gradients[(rank - 1) % _gradients.length];
    return Container(
      height: 124,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: .22),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colors.first.withValues(alpha: .86),
                        colors.last.withValues(alpha: .78),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ),
                Positioned(
                  right: -28,
                  top: -18,
                  bottom: -18,
                  child: Container(
                    width: 126,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .16),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
                  child: Row(
                    children: [
                      PlayerAvatar(player: player, api: api, radius: 26),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              player.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${player.totalPoints} pts',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .88),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _RankingMiniStat(
                                  value: '${player.wins}',
                                  label: 'Wins',
                                ),
                                _RankingMiniStat(
                                  value: '${player.matchesPlayed}',
                                  label: 'Mečevi',
                                ),
                                _RankingMiniStat(
                                  value: '${player.tournamentsWon}',
                                  label: 'Titule',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 58,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.more_horiz,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '$rank',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Ranking',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .82),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

int _comparePlayers(Player a, Player b) {
  final points = b.totalPoints.compareTo(a.totalPoints);
  if (points != 0) return points;

  final wins = b.wins.compareTo(a.wins);
  if (wins != 0) return wins;

  final losses = a.losses.compareTo(b.losses);
  if (losses != 0) return losses;

  final matches = a.matchesPlayed.compareTo(b.matchesPlayed);
  if (matches != 0) return matches;

  return a.fullName.compareTo(b.fullName);
}

class _RankingMiniStat extends StatelessWidget {
  const _RankingMiniStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SizedBox(
        height: 24,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  height: .95,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .72),
                  fontSize: 8.5,
                  height: .95,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
