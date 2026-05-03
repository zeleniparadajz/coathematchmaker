import 'package:flutter/material.dart';

import '../models/player.dart';
import '../services/api_client.dart';
import '../services/league_service.dart';
import '../theme/app_theme.dart';
import '../widgets/player_avatar.dart';

class RankingsScreen extends StatefulWidget {
  const RankingsScreen({super.key, required this.league, required this.api});

  final LeagueService league;
  final ApiClient api;

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
  Widget build(BuildContext context) {
    return FutureBuilder<List<Player>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final rankings = [...snapshot.data!]
          ..sort((a, b) => b.totalPoints.compareTo(a.totalPoints) == 0
              ? b.wins.compareTo(a.wins)
              : b.totalPoints.compareTo(a.totalPoints));

        return RefreshIndicator(
          onRefresh: () async => setState(() => _future = widget.league.rankings()),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rankings.length,
            itemBuilder: (context, index) {
              final player = rankings[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: index < 3 ? AppTheme.lime : Colors.white,
                    child: Text('${index + 1}'),
                  ),
                  title: Row(
                    children: [
                      PlayerAvatar(player: player, api: widget.api, radius: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(player.fullName)),
                    ],
                  ),
                  subtitle: Text('${player.wins} pobjeda  |  ${player.matchesPlayed} mečeva'),
                  trailing: Text('${player.totalPoints} pts'),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
