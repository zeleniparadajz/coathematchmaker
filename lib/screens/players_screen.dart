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
import 'messages_screen.dart';

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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              AppTextField(
                controller: _search,
                label: 'Pronađi',
                icon: Icons.search,
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 2),
              ...players.map(
                (player) => _PlayerDiscoveryCard(
                  player: player,
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
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PlayerDiscoveryCard extends StatelessWidget {
  const _PlayerDiscoveryCard({
    required this.player,
    required this.api,
    required this.onTap,
  });

  final Player player;
  final ApiClient api;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 252,
      margin: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppTheme.ink.withValues(alpha: .08),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: Colors.white,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _PlayerCardBackdrop(player: player, api: api),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.ink.withValues(alpha: .78),
                        AppTheme.ink.withValues(alpha: .18),
                        Colors.transparent,
                      ],
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                      stops: const [0, .52, 1],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _CardPill(
                            icon: Icons.location_on_outlined,
                            label: player.country,
                            glass: true,
                          ),
                          const Spacer(),
                          _CardPill(
                            icon: Icons.bolt,
                            label: player.isAvailableForMatch
                                ? 'Aktivan'
                                : 'Neaktivan',
                            bright: player.isAvailableForMatch,
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Text(
                              player.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _PlayerCardTypography.name,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Transform.rotate(
                            angle: -.55,
                            child: Container(
                              width: 13,
                              height: 8,
                              margin: const EdgeInsets.only(bottom: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.court,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              player.club ?? 'Individual',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _PlayerCardTypography.meta,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text('|', style: _PlayerCardTypography.meta),
                          const SizedBox(width: 7),
                          Icon(
                            Icons.sports_tennis,
                            color: Colors.white.withValues(alpha: .84),
                            size: 13,
                          ),
                        ],
                      ),
                      const SizedBox(height: 11),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _CardPill(
                            icon: Icons.sports_tennis,
                            label: '${player.matchesPlayed} susret',
                          ),
                          _CardPill(
                            icon: Icons.bar_chart,
                            label: '${player.wins}W ${player.losses}L',
                          ),
                          const _CardPill(
                            icon: Icons.person_outline,
                            label: 'Singl / Dubl',
                          ),
                        ],
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

class _PlayerCardTypography {
  static final name = TextStyle(
    color: Colors.white,
    fontFamily: 'Avenir Next Rounded',
    fontFamilyFallback: const ['Avenir Next', 'SF Pro Display'],
    fontSize: 20,
    height: 1,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    shadows: [
      Shadow(
        color: Colors.black.withValues(alpha: .30),
        blurRadius: 10,
        offset: const Offset(0, 2),
      ),
    ],
  );

  static final meta = TextStyle(
    color: Colors.white.withValues(alpha: .92),
    fontFamily: 'Avenir Next Rounded',
    fontFamilyFallback: const ['Avenir Next', 'SF Pro Text'],
    fontSize: 11,
    height: 1,
    fontWeight: FontWeight.w700,
    letterSpacing: .05,
    shadows: [
      Shadow(
        color: Colors.black.withValues(alpha: .28),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );
}

class _PlayerCardBackdrop extends StatelessWidget {
  const _PlayerCardBackdrop({required this.player, required this.api});

  final Player player;
  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    final url = api.imageUrl(player.profileImage);
    if (url.isEmpty) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.court, AppTheme.lime],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Icon(
          Icons.sports_tennis,
          size: 76,
          color: Colors.white.withValues(alpha: .24),
        ),
      );
    }

    return Image.network(url, fit: BoxFit.cover);
  }
}

class _CardPill extends StatelessWidget {
  const _CardPill({
    required this.icon,
    required this.label,
    this.bright = false,
    this.glass = false,
  });

  final IconData icon;
  final String label;
  final bool bright;
  final bool glass;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: glass
            ? Colors.black.withValues(alpha: .20)
            : bright
            ? AppTheme.lime.withValues(alpha: .92)
            : Colors.white.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: glass ? Colors.white : AppTheme.ink),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: glass ? Colors.white : AppTheme.ink,
              fontFamily: 'Avenir Next Rounded',
              fontFamilyFallback: const ['Avenir Next', 'SF Pro Text'],
              fontSize: 10.5,
              height: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
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
                  fontFamily: 'Avenir Next',
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              Text(
                '${player.country}  |  ${player.club ?? 'Bez kluba'}',
                textAlign: TextAlign.center,
              ),
              if (!canEdit) ...[
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () async {
                    final conversation = await widget.league.startConversation(
                      player.id,
                    );
                    if (!context.mounted) return;
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          league: widget.league,
                          api: widget.api,
                          auth: widget.auth,
                          conversation: conversation,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Pošalji poruku'),
                ),
              ],
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
