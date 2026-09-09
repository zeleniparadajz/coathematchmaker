import 'package:coathematchmaker/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/league_settings.dart';
import '../models/match.dart';
import '../models/display_labels.dart';
import '../models/player.dart';
import '../models/tournament.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/league_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_form_fields.dart';
import '../widgets/map_location_card.dart';
import '../widgets/location_picker.dart';
import '../models/app_location.dart';
import '../widgets/load_error.dart';
import '../widgets/photo_viewer.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({
    super.key,
    required this.league,
    required this.auth,
    this.onChanged,
    this.refreshTick = 0,
  });

  final LeagueService league;
  final AuthService auth;
  final VoidCallback? onChanged;
  final int refreshTick;

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  late Future<_MatchesData> _future;
  String _statusFilter = 'all';
  String _sortBy = 'scheduled_asc';
  bool _acting = false;

  static const _filters = [
    'all',
    'pending',
    'accepted',
    'waiting_confirmation',
    'confirmed',
    'disputed',
    'rejected',
    'cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant MatchesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) {
      setState(() {
        _future = _load();
      });
    }
  }

  Future<_MatchesData> _load() async {
    final matches = widget.auth.isAdmin
        ? await widget.league.matches()
        : await widget.league.myMatches();
    final settings = await widget.league.settings();
    return _MatchesData(matches, settings);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    try {
      await _future;
      widget.onChanged?.call();
    } catch (_) {
      /* Retry is shown in the list. */
    }
  }

  Future<void> _act(Future<void> Function() action) async {
    if (_acting) return;
    _acting = true;
    try {
      await action();
      await _refresh();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.serverMessage(error.message))),
        );
      }
    } finally {
      _acting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'matches-create-challenge-fab',
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ChallengeFormScreen(
                league: widget.league,
                canManageLocations: widget.auth.isAdmin,
                currentPlayerId: widget.auth.currentPlayer!.id,
              ),
            ),
          );
          await _refresh();
        },
        icon: const Icon(Icons.add),
        label: Text(context.tr("Izazov")),
      ),
      body: FutureBuilder<_MatchesData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) return LoadError(onRetry: _refresh);
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final matches = _statusFilter == 'all'
              ? data.matches
              : data.matches
                    .where((match) => match.status == _statusFilter)
                    .toList();
          _sortMatches(matches);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                _StatusFilterBar(
                  statuses: _filters,
                  selected: _statusFilter,
                  onSelected: (value) => setState(() => _statusFilter = value),
                ),
                const SizedBox(height: 10),
                _MatchSortBar(
                  selected: _sortBy,
                  onSelected: (value) => setState(() => _sortBy = value),
                ),
                const SizedBox(height: 12),
                if (matches.isEmpty)
                  const _EmptyMatches()
                else
                  ...matches.map(
                    (match) => _MatchCard(
                      match: match,
                      settings: data.settings,
                      currentPlayerId: widget.auth.currentPlayer!.id,
                      isAdmin: widget.auth.isAdmin,
                      onAccept: () =>
                          _act(() => widget.league.acceptMatch(match.id)),
                      onReject: () =>
                          _act(() => widget.league.rejectMatch(match.id)),
                      onConfirm: () =>
                          _act(() => widget.league.confirmResult(match.id)),
                      onDispute: () =>
                          _act(() => widget.league.disputeResult(match.id)),
                      onSubmitResult: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => SubmitResultScreen(
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
                                  builder: (context) => AdminResolveScreen(
                                    league: widget.league,
                                    match: match,
                                  ),
                                ),
                              );
                              await _refresh();
                            }
                          : null,
                      onOpen: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => MatchDetailsScreen(
                              league: widget.league,
                              match: match,
                              settings: data.settings,
                              currentPlayerId: widget.auth.currentPlayer!.id,
                              isAdmin: widget.auth.isAdmin,
                            ),
                          ),
                        );
                        await _refresh();
                      },
                    ),
                  ),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }

  void _sortMatches(List<TennisMatch> matches) {
    int compareDate(DateTime? a, DateTime? b, {bool descending = false}) {
      final left = a ?? DateTime.fromMillisecondsSinceEpoch(0);
      final right = b ?? DateTime.fromMillisecondsSinceEpoch(0);
      return descending ? right.compareTo(left) : left.compareTo(right);
    }

    matches.sort((a, b) {
      return switch (_sortBy) {
        'newest' => compareDate(a.createdAt, b.createdAt, descending: true),
        'status' => a.status.compareTo(b.status),
        'tournament' => (a.tournament?.name ?? 'Challenge').compareTo(
          b.tournament?.name ?? 'Challenge',
        ),
        _ => compareDate(
          a.scheduledAt ?? a.createdAt,
          b.scheduledAt ?? b.createdAt,
        ),
      };
    });
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
    required this.onOpen,
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
  final VoidCallback onOpen;

  bool get _isPlayer2 => match.player2.id == currentPlayerId;
  bool get _isSubmitter => match.resultSubmittedBy?.id == currentPlayerId;

  @override
  Widget build(BuildContext context) {
    final tooEarly = _minutesLeft() > 0;
    final hasWinner = match.winner != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _MatchTypeIcon(status: match.status, hasWinner: hasWinner),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          match.team1Name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          'vs',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: AppTheme.ink.withValues(alpha: .56),
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        Text(
                          match.team2Name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Align(
                    alignment: Alignment.topRight,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 112),
                      child: _StatusBadge(status: match.status),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetaPill(
                    icon: Icons.flag,
                    label: match.tournament?.name ?? context.tr("Izazov"),
                  ),
                  if (match.round.isNotEmpty && match.round != 'Challenge')
                    _MetaPill(icon: Icons.label, label: match.round),
                  if (match.friendly)
                    _MetaPill(
                      icon: Icons.favorite,
                      label: context.tr("Prijateljski"),
                    ),
                  if (match.scheduledAt != null)
                    _MetaPill(
                      icon: Icons.event_available,
                      label: _dateTimeLabel(match.scheduledAt!),
                    ),
                  if ((match.location ?? '').isNotEmpty)
                    _MetaPill(icon: Icons.place, label: match.location!),
                  if (match.images.isNotEmpty)
                    _MetaPill(
                      icon: Icons.photo_library_outlined,
                      label: context.tr("{p0}/5 slika", [match.images.length]),
                    ),
                ],
              ),
              if (match.scoreText.isNotEmpty) ...[
                const SizedBox(height: 12),
                _ScoreSummary(match: match),
              ] else if (hasWinner) ...[
                const SizedBox(height: 12),
                _WinnerBanner(name: match.winner!.fullName),
              ],
              if (match.status == 'pending') ...[
                const SizedBox(height: 10),
                _HintLine(
                  icon: Icons.hourglass_top,
                  text: context.tr("Čeka se odgovor protivnika"),
                ),
              ],
              if (match.friendly) ...[
                const SizedBox(height: 10),
                _HintLine(
                  icon: Icons.favorite,
                  text: context.tr(
                    "Prijateljski meč: ne ulazi u statistiku i ne dodaje poene.",
                  ),
                ),
              ],
              if (match.status == 'waiting_confirmation') ...[
                const SizedBox(height: 10),
                _HintLine(
                  icon: Icons.verified_outlined,
                  text: context.tr("Rezultat čeka potvrdu druge strane"),
                ),
              ],
              if (match.status == 'rejected' ||
                  match.status == 'cancelled') ...[
                const SizedBox(height: 10),
                _HintLine(
                  icon: Icons.block,
                  text: context.tr("Meč nije aktivan"),
                ),
              ],
              if (match.status == 'accepted' && tooEarly)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    context.tr(
                      "Prerano za unos rezultata. Preostalo oko {p0} min.",
                      [_minutesLeft()],
                    ),
                    style: const TextStyle(color: AppTheme.clay),
                  ),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (match.status == 'pending' && (_isPlayer2 || isAdmin)) ...[
                    FilledButton.tonal(
                      onPressed: onAccept,
                      child: Text(context.tr("Prihvati")),
                    ),
                    OutlinedButton(
                      onPressed: onReject,
                      child: Text(context.tr("Odbij")),
                    ),
                  ],
                  if (match.status == 'accepted' && (!tooEarly || isAdmin))
                    FilledButton.icon(
                      onPressed: onSubmitResult,
                      icon: const Icon(Icons.sports_score),
                      label: Text(context.tr("Unesi rezultat")),
                    ),
                  if (match.status == 'waiting_confirmation' &&
                      (!_isSubmitter || isAdmin)) ...[
                    FilledButton(
                      onPressed: onConfirm,
                      child: Text(context.tr("Potvrdi rezultat")),
                    ),
                    OutlinedButton(
                      onPressed: onDispute,
                      child: Text(context.tr("Ospori rezultat")),
                    ),
                  ],
                  if (isAdmin &&
                      (match.status == 'disputed' ||
                          match.status == 'waiting_confirmation'))
                    FilledButton.tonal(
                      onPressed: onAdminResolve,
                      child: Text(context.tr("Rješavanje spora")),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _minutesLeft() {
    if (match.acceptedAt == null) return settings.resultEntryDelayMinutes;
    final earliest = match.acceptedAt!.add(
      Duration(minutes: settings.resultEntryDelayMinutes),
    );
    return earliest.isAfter(DateTime.now())
        ? earliest.difference(DateTime.now()).inMinutes + 1
        : 0;
  }

  String _dateTimeLabel(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.${local.year}  $hour:$minute';
  }
}

