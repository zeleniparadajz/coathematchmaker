import 'package:coathematchmaker/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import '../models/player.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/league_service.dart';
import '../theme/app_theme.dart';
import '../widgets/player_avatar.dart';
import '../widgets/load_error.dart';
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
    if (oldWidget.refreshTick != widget.refreshTick) _reload();
  }

  Future<void> _reload() async {
    final future = widget.league.rankings();
    setState(() {
      _future = future;
    });
    try {
      await future;
    } catch (_) {
      /* The list provides a retry action. */
    }
  }

  void _open(Player player) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => PlayerProfileScreen(
        playerId: player.id,
        league: widget.league,
        api: widget.api,
        auth: widget.auth,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Player>>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.hasError) return LoadError(onRetry: _reload);
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      // The API is the single source of ranking order, including ties.
      final players = snapshot.data!;
      final myIndex = players.indexWhere(
        (player) => player.id == widget.auth.currentPlayer?.id,
      );
      return RefreshIndicator(
        onRefresh: _reload,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          itemCount: players.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (players.length >= 3) ...[
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final position in [1, 0, 2])
                          Expanded(
                            child: _PodiumPlayer(
                              player: players[position],
                              api: widget.api,
                              position: position + 1,
                              onTap: () => _open(players[position]),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 26),
                  ],
                  if (myIndex >= 0)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.court,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.leaderboard_outlined,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              context.tr("Moja pozicija: {p0}.", [myIndex + 1]),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            context.tr("{p0} poena", [
                              players[myIndex].totalPoints,
                            ]),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      SizedBox(width: 38, child: Text('#')),
                      Expanded(child: Text(context.tr("Igrač"))),
                      Text(context.tr("Poeni")),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (players.isEmpty)
                    Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(context.tr("Rang-lista je trenutno prazna.")),
                    ),
                ],
              );
            }
            final player = players[index - 1];
            final isMe = player.id == widget.auth.currentPlayer?.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                borderRadius: BorderRadius.circular(24),
                color: isMe
                    ? AppTheme.lime
                    : Colors.white.withValues(alpha: .8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => _open(player),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 10,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 34,
                          child: index <= 3
                              ? Icon(
                                  Icons.emoji_events,
                                  size: 21,
                                  color: [
                                    AppTheme.gold,
                                    AppTheme.muted,
                                    AppTheme.clay,
                                  ][index - 1],
                                )
                              : Text(
                                  '$index',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                        PlayerAvatar(
                          player: player,
                          api: widget.api,
                          radius: 21,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                player.fullName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.tr("{p0} pobjeda · {p1} mečeva", [
                                  player.wins,
                                  player.matchesPlayed,
                                ]),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${player.totalPoints}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
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

class _PodiumPlayer extends StatelessWidget {
  const _PodiumPlayer({
    required this.player,
    required this.api,
    required this.position,
    required this.onTap,
  });
  final Player player;
  final ApiClient api;
  final int position;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final first = position == 1;
    final color = first
        ? AppTheme.court
        : (position == 2 ? AppTheme.blue : AppTheme.gold);
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(4, 4, 4, first ? 24 : 0),
        child: Column(
          children: [
            if (first) ...[
              const Icon(Icons.emoji_events, color: AppTheme.gold, size: 25),
              const SizedBox(height: 10),
            ],
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.withValues(alpha: .55),
                  width: 2,
                ),
                color: Colors.white.withValues(alpha: .7),
              ),
              child: PlayerAvatar(
                player: player,
                api: api,
                radius: first ? 36 : 29,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              player.fullName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${player.totalPoints}',
              style: TextStyle(
                fontSize: first ? 25 : 21,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              context.tr("{p0}. mjesto", [position]),
              style: const TextStyle(fontSize: 11, color: AppTheme.muted),
            ),
          ],
        ),
      ),
    );
  }
}
