import 'package:flutter/material.dart';

import '../models/league_settings.dart';
import '../models/match.dart';
import '../models/player.dart';
import '../models/tournament.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/league_service.dart';
import '../theme/app_theme.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({
    super.key,
    required this.league,
    required this.auth,
    this.onChanged,
  });

  final LeagueService league;
  final AuthService auth;
  final VoidCallback? onChanged;

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  late Future<_MatchesData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_MatchesData> _load() async {
    final matches = await widget.league.myMatches();
    final settings = await widget.league.settings();
    return _MatchesData(matches, settings);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
    widget.onChanged?.call();
  }

  Future<void> _act(Future<void> Function() action) async {
    try {
      await action();
      await _refresh();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChallengeFormScreen(
                league: widget.league,
                currentPlayerId: widget.auth.currentPlayer!.id,
              ),
            ),
          );
          await _refresh();
        },
        icon: const Icon(Icons.add),
        label: const Text('Challenge'),
      ),
      body: FutureBuilder<_MatchesData>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final data = snapshot.data!;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ...data.matches.map((match) => _MatchCard(
                      match: match,
                      settings: data.settings,
                      currentPlayerId: widget.auth.currentPlayer!.id,
                      isAdmin: widget.auth.isAdmin,
                      onAccept: () => _act(() => widget.league.acceptMatch(match.id)),
                      onReject: () => _act(() => widget.league.rejectMatch(match.id)),
                      onConfirm: () => _act(() => widget.league.confirmResult(match.id)),
                      onDispute: () => _act(() => widget.league.disputeResult(match.id)),
                      onSubmitResult: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SubmitResultScreen(
                              league: widget.league,
                              match: match,
                            ),
                          ),
                        );
                        await _refresh();
                      },
                      onAdminResolve: widget.auth.isAdmin
                          ? () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => AdminResolveScreen(
                                    league: widget.league,
                                    match: match,
                                  ),
                                ),
                              );
                              await _refresh();
                            }
                          : null,
                    )),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.match,
    required this.settings,
    required this.currentPlayerId,
    required this.isAdmin,
    required this.onAccept,
    required this.onReject,
    required this.onSubmitResult,
    required this.onConfirm,
    required this.onDispute,
    this.onAdminResolve,
  });

  final TennisMatch match;
  final LeagueSettings settings;
  final String currentPlayerId;
  final bool isAdmin;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onSubmitResult;
  final VoidCallback onConfirm;
  final VoidCallback onDispute;
  final VoidCallback? onAdminResolve;

  bool get _isPlayer2 => match.player2.id == currentPlayerId;
  bool get _isSubmitter => match.resultSubmittedBy?.id == currentPlayerId;

  @override
  Widget build(BuildContext context) {
    final tooEarly = _minutesLeft() > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${match.player1.fullName} vs ${match.player2.fullName}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                _StatusBadge(status: match.status),
              ],
            ),
            const SizedBox(height: 6),
            Text('${match.tournament?.name ?? 'Challenge'}  |  ${match.round}'),
            if (match.scoreText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Rezultat: ${match.scoreText}  |  W: ${match.winner?.fullName ?? '-'}'),
            ],
            if (match.status == 'accepted' && tooEarly)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Prerano za unos rezultata. Preostalo oko ${_minutesLeft()} min.',
                  style: const TextStyle(color: AppTheme.clay),
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (match.status == 'pending' && (_isPlayer2 || isAdmin)) ...[
                  FilledButton.tonal(onPressed: onAccept, child: const Text('Accept')),
                  OutlinedButton(onPressed: onReject, child: const Text('Reject')),
                ],
                if (match.status == 'accepted' && (!tooEarly || isAdmin))
                  FilledButton.icon(
                    onPressed: onSubmitResult,
                    icon: const Icon(Icons.sports_score),
                    label: const Text('Unesi rezultat'),
                  ),
                if (match.status == 'waiting_confirmation' && (!_isSubmitter || isAdmin)) ...[
                  FilledButton(onPressed: onConfirm, child: const Text('Confirm Result')),
                  OutlinedButton(onPressed: onDispute, child: const Text('Dispute Result')),
                ],
                if (isAdmin && (match.status == 'disputed' || match.status == 'waiting_confirmation'))
                  FilledButton.tonal(onPressed: onAdminResolve, child: const Text('Admin resolve')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int _minutesLeft() {
    if (match.acceptedAt == null) return settings.resultEntryDelayMinutes;
    final earliest = match.acceptedAt!.add(Duration(minutes: settings.resultEntryDelayMinutes));
    return earliest.isAfter(DateTime.now()) ? earliest.difference(DateTime.now()).inMinutes + 1 : 0;
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'pending' => Colors.amber,
      'accepted' => Colors.blue,
      'waiting_confirmation' => AppTheme.clay,
      'confirmed' => AppTheme.court,
      'disputed' => Colors.red,
      'rejected' || 'cancelled' => Colors.grey,
      _ => Colors.grey,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

class ChallengeFormScreen extends StatefulWidget {
  const ChallengeFormScreen({
    super.key,
    required this.league,
    required this.currentPlayerId,
  });

  final LeagueService league;
  final String currentPlayerId;

  @override
  State<ChallengeFormScreen> createState() => _ChallengeFormScreenState();
}

class _ChallengeFormScreenState extends State<ChallengeFormScreen> {
  final _round = TextEditingController(text: 'Challenge');
  final _search = TextEditingController();
  List<Player> _players = [];
  List<Tournament> _tournaments = [];
  Player? _opponent;
  Tournament? _tournament;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final players = await widget.league.players();
    final tournaments = await widget.league.tournaments();
    final opponents = players.where((player) => player.id != widget.currentPlayerId).toList();
    setState(() {
      _players = opponents;
      _tournaments = tournaments;
      _opponent = opponents.isNotEmpty ? opponents.first : null;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_opponent == null) return;
    setState(() => _saving = true);
    try {
      await widget.league.challengeMatch(
        opponentId: _opponent!.id,
        tournamentId: _tournament?.id,
        round: _round.text.trim().isEmpty ? 'Challenge' : _round.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Challenge je poslat')),
        );
        Navigator.of(context).pop();
      }
    } on ApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredPlayers = _players
        .where((player) => player.fullName.toLowerCase().contains(_search.text.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Novi challenge')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
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
                      const Icon(Icons.sports_tennis, color: AppTheme.lime, size: 34),
                      const SizedBox(height: 18),
                      Text(
                        'Izazovi igrača',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Pošalji challenge, protivnik prihvata, a rezultat se potvrđuje s obje strane.',
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Protivnik',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _search,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            labelText: 'Pretraži igrača',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 10),
                        if (filteredPlayers.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('Nema dostupnih protivnika.'),
                          )
                        else
                          ...filteredPlayers.take(8).map(
                                (player) => ListTile(
                                  selected: _opponent?.id == player.id,
                                  selectedTileColor: AppTheme.court.withValues(alpha: .08),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  onTap: () => setState(() => _opponent = player),
                                  title: Text(player.fullName),
                                  subtitle: Text(player.club ?? player.country),
                                  trailing: _opponent?.id == player.id
                                      ? const Icon(Icons.check_circle, color: AppTheme.court)
                                      : const Icon(Icons.circle_outlined),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _dropdown<Tournament>(
                          'Turnir (opciono)',
                          _tournament,
                          _tournaments,
                          (t) => t.name,
                          (value) => setState(() => _tournament = value),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _round,
                          decoration: const InputDecoration(
                            labelText: 'Runda',
                            prefixIcon: Icon(Icons.flag),
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _saving || _opponent == null ? null : _save,
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.send),
                            label: const Text('Pošalji challenge'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class SubmitResultScreen extends StatefulWidget {
  const SubmitResultScreen({super.key, required this.league, required this.match});

  final LeagueService league;
  final TennisMatch match;

  @override
  State<SubmitResultScreen> createState() => _SubmitResultScreenState();
}

class _SubmitResultScreenState extends State<SubmitResultScreen> {
  final _sets = <_EditableSetScore>[
    _EditableSetScore(6, 4),
    _EditableSetScore(6, 3),
  ];
  late Player _winner = widget.match.player1;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.league.submitResult(
        matchId: widget.match.id,
        winner: _winner.id,
        round: widget.match.round,
        sets: _sets
            .map((set) => SetScore(
                  player1Games: set.player1Games,
                  player2Games: set.player2Games,
                ))
            .toList(),
      );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p1 = widget.match.player1;
    final p2 = widget.match.player2;

    return Scaffold(
      appBar: AppBar(title: const Text('Rezultat meča')),
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
                Row(
                  children: [
                    const Icon(Icons.sports_score, color: AppTheme.lime, size: 34),
                    const Spacer(),
                    _StatusBadge(status: widget.match.status),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  '${p1.fullName} vs ${p2.fullName}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${widget.match.tournament?.name ?? 'Challenge'}  |  ${widget.match.round}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pobjednik',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _winnerTile(p1)),
                      const SizedBox(width: 10),
                      Expanded(child: _winnerTile(p2)),
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Setovi',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),
                      Text('${p1.lastName} / ${p2.lastName}'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._sets.asMap().entries.map(
                        (entry) => _SetScoreEditor(
                          index: entry.key,
                          score: entry.value,
                          player1Label: p1.lastName,
                          player2Label: p2.lastName,
                          onChanged: () => setState(() {}),
                          onRemove: _sets.length > 1
                              ? () => setState(() => _sets.removeAt(entry.key))
                              : null,
                        ),
                      ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _sets.add(_EditableSetScore(0, 0))),
                    icon: const Icon(Icons.add),
                    label: const Text('Dodaj set'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.clay.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.clay),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Rezultat ide drugom igraču na potvrdu prije računanja poena.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: const Text('Pošalji na potvrdu'),
          ),
        ],
      ),
    );
  }

  Widget _winnerTile(Player player) {
    final selected = _winner.id == player.id;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _winner = player),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.court.withValues(alpha: .12) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.court : AppTheme.ink.withValues(alpha: .08),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? AppTheme.court : Colors.grey,
            ),
            const SizedBox(height: 8),
            Text(
              player.fullName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditableSetScore {
  _EditableSetScore(this.player1Games, this.player2Games);

  int player1Games;
  int player2Games;
}

class _SetScoreEditor extends StatelessWidget {
  const _SetScoreEditor({
    required this.index,
    required this.score,
    required this.player1Label,
    required this.player2Label,
    required this.onChanged,
    this.onRemove,
  });

  final int index;
  final _EditableSetScore score;
  final String player1Label;
  final String player2Label;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.ink.withValues(alpha: .035),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Set ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              if (onRemove != null)
                IconButton(
                  tooltip: 'Ukloni set',
                  onPressed: onRemove,
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
          _scoreRow(player1Label, score.player1Games, (value) {
            score.player1Games = value;
            onChanged();
          }),
          const SizedBox(height: 8),
          _scoreRow(player2Label, score.player2Games, (value) {
            score.player2Games = value;
            onChanged();
          }),
        ],
      ),
    );
  }

  Widget _scoreRow(String label, int value, ValueChanged<int> onValueChanged) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
        IconButton.filledTonal(
          onPressed: value > 0 ? () => onValueChanged(value - 1) : null,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 46,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
        ),
        IconButton.filled(
          onPressed: value < 99 ? () => onValueChanged(value + 1) : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

class AdminResolveScreen extends StatefulWidget {
  const AdminResolveScreen({super.key, required this.league, required this.match});

  final LeagueService league;
  final TennisMatch match;

  @override
  State<AdminResolveScreen> createState() => _AdminResolveScreenState();
}

class _AdminResolveScreenState extends State<AdminResolveScreen> {
  final _note = TextEditingController();

  Future<void> _resolve(String action) async {
    try {
      await widget.league.adminResolve(
        matchId: widget.match.id,
        action: action,
        winner: action == 'confirm' ? widget.match.winner?.id ?? widget.match.player1.id : null,
        sets: action == 'confirm' ? widget.match.sets : null,
        note: _note.text.trim(),
      );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin resolve')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('${widget.match.player1.fullName} vs ${widget.match.player2.fullName}', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(controller: _note, decoration: const InputDecoration(labelText: 'Napomena')),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => _resolve('confirm'), child: const Text('Potvrdi rezultat')),
          OutlinedButton(onPressed: () => _resolve('reject'), child: const Text('Odbij rezultat')),
          OutlinedButton(onPressed: () => _resolve('cancel'), child: const Text('Poništi meč')),
        ],
      ),
    );
  }
}

class _MatchesData {
  const _MatchesData(this.matches, this.settings);

  final List<TennisMatch> matches;
  final LeagueSettings settings;
}

Widget _dropdown<T>(
  String label,
  T? value,
  List<T> items,
  String Function(T) title,
  ValueChanged<T?> onChanged,
) {
  return DropdownButtonFormField<T>(
    initialValue: value,
    items: items.map((item) => DropdownMenuItem(value: item, child: Text(title(item)))).toList(),
    onChanged: onChanged,
    decoration: InputDecoration(labelText: label),
  );
}
