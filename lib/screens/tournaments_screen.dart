import 'package:coathematchmaker/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/match.dart';
import '../models/app_location.dart';
import '../models/display_labels.dart';
import '../models/player.dart';
import '../models/tournament.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/league_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_form_fields.dart';
import '../widgets/location_picker.dart';
import '../widgets/map_location_card.dart';
import '../widgets/google_maps_attribution.dart';
import '../widgets/player_avatar.dart';
import '../widgets/section_header.dart';
import '../widgets/load_error.dart';
import '../widgets/photo_viewer.dart';
import '../widgets/sport_surfaces.dart';
import '../widgets/tournament_phases.dart';
import 'matches_screen.dart';
import 'deletion_screen.dart';

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
        if (snapshot.hasError) {
          return LoadError(
            onRetry: () => setState(() {
              _future = widget.league.tournaments();
            }),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'tournaments-create-fab',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => TournamentFormScreen(
                    league: widget.league,
                    canManageLocations: widget.auth.isAdmin,
                  ),
                ),
              );
              setState(() {
                _future = widget.league.tournaments();
              });
            },
            icon: const Icon(Icons.add),
            label: Text(context.tr("Turnir")),
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _future = widget.league.tournaments();
              });
              await _future;
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 96),
              children: [
                if (snapshot.data!.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(context.tr("Trenutno nema turnira.")),
                    ),
                  ),
                ...snapshot.data!.map((tournament) {
                  return _TournamentListCard(
                    tournament: tournament,
                    api: widget.api,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => TournamentDetailsScreen(
                            tournamentId: tournament.id,
                            league: widget.league,
                            api: widget.api,
                            auth: widget.auth,
                          ),
                        ),
                      );
                      if (context.mounted) {
                        setState(() {
                          _future = widget.league.tournaments();
                        });
                      }
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TournamentListCard extends StatelessWidget {
  const _TournamentListCard({
    required this.tournament,
    required this.api,
    required this.onTap,
  });
  final Tournament tournament;
  final ApiClient api;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final photo = tournament.images.isEmpty
        ? null
        : api.imageUrl(tournament.images.first);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 3,
        shadowColor: AppTheme.blue.withValues(alpha: .15),
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 270),
            child: Stack(
              children: [
                Positioned.fill(child: SportPhoto(url: photo)),
                const Positioned.fill(child: PhotoShade(strong: true)),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _TournamentStatusPill(status: tournament.status),
                          const Spacer(),
                          const CircleAvatar(
                            radius: 20,
                            backgroundColor: Color(0xE6FFFFFF),
                            child: Icon(
                              Icons.arrow_outward,
                              size: 20,
                              color: AppTheme.ink,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 60),
                      Text(
                        tournament.name.replaceAllMapped(
                          RegExp(r'(\S+) +(\d+\))'),
                          (match) => '${match[1]}\u00a0${match[2]}',
                        ),
                        semanticsLabel: tournament.name,
                        softWrap: true,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.place_outlined,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              tournament.locationLabel,
                              softWrap: true,
                              style: const TextStyle(
                                color: Color(0xFFE0EDE8),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      GoogleVenueAttributions(
                        locations: tournament.locations,
                        onDark: true,
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _TournamentMiniPill(
                            icon: Icons.grass,
                            label: context.tr(surfaceLabel(tournament.surface)),
                          ),
                          _TournamentMiniPill(
                            icon: Icons.groups,
                            label: context.tr("{p0} igrača", [
                              tournament.participants.length,
                            ]),
                          ),
                          _TournamentMiniPill(
                            icon: Icons.account_tree,
                            label: context.tr(tournament.formatLabel),
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

class _TournamentStatusPill extends StatelessWidget {
  const _TournamentStatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'active' => AppTheme.court,
      'finished' => AppTheme.cream,
      _ => AppTheme.lime,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        context.tr(tournamentStatusLabel(status)),
        style: TextStyle(
          color: status == 'active' ? Colors.white : AppTheme.ink,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TournamentMiniPill extends StatelessWidget {
  const _TournamentMiniPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.ink.withValues(alpha: .65)),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
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
  bool _openingDelete = false;

  Future<void> _deleteTournament() async {
    if (_openingDelete) return;
    setState(() => _openingDelete = true);
    try {
      final data = await _future;
      if (!mounted) return;
      final deleted = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => DeletionScreen(
            league: widget.league,
            id: widget.tournamentId,
            title: data.tournament.name,
            tournament: true,
          ),
        ),
      );
      if (deleted == true && mounted) Navigator.pop(context);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.serverMessage(error.message))),
        );
      }
    } finally {
      if (mounted) setState(() => _openingDelete = false);
    }
  }

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
    final players =
        tournament.canManage(
          widget.auth.currentPlayer?.id,
          appAdmin: widget.auth.isAdmin,
        )
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.serverMessage(error.message))),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.serverMessage(error.message))),
        );
      }
    }
  }

  Future<void> _addTournamentAdmin(String playerId) async {
    try {
      await widget.league.addTournamentAdmin(widget.tournamentId, playerId);
      setState(() {
        _future = _load();
      });
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.serverMessage(error.message))),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.serverMessage(error.message))),
        );
      }
    }
  }

  Future<void> _pickTournamentImage(Tournament tournament) async {
    if (tournament.images.length >= 5) {
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

    setState(() => _uploadingImage = true);
    try {
      await widget.league.uploadTournamentImage(tournament.id, file);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.serverMessage(error.message))),
        );
      }
    }
  }

  Future<void> _editTournament(Tournament tournament) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TournamentFormScreen(
          league: widget.league,
          tournament: tournament,
          canManageLocations: widget.auth.isAdmin,
        ),
      ),
    );
    if (mounted) {
      setState(() {
        _future = _load();
      });
    }
  }

  Future<void> _openMatch(TennisMatch match) async {
    try {
      final settings = await widget.league.settings();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MatchDetailsScreen(
            league: widget.league,
            match: match,
            settings: settings,
            currentPlayerId: widget.auth.currentPlayer?.id ?? '',
            isAdmin: widget.auth.isAdmin,
          ),
        ),
      );
      if (mounted) setState(() => _future = _load());
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
      appBar: AppBar(
        title: Text(context.tr("Turnir")),
        actions: [
          if (widget.auth.isAdmin)
            IconButton(
              tooltip: context.tr('Obriši turnir'),
              onPressed: _openingDelete || _uploadingImage
                  ? null
                  : _deleteTournament,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: FutureBuilder<_TournamentDetailsData>(
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
          final tournament = snapshot.data!.tournament;
          final availablePlayers = snapshot.data!.players
              .where(
                (player) => !tournament.participants.any(
                  (participant) => participant.id == player.id,
                ),
              )
              .toList();
          final adminCandidates = snapshot.data!.players
              .where(
                (player) =>
                    !tournament.admins.any((admin) => admin.id == player.id),
              )
              .toList();
          final registered = tournament.participants.any(
            (player) => player.id == widget.auth.currentPlayer?.id,
          );
          final canManage = tournament.canManage(
            widget.auth.currentPlayer?.id,
            appAdmin: widget.auth.isAdmin,
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _TournamentHero(tournament: tournament),
              const SizedBox(height: 12),
              if (tournament.isPrivate) ...[
                _FriendlyInfoCard(
                  title: context.tr("Privatni turnir"),
                  text: context.tr(
                    "Vidljiv je samo učesnicima i administratorima. Mečevi su prijateljski i ne utiču na rang-listu.",
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (tournament.friendly) ...[
                _FriendlyInfoCard(
                  title: context.tr("Prijateljski turnir"),
                  text: context.tr(
                    "Mečevi iz ovog turnira ne ulaze u statistiku i ne dodaju poene.",
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (tournament.locations.isEmpty)
                MapLocationCard(location: tournament.location)
              else
                ...tournament.locations.map(
                  (location) => MapLocationCard(
                    location: location.label,
                    googlePlaceId: location.googlePlaceId,
                    venue: location,
                  ),
                ),
              const SizedBox(height: 14),
              _TournamentGallery(
                tournament: tournament,
                api: widget.api,
                canUpload:
                    (canManage || registered) && tournament.images.length < 5,
                uploading: _uploadingImage,
                onUpload: () => _pickTournamentImage(tournament),
              ),
              const SizedBox(height: 14),
              _TournamentActions(
                canManage: canManage,
                canGenerate: snapshot.data!.matches.isEmpty,
                isUpcoming: tournament.isUpcoming,
                registered: registered,
                onRegister: _register,
                onEdit: () => _editTournament(tournament),
                onGenerateDraw: _generateDraw,
              ),
              if (tournament.format == 'round_robin' &&
                  tournament.discipline == 'singles')
                TournamentPhases(
                  tournament: tournament,
                  matches: snapshot.data!.matches,
                  league: widget.league,
                  canManage: canManage,
                  onChanged: () => setState(() => _future = _load()),
                  onOpenMatch: _openMatch,
                ),
              if (canManage && tournament.admins.isNotEmpty) ...[
                SectionHeader(context.tr("Administratori turnira")),
                ...tournament.admins.map(
                  (player) => Card(
                    child: ListTile(
                      leading: PlayerAvatar(player: player, api: widget.api),
                      title: Text(player.fullName),
                      subtitle: Text(
                        player.id == tournament.owner?.id
                            ? context.tr("Kreator turnira")
                            : context.tr("Administrator turnira"),
                      ),
                    ),
                  ),
                ),
              ],
              if (canManage &&
                  availablePlayers.isNotEmpty &&
                  !(tournament.format == 'round_robin' &&
                      tournament.hasDraw)) ...[
                SectionHeader(context.tr("Dodaj igrača")),
                AppSelectField(
                  label: context.tr("Igrač"),
                  value: context.tr("Izaberi igrača"),
                  icon: Icons.person_add,
                  onTap: () async {
                    final player = await showAppOptionPicker<Player>(
                      context: context,
                      title: context.tr("Dodaj igrača"),
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
              if (canManage && adminCandidates.isNotEmpty) ...[
                const SizedBox(height: 10),
                AppSelectField(
                  label: context.tr("Dodaj administratora turnira"),
                  value: context.tr("Izaberi igrača"),
                  icon: Icons.admin_panel_settings,
                  onTap: () async {
                    final player = await showAppOptionPicker<Player>(
                      context: context,
                      title: context.tr("Dodaj administratora"),
                      selected: adminCandidates.first,
                      options: adminCandidates,
                      labelBuilder: (player) => player.fullName,
                      leadingBuilder: (player) => PlayerAvatar(
                        player: player,
                        api: widget.api,
                        radius: 18,
                      ),
                    );
                    if (player != null) {
                      _addTournamentAdmin(player.id);
                    }
                  },
                ),
              ],
              SectionHeader(context.tr("Učesnici")),
              ...tournament.participants.map(
                (player) => Card(
                  child: ListTile(
                    leading: PlayerAvatar(player: player, api: widget.api),
                    title: Text(player.fullName),
                    subtitle: Text(player.club ?? player.country),
                    trailing: canManage && !tournament.hasDraw
                        ? IconButton(
                            tooltip: context.tr("Ukloni"),
                            onPressed: () => _removeParticipant(player.id),
                            icon: const Icon(Icons.remove_circle_outline),
                          )
                        : null,
                  ),
                ),
              ),
              if (tournament.format != 'round_robin' ||
                  tournament.discipline != 'singles') ...[
                SectionHeader(context.tr("Rang-lista turnira")),
                ...snapshot.data!.rankings.map(
                  (ranking) => Card(
                    child: ListTile(
                      leading: PlayerAvatar(
                        player: ranking.player,
                        api: widget.api,
                      ),
                      title: Text(ranking.player.fullName),
                      subtitle: Text(
                        context.tr("{p0} pobjeda, {p1} poraza", [
                          ranking.wins,
                          ranking.losses,
                        ]),
                      ),
                      trailing: Text(
                        context.tr("{p0} poena", [ranking.points]),
                      ),
                    ),
                  ),
                ),
                SectionHeader(context.tr("Mečevi turnira")),
                ...snapshot.data!.matches.map(
                  (match) => Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.sports_tennis,
                        color: AppTheme.court,
                      ),
                      title: Text('${match.team1Name} - ${match.team2Name}'),
                      subtitle: Text(
                        '${match.round} · ${context.tr(matchStatusLabel(match.status))}',
                      ),
                      trailing: Text(
                        match.scoreText.isEmpty ? '-' : match.scoreText,
                      ),
                    ),
                  ),
                ),
              ],
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
              _HeroBadge(
                label: context.tr(tournamentStatusLabel(tournament.status)),
              ),
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
              _HeroMeta(icon: Icons.place, label: tournament.locationLabel),
              GoogleVenueAttributions(
                locations: tournament.locations,
                onDark: true,
              ),
              _HeroMeta(icon: Icons.grass, label: tournament.surface),
              _HeroMeta(icon: Icons.category, label: tournament.category),
              _HeroMeta(
                icon: Icons.account_tree,
                label: context.tr(tournament.formatLabel),
              ),
              _HeroMeta(
                icon: tournament.isPrivate ? Icons.lock : Icons.public,
                label: tournament.isPrivate
                    ? context.tr("Privatni")
                    : context.tr("Javni"),
              ),
              if (tournament.friendly)
                _HeroMeta(
                  icon: Icons.favorite,
                  label: context.tr("Prijateljski"),
                ),
              if (!tournament.friendly)
                _HeroMeta(
                  icon: Icons.leaderboard,
                  label: context.tr("Takmičarski"),
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
                    context.tr("Galerija"),
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
                child: Text(context.tr("Još nema slika za ovaj turnir.")),
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
                    return GestureDetector(
                      onTap: () => openPhotoViewer(
                        context,
                        tournament.images.map(api.imageUrl).toList(),
                        initialIndex: index,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Image.network(
                            api.imageUrl(image),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.broken_image_outlined),
                          ),
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
                  label: Text(context.tr("Dodaj sliku turnira")),
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
    required this.canManage,
    required this.canGenerate,
    required this.isUpcoming,
    required this.registered,
    required this.onRegister,
    required this.onEdit,
    required this.onGenerateDraw,
  });

  final bool canManage;
  final bool canGenerate;
  final bool isUpcoming;
  final bool registered;
  final VoidCallback onRegister;
  final VoidCallback onEdit;
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
            label: Text(context.tr("Prijavi se na turnir")),
          ),
        if (registered)
          Chip(
            avatar: const Icon(Icons.check, size: 18),
            label: Text(context.tr("Prijavljen si")),
            backgroundColor: AppTheme.court.withValues(alpha: .10),
          ),
        if (canManage)
          FilledButton.tonalIcon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit),
            label: Text(context.tr("Uredi turnir")),
          ),
        if (canManage && canGenerate)
          FilledButton.icon(
            onPressed: onGenerateDraw,
            icon: const Icon(Icons.account_tree),
            label: Text(context.tr("Formiraj žrijeb")),
          ),
      ],
    );
  }
}

class _FriendlyModeTile extends StatelessWidget {
  const _FriendlyModeTile({
    required this.value,
    required this.onChanged,
    this.locked = false,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final bool locked;

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
                  context.tr("Prijateljski turnir"),
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  locked
                      ? context.tr(
                          "Privatni turnir je uvijek prijateljski i ne utiče na rang-listu.",
                        )
                      : context.tr(
                          "Mečevi ne ulaze u statistiku i ne dodaju poene.",
                        ),
                  style: TextStyle(
                    color: AppTheme.ink.withValues(alpha: .58),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: locked ? null : onChanged),
        ],
      ),
    );
  }
}

class _VisibilityModeTile extends StatelessWidget {
  const _VisibilityModeTile({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final private = value == 'private';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: private
            ? AppTheme.ink.withValues(alpha: .055)
            : AppTheme.court.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.ink.withValues(alpha: .08)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: private ? AppTheme.ink : AppTheme.court,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              private ? Icons.lock : Icons.public,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  private
                      ? context.tr("Privatni turnir")
                      : context.tr("Javni turnir"),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  private
                      ? context.tr(
                          "Vidljiv je samo učesnicima i administratorima.",
                        )
                      : context.tr(
                          "Prikazuje se na listi turnira. Može biti prijateljski ili takmičarski.",
                        ),
                  style: TextStyle(
                    color: AppTheme.ink.withValues(alpha: .58),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'public', icon: Icon(Icons.public)),
              ButtonSegment(value: 'private', icon: Icon(Icons.lock)),
            ],
            selected: {value},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => onChanged(selection.first),
          ),
        ],
      ),
    );
  }
}

