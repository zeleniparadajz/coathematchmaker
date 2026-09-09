import 'package:coathematchmaker/l10n/app_strings.dart';
import '../widgets/player_activity.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/league_settings.dart';
import '../models/match.dart';
import '../models/player.dart';
import '../models/tournament.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/league_service.dart';
import '../theme/app_theme.dart';
import '../widgets/player_avatar.dart';
import '../widgets/stat_card.dart';
import '../widgets/load_error.dart';
import '../widgets/photo_viewer.dart';
import '../widgets/sport_surfaces.dart';
import 'messages_screen.dart';
import 'matches_screen.dart';

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
  String? _city;
  String? _club;
  bool _available = false;
  bool _compact = false;

  @override
  void initState() {
    super.initState();
    _future = _loadPlayers();
    _restoreView();
  }

  Future<void> _restoreView() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _compact = prefs.getBool('players_compact') ?? false);
    }
  }

  Future<void> _setCompact(bool value) async {
    setState(() => _compact = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('players_compact', value);
  }

  Future<List<Player>> _loadPlayers() async {
    final players = await widget.league.players();
    return players
        .where((p) => p.active || p.id == widget.auth.currentPlayer?.id)
        .toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
  }

  Future<void> _reload() async {
    final future = _loadPlayers();
    setState(() {
      _future = future;
    });
    try {
      await future;
    } catch (_) {
      /* The view shows a retry action. */
    }
  }

  @override
  void didUpdateWidget(covariant PlayersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
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

  Future<void> _filters(List<Player> players) async {
    var city = _city;
    var club = _club;
    final cities =
        players
            .map((p) => p.city?.trim() ?? '')
            .where((v) => v.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final clubs =
        players
            .map((p) => p.club?.trim() ?? '')
            .where((v) => v.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    if (!cities.contains(city)) city = null;
    if (!clubs.contains(club)) club = null;
    final apply = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.tr("Filteri igrača"),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: city ?? '',
                  isExpanded: true,
                  decoration: InputDecoration(labelText: context.tr("Grad")),
                  items: [
                    DropdownMenuItem(
                      value: '',
                      child: Text(context.tr("Svi gradovi")),
                    ),
                    ...cities.map(
                      (v) => DropdownMenuItem(value: v, child: Text(v)),
                    ),
                  ],
                  onChanged: (v) => update(() => city = v == '' ? null : v),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: club ?? '',
                  isExpanded: true,
                  decoration: InputDecoration(labelText: context.tr("Klub")),
                  items: [
                    DropdownMenuItem(
                      value: '',
                      child: Text(context.tr("Svi klubovi")),
                    ),
                    ...clubs.map(
                      (v) => DropdownMenuItem(value: v, child: Text(v)),
                    ),
                  ],
                  onChanged: (v) => update(() => club = v == '' ? null : v),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(context.tr("Prikaži igrače")),
                ),
                TextButton(
                  onPressed: () {
                    city = null;
                    club = null;
                    Navigator.pop(context, true);
                  },
                  child: Text(context.tr("Ukloni filtere")),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (apply == true && mounted) {
      setState(() {
        _city = city;
        _club = club;
      });
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Player>>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.hasError) return LoadError(onRetry: _reload);
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final all = snapshot.data!;
      final players = all.where((p) {
        final haystack =
            '${p.fullName} ${p.city ?? ''} ${p.club ?? ''} ${p.country}'
                .toLowerCase();
        return haystack.contains(_query.toLowerCase().trim()) &&
            (!_available || p.isAvailableForMatch) &&
            (_city == null || p.city == _city) &&
            (_club == null || p.club == _club);
      }).toList();
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: context.tr("Pronađi igrača"),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: context.tr("Obriši pretragu"),
                              onPressed: () {
                                _search.clear();
                                setState(() => _query = '');
                              },
                              icon: const Icon(Icons.close),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: context.tr("Filteri"),
                  onPressed: () => _filters(all),
                  icon: Badge(
                    isLabelVisible: _city != null || _club != null,
                    child: const Icon(Icons.tune),
                  ),
                ),
                IconButton(
                  tooltip: _compact
                      ? context.tr("Prikaz fotografija")
                      : context.tr("Sažeta lista"),
                  onPressed: () => _setCompact(!_compact),
                  icon: Icon(
                    _compact ? Icons.grid_view : Icons.view_list_outlined,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                FilterChip(
                  label: Text(context.tr("Dostupni za meč")),
                  selected: _available,
                  onSelected: (v) => setState(() => _available = v),
                ),
                Text(
                  context.tr("{p0} igrača", [players.length]),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _reload,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (players.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 64),
                        const Icon(Icons.person_search_outlined, size: 40),
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            context.tr("Nema igrača za izabrane filtere."),
                          ),
                        ),
                        Center(
                          child: TextButton(
                            onPressed: () {
                              _search.clear();
                              setState(() {
                                _city = null;
                                _club = null;
                                _available = false;
                                _query = '';
                              });
                            },
                            child: Text(context.tr("Prikaži sve igrače")),
                          ),
                        ),
                      ],
                    );
                  }
                  if (_compact) {
                    return ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: players.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final p = players[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 6,
                          ),
                          leading: PlayerAvatar(player: p, api: widget.api),
                          title: Text(p.fullName),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                [p.city, p.club]
                                    .whereType<String>()
                                    .where((v) => v.isNotEmpty)
                                    .join(' · '),
                              ),
                              PlayerActivity(lastActiveAt: p.lastActiveAt),
                            ],
                          ),
                          trailing: Icon(
                            Icons.circle,
                            size: 10,
                            color: p.isAvailableForMatch
                                ? AppTheme.court
                                : AppTheme.muted,
                          ),
                          onTap: () => _open(p),
                        );
                      },
                    );
                  }
                  final columns = constraints.maxWidth >= 1000
                      ? 3
                      : constraints.maxWidth >= 650
                      ? 2
                      : 1;
                  final width =
                      (constraints.maxWidth - 32 - (columns - 1) * 16) /
                      columns;
                  return GridView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      mainAxisExtent:
                          width * 1.12 +
                          64 +
                          100 * (MediaQuery.textScalerOf(context).scale(1) - 1),
                    ),
                    itemCount: players.length,
                    itemBuilder: (_, index) => _PlayerCard(
                      player: players[index],
                      api: widget.api,
                      onOpen: () => _open(players[index]),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({
    required this.player,
    required this.api,
    required this.onOpen,
  });
  final Player player;
  final ApiClient api;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final url = api.imageUrl(player.profileImage);
    final available = player.isAvailableForMatch;
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      shadowColor: AppTheme.courtDark.withValues(alpha: .14),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url.isNotEmpty)
            SportPhoto(url: url, alignment: Alignment.topCenter)
          else ...[
            const SportPhoto(),
            const ColoredBox(color: Color(0x881C5968)),
            Positioned(
              top: 14,
              right: 14,
              child: PlayerAvatar(
                key: ValueKey('player-card-avatar:${player.id}'),
                player: player,
                api: api,
                radius: 30,
              ),
            ),
          ],
          const PhotoShade(),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: url.isEmpty
                    ? onOpen
                    : () => openPhotoViewer(context, [url]),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          Positioned(
            top: 14,
            left: 14,
            right: 14,
            child: Row(
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: available
                          ? AppTheme.court
                          : const Color(0xDD243D41),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .3),
                      ),
                    ),
                    child: Text(
                      available
                          ? context.tr("Dostupan za meč")
                          : context.tr("Nedostupan"),
                      maxLines: 2,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                if (url.isNotEmpty)
                  IconButton(
                    tooltip: context.tr("Prikaži cijelu fotografiju"),
                    onPressed: () => openPhotoViewer(context, [url]),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: .88),
                      foregroundColor: AppTheme.ink,
                    ),
                    icon: const Icon(Icons.open_in_full, size: 19),
                  ),
              ],
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.fullName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    height: 1.12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  [
                    player.city?.isNotEmpty == true
                        ? player.city!
                        : player.country,
                    if (player.club?.isNotEmpty == true) player.club!,
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFE0EDE8),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                PlayerActivity(
                  lastActiveAt: player.lastActiveAt,
                  color: Colors.white,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Icon(
                      Icons.sports_tennis,
                      color: Color(0xFFDFF2AE),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.tr("{p0} pobjeda · {p1} poena", [
                          player.wins,
                          player.totalPoints,
                        ]),
                        maxLines: 2,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: onOpen,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.ink,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(context.tr("Profil")),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 17),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
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
    final results = await Future.wait([
      widget.league.player(widget.playerId),
      widget.league.settings(),
      widget.league.matches(),
      widget.league.tournaments(),
    ]);
    return _PlayerProfileData(
      player: results[0] as Player,
      settings: results[1] as LeagueSettings,
      matches: results[2] as List<TennisMatch>,
      tournaments: results[3] as List<Tournament>,
    );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.serverMessage(error.message))),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr("Profil igrača"))),
      body: FutureBuilder<_PlayerProfileData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return LoadError(
              onRetry: () => setState(() {
                _future = _load();
              }),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final player = snapshot.data!.player;
          final profileData = snapshot.data!;
          final canEdit = widget.auth.currentPlayer?.id == player.id;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    PlayerAvatar(
                      player: player,
                      api: widget.api,
                      radius: 62,
                      allowPreview: true,
                    ),
                    if (canEdit)
                      IconButton.filled(
                        tooltip: context.tr("Promijeni sliku"),
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
                '${player.country}  |  ${player.club ?? context.tr("Bez kluba")}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Center(child: PlayerActivity(lastActiveAt: player.lastActiveAt)),
              if (!player.isAvailableForMatch) ...[
                const SizedBox(height: 8),
                Text(
                  context.tr(
                    player.unavailableDueToInactivity
                        ? 'Nedostupan zbog neaktivnosti'
                        : 'Nedostupan za meč',
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (!canEdit) ...[
                const SizedBox(height: 14),
                if (player.isAvailableForMatch)
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => ChallengeFormScreen(
                          league: widget.league,
                          canManageLocations: widget.auth.isAdmin,
                          currentPlayerId: widget.auth.currentPlayer!.id,
                          initialOpponentId: player.id,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.sports_tennis),
                    label: Text(context.tr("Izazovi na meč")),
                  ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () async {
                    final conversation = await widget.league.startConversation(
                      player.id,
                    );
                    if (!context.mounted) return;
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          league: widget.league,
                          api: widget.api,
                          auth: widget.auth,
                          conversation: conversation,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: Text(context.tr("Pošalji poruku")),
                ),
              ],
              const SizedBox(height: 18),
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: MediaQuery.sizeOf(context).width >= 700
                      ? 3
                      : 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  mainAxisExtent:
                      158 +
                      52 * (MediaQuery.textScalerOf(context).scale(1) - 1),
                ),
                children: [
                  StatCard(
                    label: context.tr("Poeni"),
                    value: '${player.totalPoints}',
                    icon: Icons.leaderboard,
                    onTap: () => _showPointsBreakdown(profileData),
                  ),
                  StatCard(
                    label: context.tr("Pobjede"),
                    value: '${player.wins}',
                    icon: Icons.check_circle,
                    color: AppTheme.court,
                    onTap: () =>
                        _showStatBreakdown(profileData, _StatKind.wins),
                  ),
                  StatCard(
                    label: context.tr("Porazi"),
                    value: '${player.losses}',
                    icon: Icons.cancel,
                    color: AppTheme.clay,
                    onTap: () =>
                        _showStatBreakdown(profileData, _StatKind.losses),
                  ),
                  StatCard(
                    label: context.tr("Mečevi"),
                    value: '${player.matchesPlayed}',
                    icon: Icons.sports_tennis,
                    onTap: () =>
                        _showStatBreakdown(profileData, _StatKind.matches),
                  ),
                  StatCard(
                    label: context.tr("Titule"),
                    value: '${player.tournamentsWon}',
                    icon: Icons.emoji_events,
                    color: AppTheme.clay,
                    onTap: () =>
                        _showStatBreakdown(profileData, _StatKind.titles),
                  ),
                  StatCard(
                    label: context.tr("Godište"),
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

  void _showPointsBreakdown(_PlayerProfileData data) {
    final player = data.player;
    final settings = data.settings;
    final matchPoints = data.competitiveWins.length * settings.matchWinPoints;
    final titlePoints =
        data.competitiveTitles.length * settings.tournamentWinPoints;
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
        wins: data.competitiveWins,
        titles: data.competitiveTitles,
      ),
    );
  }

  void _showStatBreakdown(_PlayerProfileData data, _StatKind kind) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _StatBreakdownSheet(data: data, kind: kind),
    );
  }
}

class _PlayerProfileData {
  const _PlayerProfileData({
    required this.player,
    required this.settings,
    required this.matches,
    required this.tournaments,
  });

  final Player player;
  final LeagueSettings settings;
  final List<TennisMatch> matches;
  final List<Tournament> tournaments;

  List<TennisMatch> get confirmedMatches => matches
      .where(
        (match) =>
            match.status == 'confirmed' &&
            !match.friendly &&
            _isParticipant(match, player.id),
      )
      .toList();

  List<TennisMatch> get competitiveWins =>
      confirmedMatches.where((match) => _isWinner(match, player.id)).toList();

  List<TennisMatch> get competitiveLosses =>
      confirmedMatches.where((match) => _isLoser(match, player.id)).toList();

  List<Tournament> get competitiveTitles => tournaments
      .where(
        (tournament) =>
            !tournament.friendly && tournament.winner?.id == player.id,
      )
      .toList();

  static bool _isParticipant(TennisMatch match, String playerId) {
    return [
      match.player1.id,
      match.player2.id,
      match.player1Partner?.id,
      match.player2Partner?.id,
    ].contains(playerId);
  }

  static bool _isWinner(TennisMatch match, String playerId) {
    final winnerId = match.winner?.id;
    if (winnerId == null) return false;
    if (winnerId == match.player1.id) {
      return playerId == match.player1.id ||
          playerId == match.player1Partner?.id;
    }
    if (winnerId == match.player2.id) {
      return playerId == match.player2.id ||
          playerId == match.player2Partner?.id;
    }
    return false;
  }

  static bool _isLoser(TennisMatch match, String playerId) {
    return _isParticipant(match, playerId) && !_isWinner(match, playerId);
  }
}

class _PointsBreakdownSheet extends StatelessWidget {
  const _PointsBreakdownSheet({
    required this.player,
    required this.settings,
    required this.matchPoints,
    required this.titlePoints,
    required this.adjustment,
    required this.wins,
    required this.titles,
  });

  final Player player;
  final LeagueSettings settings;
  final int matchPoints;
  final int titlePoints;
  final int adjustment;
  final List<TennisMatch> wins;
  final List<Tournament> titles;

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
                          context.tr("Kako su izračunati poeni"),
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
                title: context.tr("Pobjede"),
                detail: context.tr("{p0} x {p1} poena", [
                  wins.length,
                  settings.matchWinPoints,
                ]),
                points: matchPoints,
                color: AppTheme.court,
              ),
              _pointsRow(
                context,
                icon: Icons.emoji_events,
                title: context.tr("Titule"),
                detail: context.tr("{p0} x {p1} poena", [
                  titles.length,
                  settings.tournamentWinPoints,
                ]),
                points: titlePoints,
                color: AppTheme.clay,
              ),
              if (adjustment != 0)
                _pointsRow(
                  context,
                  icon: Icons.tune,
                  title: context.tr("Korekcija"),
                  detail: context.tr(
                    "Razlika zbog ranijih pravila ili izmjene administratora",
                  ),
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
                    Text(
                      context.tr("Ukupno"),
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const Spacer(),
                    Text(
                      context.tr("{p0} poena", [player.totalPoints]),
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
                context.tr(
                  "Rang-lista obuhvata samo potvrđene takmičarske mečeve. Prijateljski mečevi ne ulaze u statistiku i ne donose poene.",
                ),
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

enum _StatKind { wins, losses, matches, titles }

class _StatBreakdownSheet extends StatelessWidget {
  const _StatBreakdownSheet({required this.data, required this.kind});

  final _PlayerProfileData data;
  final _StatKind kind;

  @override
  Widget build(BuildContext context) {
    final config = _config(context);
    final items = _items();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * .84,
      ),
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
                      color: config.color.withValues(alpha: .14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(config.icon, color: config.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          config.title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          config.subtitle,
                          style: TextStyle(
                            color: AppTheme.ink.withValues(alpha: .58),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${items.length}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _noteCard(context.tr(config.note)),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (items.isEmpty)
                      _emptyCard(context.tr(config.emptyText))
                    else
                      ...items.map((item) => _itemCard(context, item)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _StatConfig _config(BuildContext context) {
    return switch (kind) {
      _StatKind.wins => _StatConfig(
        title: context.tr("Pobjede"),
        subtitle: context.tr("Samo potvrđeni takmičarski mečevi"),
        note: context.tr(
          "Prijateljski mečevi ne ulaze u pobjede, statistiku ni poene.",
        ),
        emptyText: context.tr("Nema takmičarskih pobjeda."),
        icon: Icons.check_circle,
        color: AppTheme.court,
      ),
      _StatKind.losses => _StatConfig(
        title: context.tr("Porazi"),
        subtitle: context.tr("Samo potvrđeni takmičarski mečevi"),
        note: context.tr(
          "Prijateljski mečevi ne ulaze u poraze, statistiku ni poene.",
        ),
        emptyText: context.tr("Nema takmičarskih poraza."),
        icon: Icons.cancel,
        color: AppTheme.clay,
      ),
      _StatKind.matches => _StatConfig(
        title: context.tr("Mečevi"),
        subtitle: context.tr("Samo potvrđeni takmičarski mečevi"),
        note: context.tr(
          "Ovdje ulaze samo potvrđeni takmičarski mečevi. Prijateljski mečevi se ne računaju u statistiku.",
        ),
        emptyText: context.tr("Nema potvrđenih mečeva."),
        icon: Icons.sports_tennis,
        color: AppTheme.court,
      ),
      _StatKind.titles => _StatConfig(
        title: context.tr("Titule"),
        subtitle: context.tr("Samo takmičarski osvojeni turniri"),
        note: context.tr(
          "Prijateljski turniri ne ulaze u zvanične titule i ne daju poene.",
        ),
        emptyText: context.tr("Nema takmičarskih titula."),
        icon: Icons.emoji_events,
        color: AppTheme.clay,
      ),
    };
  }

  List<Object> _items() {
    return switch (kind) {
      _StatKind.wins => data.competitiveWins,
      _StatKind.losses => data.competitiveLosses,
      _StatKind.matches => data.confirmedMatches,
      _StatKind.titles => data.competitiveTitles,
    };
  }

  Widget _noteCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.lime.withValues(alpha: .22),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: AppTheme.ink.withValues(alpha: .68),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _emptyCard(String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  Widget _itemCard(BuildContext context, Object item) {
    if (item is Tournament) {
      return _baseCard(
        icon: Icons.emoji_events,
        title: item.name,
        subtitle: '${item.locationLabel} | ${_dateLabel(item.endDate)}',
        trailing: context.tr('titula'),
      );
    }

    final match = item as TennisMatch;
    final result = match.scoreText.isEmpty
        ? context.tr('bez rezultata')
        : match.scoreText;
    return _baseCard(
      icon: Icons.sports_tennis,
      title: '${match.team1Name} - ${match.team2Name}',
      subtitle: '${match.tournament?.name ?? match.round} | $result',
      trailing: context.tr('potvrđen'),
    );
  }

  Widget _baseCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.court.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: AppTheme.court),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.ink.withValues(alpha: .58),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            trailing,
            style: TextStyle(
              color: AppTheme.ink.withValues(alpha: .48),
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  String _dateLabel(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month.${value.year}';
  }
}

class _StatConfig {
  const _StatConfig({
    required this.title,
    required this.subtitle,
    required this.note,
    required this.emptyText,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final String note;
  final String emptyText;
  final IconData icon;
  final Color color;
}
