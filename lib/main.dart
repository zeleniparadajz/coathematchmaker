import 'dart:async';

import 'package:flutter/material.dart';

import 'screens/auth_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/matches_screen.dart';
import 'screens/players_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/rankings_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/tournaments_screen.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/league_service.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const CoaMatchmakerApp());
}

class CoaMatchmakerApp extends StatefulWidget {
  const CoaMatchmakerApp({super.key});

  @override
  State<CoaMatchmakerApp> createState() => _CoaMatchmakerAppState();
}

class _CoaMatchmakerAppState extends State<CoaMatchmakerApp> {
  final api = ApiClient();
  late final auth = AuthService(api);
  late final league = LeagueService(api);

  @override
  void initState() {
    super.initState();
    auth.addListener(() => setState(() {}));
    auth.restoreSession();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Coa The Matchmaker',
      theme: AppTheme.light,
      home: auth.loading
          ? const _SplashScreen()
          : auth.isLoggedIn
          ? MainShell(auth: auth, league: league, api: api)
          : AuthScreen(auth: auth),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.auth,
    required this.league,
    required this.api,
  });

  final AuthService auth;
  final LeagueService league;
  final ApiClient api;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _index = 0;
  int _pendingChallengeCount = 0;
  int _refreshVersion = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshVisibleData();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 25),
      (_) => _refreshVisibleData(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshVisibleData();
    }
  }

  Future<void> _loadPendingChallengeCount() async {
    try {
      final pending = await widget.league.pendingMatches();
      if (mounted) {
        setState(() => _pendingChallengeCount = pending.length);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _pendingChallengeCount = 0);
      }
    }
  }

  Future<void> _refreshVisibleData() async {
    await Future.wait([
      _loadPendingChallengeCount(),
      widget.auth.refreshMe().catchError((_) {}),
    ]);
    if (!mounted) return;
    setState(() {
      _refreshVersion++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(
        auth: widget.auth,
        league: widget.league,
        api: widget.api,
        refreshTick: _refreshVersion,
      ),
      PlayersScreen(
        league: widget.league,
        api: widget.api,
        auth: widget.auth,
        refreshTick: _refreshVersion,
      ),
      TournamentsScreen(
        league: widget.league,
        api: widget.api,
        auth: widget.auth,
        refreshTick: _refreshVersion,
      ),
      MatchesScreen(
        league: widget.league,
        auth: widget.auth,
        onChanged: () => _refreshVisibleData(),
        refreshTick: _refreshVersion,
      ),
      RankingsScreen(
        league: widget.league,
        api: widget.api,
        refreshTick: _refreshVersion,
      ),
      ProfileScreen(auth: widget.auth, league: widget.league, api: widget.api),
      if (widget.auth.isAdmin)
        SettingsScreen(league: widget.league, refreshTick: _refreshVersion),
    ];
    final titles = [
      'Dashboard',
      'Igrači',
      'Turniri',
      'Challenges',
      'Ranking',
      'Profil',
      if (widget.auth.isAdmin) 'Podešavanja',
    ];
    final destinations = [
      const NavigationDestination(icon: Icon(Icons.dashboard), label: 'Home'),
      const NavigationDestination(icon: Icon(Icons.groups), label: 'Igrači'),
      const NavigationDestination(
        icon: Icon(Icons.emoji_events),
        label: 'Turniri',
      ),
      NavigationDestination(
        icon: _ChallengeTabIcon(count: _pendingChallengeCount),
        selectedIcon: _ChallengeTabIcon(
          count: _pendingChallengeCount,
          selected: true,
        ),
        label: 'Mečevi',
      ),
      const NavigationDestination(
        icon: Icon(Icons.leaderboard),
        label: 'Ranking',
      ),
      const NavigationDestination(icon: Icon(Icons.person), label: 'Profil'),
      if (widget.auth.isAdmin)
        const NavigationDestination(
          icon: Icon(Icons.settings),
          label: 'Settings',
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: _BrandTitle(section: titles[_index]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              tooltip: 'Logout',
              onPressed: widget.auth.logout,
              icon: const Icon(Icons.logout),
            ),
          ),
        ],
      ),
      extendBody: true,
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
          decoration: BoxDecoration(
            color: AppTheme.lime,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: AppTheme.ink.withValues(alpha: .16),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (index) {
                setState(() => _index = index);
                _refreshVisibleData();
              },
              destinations: destinations,
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandTitle extends StatelessWidget {
  const _BrandTitle({required this.section});

  final String section;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset('assets/images/coa.png', width: 34, height: 34),
        const SizedBox(width: 8),
        RichText(
          text: const TextSpan(
            style: TextStyle(
              color: AppTheme.ink,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
            children: [
              TextSpan(text: 'C'),
              TextSpan(
                text: 'O',
                style: TextStyle(color: AppTheme.court),
              ),
              TextSpan(text: 'A'),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChallengeTabIcon extends StatelessWidget {
  const _ChallengeTabIcon({required this.count, this.selected = false});

  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      Icons.sports_tennis,
      color: selected ? AppTheme.court : null,
    );

    if (count == 0) return icon;

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppTheme.clay.withValues(alpha: .45),
            blurRadius: 18,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Badge.count(
        count: count,
        backgroundColor: AppTheme.clay,
        textColor: Colors.white,
        child: icon,
      ),
    );
  }
}