class _StatusFilterBar extends StatelessWidget {
  const _StatusFilterBar({
    required this.statuses,
    required this.selected,
    required this.onSelected,
  });

  final List<String> statuses;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: statuses.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final status = statuses[index];
          return ChoiceChip(
            selected: selected == status,
            label: Text(
              status == 'all'
                  ? context.tr("Svi")
                  : context.tr(matchStatusLabel(status)),
            ),
            avatar: selected == status
                ? const Icon(Icons.check, size: 16)
                : null,
            backgroundColor: Colors.white,
            selectedColor: AppTheme.lime,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: BorderSide(color: AppTheme.ink.withValues(alpha: .10)),
            ),
            onSelected: (_) => onSelected(status),
          );
        },
      ),
    );
  }
}

class _MatchSortBar extends StatelessWidget {
  const _MatchSortBar({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  static const _options = {
    'scheduled_asc': 'Termin',
    'newest': 'Najnovije',
    'status': 'Status',
    'tournament': 'Turnir',
  };

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: PopupMenuButton<String>(
        initialValue: selected,
        onSelected: onSelected,
        itemBuilder: (context) => _options.entries
            .map(
              (entry) => PopupMenuItem<String>(
                value: entry.key,
                child: Row(
                  children: [
                    Icon(
                      selected == entry.key
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      size: 18,
                      color: selected == entry.key
                          ? AppTheme.court
                          : AppTheme.ink.withValues(alpha: .46),
                    ),
                    const SizedBox(width: 10),
                    Text(context.tr(entry.value)),
                  ],
                ),
              ),
            )
            .toList(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.court.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sort, size: 18, color: AppTheme.court),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  context.tr(_options[selected] ?? 'Termin'),
                  style: const TextStyle(
                    color: AppTheme.court,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: AppTheme.court,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchTypeIcon extends StatelessWidget {
  const _MatchTypeIcon({required this.status, required this.hasWinner});

  final String status;
  final bool hasWinner;

  @override
  Widget build(BuildContext context) {
    final icon = hasWinner
        ? Icons.emoji_events
        : switch (status) {
            'pending' => Icons.hourglass_top,
            'accepted' => Icons.handshake,
            'waiting_confirmation' => Icons.verified_outlined,
            'disputed' => Icons.report_problem,
            'rejected' || 'cancelled' => Icons.block,
            _ => Icons.sports_tennis,
          };
    final color = hasWinner ? AppTheme.clay : AppTheme.court;

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 21),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.ink.withValues(alpha: .045),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.ink.withValues(alpha: .66)),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.ink.withValues(alpha: .72),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreSummary extends StatelessWidget {
  const _ScoreSummary({required this.match});

  final TennisMatch match;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.court.withValues(alpha: .075),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.court.withValues(alpha: .10)),
      ),
      child: Row(
        children: [
          const Icon(Icons.scoreboard, color: AppTheme.court, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              match.scoreText,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          if (match.winner != null)
            Flexible(
              child: _WinnerBanner(
                name: match.winner!.fullName,
                score: _teamSetScore(match),
              ),
            ),
        ],
      ),
    );
  }

  String _teamSetScore(TennisMatch match) {
    if (match.winner == null || match.sets.isEmpty) return '';
    var team1Sets = 0;
    var team2Sets = 0;
    for (final set in match.sets) {
      if (set.player1Games > set.player2Games) {
        team1Sets++;
      } else if (set.player2Games > set.player1Games) {
        team2Sets++;
      }
    }
    return '$team1Sets-$team2Sets';
  }
}

class _WinnerBanner extends StatelessWidget {
  const _WinnerBanner({required this.name, this.score});

  final String name;
  final String? score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.clay.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events, size: 15, color: AppTheme.clay),
          const SizedBox(width: 5),
          if ((score ?? '').isNotEmpty) ...[
            Text(
              score!,
              style: const TextStyle(
                color: AppTheme.clay,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.clay,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HintLine extends StatelessWidget {
  const _HintLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.ink.withValues(alpha: .54)),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: AppTheme.ink.withValues(alpha: .62)),
          ),
        ),
      ],
    );
  }
}

