import 'package:flutter/material.dart';

import '../models/player.dart';
import '../models/tournament.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/league_service.dart';
import '../theme/app_theme.dart';
import '../widgets/player_avatar.dart';
import '../widgets/section_header.dart';
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
          final top = data.rankings.take(5).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.ink, AppTheme.court],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    PlayerAvatar(player: me, api: widget.api, radius: 34),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Zdravo, ${me.firstName}',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          Text(
                            '${me.totalPoints} poena  |  ${me.wins}-${me.losses}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Logout',
                      onPressed: widget.auth.logout,
                      icon: const Icon(Icons.logout, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
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
                    label: 'Aktivni turniri',
                    value: '$active',
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
              const SectionHeader('Top 5 ranking'),
              ...top.asMap().entries.map((entry) {
                final player = entry.value;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.lime,
                      child: Text('${entry.key + 1}'),
                    ),
                    title: Text(player.fullName),
                    subtitle: Text('${player.wins} pobjeda'),
                    trailing: Text('${player.totalPoints} pts'),
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
