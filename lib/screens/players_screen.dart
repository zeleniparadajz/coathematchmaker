import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/player.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/league_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_form_fields.dart';
import '../widgets/player_avatar.dart';
import '../widgets/stat_card.dart';

class PlayersScreen extends StatefulWidget {
  const PlayersScreen({
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
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  late Future<List<Player>> _future;
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = widget.league.players();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PlayersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) {
      setState(() {
        _future = widget.league.players();
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
        final players = snapshot.data!
            .where(
              (player) =>
                  player.fullName.toLowerCase().contains(_query.toLowerCase()),
            )
            .toList();
        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _future = widget.league.players();
            });
            await _future;
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppTextField(
                controller: _search,
                label: 'Pretraga igrača',
                icon: Icons.search,
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 12),
              ...players.map(
                (player) => Card(
                  child: ListTile(
                    leading: PlayerAvatar(player: player, api: widget.api),
                    title: Text(player.fullName),
                    subtitle: Text(
                      '${player.club ?? player.country}  |  ${player.wins}-${player.losses}',
                    ),
                    trailing: Text('${player.totalPoints} pts'),
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
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class PlayerProfileScreen extends StatefulWidget {
  const PlayerProfileScreen({
    super.key,
    required this.playerId,
    required this.league,
    required this.api,
    required this.auth,
  });

  final String playerId;
  final LeagueService league;
  final ApiClient api;
  final AuthService auth;

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  late Future<Player> _future;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _future = widget.league.player(widget.playerId);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
    );
    if (file == null) return;

    setState(() => _uploading = true);
    try {
      await widget.league.uploadProfileImage(file);
      await widget.auth.refreshMe();
      setState(() {
        _future = widget.league.player(widget.playerId);
      });
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil igrača')),
      body: FutureBuilder<Player>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final player = snapshot.data!;
          final canEdit = widget.auth.currentPlayer?.id == player.id;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    PlayerAvatar(player: player, api: widget.api, radius: 62),
                    if (canEdit)
                      IconButton.filled(
                        tooltip: 'Promijeni sliku',
                        onPressed: _uploading ? null : _pickImage,
                        icon: _uploading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.photo_camera),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                player.fullName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '${player.country}  |  ${player.club ?? 'Bez kluba'}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.25,
                children: [
                  StatCard(
                    label: 'Poeni',
                    value: '${player.totalPoints}',
                    icon: Icons.leaderboard,
                  ),
                  StatCard(
                    label: 'Pobjede',
                    value: '${player.wins}',
                    icon: Icons.check_circle,
                    color: AppTheme.court,
                  ),
                  StatCard(
                    label: 'Porazi',
                    value: '${player.losses}',
                    icon: Icons.cancel,
                    color: AppTheme.clay,
                  ),
                  StatCard(
                    label: 'Mečevi',
                    value: '${player.matchesPlayed}',
                    icon: Icons.sports_tennis,
                  ),
                  StatCard(
                    label: 'Titule',
                    value: '${player.tournamentsWon}',
                    icon: Icons.emoji_events,
                    color: AppTheme.clay,
                  ),
                  StatCard(
                    label: 'Godište',
                    value: '${player.birthYear}',
                    icon: Icons.cake,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