class _EmptyMatches extends StatelessWidget {
  const _EmptyMatches();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(Icons.sports_tennis, size: 42, color: AppTheme.court),
          SizedBox(height: 10),
          Text(context.tr("Nema mečeva za ovaj filter.")),
        ],
      ),
    );
  }
}

class _FriendlyMatchInfoCard extends StatelessWidget {
  const _FriendlyMatchInfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.lime.withValues(alpha: .28),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.court.withValues(alpha: .18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.favorite, color: AppTheme.court),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.tr(
                "Ovaj meč je prijateljski. Ne ulazi u statistiku i ne dodaje poene.",
              ),
              style: TextStyle(
                color: AppTheme.ink.withValues(alpha: .72),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MatchDetailsScreen extends StatefulWidget {
  const MatchDetailsScreen({
    super.key,
    required this.league,
    required this.match,
    required this.settings,
    required this.currentPlayerId,
    required this.isAdmin,
  });

  final LeagueService league;
  final TennisMatch match;
  final LeagueSettings settings;
  final String currentPlayerId;
  final bool isAdmin;

  @override
  State<MatchDetailsScreen> createState() => _MatchDetailsScreenState();
}

class _MatchDetailsScreenState extends State<MatchDetailsScreen> {
  late TennisMatch _match = widget.match;
  bool _uploading = false;

  Future<void> _pickImage() async {
    if (_match.images.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr("Galerija može imati najviše 5 slika.")),
        ),
      );
      return;
    }

    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 86,
    );
    if (file == null) return;

    setState(() => _uploading = true);
    try {
      final updated = await widget.league.uploadMatchImage(_match.id, file);
      if (mounted) {
        setState(() => _match = updated);
      }
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
    final canUpload =
        widget.isAdmin ||
        _match.player1.id == widget.currentPlayerId ||
        _match.player2.id == widget.currentPlayerId;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr("Detalji meča"))),
      floatingActionButton: canUpload
          ? FloatingActionButton.extended(
              heroTag: 'match-detail-upload-image-fab-${_match.id}',
              onPressed: _uploading ? null : _pickImage,
              icon: _uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_photo_alternate),
              label: Text(context.tr("Slika")),
            )
          : null,
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
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusBadge(status: _match.status),
                const SizedBox(height: 14),
                Text(
                  '${_match.team1Name} - ${_match.team2Name}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_match.tournament?.name ?? 'Challenge'}  |  ${_match.round}',
                  style: const TextStyle(color: Colors.white70),
                ),
                if (_match.friendly)
                  Text(
                    context.tr("Prijateljski meč - bez poena za rang-listu"),
                    style: TextStyle(
                      color: AppTheme.lime,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                if (_match.scheduledAt != null)
                  Text(
                    context.tr("Termin: {p0}", [
                      _matchDateTimeLabel(_match.scheduledAt!),
                    ]),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if ((_match.location ?? '').isNotEmpty)
                  Text(
                    _match.location!,
                    style: const TextStyle(color: Colors.white70),
                  ),
              ],
            ),
          ),
          if (_match.friendly) ...[
            const SizedBox(height: 12),
            const _FriendlyMatchInfoCard(),
          ],
          if ((_match.location ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            MapLocationCard(
              location: _match.venue?.label ?? _match.location!,
              googlePlaceId: _match.venue?.googlePlaceId,
            ),
          ],
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.scoreboard, color: AppTheme.court),
                      const SizedBox(width: 8),
                      Text(
                        context.tr("Rezultat"),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_match.sets.isEmpty)
                    Text(context.tr("Rezultat još nije unesen."))
                  else
                    _SetScoreBoard(match: _match),
                  const SizedBox(height: 14),
                  if (_match.winner != null)
                    _WinnerHero(player: _match.winner!)
                  else
                    _HintLine(
                      icon: Icons.hourglass_empty,
                      text: context.tr("Pobjednik još nije postavljen."),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.tr("Galerija ({p0}/5)", [_match.images.length]),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          if (_match.images.isEmpty)
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(context.tr("Još nema slika za ovaj meč.")),
              ),
            )
          else
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: _match.images
                  .map(
                    (image) => GestureDetector(
                      onTap: () => openPhotoViewer(
                        context,
                        _match.images.map(widget.league.api.imageUrl).toList(),
                        initialIndex: _match.images.indexOf(image),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          widget.league.api.imageUrl(image),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 82),
        ],
      ),
    );
  }

  String _matchDateTimeLabel(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return context.tr("{p0}.{p1}.{p2} u {p3}:{p4}", [
      day,
      month,
      local.year,
      hour,
      minute,
    ]);
  }
}

