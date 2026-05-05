import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/league_settings.dart';
import '../models/match.dart';
import '../models/player.dart';
import '../models/tournament.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/league_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_form_fields.dart';
import '../widgets/map_location_card.dart';

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'matches-create-challenge-fab',
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
              padding: const EdgeInsets.all(16),
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
                      onOpen: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MatchDetailsScreen(
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
        borderRadius: BorderRadius.circular(24),
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
                    child: Text(
                      '${match.team1Name} vs ${match.team2Name}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _StatusBadge(status: match.status),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetaPill(
                    icon: Icons.flag,
                    label: match.tournament?.name ?? 'Challenge',
                  ),
                  _MetaPill(icon: Icons.label, label: match.round),
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
                      label: '${match.images.length}/5 slika',
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
                const _HintLine(
                  icon: Icons.hourglass_top,
                  text: 'Čeka se odgovor protivnika',
                ),
              ],
              if (match.status == 'waiting_confirmation') ...[
                const SizedBox(height: 10),
                const _HintLine(
                  icon: Icons.verified_outlined,
                  text: 'Rezultat čeka potvrdu druge strane',
                ),
              ],
              if (match.status == 'rejected' ||
                  match.status == 'cancelled') ...[
                const SizedBox(height: 10),
                const _HintLine(icon: Icons.block, text: 'Meč nije aktivan'),
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
                    FilledButton.tonal(
                      onPressed: onAccept,
                      child: const Text('Accept'),
                    ),
                    OutlinedButton(
                      onPressed: onReject,
                      child: const Text('Reject'),
                    ),
                  ],
                  if (match.status == 'accepted' && (!tooEarly || isAdmin))
                    FilledButton.icon(
                      onPressed: onSubmitResult,
                      icon: const Icon(Icons.sports_score),
                      label: const Text('Unesi rezultat'),
                    ),
                  if (match.status == 'waiting_confirmation' &&
                      (!_isSubmitter || isAdmin)) ...[
                    FilledButton(
                      onPressed: onConfirm,
                      child: const Text('Confirm Result'),
                    ),
                    OutlinedButton(
                      onPressed: onDispute,
                      child: const Text('Dispute Result'),
                    ),
                  ],
                  if (isAdmin &&
                      (match.status == 'disputed' ||
                          match.status == 'waiting_confirmation'))
                    FilledButton.tonal(
                      onPressed: onAdminResolve,
                      child: const Text('Admin resolve'),
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
            label: Text(status == 'all' ? 'Svi' : status.replaceAll('_', ' ')),
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
                    Text(entry.value),
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
              Text(
                'Sort: ${_options[selected] ?? 'Termin'}',
                style: const TextStyle(
                  color: AppTheme.court,
                  fontWeight: FontWeight.w900,
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
      child: const Column(
        children: [
          Icon(Icons.sports_tennis, size: 42, color: AppTheme.court),
          SizedBox(height: 10),
          Text('Nema mečeva za ovaj filter.'),
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
        const SnackBar(content: Text('Galerija može imati najviše 5 slika.')),
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
    final canUpload =
        widget.isAdmin ||
        _match.player1.id == widget.currentPlayerId ||
        _match.player2.id == widget.currentPlayerId;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalji meča')),
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
              label: const Text('Slika'),
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
                  '${_match.team1Name} vs ${_match.team2Name}',
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
                if (_match.scheduledAt != null)
                  Text(
                    'Termin: ${_matchDateTimeLabel(_match.scheduledAt!)}',
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
          if ((_match.location ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            MapLocationCard(location: _match.location!),
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
                        'Rezultat',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_match.sets.isEmpty)
                    const Text('Rezultat još nije unesen.')
                  else
                    _SetScoreBoard(match: _match),
                  const SizedBox(height: 14),
                  if (_match.winner != null)
                    _WinnerHero(player: _match.winner!)
                  else
                    const _HintLine(
                      icon: Icons.hourglass_empty,
                      text: 'Pobjednik još nije postavljen.',
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Galerija (${_match.images.length}/5)',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          if (_match.images.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Još nema slika za ovaj meč.'),
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
                    (image) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        widget.league.api.imageUrl(image),
                        fit: BoxFit.cover,
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
    return '$day.$month.${local.year} u $hour:$minute';
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
              'Pobjednik: ${player.fullName}',
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
        status.replaceAll('_', ' '),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
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
  final _location = TextEditingController();
  final _search = TextEditingController();
  List<Player> _players = [];
  List<Tournament> _tournaments = [];
  Player? _opponent;
  Player? _partner;
  Player? _opponentPartner;
  Tournament? _tournament;
  DateTime? _scheduledAt;
  String _discipline = 'singles';
  bool _loading = true;
  bool _saving = false;

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
    final players = await widget.league.players();
    final tournaments = await widget.league.tournaments();
    final opponents = players
        .where((player) => player.id != widget.currentPlayerId)
        .toList();
    setState(() {
      _players = opponents;
      _tournaments = tournaments;
      _opponent = opponents.isNotEmpty ? opponents.first : null;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_opponent == null) return;
    if (_discipline == 'doubles' &&
        (_partner == null || _opponentPartner == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Za dubl izaberi još dva igrača.')),
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
              'Termin mora biti u okviru turnira: ${_dateOnly(_tournament!.startDate)} - ${_dateOnly(_tournament!.endDate)}.',
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
        scheduledAt: _scheduledAt,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Challenge je poslat')));
        Navigator.of(context).pop();
      }
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
  Widget build(BuildContext context) {
    final filteredPlayers = _players
        .where(
          (player) => player.fullName.toLowerCase().contains(
            _search.text.toLowerCase(),
          ),
        )
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
                      const Icon(
                        Icons.sports_tennis,
                        color: AppTheme.lime,
                        size: 34,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Izazovi igrača',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
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
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          controller: _search,
                          label: 'Pretraži igrača',
                          icon: Icons.search,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 10),
                        if (filteredPlayers.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('Nema dostupnih protivnika.'),
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
                          label: 'Disciplina',
                          value: _discipline == 'doubles' ? 'Dubl' : 'Singl',
                          icon: Icons.sports_tennis,
                          onTap: () async {
                            final value = await showAppOptionPicker<String>(
                              context: context,
                              title: 'Disciplina',
                              selected: _discipline,
                              options: const ['singles', 'doubles'],
                              labelBuilder: (value) =>
                                  value == 'doubles' ? 'Dubl' : 'Singl',
                            );
                            if (value != null) {
                              setState(() => _discipline = value);
                            }
                          },
                        ),
                        if (_discipline == 'doubles') ...[
                          const SizedBox(height: 12),
                          AppSelectField(
                            label: 'Moj partner',
                            value: _partner?.fullName ?? 'Izaberi partnera',
                            icon: Icons.group_add,
                            onTap: () => _pickExtraPlayer(
                              title: 'Moj partner',
                              selected: _partner,
                              onSelected: (player) =>
                                  setState(() => _partner = player),
                            ),
                          ),
                          const SizedBox(height: 12),
                          AppSelectField(
                            label: 'Partner protivnika',
                            value:
                                _opponentPartner?.fullName ??
                                'Izaberi partnera protivnika',
                            icon: Icons.groups,
                            onTap: () => _pickExtraPlayer(
                              title: 'Partner protivnika',
                              selected: _opponentPartner,
                              onSelected: (player) =>
                                  setState(() => _opponentPartner = player),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        AppSelectField(
                          label: 'Turnir (opciono)',
                          value: _tournament?.name ?? 'Bez turnira',
                          icon: Icons.emoji_events,
                          onTap: () async {
                            final value =
                                await showAppOptionPicker<Tournament?>(
                                  context: context,
                                  title: 'Turnir',
                                  selected: _tournament,
                                  options: [null, ..._tournaments],
                                  labelBuilder: (value) =>
                                      value?.name ?? 'Bez turnira',
                                );
                            setState(() {
                              _tournament = value;
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
                        AppSelectField(
                          label: 'Datum i vrijeme',
                          value: _scheduledAt == null
                              ? 'Izaberi termin meča'
                              : _dateTimeLabel(_scheduledAt!),
                          icon: Icons.event_available,
                          onTap: _pickScheduledAt,
                        ),
                        if (_tournament != null) ...[
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Turnirski meč mora biti između ${_dateOnly(_tournament!.startDate)} i ${_dateOnly(_tournament!.endDate)}.',
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
                          label: 'Naziv meča',
                          icon: Icons.flag,
                        ),
                        const SizedBox(height: 12),
                        AppSelectField(
                          label: 'Lokacija (opciono)',
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
      title: 'Termin meča',
      initialDate: safeInitialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      actionLabel: 'Sačuvaj termin',
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
    return '${_dateOnly(local)} u $hour:$minute';
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
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
                  '${widget.match.team1Name} vs ${widget.match.team2Name}',
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin resolve')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${widget.match.team1Name} vs ${widget.match.team2Name}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _note,
            label: 'Napomena',
            icon: Icons.note_alt,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => _resolve('confirm'),
            child: const Text('Potvrdi rezultat'),
          ),
          OutlinedButton(
            onPressed: () => _resolve('reject'),
            child: const Text('Odbij rezultat'),
          ),
          OutlinedButton(
            onPressed: () => _resolve('cancel'),
            child: const Text('Poništi meč'),
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
