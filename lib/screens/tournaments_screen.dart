import 'package:flutter/material.dart';

import '../models/match.dart';
import '../models/player.dart';
import '../models/tournament.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/league_service.dart';
import '../theme/app_theme.dart';
import '../widgets/player_avatar.dart';
import '../widgets/section_header.dart';

class TournamentsScreen extends StatefulWidget {
  const TournamentsScreen({
    super.key,
    required this.league,
    required this.api,
    required this.auth,
  });

  final LeagueService league;
  final ApiClient api;
  final AuthService auth;

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
  Widget build(BuildContext context) {
    return FutureBuilder<List<Tournament>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        return Scaffold(
          floatingActionButton: widget.auth.isAdmin
              ? FloatingActionButton.extended(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TournamentFormScreen(league: widget.league),
                      ),
                    );
                    setState(() => _future = widget.league.tournaments());
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Turnir'),
                )
              : null,
          body: RefreshIndicator(
            onRefresh: () async => setState(() => _future = widget.league.tournaments()),
            child: ListView(
            padding: const EdgeInsets.all(16),
            children: snapshot.data!.map((tournament) {
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.emoji_events, color: AppTheme.clay),
                  title: Text(tournament.name),
                  subtitle: Text('${tournament.location}  |  ${tournament.surface}  |  ${tournament.category}'),
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
  State<TournamentDetailsScreen> createState() => _TournamentDetailsScreenState();
}

class _TournamentDetailsScreenState extends State<TournamentDetailsScreen> {
  late Future<_TournamentDetailsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_TournamentDetailsData> _load() async {
    final tournament = await widget.league.tournament(widget.tournamentId);
    final rankings = await widget.league.tournamentRankings(widget.tournamentId);
    final matches = await widget.league.matches(tournamentId: widget.tournamentId);
    final players = widget.auth.isAdmin ? await widget.league.players() : <Player>[];
    return _TournamentDetailsData(tournament, rankings, matches, players);
  }

  Future<void> _generateDraw() async {
    try {
      await widget.league.generateTournamentDraw(widget.tournamentId);
      setState(() => _future = _load());
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _addParticipant(String playerId) async {
    try {
      await widget.league.addTournamentParticipant(widget.tournamentId, playerId);
      setState(() => _future = _load());
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _removeParticipant(String playerId) async {
    try {
      await widget.league.removeTournamentParticipant(widget.tournamentId, playerId);
      setState(() => _future = _load());
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _register() async {
    try {
      await widget.league.registerForTournament(widget.tournamentId);
      setState(() => _future = _load());
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
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
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final tournament = snapshot.data!.tournament;
          final availablePlayers = snapshot.data!.players
              .where((player) => !tournament.participants.any((participant) => participant.id == player.id))
              .toList();
          final registered = tournament.participants
              .any((player) => player.id == widget.auth.currentPlayer?.id);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppTheme.court, AppTheme.lime]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tournament.name,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppTheme.ink,
                          ),
                    ),
                    Text('${tournament.location}  |  ${tournament.surface}  |  ${tournament.category}'),
                    Text('Format: ${tournament.format}'),
                    const SizedBox(height: 8),
                    Text('${tournament.startDate.toLocal().toString().split(' ').first} - ${tournament.endDate.toLocal().toString().split(' ').first}'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (tournament.isUpcoming && !registered)
                FilledButton.icon(
                  onPressed: _register,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Prijavi se na turnir'),
                ),
              if (registered)
                const Chip(
                  avatar: Icon(Icons.check),
                  label: Text('Prijavljen si'),
                ),
              if (widget.auth.isAdmin)
                FilledButton.icon(
                  onPressed: _generateDraw,
                  icon: const Icon(Icons.account_tree),
                  label: const Text('Automatski formiraj žrijeb'),
                ),
              if (widget.auth.isAdmin && availablePlayers.isNotEmpty) ...[
                const SectionHeader('Dodaj igrača'),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Igrač'),
                  items: availablePlayers
                      .map((player) => DropdownMenuItem(value: player.id, child: Text(player.fullName)))
                      .toList(),
                  onChanged: (playerId) {
                    if (playerId != null) _addParticipant(playerId);
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
                    leading: PlayerAvatar(player: ranking.player, api: widget.api),
                    title: Text(ranking.player.fullName),
                    subtitle: Text('${ranking.wins} pobjeda, ${ranking.losses} poraza'),
                    trailing: Text('${ranking.points} pts'),
                  ),
                ),
              ),
              const SectionHeader('Mečevi turnira'),
              ...snapshot.data!.matches.map(
                (match) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.sports_tennis, color: AppTheme.court),
                    title: Text('${match.player1.fullName} vs ${match.player2.fullName}'),
                    subtitle: Text('${match.round}  |  ${match.status}'),
                    trailing: Text(match.scoreText.isEmpty ? '-' : match.scoreText),
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

class _TournamentDetailsData {
  const _TournamentDetailsData(this.tournament, this.rankings, this.matches, this.players);

  final Tournament tournament;
  final List<TournamentRanking> rankings;
  final List<TennisMatch> matches;
  final List<Player> players;
}

class TournamentFormScreen extends StatefulWidget {
  const TournamentFormScreen({super.key, required this.league, this.tournament});

  final LeagueService league;
  final Tournament? tournament;

  @override
  State<TournamentFormScreen> createState() => _TournamentFormScreenState();
}

class _TournamentFormScreenState extends State<TournamentFormScreen> {
  final _name = TextEditingController();
  final _location = TextEditingController();
  final _category = TextEditingController(text: 'Seniori');
  final _surface = TextEditingController(text: 'Hard');
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 2));
  String _format = 'elimination';
  String _status = 'upcoming';
  bool _saving = false;

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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.tournament == null ? 'Novi turnir' : 'Uredi turnir')),
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
                  _field(_location, 'Lokacija', Icons.place),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _field(_surface, 'Podloga', Icons.grass)),
                      const SizedBox(width: 12),
                      Expanded(child: _field(_category, 'Kategorija', Icons.category)),
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
                    subtitle: 'Klasičan eliminacioni žrijeb. Ako broj nije 8/16/32, sistem dodaje BYE prolaze.',
                    icon: Icons.account_tree,
                  ),
                  _formatCard(
                    value: 'qualification',
                    title: 'Kvalifikacije',
                    subtitle: 'Višak igrača igra Q mečeve, a pobjednici ulaze u glavni 2^n bracket.',
                    icon: Icons.filter_alt,
                  ),
                  _formatCard(
                    value: 'round_robin',
                    title: 'Round-robin',
                    subtitle: 'Svako igra sa svakim. Najbolje za male grupe i ligu.',
                    icon: Icons.all_inclusive,
                  ),
                  _formatCard(
                    value: 'group_knockout',
                    title: 'Grupe + knockout',
                    subtitle: 'Prvo grupe, zatim najbolji prolaze u eliminacionu fazu.',
                    icon: Icons.grid_view,
                  ),
                  _formatCard(
                    value: 'double_elimination',
                    title: 'Double elimination',
                    subtitle: 'Igrač ispada tek poslije dva poraza. Više mečeva, manje slučajnosti.',
                    icon: Icons.restart_alt,
                  ),
                  _formatCard(
                    value: 'compass',
                    title: 'Compass draw',
                    subtitle: 'Igrači nastavljaju i poslije poraza, dobro za rekreativne turnire.',
                    icon: Icons.explore,
                  ),
                  _formatCard(
                    value: 'swiss',
                    title: 'Swiss system',
                    subtitle: 'Kola se uparuju po skoru. Dobro za mnogo igrača i ograničeno vrijeme.',
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
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      prefixIcon: Icon(Icons.timeline),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'upcoming', child: Text('Upcoming')),
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(value: 'finished', child: Text('Finished')),
                    ],
                    onChanged: (value) => setState(() => _status = value ?? _status),
                  ),
                  const SizedBox(height: 8),
                  _dateTile('Datum početka', _startDate, (date) => setState(() => _startDate = date)),
                  _dateTile('Datum kraja', _endDate, (date) => setState(() => _endDate = date)),
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
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
    );
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
          color: selected ? AppTheme.court.withValues(alpha: .10) : AppTheme.ink.withValues(alpha: .03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.court : AppTheme.ink.withValues(alpha: .08),
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
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
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

  Widget _dateTile(String label, DateTime value, ValueChanged<DateTime> onChanged) {
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