class _FriendlyInfoCard extends StatelessWidget {
  const _FriendlyInfoCard({required this.title, required this.text});

  final String title;
  final String text;

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: TextStyle(
                    color: AppTheme.ink.withValues(alpha: .66),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
    this.canManageLocations = false,
  });

  final LeagueService league;
  final Tournament? tournament;
  final bool canManageLocations;

  @override
  State<TournamentFormScreen> createState() => _TournamentFormScreenState();
}

class _TournamentFormScreenState extends State<TournamentFormScreen> {
  final _name = TextEditingController();
  final _location = TextEditingController();
  List<AppLocation> _locations = [];
  final _category = TextEditingController(text: 'Seniori');
  final _surface = TextEditingController(text: 'Tvrda podloga');
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 2));
  String _discipline = 'singles';
  String _format = 'elimination';
  int _knockoutSize = 0;
  bool get _structureLocked =>
      widget.tournament?.format == 'round_robin' && widget.tournament!.hasDraw;
  bool get _knockoutLocked =>
      widget.tournament?.knockoutStarted == true ||
      widget.tournament?.status == 'finished';
  String _status = 'upcoming';
  String _visibility = 'public';
  bool _friendly = false;
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
      _location.text = tournament.locationLabel;
      _locations = [...tournament.locations];
      _category.text = tournament.category;
      _surface.text = tournament.surface;
      _discipline = tournament.discipline;
      _startDate = tournament.startDate;
      _endDate = tournament.endDate;
      _format = tournament.format;
      _knockoutSize = tournament.knockoutSize;
      _status = tournament.status;
      _visibility = tournament.visibility;
      _friendly = tournament.friendly;
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      if (widget.tournament == null) {
        await widget.league.createTournament(
          name: _name.text.trim(),
          discipline: _discipline,
          location: _location.text.trim(),
          locationIds: _locations.map((item) => item.id).toList(),
          surface: _surface.text.trim(),
          category: _category.text.trim(),
          format: _format,
          knockoutSize: _format == 'round_robin' ? _knockoutSize : 0,
          startDate: _startDate,
          endDate: _endDate,
          visibility: _visibility,
          friendly: _friendly,
          status: _status,
        );
      } else {
        await widget.league.updateTournament(
          id: widget.tournament!.id,
          name: _name.text.trim(),
          discipline: _discipline,
          location: _location.text.trim(),
          locationIds: _locations.map((item) => item.id).toList(),
          surface: _surface.text.trim(),
          category: _category.text.trim(),
          format: _format,
          knockoutSize: _format == 'round_robin' ? _knockoutSize : 0,
          startDate: _startDate,
          endDate: _endDate,
          status: _status,
          visibility: _visibility,
          friendly: _friendly,
        );
      }
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
        title: Text(
          widget.tournament == null
              ? context.tr("Novi turnir")
              : context.tr("Uredi turnir"),
        ),
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
                  widget.tournament == null
                      ? context.tr("Kreiraj turnir")
                      : context.tr("Uredi turnir"),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr(
                    "Izaberi format žrijeba, podlogu i datume. Učesnike dodaješ na stranici turnira.",
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
                children: [
                  _field(_name, context.tr("Naziv turnira"), Icons.title),
                  const SizedBox(height: 12),
                  AppSelectField(
                    label: context.tr("Lokacije"),
                    value: _locations.isNotEmpty
                        ? context.tr('Izabrano lokacija: {p0}', [
                            _locations.length,
                          ])
                        : _location.text.trim().isEmpty
                        ? context.tr("Izaberi lokacije")
                        : _location.text.trim(),
                    icon: Icons.place,
                    onTap: () async {
                      final value = await showLocationPicker(
                        context: context,
                        league: widget.league,
                        selected: _locations,
                        legacy: _locations.isEmpty ? _location.text : '',
                        multiple: true,
                        canManage: widget.canManageLocations,
                      );
                      if (mounted && value != null) {
                        setState(() {
                          _location.text = value.label;
                          _locations = value.locations;
                        });
                      }
                    },
                  ),
                  for (final location in _locations)
                    ListTile(
                      key: ValueKey('tournament-location-${location.id}'),
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.location_on_outlined),
                      title: Text(location.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (location.address.isNotEmpty)
                            Text(location.address),
                          GoogleVenueAttributions(locations: [location]),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: context.tr('Ukloni lokaciju'),
                        onPressed: _saving
                            ? null
                            : () => setState(() {
                                _locations.removeWhere(
                                  (item) => item.id == location.id,
                                );
                                _location.text = LocationSelection(
                                  locations: _locations,
                                ).label;
                              }),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: AppSelectField(
                          label: context.tr("Podloga"),
                          value: context.tr(surfaceLabel(_surface.text)),
                          icon: Icons.grass,
                          onTap: () async {
                            final value = await showAppOptionPicker<String>(
                              context: context,
                              title: context.tr("Podloga"),
                              selected: _surface.text,
                              options: _surfaces,
                              labelBuilder: (value) =>
                                  context.tr(surfaceLabel(value)),
                            );
                            if (value != null) {
                              setState(() => _surface.text = value);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          _category,
                          context.tr("Kategorija"),
                          Icons.category,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AppSelectField(
                    label: context.tr("Disciplina"),
                    value: _discipline == 'doubles'
                        ? context.tr("Dubl")
                        : context.tr("Singl"),
                    icon: Icons.sports_tennis,
                    onTap: () async {
                      if (_structureLocked || _knockoutLocked) return;
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
                        setState(() {
                          _discipline = value;
                          if (value != 'singles') _knockoutSize = 0;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _VisibilityModeTile(
                    value: _visibility,
                    onChanged: (value) => setState(() {
                      _visibility = value;
                      if (value == 'private') {
                        _friendly = true;
                      }
                    }),
                  ),
                  const SizedBox(height: 12),
                  _FriendlyModeTile(
                    value: _friendly,
                    locked: _visibility == 'private',
                    onChanged: (value) => setState(() => _friendly = value),
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
                    context.tr("Format turnira"),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _formatCard(
                    value: 'elimination',
                    title: context.tr("Eliminacioni žrijeb"),
                    subtitle: context.tr(
                      "Klasičan eliminacioni žrijeb sa slobodnim prolazima kada je potrebno.",
                    ),
                    icon: Icons.account_tree,
                  ),
                  _formatCard(
                    value: 'qualification',
                    title: context.tr("Kvalifikacije"),
                    subtitle: context.tr(
                      "Pobjednici kvalifikacionih mečeva ulaze u glavni žrijeb.",
                    ),
                    icon: Icons.filter_alt,
                  ),
                  _formatCard(
                    value: 'round_robin',
                    title: context.tr("Round-robin + knockout (opciono)"),
                    subtitle: context.tr(
                      "Svako igra sa svakim. Najbolje za male grupe i ligu.",
                    ),
                    icon: Icons.all_inclusive,
                  ),
                  if (_format == 'round_robin') ...[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.tr("Knockout završnica")),
                      value: _knockoutSize > 0,
                      onChanged: _knockoutLocked || _discipline != 'singles'
                          ? null
                          : (enabled) =>
                                setState(() => _knockoutSize = enabled ? 4 : 0),
                    ),
                    if (_discipline != 'singles')
                      Text(context.tr("Knockout završnica: samo singl.")),
                    if (_knockoutSize > 0) ...[
                      const SizedBox(height: 8),
                      Text(context.tr("Broj učesnika u završnici")),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<int>(
                          segments: [
                            for (final size in [2, 4, 8, 16])
                              ButtonSegment(value: size, label: Text('$size')),
                          ],
                          selected: {_knockoutSize},
                          showSelectedIcon: false,
                          onSelectionChanged: _knockoutLocked
                              ? null
                              : (value) =>
                                    setState(() => _knockoutSize = value.first),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                  _formatCard(
                    value: 'group_knockout',
                    title: context.tr("Grupe + knockout"),
                    subtitle: context.tr(
                      "Prvo grupe, zatim najbolji prolaze u eliminacionu fazu.",
                    ),
                    icon: Icons.grid_view,
                  ),
                  _formatCard(
                    value: 'double_elimination',
                    title: context.tr("Dvostruka eliminacija"),
                    subtitle: context.tr(
                      "Igrač ispada tek poslije dva poraza. Više mečeva, manje slučajnosti.",
                    ),
                    icon: Icons.restart_alt,
                  ),
                  _formatCard(
                    value: 'compass',
                    title: context.tr("Kompas žrijeb"),
                    subtitle: context.tr(
                      "Igrači nastavljaju i poslije poraza, dobro za rekreativne turnire.",
                    ),
                    icon: Icons.explore,
                  ),
                  _formatCard(
                    value: 'swiss',
                    title: context.tr("Švajcarski sistem"),
                    subtitle: context.tr(
                      "Parovi se određuju prema rezultatima. Dobro za mnogo igrača i ograničeno vrijeme.",
                    ),
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
                    label: context.tr("Status"),
                    value: _statusLabel(_status),
                    icon: Icons.timeline,
                    onTap: () async {
                      final value = await showAppOptionPicker<String>(
                        context: context,
                        title: context.tr("Status"),
                        selected: _status,
                        options: const ['upcoming', 'active', 'finished'],
                        labelBuilder: _statusLabel,
                      );
                      if (value != null) setState(() => _status = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  _dateTile(
                    context.tr("Datum početka"),
                    _startDate,
                    (date) => setState(() => _startDate = date),
                  ),
                  _dateTile(
                    context.tr("Datum završetka"),
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
            label: Text(context.tr("Sačuvaj turnir")),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, IconData icon) {
    return AppTextField(controller: controller, label: label, icon: icon);
  }

  String _statusLabel(String value) {
    return context.tr(tournamentStatusLabel(value));
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
      onTap: _structureLocked ? null : () => setState(() => _format = value),
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
