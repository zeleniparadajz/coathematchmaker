import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/match.dart';
import '../models/player.dart';
import '../models/tournament.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/league_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_form_fields.dart';
import '../widgets/player_avatar.dart';
import '../widgets/section_header.dart';

class TournamentsScreen extends StatefulWidget {
  const TournamentsScreen({
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
  State<TournamentsScreen> createState() => _TournamentsScreenState();
}

class _TournamentsScreenState extends State<TournamentsScreen> {
  late Future<List<Tournament>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.league.tournaments();
  }

  @override
  void didUpdateWidget(covariant TournamentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) {
      setState(() {
        _future = widget.league.tournaments();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Tournament>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return Scaffold(
          floatingActionButton: widget.auth.isAdmin
              ? FloatingActionButton.extended(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            TournamentFormScreen(league: widget.league),
                      ),
                    );
                    setState(() {
                      _future = widget.league.tournaments();
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Turnir'),
                )
              : null,
          body: RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _future = widget.league.tournaments();
              });
              await _future;
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: snapshot.data!.map((tournament) {
                return Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.emoji_events,
                      color: AppTheme.clay,
                    ),
                    title: Text(tournament.name),
                    subtitle: Text(
                      '${tournament.location}  |  ${tournament.surface}  |  ${tournament.category}',
                    ),
                    trailing: Chip(label: Text(tournament.status)),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TournamentDetailsScreen(
                          tournamentId: tournament.id,
                          league: widget.league,
                          api: widget.api,
                          auth: widget.auth,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

class TournamentDetailsScreen extends StatefulWidget {
  const TournamentDetailsScreen({
    super.key,
    required this.tournamentId,
    required this.league,
    required this.api,
    required this.auth,
  });

  final String tournamentId;
  final LeagueService league;
  final ApiClient api;
  final AuthService auth;

  @override
  State<TournamentDetailsScreen> createState() =>
      _TournamentDetailsScreenState();
}

class _TournamentDetailsScreenState extends State<TournamentDetailsScreen> {
  late Future<_TournamentDetailsData> _future;
  bool _uploadingImage = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_TournamentDetailsData> _load() async {
    final tournament = await widget.league.tournament(widget.tournamentId);
    final rankings = await widget.league.tournamentRankings(
      widget.tournamentId,
    );
    final matches = await widget.league.matches(
      tournamentId: widget.tournamentId,
    );
    final players = widget.auth.isAdmin
        ? await widget.league.players()
        : <Player>[];
    return _TournamentDetailsData(tournament, rankings, matches, players);
  }

  Future<void> _generateDraw() async {
    try {
      await widget.league.generateTournamentDraw(widget.tournamentId);
      setState(() {
        _future = _load();
      });
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _addParticipant(String playerId) async {
    try {
      await widget.league.addTournamentParticipant(
        widget.tournamentId,
        playerId,
      );
      setState(() {
        _future = _load();
      });
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _removeParticipant(String playerId) async {
    try {
      await widget.league.removeTournamentParticipant(
        widget.tournamentId,
        playerId,
      );
      setState(() {
        _future = _load();
      });
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _pickTournamentImage(Tournament tournament) async {
    if (tournament.images.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Galerija može imati najviše 5 slika.')),
      );
      return;
    }

    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 86,
    );
    if (file == null) return;

    setState(() => _uploadingImage = true);
    try {
      await widget.league.uploadTournamentImage(tournament.id, file);
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
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _register() async {
    try {
      await widget.league.registerForTournament(widget.tournamentId);
      setState(() {
        _future = _load();
      });
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Turnir')),
      body: FutureBuilder<_TournamentDetailsData>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final tournament = snapshot.data!.tournament;
          final availablePlayers = snapshot.data!.players
              .where(
                (player) => !tournament.participants.any(
                  (participant) => participant.id == player.id,
                ),
              )
              .toList();
          final registered = tournament.participants.any(
            (player) => player.id == widget.auth.currentPlayer?.id,
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _TournamentHero(tournament: tournament),
              const SizedBox(height: 14),
              _TournamentGallery(
                tournament: tournament,
                api: widget.api,
                canUpload:
                    (widget.auth.isAdmin || registered) &&
                    tournament.images.length < 5,
                uploading: _uploadingImage,
                onUpload: () => _pickTournamentImage(tournament),
              ),
              const SizedBox(height: 14),
              _TournamentActions(
                isAdmin: widget.auth.isAdmin,
                isUpcoming: tournament.isUpcoming,
                registered: registered,
                onRegister: _register,
                onGenerateDraw: _generateDraw,
              ),
              if (widget.auth.isAdmin && availablePlayers.isNotEmpty) ...[
                const SectionHeader('Dodaj igrača'),
                AppSelectField(
                  label: 'Igrač',
                  value: 'Izaberi igrača',
                  icon: Icons.person_add,
                  onTap: () async {
                    final player = await showAppOptionPicker<Player>(
                      context: context,
                      title: 'Dodaj igrača',
                      selected: availablePlayers.first,
                      options: availablePlayers,
                      labelBuilder: (player) => player.fullName,
                      leadingBuilder: (player) => PlayerAvatar(
                        player: player,
                        api: widget.api,
                        radius: 18,
                      ),
                    );
                    if (player != null) {
                      _addParticipant(player.id);
                    }
                  },
                ),
              ],
              const SectionHeader('Učesnici'),
              ...tournament.participants.map(
                (player) => Card(
                  child: ListTile(
                    leading: PlayerAvatar(player: player, api: widget.api),
                    title: Text(player.fullName),
                    subtitle: Text(player.club ?? player.country),
                    trailing: widget.auth.isAdmin
                        ? IconButton(
                            tooltip: 'Ukloni',
                            onPressed: () => _removeParticipant(player.id),
                            icon: const Icon(Icons.remove_circle_outline),
                          )
                        : null,
                  ),
                ),
              ),
              const SectionHeader('Ranking turnira'),
              ...snapshot.data!.rankings.map(
                (ranking) => Card(
                  child: ListTile(
                    leading: PlayerAvatar(
                      player: ranking.player,
                      api: widget.api,
                    ),
                    title: Text(ranking.player.fullName),
                    subtitle: Text(
                      '${ranking.wins} pobjeda, ${ranking.losses} poraza',
                    ),
                    trailing: Text('${ranking.points} pts'),
                  ),
                ),
              ),
              const SectionHeader('Mečevi turnira'),
              ...snapshot.data!.matches.map(
                (match) => Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.sports_tennis,
                      color: AppTheme.court,
                    ),
                    title: Text(
                      '${match.player1.fullName} vs ${match.player2.fullName}',
                    ),
                    subtitle: Text('${match.round}  |  ${match.status}'),
                    trailing: Text(
                      match.scoreText.isEmpty ? '-' : match.scoreText,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TournamentHero extends StatelessWidget {
  const _TournamentHero({required this.tournament});

  final Tournament tournament;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.ink, AppTheme.court],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.court.withValues(alpha: .20),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.lime.withValues(alpha: .18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emoji_events, color: AppTheme.lime),
              ),
              const Spacer(),
              _HeroBadge(label: tournament.status),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            tournament.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroMeta(icon: Icons.place, label: tournament.location),
              _HeroMeta(icon: Icons.grass, label: tournament.surface),
              _HeroMeta(icon: Icons.category, label: tournament.category),
              _HeroMeta(
                icon: Icons.account_tree,
                label: _formatLabel(tournament.format),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.calendar_month, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_dateLabel(tournament.startDate)} - ${_dateLabel(tournament.endDate)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _dateLabel(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  static String _formatLabel(String value) {
    return switch (value) {
      'elimination' => 'Eliminacija',
      'round_robin' => 'Round-robin',
      'qualification' => 'Kvalifikacije',
      'group_knockout' => 'Grupe + knockout',
      'double_elimination' => 'Double elimination',
      'compass' => 'Compass draw',
      'swiss' => 'Swiss',
      _ => value,
    };
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _HeroMeta extends StatelessWidget {
  const _HeroMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 15),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _TournamentGallery extends StatelessWidget {
  const _TournamentGallery({
    required this.tournament,
    required this.api,
    required this.canUpload,
    required this.uploading,
    required this.onUpload,
  });

  final Tournament tournament;
  final ApiClient api;
  final bool canUpload;
  final bool uploading;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.photo_library_outlined, color: AppTheme.court),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Galerija',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text('${tournament.images.length}/5'),
              ],
            ),
            const SizedBox(height: 12),
            if (tournament.images.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.court.withValues(alpha: .055),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Još nema slika za ovaj turnir.'),
              )
            else
              SizedBox(
                height: 170,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: tournament.images.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final image = tournament.images[index];
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Image.network(
                          api.imageUrl(image),
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (canUpload) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: uploading ? null : onUpload,
                  icon: uploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_photo_alternate),
                  label: const Text('Dodaj sliku turnira'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TournamentActions extends StatelessWidget {
  const _TournamentActions({
    required this.isAdmin,
    required this.isUpcoming,
    required this.registered,
    required this.onRegister,
    required this.onGenerateDraw,
  });

  final bool isAdmin;
  final bool isUpcoming;
  final bool registered;
  final VoidCallback onRegister;
  final VoidCallback onGenerateDraw;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (isUpcoming && !registered)
          FilledButton.icon(
            onPressed: onRegister,
            icon: const Icon(Icons.person_add),
            label: const Text('Prijavi se na turnir'),
          ),
        if (registered)
          Chip(
            avatar: const Icon(Icons.check, size: 18),
            label: const Text('Prijavljen si'),
            backgroundColor: AppTheme.court.withValues(alpha: .10),
          ),
        if (isAdmin)
          FilledButton.icon(
            onPressed: onGenerateDraw,
            icon: const Icon(Icons.account_tree),
            label: const Text('Formiraj žrijeb'),
          ),
      ],
    );
  }
}

class _TournamentDetailsData {
  const _TournamentDetailsData(
    this.tournament,
    this.rankings,
    this.matches,
    this.players,
  );

  final Tournament tournament;
  final List<TournamentRanking> rankings;
  final List<TennisMatch> matches;
  final List<Player> players;
}

class TournamentFormScreen extends StatefulWidget {
  const TournamentFormScreen({
    super.key,
    required this.league,
    this.tournament,
  });

  final LeagueService league;
  final Tournament? tournament;

  @override
  State<TournamentFormScreen> createState() => _TournamentFormScreenState();
}

class _TournamentFormScreenState extends State<TournamentFormScreen> {
  final _name = TextEditingController();
  final _location = TextEditingController();
  final _category = TextEditingController(text: 'Seniori');
  final _surface = TextEditingController(text: 'Tvrda podloga');
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 2));
  String _format = 'elimination';
  String _status = 'upcoming';
  bool _saving = false;

  static const _surfaces = [
    'Tvrda podloga',
    'Šljaka',
    'Trava',
    'Tepih',
    'Akrilna podloga',
    'Beton',
    'Vještačka trava',
    'Dvoranska tvrda',
  ];

  @override
  void initState() {
    super.initState();
    final tournament = widget.tournament;
    if (tournament != null) {
      _name.text = tournament.name;
      _location.text = tournament.location;
      _category.text = tournament.category;
      _surface.text = tournament.surface;
      _startDate = tournament.startDate;
      _endDate = tournament.endDate;
      _format = tournament.format;
      _status = tournament.status;
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      if (widget.tournament == null) {
        await widget.league.createTournament(
          name: _name.text.trim(),
          location: _location.text.trim(),
          surface: _surface.text.trim(),
          category: _category.text.trim(),
          format: _format,
          startDate: _startDate,
          endDate: _endDate,
          status: _status,
        );
      } else {
        await widget.league.updateTournament(
          id: widget.tournament!.id,
          name: _name.text.trim(),
          location: _location.text.trim(),
          surface: _surface.text.trim(),
          category: _category.text.trim(),
          format: _format,
          startDate: _startDate,
          endDate: _endDate,
          status: _status,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _category.dispose();
    _surface.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tournament == null ? 'Novi turnir' : 'Uredi turnir'),
      ),
      body: ListView(
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
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.emoji_events, color: AppTheme.lime, size: 36),
                const SizedBox(height: 18),
                Text(
                  widget.tournament == null ? 'Kreiraj turnir' : 'Uredi turnir',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Izaberi format žrijeba, podlogu i datume. Učesnike dodaješ na detalju turnira.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _field(_name, 'Naziv turnira', Icons.title),
                  const SizedBox(height: 12),
                  AppSelectField(
                    label: 'Lokacija',
                    value: _location.text.trim().isEmpty
                        ? 'Izaberi ili ukucaj lokaciju'
                        : _location.text.trim(),
                    icon: Icons.place,
                    onTap: () async {
                      final value = await showAppLocationPicker(
                        context: context,
                        initialValue: _location.text,
                      );
                      if (value != null) {
                        setState(() => _location.text = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: AppSelectField(
                          label: 'Podloga',
                          value: _surface.text,
                          icon: Icons.grass,
                          onTap: () async {
                            final value = await showAppOptionPicker<String>(
                              context: context,
                              title: 'Podloga',
                              selected: _surface.text,
                              options: _surfaces,
                              labelBuilder: (value) => value,
                            );
                            if (value != null) {
                              setState(() => _surface.text = value);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(_category, 'Kategorija', Icons.category),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Format turnira',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _formatCard(
                    value: 'elimination',
                    title: 'BYE bracket',
                    subtitle:
                        'Klasičan eliminacioni žrijeb. Ako broj nije 8/16/32, sistem dodaje BYE prolaze.',
                    icon: Icons.account_tree,
                  ),
                  _formatCard(
                    value: 'qualification',
                    title: 'Kvalifikacije',
                    subtitle:
                        'Višak igrača igra Q mečeve, a pobjednici ulaze u glavni 2^n bracket.',
                    icon: Icons.filter_alt,
                  ),
                  _formatCard(
                    value: 'round_robin',
                    title: 'Round-robin',
                    subtitle:
                        'Svako igra sa svakim. Najbolje za male grupe i ligu.',
                    icon: Icons.all_inclusive,
                  ),
                  _formatCard(
                    value: 'group_knockout',
                    title: 'Grupe + knockout',
                    subtitle:
                        'Prvo grupe, zatim najbolji prolaze u eliminacionu fazu.',
                    icon: Icons.grid_view,
                  ),
                  _formatCard(
                    value: 'double_elimination',
                    title: 'Double elimination',
                    subtitle:
                        'Igrač ispada tek poslije dva poraza. Više mečeva, manje slučajnosti.',
                    icon: Icons.restart_alt,
                  ),
                  _formatCard(
                    value: 'compass',
                    title: 'Compass draw',
                    subtitle:
                        'Igrači nastavljaju i poslije poraza, dobro za rekreativne turnire.',
                    icon: Icons.explore,
                  ),
                  _formatCard(
                    value: 'swiss',
                    title: 'Swiss system',
                    subtitle:
                        'Kola se uparuju po skoru. Dobro za mnogo igrača i ograničeno vrijeme.',
                    icon: Icons.swap_horiz,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  AppSelectField(
                    label: 'Status',
                    value: _statusLabel(_status),
                    icon: Icons.timeline,
                    onTap: () async {
                      final value = await showAppOptionPicker<String>(
                        context: context,
                        title: 'Status',
                        selected: _status,
                        options: const ['upcoming', 'active', 'finished'],
                        labelBuilder: _statusLabel,
                      );
                      if (value != null) setState(() => _status = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  _dateTile(
                    'Datum početka',
                    _startDate,
                    (date) => setState(() => _startDate = date),
                  ),
                  _dateTile(
                    'Datum kraja',
                    _endDate,
                    (date) => setState(() => _endDate = date),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: const Text('Sačuvaj turnir'),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, IconData icon) {
    return AppTextField(controller: controller, label: label, icon: icon);
  }

  String _statusLabel(String value) {
    return switch (value) {
      'upcoming' => 'Upcoming',
      'active' => 'Active',
      'finished' => 'Finished',
      _ => value,
    };
  }

  Widget _formatCard({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = _format == value;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _format = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.court.withValues(alpha: .10)
              : AppTheme.ink.withValues(alpha: .03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppTheme.court
                : AppTheme.ink.withValues(alpha: .08),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: selected ? AppTheme.court : Colors.white,
              child: Icon(icon, color: selected ? Colors.white : AppTheme.ink),
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
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? AppTheme.court : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateTile(
    String label,
    DateTime value,
    ValueChanged<DateTime> onChanged,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(value.toLocal().toString().split(' ').first),
      trailing: const Icon(Icons.calendar_month),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) onChanged(picked);
      },
    );
  }
}
