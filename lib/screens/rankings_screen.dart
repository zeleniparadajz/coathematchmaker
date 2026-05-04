import 'package:flutter/material.dart';

import '../models/player.dart';
import '../services/api_client.dart';
import '../services/league_service.dart';
import '../theme/app_theme.dart';
import '../widgets/player_avatar.dart';

class RankingsScreen extends StatefulWidget {
  const RankingsScreen({
    super.key,
    required this.league,
    required this.api,
    this.refreshTick = 0,
  });

  final LeagueService league;
  final ApiClient api;
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
        final rankings = [...snapshot.data!]
          ..sort(
            (a, b) => b.totalPoints.compareTo(a.totalPoints) == 0
                ? b.wins.compareTo(a.wins)
                : b.totalPoints.compareTo(a.totalPoints),
          );

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
                final leader = rankings.isNotEmpty ? rankings.first : null;
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
                              'Generalna rang lista',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              leader == null
                                  ? 'Još nema rangiranih igrača.'
                                  : 'Lider: ${leader.fullName} sa ${leader.totalPoints} pts',
                              style: TextStyle(
                                color: AppTheme.ink.withValues(alpha: .68),
                                fontWeight: FontWeight.w700,
                              ),
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
              final podium = rankingIndex < 3;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  gradient: podium
                      ? LinearGradient(
                          colors: [
                            AppTheme.lime.withValues(alpha: .34),
                            Colors.white,
                          ],
                        )
                      : null,
                  color: podium ? null : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.ink.withValues(alpha: .05),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  leading: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      PlayerAvatar(player: player, api: widget.api, radius: 27),
                      CircleAvatar(
                        radius: 13,
                        backgroundColor: podium ? AppTheme.clay : AppTheme.ink,
                        child: Text(
                          '${rankingIndex + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  title: Text(
                    player.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    '${player.wins}W - ${player.losses}L  |  ${player.matchesPlayed} mečeva',
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${player.totalPoints}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Text('pts'),
                    ],
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
