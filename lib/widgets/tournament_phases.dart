import 'package:coathematchmaker/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import '../models/match.dart';
import '../models/tournament.dart';
import '../models/round_robin.dart';
import '../models/display_labels.dart';
import '../services/api_client.dart';
import '../services/league_service.dart';
import 'load_error.dart';

class TournamentPhases extends StatefulWidget {
  const TournamentPhases({
    super.key,
    required this.tournament,
    required this.matches,
    required this.league,
    required this.canManage,
    required this.onChanged,
    this.onOpenMatch,
  });
  final Tournament tournament;
  final List<TennisMatch> matches;
  final LeagueService league;
  final bool canManage;
  final VoidCallback onChanged;
  final ValueChanged<TennisMatch>? onOpenMatch;
  @override
  State<TournamentPhases> createState() => _TournamentPhasesState();
}

class _TournamentPhasesState extends State<TournamentPhases> {
  static const _actionStyle = ButtonStyle(
    padding: WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    ),
  );
  late Future<RoundRobinState> _future = widget.league.roundRobin(
    widget.tournament.id,
  );
  late bool _knockout = widget.tournament.knockoutStarted;
  bool _busy = false;

  @override
  void didUpdateWidget(covariant TournamentPhases oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.tournament, widget.tournament)) {
      _future = widget.league.roundRobin(widget.tournament.id);
    }
  }

  String _name(String id) {
    for (final player in widget.tournament.participants) {
      if (player.id == id) return player.fullName;
    }
    return context.tr("Igrač");
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      setState(() {
        _knockout = true;
        _future = widget.league.roundRobin(widget.tournament.id);
      });
      widget.onChanged();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.serverMessage(error.message))),
        );
        setState(
          () => _future = widget.league.roundRobin(widget.tournament.id),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _preview(RoundRobinState state) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr("Potvrdi knockout parove")),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final pair in state.pairs)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      '${state.seeds.indexOf(pair[0]) + 1}. ${_name(pair[0])}\n${state.seeds.indexOf(pair[1]) + 1}. ${_name(pair[1])}',
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr("Odustani")),
          ),
          FilledButton(
            style: _actionStyle,
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              context.tr("Pokreni knockout"),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
    if (approved == true && mounted) {
      await _run(
        () => widget.league.startKnockout(widget.tournament.id, state.seeds),
      );
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<RoundRobinState>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return LoadError(
          onRetry: () => setState(
            () => _future = widget.league.roundRobin(widget.tournament.id),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      final state = snapshot.data!;
      final enabled = widget.tournament.knockoutSize > 0;
      final matches = widget.matches
          .where(
            (m) => _knockout && enabled ? m.round != 'RR' : m.round == 'RR',
          )
          .toList();
      const rounds = ['R16', 'QF', 'SF', 'F'];
      matches.sort(
        (a, b) => rounds.indexOf(a.round).compareTo(rounds.indexOf(b.round)),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: enabled
                    ? SegmentedButton<bool>(
                        segments: [
                          ButtonSegment(
                            value: false,
                            label: Text(context.tr("Liga")),
                          ),
                          ButtonSegment(
                            value: true,
                            label: Text(context.tr("Knockout")),
                          ),
                        ],
                        selected: {_knockout},
                        onSelectionChanged: (value) =>
                            setState(() => _knockout = value.first),
                      )
                    : Text(
                        context.tr("Liga"),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
              ),
              IconButton(
                tooltip: context.tr("Osvježi rezultate"),
                onPressed: _busy ? null : widget.onChanged,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!_knockout || !enabled) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr("Tabela lige"),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: context.tr("Pravila poretka"),
                  icon: const Icon(Icons.info_outline),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(context.tr("Pravila poretka")),
                      content: Text(context.serverMessage(state.rankingRules)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(context.tr("U redu")),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            for (final row in state.standings)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
                color: enabled && state.seeds.contains(row.playerId)
                    ? Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: .08)
                    : null,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 30, child: Text('${row.seed}.')),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _name(row.playerId),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.tr(
                              "Mečevi {p0} · Setovi {p1}:{p2} · Gemovi {p3}:{p4}",
                              [
                                row.played,
                                row.setsWon,
                                row.setsLost,
                                row.gamesWon,
                                row.gamesLost,
                              ],
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: context.tr("Pobjede : porazi"),
                      child: Text(
                        '${row.wins} : ${row.losses}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (enabled && !state.started) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                state.canStart
                    ? context.tr("Broj učesnika spremnih za završnicu: {p0}.", [
                        widget.tournament.knockoutSize,
                      ])
                    : context.serverMessage(
                        state.blockedReason ?? 'Liga je u toku.',
                      ),
              ),
            ),
            if (widget.canManage)
              FilledButton.icon(
                style: _actionStyle,
                onPressed: state.canStart && !_busy
                    ? () => _preview(state)
                    : null,
                icon: const Icon(Icons.account_tree_outlined),
                label: Text(
                  context.tr("Pregledaj knockout parove"),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
          if (state.started && _knockout) ...[
            if (state.needsRepair && widget.canManage)
              FilledButton.icon(
                style: _actionStyle,
                onPressed: _busy
                    ? null
                    : () => _run(
                        () => widget.league.startKnockout(
                          widget.tournament.id,
                          state.seeds,
                        ),
                      ),
                icon: const Icon(Icons.refresh),
                label: Text(
                  context.tr("Dovrši formiranje mečeva"),
                  textAlign: TextAlign.center,
                ),
              ),
            if (state.finished && state.winnerId != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.emoji_events_outlined),
                title: Text(_name(state.winnerId!)),
                subtitle: Text(context.tr("Pobjednik turnira")),
              ),
            if (widget.canManage && !state.finished) ...[
              if (!state.canAdvance)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    context.tr("Čekaju se potvrđeni rezultati ove runde."),
                  ),
                ),
              FilledButton.icon(
                style: _actionStyle,
                onPressed: state.canAdvance && !_busy
                    ? () => _run(
                        () => widget.league.advanceKnockout(
                          widget.tournament.id,
                          state.currentRound!,
                        ),
                      )
                    : null,
                icon: const Icon(Icons.arrow_forward),
                label: Text(
                  state.currentRound == 'F'
                      ? context.tr("Potvrdi pobjednika")
                      : context.tr("Formiraj narednu rundu"),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
          const SizedBox(height: 16),
          for (final match in matches)
            InkWell(
              onTap: widget.onOpenMatch == null
                  ? null
                  : () => widget.onOpenMatch!(match),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${match.round} · ${context.tr(matchStatusLabel(match.status))}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${match.team1Name}\n${match.team2Name}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (widget.onOpenMatch != null)
                          const Icon(Icons.chevron_right),
                      ],
                    ),
                    if (match.scoreText.isNotEmpty) Text(match.scoreText),
                    const Divider(),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}
