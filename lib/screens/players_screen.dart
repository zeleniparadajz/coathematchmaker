import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/league_settings.dart';
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
                            label: '${player.matchesPlayed} ',
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
  late Future<_PlayerProfileData> _future;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_PlayerProfileData> _load() async {
    final player = await widget.league.player(widget.playerId);
    final settings = await widget.league.settings();
    return _PlayerProfileData(player: player, settings: settings);
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
        _future = _load();
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
      body: FutureBuilder<_PlayerProfileData>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final player = snapshot.data!.player;
          final settings = snapshot.data!.settings;
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
                    onTap: () => _showPointsBreakdown(player, settings),
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

  void _showPointsBreakdown(Player player, LeagueSettings settings) {
    final matchPoints = player.wins * settings.matchWinPoints;
    final titlePoints = player.tournamentsWon * settings.tournamentWinPoints;
    final calculated = matchPoints + titlePoints;
    final adjustment = player.totalPoints - calculated;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PointsBreakdownSheet(
        player: player,
        settings: settings,
        matchPoints: matchPoints,
        titlePoints: titlePoints,
        adjustment: adjustment,
      ),
    );
  }
}

class _PlayerProfileData {
  const _PlayerProfileData({required this.player, required this.settings});

  final Player player;
  final LeagueSettings settings;
}

class _PointsBreakdownSheet extends StatelessWidget {
  const _PointsBreakdownSheet({
    required this.player,
    required this.settings,
    required this.matchPoints,
    required this.titlePoints,
    required this.adjustment,
  });

  final Player player;
  final LeagueSettings settings;
  final int matchPoints;
  final int titlePoints;
  final int adjustment;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xfff7faf4),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.ink.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.court.withValues(alpha: .14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.leaderboard, color: AppTheme.court),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kako su izračunati poeni',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          player.fullName,
                          style: TextStyle(
                            color: AppTheme.ink.withValues(alpha: .58),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _pointsRow(
                context,
                icon: Icons.check_circle,
                title: 'Pobjede',
                detail: '${player.wins} x ${settings.matchWinPoints} pts',
                points: matchPoints,
                color: AppTheme.court,
              ),
              _pointsRow(
                context,
                icon: Icons.emoji_events,
                title: 'Titule',
                detail:
                    '${player.tournamentsWon} x ${settings.tournamentWinPoints} pts',
                points: titlePoints,
                color: AppTheme.clay,
              ),
              if (adjustment != 0)
                _pointsRow(
                  context,
                  icon: Icons.tune,
                  title: 'Korekcija',
                  detail:
                      'Razlika nastala iz ranijih pravila ili admin izmjene',
                  points: adjustment,
                  color: Colors.blueGrey,
                ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.court.withValues(alpha: .16),
                      AppTheme.lime.withValues(alpha: .26),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Text(
                      'Ukupno',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const Spacer(),
                    Text(
                      '${player.totalPoints} pts',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppTheme.ink,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Ranking računa samo potvrđene takmičarske mečeve. Prijateljski mečevi se broje u skor, ali ne dodaju poene.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.ink.withValues(alpha: .58),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pointsRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String detail,
    required int points,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: TextStyle(
                    color: AppTheme.ink.withValues(alpha: .56),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${points >= 0 ? '+' : ''}$points',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