class _SetScoreBoard extends StatelessWidget {
  const _SetScoreBoard({required this.match});

  final TennisMatch match;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _scoreRow(
          context,
          player: match.team1Name,
          scores: match.sets.map((set) => set.player1Games).toList(),
          winner: match.winner?.id == match.player1.id,
        ),
        const SizedBox(height: 8),
        _scoreRow(
          context,
          player: match.team2Name,
          scores: match.sets.map((set) => set.player2Games).toList(),
          winner: match.winner?.id == match.player2.id,
        ),
      ],
    );
  }

  Widget _scoreRow(
    BuildContext context, {
    required String player,
    required List<int> scores,
    required bool winner,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: winner
            ? AppTheme.court.withValues(alpha: .08)
            : AppTheme.ink.withValues(alpha: .035),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            winner ? Icons.emoji_events : Icons.sports_tennis,
            size: 17,
            color: winner ? AppTheme.clay : AppTheme.ink.withValues(alpha: .55),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              player,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          ...scores.map(
            (score) => Container(
              width: 30,
              alignment: Alignment.center,
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$score',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WinnerHero extends StatelessWidget {
  const _WinnerHero({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.clay.withValues(alpha: .16),
            AppTheme.lime.withValues(alpha: .22),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events, color: AppTheme.clay),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.tr("Pobjednik: {p0}", [player.fullName]),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
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
        context.tr(matchStatusLabel(status)),
        style: TextStyle(
          color: Color.lerp(color, Colors.black, .4),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _FriendlyChallengeTile extends StatelessWidget {
  const _FriendlyChallengeTile({
    required this.value,
    required this.lockedByTournament,
    required this.onChanged,
  });

  final bool value;
  final bool lockedByTournament;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: value
            ? AppTheme.lime.withValues(alpha: .26)
            : AppTheme.ink.withValues(alpha: .035),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value
              ? AppTheme.court.withValues(alpha: .35)
              : AppTheme.ink.withValues(alpha: .08),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: value ? AppTheme.court : Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.favorite,
              color: value ? Colors.white : AppTheme.ink.withValues(alpha: .58),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr("Prijateljski meč"),
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  lockedByTournament
                      ? context.tr("Meč prati tip izabranog turnira.")
                      : context.tr("Ne ulazi u statistiku i ne dodaje poene."),
                  style: TextStyle(
                    color: AppTheme.ink.withValues(alpha: .58),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: lockedByTournament ? null : onChanged,
          ),
        ],
      ),
    );
  }
}

class ChallengeFormScreen extends StatefulWidget {
  const ChallengeFormScreen({
    super.key,
    required this.league,
    required this.currentPlayerId,
    this.initialOpponentId,
    this.canManageLocations = false,
  });

  final LeagueService league;
  final String currentPlayerId;
  final String? initialOpponentId;
  final bool canManageLocations;

  @override
  State<ChallengeFormScreen> createState() => _ChallengeFormScreenState();
}

class _ChallengeFormScreenState extends State<ChallengeFormScreen> {
  final _round = TextEditingController(text: 'Challenge');
  final _location = TextEditingController();
  AppLocation? _venue;
  final _search = TextEditingController();
  List<Player> _players = [];
  List<Tournament> _tournaments = [];
  Player? _opponent;
  Player? _partner;
  Player? _opponentPartner;
  Tournament? _tournament;
  DateTime? _scheduledAt;
  String _discipline = 'singles';
  bool _friendly = false;
  bool _loading = true;
  bool _saving = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _round.dispose();
    _location.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _failed = false;
      });
    }
    try {
      final results = await Future.wait([
        widget.league.players(),
        widget.league.tournaments(),
      ]);
      final players = results[0] as List<Player>;
      final tournaments = results[1] as List<Tournament>;
      final opponents = players
          .where(
            (player) =>
                player.id != widget.currentPlayerId &&
                player.active &&
                player.isAvailableForMatch,
          )
          .toList();
      if (!mounted) return;
      setState(() {
        _players = opponents;
        _tournaments = tournaments;
        _opponent =
            opponents
                .where((p) => p.id == widget.initialOpponentId)
                .firstOrNull ??
            (opponents.isNotEmpty ? opponents.first : null);
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_opponent == null) return;
    if (_discipline == 'doubles' &&
        (_partner == null || _opponentPartner == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr("Za dubl izaberi još dva igrača."))),
      );
      return;
    }
    if (_tournament != null && _scheduledAt != null) {
      final start = DateTime(
        _tournament!.startDate.year,
        _tournament!.startDate.month,
        _tournament!.startDate.day,
      );
      final end = DateTime(
        _tournament!.endDate.year,
        _tournament!.endDate.month,
        _tournament!.endDate.day,
        23,
        59,
      );
      if (_scheduledAt!.isBefore(start) || _scheduledAt!.isAfter(end)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr("Termin mora biti u okviru turnira: {p0} - {p1}.", [
                _dateOnly(_tournament!.startDate),
                _dateOnly(_tournament!.endDate),
              ]),
            ),
          ),
        );
        return;
      }
    }
    setState(() => _saving = true);
    try {
      await widget.league.challengeMatch(
        opponentId: _opponent!.id,
        partnerId: _discipline == 'doubles' ? _partner?.id : null,
        opponentPartnerId: _discipline == 'doubles'
            ? _opponentPartner?.id
            : null,
        discipline: _discipline,
        tournamentId: _tournament?.id,
        round: _round.text.trim().isEmpty ? 'Challenge' : _round.text.trim(),
        location: _location.text.trim().isEmpty ? null : _location.text.trim(),
        locationId: _venue?.id,
        scheduledAt: _scheduledAt,
        friendly: _tournament?.friendly ?? _friendly,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.tr("Izazov je poslat"))));
        Navigator.of(context).pop();
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.serverMessage(error.message))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredPlayers = _players
        .where(
          (player) => player.fullName.toLowerCase().contains(
            _search.text.toLowerCase(),
          ),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(context.tr("Novi izazov"))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failed
          ? LoadError(onRetry: _load)
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
                      const Icon(
                        Icons.sports_tennis,
                        color: AppTheme.lime,
                        size: 34,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        context.tr("Izazovi igrača"),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.tr(
                          "Pošalji izazov protivniku. Nakon prihvatanja izazova i odigranog meča, oba igrača potvrđuju rezultat.",
                        ),
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
                          context.tr("Protivnik"),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          controller: _search,
                          label: context.tr("Pretraži igrača"),
                          icon: Icons.search,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 10),
                        if (filteredPlayers.isEmpty)
                          Padding(
                            padding: EdgeInsets.all(12),
                            child: Text(
                              context.tr("Nema dostupnih protivnika."),
                            ),
                          )
                        else
                          ...filteredPlayers
                              .take(8)
                              .map(
                                (player) => ListTile(
                                  selected: _opponent?.id == player.id,
                                  selectedTileColor: AppTheme.court.withValues(
                                    alpha: .08,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  onTap: () =>
                                      setState(() => _opponent = player),
                                  title: Text(player.fullName),
                                  subtitle: Text(player.club ?? player.country),
                                  trailing: _opponent?.id == player.id
                                      ? const Icon(
                                          Icons.check_circle,
                                          color: AppTheme.court,
                                        )
                                      : const Icon(Icons.circle_outlined),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
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
                        AppSelectField(
                          label: context.tr("Disciplina"),
                          value: _discipline == 'doubles'
                              ? context.tr("Dubl")
                              : context.tr("Singl"),
                          icon: Icons.sports_tennis,
                          onTap: () async {
                            final value = await showAppOptionPicker<String>(
                              context: context,
                              title: context.tr("Disciplina"),
                              selected: _discipline,
                              options: const ['singles', 'doubles'],
                              labelBuilder: (value) => value == 'doubles'
                                  ? context.tr("Dubl")
                                  : context.tr("Singl"),
                            );
                            if (value != null) {
                              setState(() => _discipline = value);
                            }
                          },
                        ),
                        if (_discipline == 'doubles') ...[
                          const SizedBox(height: 12),
                          AppSelectField(
                            label: context.tr("Moj partner"),
                            value:
                                _partner?.fullName ??
                                context.tr("Izaberi partnera"),
                            icon: Icons.group_add,
                            onTap: () => _pickExtraPlayer(
                              title: context.tr("Moj partner"),
                              selected: _partner,
                              onSelected: (player) =>
                                  setState(() => _partner = player),
                            ),
                          ),
                          const SizedBox(height: 12),
                          AppSelectField(
                            label: context.tr("Partner protivnika"),
                            value:
                                _opponentPartner?.fullName ??
                                context.tr("Izaberi partnera protivnika"),
                            icon: Icons.groups,
                            onTap: () => _pickExtraPlayer(
                              title: context.tr("Partner protivnika"),
                              selected: _opponentPartner,
                              onSelected: (player) =>
                                  setState(() => _opponentPartner = player),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        AppSelectField(
                          label: context.tr("Turnir (opciono)"),
                          value: _tournament?.name ?? context.tr("Bez turnira"),
                          icon: Icons.emoji_events,
                          onTap: () async {
                            final value =
                                await showAppOptionPicker<Tournament?>(
                                  context: context,
                                  title: context.tr("Turnir"),
                                  selected: _tournament,
                                  options: [null, ..._tournaments],
                                  labelBuilder: (value) =>
                                      value?.name ?? context.tr("Bez turnira"),
                                );
                            setState(() {
                              _tournament = value;
                              if (value?.friendly == true) {
                                _friendly = true;
                              }
                              if (value != null && _scheduledAt != null) {
                                final start = DateTime(
                                  value.startDate.year,
                                  value.startDate.month,
                                  value.startDate.day,
                                );
                                final end = DateTime(
                                  value.endDate.year,
                                  value.endDate.month,
                                  value.endDate.day,
                                  23,
                                  59,
                                );
                                if (_scheduledAt!.isBefore(start) ||
                                    _scheduledAt!.isAfter(end)) {
                                  _scheduledAt = start.add(
                                    const Duration(hours: 18),
                                  );
                                }
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        _FriendlyChallengeTile(
                          value: _tournament?.friendly ?? _friendly,
                          lockedByTournament: _tournament != null,
                          onChanged: (value) =>
                              setState(() => _friendly = value),
                        ),
                        const SizedBox(height: 12),
                        AppSelectField(
                          label: context.tr("Datum i vrijeme"),
                          value: _scheduledAt == null
                              ? context.tr("Izaberi termin meča")
                              : _dateTimeLabel(_scheduledAt!),
                          icon: Icons.event_available,
                          onTap: _pickScheduledAt,
                        ),
                        if (_tournament != null) ...[
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              context.tr(
                                "Turnirski meč mora biti između {p0} i {p1}.",
                                [
                                  _dateOnly(_tournament!.startDate),
                                  _dateOnly(_tournament!.endDate),
                                ],
                              ),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppTheme.ink.withValues(alpha: .58),
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        AppTextField(
                          controller: _round,
                          label: context.tr("Naziv meča"),
                          icon: Icons.flag,
                        ),
                        const SizedBox(height: 12),
                        AppSelectField(
                          label: context.tr("Lokacija (opciono)"),
                          value: _location.text.trim().isEmpty
                              ? context.tr("Izaberi lokaciju")
                              : _location.text.trim(),
                          icon: Icons.place,
                          onTap: () async {
                            final value = await showLocationPicker(
                              context: context,
                              league: widget.league,
                              selected: _venue == null ? [] : [_venue!],
                              legacy: _venue == null ? _location.text : '',
                              canManage: widget.canManageLocations,
                              optional: true,
                            );
                            if (mounted && value != null) {
                              setState(() {
                                _location.text = value.label;
                                _venue = value.locations.firstOrNull;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _saving || _opponent == null
                                ? null
                                : _save,
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.send),
                            label: Text(context.tr("Pošalji izazov")),
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

  Future<void> _pickExtraPlayer({
    required String title,
    required Player? selected,
    required ValueChanged<Player> onSelected,
  }) async {
    final usedIds = {
      widget.currentPlayerId,
      _opponent?.id,
      _partner?.id,
      _opponentPartner?.id,
    };
    final options = _players
        .where(
          (player) => player.id == selected?.id || !usedIds.contains(player.id),
        )
        .toList();
    if (options.isEmpty) return;
    final value = await showAppOptionPicker<Player>(
      context: context,
      title: title,
      selected: selected ?? options.first,
      options: options,
      labelBuilder: (player) => player.fullName,
    );
    if (value != null) onSelected(value);
  }

  Future<void> _pickScheduledAt() async {
    final now = DateTime.now();
    final rawFirstDate = _tournament?.startDate ?? now;
    final rawLastDate =
        _tournament?.endDate ?? now.add(const Duration(days: 365));
    final firstDate = _tournament == null
        ? rawFirstDate
        : DateTime(rawFirstDate.year, rawFirstDate.month, rawFirstDate.day);
    final lastDate = _tournament == null
        ? rawLastDate
        : DateTime(
            rawLastDate.year,
            rawLastDate.month,
            rawLastDate.day,
            23,
            59,
          );
    final initialDate = _scheduledAt ?? firstDate.add(const Duration(hours: 1));
    final safeInitialDate = initialDate.isBefore(firstDate)
        ? firstDate
        : initialDate.isAfter(lastDate)
        ? lastDate
        : initialDate;

    final picked = await showAppDateTimePicker(
      context: context,
      title: context.tr("Termin meča"),
      initialDate: safeInitialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      actionLabel: context.tr("Sačuvaj termin"),
    );
    if (picked == null) return;

    setState(() {
      _scheduledAt = picked;
    });
  }

  String _dateOnly(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day.$month.${local.year}';
  }

  String _dateTimeLabel(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return context.tr("{p0} u {p1}:{p2}", [_dateOnly(local), hour, minute]);
  }
}

class SubmitResultScreen extends StatefulWidget {
  const SubmitResultScreen({
    super.key,
    required this.league,
    required this.match,
  });

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
            .map(
              (set) => SetScore(
                player1Games: set.player1Games,
                player2Games: set.player2Games,
              ),
            )
            .toList(),
      );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.serverMessage(error.message))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p1 = widget.match.player1;
    final p2 = widget.match.player2;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr("Rezultat meča"))),
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
                    const Icon(
                      Icons.sports_score,
                      color: AppTheme.lime,
                      size: 34,
                    ),
                    const Spacer(),
                    _StatusBadge(status: widget.match.status),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  '${widget.match.team1Name} - ${widget.match.team2Name}',
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
                    context.tr("Pobjednik"),
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
                          context.tr("Setovi"),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
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
                    onPressed: () =>
                        setState(() => _sets.add(_EditableSetScore(0, 0))),
                    icon: const Icon(Icons.add),
                    label: Text(context.tr("Dodaj set")),
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
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.clay),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.tr(
                      "Rezultat ide drugom igraču na potvrdu prije računanja poena.",
                    ),
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
            label: Text(context.tr("Pošalji na potvrdu")),
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
          color: selected
              ? AppTheme.court.withValues(alpha: .12)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppTheme.court
                : AppTheme.ink.withValues(alpha: .08),
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
                  context.tr("Set {p0}", [index + 1]),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              if (onRemove != null)
                IconButton(
                  tooltip: context.tr("Ukloni set"),
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
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
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
  const AdminResolveScreen({
    super.key,
    required this.league,
    required this.match,
  });

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
        winner: action == 'confirm'
            ? widget.match.winner?.id ?? widget.match.player1.id
            : null,
        sets: action == 'confirm' ? widget.match.sets : null,
        note: _note.text.trim(),
      );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.serverMessage(error.message))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr("Rješavanje spora"))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${widget.match.team1Name} - ${widget.match.team2Name}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _note,
            label: context.tr("Napomena"),
            icon: Icons.note_alt,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => _resolve('confirm'),
            child: Text(context.tr("Potvrdi rezultat")),
          ),
          OutlinedButton(
            onPressed: () => _resolve('reject'),
            child: Text(context.tr("Odbij rezultat")),
          ),
          OutlinedButton(
            onPressed: () => _resolve('cancel'),
            child: Text(context.tr("Poništi meč")),
          ),
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
