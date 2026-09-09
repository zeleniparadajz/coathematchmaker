import 'package:coathematchmaker/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/player.dart';
import '../models/match.dart';
import '../models/tournament.dart';
import '../models/display_labels.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/league_service.dart';
import '../theme/app_theme.dart';
import '../widgets/player_avatar.dart';
import '../widgets/load_error.dart';
import '../widgets/sport_surfaces.dart';
import '../widgets/photo_viewer.dart';
import '../widgets/stat_card.dart';
import 'players_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.auth,
    required this.league,
    required this.api,
    this.refreshTick = 0,
    this.onNavigate,
  });
  final AuthService auth;
  final LeagueService league;
  final ApiClient api;
  final int refreshTick;
  final ValueChanged<int>? onNavigate;
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<_DashboardData> _future;
  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) _reload();
  }

  Future<_DashboardData> _load() async {
    final results = await Future.wait([
      widget.league.rankings(),
      widget.league.myMatches(),
      widget.league.players(),
      widget.league.tournaments(),
    ]);
    return _DashboardData(
      results[0] as List<Player>,
      results[1] as List<TennisMatch>,
      results[2] as List<Player>,
      results[3] as List<Tournament>,
    );
  }

  Future<void> _reload() async {
    final future = _load();
    setState(() {
      _future = future;
    });
    try {
      await future;
    } catch (_) {
      /* FutureBuilder provides the retry state. */
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_DashboardData>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.hasError) return LoadError(onRetry: _reload);
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final data = snapshot.data!;
      final me = widget.auth.currentPlayer!;
      final myRank = data.rankings.indexWhere((player) => player.id == me.id);
      final current = data.players.firstWhere(
        (p) => p.id == me.id,
        orElse: () => me,
      );
      final activeTournaments = data.tournaments
          .where((t) => t.status == 'active')
          .length;
      final myTournaments = data.tournaments
          .where((t) => t.participants.any((p) => p.id == me.id))
          .length;
      void openMyProfile() => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => PlayerProfileScreen(
            playerId: current.id,
            league: widget.league,
            api: widget.api,
            auth: widget.auth,
          ),
        ),
      );
      final waiting = data.matches
          .where(
            (match) =>
                (match.status == 'pending' &&
                    [
                      match.player2.id,
                      match.player2Partner?.id,
                    ].contains(me.id)) ||
                (match.status == 'waiting_confirmation' &&
                    match.resultSubmittedBy?.id != me.id),
          )
          .length;
      final upcoming =
          data.matches
              .where(
                (match) =>
                    match.status == 'accepted' &&
                    match.scheduledAt != null &&
                    match.scheduledAt!.isAfter(DateTime.now()),
              )
              .toList()
            ..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));
      return RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text(
              context.tr("Zdravo, {p0}", [current.firstName]),
              style: const TextStyle(
                fontSize: 27,
                height: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr("Spreman za sledeći meč?"),
              style: TextStyle(color: AppTheme.muted),
            ),
            const SizedBox(height: 20),
            _PersonalOverview(
              key: const ValueKey('dashboard-personal-overview'),
              player: current,
              api: widget.api,
              position: myRank < 0 ? null : myRank + 1,
              onOpenProfile: openMyProfile,
            ),
            const SizedBox(height: 20),
            _SectionTitle(
              title: context.tr("Liga danas"),
              action: context.tr("Moj profil"),
              onTap: openMyProfile,
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) => GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: constraints.maxWidth >= 700 ? 4 : 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  mainAxisExtent:
                      150 +
                      70 * (MediaQuery.textScalerOf(context).scale(1) - 1),
                ),
                children: [
                  StatCard(
                    label: context.tr("Igrača"),
                    value: '${data.players.length}',
                    icon: Icons.groups,
                  ),
                  StatCard(
                    label: context.tr("Moji turniri"),
                    value: '$myTournaments',
                    icon: Icons.emoji_events,
                    color: AppTheme.gold,
                  ),
                  StatCard(
                    label: context.tr("Moji mečevi"),
                    value: '${current.matchesPlayed}',
                    icon: Icons.sports_tennis,
                    color: AppTheme.blue,
                  ),
                  StatCard(
                    label: context.tr("Titule"),
                    value: '${current.tournamentsWon}',
                    icon: Icons.workspace_premium,
                    color: AppTheme.clay,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.bolt, size: 18, color: AppTheme.court),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    activeTournaments > 0
                        ? context.tr("Turniri u toku: {p0}", [
                            activeTournaments,
                          ])
                        : context.tr("Trenutno nema aktivnih turnira."),
                    style: const TextStyle(color: AppTheme.muted, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => widget.onNavigate?.call(1),
              icon: const Icon(Icons.person_search_outlined, size: 19),
              label: Text(context.tr("Pronađi protivnika")),
            ),
            if (waiting > 0) ...[
              const SizedBox(height: 22),
              Material(
                color: const Color(0xFFEDF1C9),
                borderRadius: BorderRadius.circular(22),
                child: ListTile(
                  leading: const Icon(
                    Icons.mark_chat_unread_outlined,
                    color: AppTheme.courtDark,
                  ),
                  title: Text(
                    context.tr("Zahtjevi koji čekaju odgovor: {p0}", [waiting]),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: const Icon(Icons.arrow_forward, size: 20),
                  onTap: () => widget.onNavigate?.call(3),
                ),
              ),
            ],
            const SizedBox(height: 24),
            _SectionTitle(
              title: context.tr("Sledeći meč"),
              action: context.tr("Moji mečevi"),
              onTap: () => widget.onNavigate?.call(3),
            ),
            const SizedBox(height: 10),
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(26),
                onTap: () => widget.onNavigate?.call(3),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: upcoming.isEmpty
                      ? Row(
                          children: [
                            Icon(
                              Icons.event_available_outlined,
                              color: AppTheme.court,
                              size: 28,
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                context.tr("Još nema dogovorenog termina."),
                                style: TextStyle(color: AppTheme.muted),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.schedule,
                                  size: 18,
                                  color: AppTheme.court,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    shortDateTime(upcoming.first.scheduledAt!),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              context.tr("{p0}\nprotiv {p1}", [
                                upcoming.first.team1Name,
                                upcoming.first.team2Name,
                              ]),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (upcoming.first.location?.isNotEmpty ==
                                true) ...[
                              const SizedBox(height: 8),
                              Text(
                                upcoming.first.location!,
                                style: const TextStyle(color: AppTheme.muted),
                              ),
                            ],
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _SectionTitle(
              title: context.tr("Vrh rang-liste"),
              action: context.tr("Svi igrači"),
              onTap: () => widget.onNavigate?.call(4),
            ),
            const SizedBox(height: 10),
            if (data.rankings.isEmpty)
              Padding(
                padding: EdgeInsets.all(20),
                child: Text(context.tr("Još nema igrača na rang-listi.")),
              ),
            ...data.rankings.take(5).toList().asMap().entries.map((entry) {
              final p = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    leading: SizedBox(
                      width: 68,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 25,
                            child: Text(
                              '${entry.key + 1}.',
                              style: const TextStyle(
                                color: AppTheme.muted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          PlayerAvatar(player: p, api: widget.api, radius: 21),
                        ],
                      ),
                    ),
                    title: Text(
                      p.fullName,
                      maxLines: 2,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      context.tr("{p0} pobjeda", [p.wins]),
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Text(
                      '${p.totalPoints}',
                      style: const TextStyle(
                        fontSize: 20,
                        color: AppTheme.court,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => PlayerProfileScreen(
                          playerId: p.id,
                          league: widget.league,
                          api: widget.api,
                          auth: widget.auth,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      );
    },
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.action,
    required this.onTap,
  });
  final String title;
  final String action;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      TextButton(
        onPressed: onTap,
        child: Text(action, style: const TextStyle(fontSize: 12)),
      ),
    ],
  );
}

class _PersonalOverview extends StatelessWidget {
  const _PersonalOverview({
    super.key,
    required this.player,
    required this.api,
    required this.position,
    required this.onOpenProfile,
  });
  final Player player;
  final ApiClient api;
  final int? position;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final url = api.imageUrl(player.profileImage);
    final initials = [
      if (player.firstName.isNotEmpty) player.firstName[0],
      if (player.lastName.isNotEmpty) player.lastName[0],
    ].join().toUpperCase();
    Widget fallback() => ColoredBox(
      color: AppTheme.courtDark,
      child: Align(
        alignment: const Alignment(0, -.45),
        child: CircleAvatar(
          radius: 58,
          backgroundColor: AppTheme.lime,
          child: Text(
            initials,
            style: const TextStyle(
              fontSize: 40,
              color: AppTheme.courtDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 4,
      shadowColor: AppTheme.courtDark.withValues(alpha: .16),
      child: SizedBox(
        height: 330 + 90 * (MediaQuery.textScalerOf(context).scale(1) - 1),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (url.isEmpty)
              fallback()
            else
              CachedNetworkImage(
                key: const ValueKey('dashboard-profile-photo'),
                imageUrl: url,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                placeholder: (_, _) => fallback(),
                errorWidget: (_, _, _) => fallback(),
              ),
            const PhotoShade(),
            if (url.isNotEmpty)
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(onTap: () => openPhotoViewer(context, [url])),
                ),
              ),
            Positioned(
              top: 14,
              left: 16,
              right: 14,
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: position == null
                          ? const SizedBox()
                          : Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.court,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Text(
                                context.tr("{p0}. na rang-listi", [position]),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (url.isNotEmpty)
                    IconButton(
                      tooltip: context.tr("Prikaži moju fotografiju"),
                      onPressed: () => openPhotoViewer(context, [url]),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: .9),
                      ),
                      icon: const Icon(Icons.open_in_full, size: 19),
                    ),
                ],
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: onOpenProfile,
                    child: Text(
                      player.fullName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 25,
                        height: 1.15,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0x55FFFFFF), height: 1),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _HeroNumber(
                        label: context.tr("Poeni"),
                        value: '${player.totalPoints}',
                      ),
                      _HeroNumber(
                        label: context.tr("Pobjede"),
                        value: '${player.wins}',
                      ),
                      _HeroNumber(
                        label: context.tr("Porazi"),
                        value: '${player.losses}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroNumber extends StatelessWidget {
  const _HeroNumber({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(color: Color(0xFFE0EDE8), fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

class _DashboardData {
  const _DashboardData(
    this.rankings,
    this.matches,
    this.players,
    this.tournaments,
  );
  final List<Player> rankings;
  final List<TennisMatch> matches;
  final List<Player> players;
  final List<Tournament> tournaments;
}
