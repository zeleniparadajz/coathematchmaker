import 'package:flutter/material.dart';

import '../models/player.dart';
import '../models/tournament.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/league_service.dart';
import '../theme/app_theme.dart';
import '../widgets/player_avatar.dart';
import '../widgets/stat_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.auth,
    required this.league,
    required this.api,
    this.refreshTick = 0,
  });

  final AuthService auth;
  final LeagueService league;
  final ApiClient api;
  final int refreshTick;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<_DashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) {
      setState(() {
        _future = _load();
      });
    }
  }

  Future<_DashboardData> _load() async {
    final results = await Future.wait([
      widget.league.players(),
      widget.league.tournaments(),
      widget.league.rankings(),
    ]);
    return _DashboardData(
      players: results[0] as List<Player>,
      tournaments: results[1] as List<Tournament>,
      rankings: results[2] as List<Player>,
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.auth.currentPlayer!;
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _future = _load();
        });
        await _future;
      },
      child: FutureBuilder<_DashboardData>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final active = data.tournaments
              .where((t) => t.status == 'active')
              .length;
          final myTournaments = data.tournaments
              .where(
                (tournament) =>
                    tournament.participants.any((player) => player.id == me.id),
              )
              .length;
          final top = data.rankings.take(5).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.courtDark, AppTheme.court],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.court.withValues(alpha: .22),
                      blurRadius: 26,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        PlayerAvatar(player: me, api: widget.api, radius: 36),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                me.fullName,
                                style: _DashboardTypography.heroName,
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.lime.withValues(alpha: .22),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${me.totalPoints} pts  |  ${me.wins}W ${me.losses}L',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Avenir Next Rounded',
                                    fontFamilyFallback: [
                                      'Avenir Next',
                                      'SF Pro Text',
                                    ],
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        _HeroMiniStat(
                          label: 'Mečevi',
                          value: '${me.matchesPlayed}',
                          icon: Icons.sports_tennis,
                        ),
                        const SizedBox(width: 10),
                        _HeroMiniStat(
                          label: 'Titule',
                          value: '${me.tournamentsWon}',
                          icon: Icons.emoji_events,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.bolt,
                            color: AppTheme.lime,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              active > 0
                                  ? '$active aktivnih turnira se trenutno igra'
                                  : 'Nema aktivnih turnira trenutno',
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Avenir Next Rounded',
                                fontFamilyFallback: [
                                  'Avenir Next',
                                  'SF Pro Text',
                                ],
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text('Liga danas', style: _DashboardTypography.section),
              const SizedBox(height: 10),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.35,
                children: [
                  StatCard(
                    label: 'Igrača',
                    value: '${data.players.length}',
                    icon: Icons.groups,
                  ),
                  StatCard(
                    label: 'Moji turniri',
                    value: '$myTournaments',
                    icon: Icons.emoji_events,
                    color: AppTheme.clay,
                  ),
                  StatCard(
                    label: 'Moji mečevi',
                    value: '${me.matchesPlayed}',
                    icon: Icons.sports_score,
                  ),
                  StatCard(
                    label: 'Titule',
                    value: '${me.tournamentsWon}',
                    icon: Icons.workspace_premium,
                    color: AppTheme.clay,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text('Top 5 ranking', style: _DashboardTypography.section),
              const SizedBox(height: 10),
              ...top.asMap().entries.map((entry) {
                final player = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.ink.withValues(alpha: .05),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: entry.key < 3
                            ? AppTheme.court
                            : AppTheme.cream,
                        child: Text(
                          '${entry.key + 1}',
                          style: const TextStyle(
                            color: AppTheme.ink,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      PlayerAvatar(player: player, api: widget.api, radius: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              player.fullName,
                              style: _DashboardTypography.rankingName,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${player.wins} pobjeda  |  ${player.matchesPlayed} mečeva',
                              style: TextStyle(
                                color: AppTheme.ink.withValues(alpha: .56),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.lime,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${player.totalPoints} pts',
                          style: _DashboardTypography.pointsPill,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _HeroMiniStat extends StatelessWidget {
  const _HeroMiniStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .13),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.lime, size: 20),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Avenir Next Rounded',
                    fontFamilyFallback: ['Avenir Next', 'SF Pro Text'],
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontFamily: 'Avenir Next Rounded',
                    fontFamilyFallback: ['Avenir Next', 'SF Pro Text'],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardTypography {
  static const heroName = TextStyle(
    color: Colors.white,
    fontFamily: 'Avenir Next Rounded',
    fontFamilyFallback: ['Avenir Next', 'SF Pro Display'],
    fontSize: 22,
    height: 1,
    fontWeight: FontWeight.w700,
  );

  static const section = TextStyle(
    color: AppTheme.ink,
    fontFamily: 'Avenir Next Rounded',
    fontFamilyFallback: ['Avenir Next', 'SF Pro Display'],
    fontSize: 21,
    height: 1.05,
    fontWeight: FontWeight.w700,
  );

  static const rankingName = TextStyle(
    fontFamily: 'Avenir Next Rounded',
    fontFamilyFallback: ['Avenir Next', 'SF Pro Text'],
    fontSize: 14.5,
    fontWeight: FontWeight.w700,
  );

  static const pointsPill = TextStyle(
    fontFamily: 'Avenir Next Rounded',
    fontFamilyFallback: ['Avenir Next', 'SF Pro Text'],
    fontWeight: FontWeight.w700,
  );
}

class _DashboardData {
  const _DashboardData({
    required this.players,
    required this.tournaments,
    required this.rankings,
  });

  final List<Player> players;
  final List<Tournament> tournaments;
  final List<Player> rankings;
}
