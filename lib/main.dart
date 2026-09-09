import 'package:coathematchmaker/l10n/app_strings.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_language.dart';

import 'screens/auth_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/matches_screen.dart';
import 'screens/messages_screen.dart';
import 'screens/players_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/locations_screen.dart';
import 'screens/rankings_screen.dart';
import 'screens/tournaments_screen.dart';
import 'services/api_client.dart';
import 'services/app_config_service.dart';
import 'services/auth_service.dart';
import 'services/activity_service.dart';
import 'services/league_service.dart';
import 'theme/app_theme.dart';
import 'widgets/player_avatar.dart';
import 'widgets/update_screen.dart';
import 'widgets/sport_surfaces.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CoaMatchmakerApp());
}

class CoaMatchmakerApp extends StatefulWidget {
  const CoaMatchmakerApp({
    super.key,
    this.api,
    this.configService,
    this.languageController,
  });
  final ApiClient? api;
  final AppConfigService? configService;
  final AppLanguageController? languageController;
  @override
  State<CoaMatchmakerApp> createState() => _CoaMatchmakerAppState();
}

class _CoaMatchmakerAppState extends State<CoaMatchmakerApp>
    with WidgetsBindingObserver {
  late final api = widget.api ?? ApiClient();
  late final auth = AuthService(api);
  late final activity = AppActivityTracker(auth);
  late final league = LeagueService(api);
  late final appConfig = widget.configService ?? AppConfigService(api);
  late final language = widget.languageController ?? AppLanguageController();
  bool _starting = true;
  bool _checking = false;
  bool _sessionRestored = false;
  AppConfig? _config;
  Timer? _timer;
  DateTime? _checkedAt;

  @override
  void initState() {
    super.initState();
    auth.addListener(_authChanged);
    activity.start();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
    _startTimer();
  }

  Future<void> _initialize() async {
    await language.restore();
    if (mounted) await _checkUpdate();
  }

  void _authChanged() {
    if (mounted) setState(() {});
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => _checkUpdate());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startTimer();
      if (_checkedAt == null ||
          DateTime.now().difference(_checkedAt!) >
              const Duration(seconds: 15)) {
        _checkUpdate();
      }
    } else {
      _timer?.cancel();
    }
  }

  Future<void> _checkUpdate() async {
    if (_checking) return;
    _checking = true;
    try {
      final config = await appConfig.load();
      if (!mounted) return;
      setState(() => _config = config);
      if (!appConfig.lastCheckUsedCache) _checkedAt = DateTime.now();
    } catch (_) {
      // Keep a known mandatory update in place if a later request fails.
    } finally {
      _checking = false;
    }
    if (!mounted) return;
    if (_config?.updateRequired != true && !_sessionRestored) {
      _sessionRestored = true;
      await auth.restoreSession();
    }
    if (mounted) setState(() => _starting = false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    auth.removeListener(_authChanged);
    activity.dispose();
    auth.dispose();
    if (widget.languageController == null) language.dispose();
    if (widget.api == null) api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppLanguageScope(
    controller: language,
    child: ListenableBuilder(
      listenable: language,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'COA The Matchmaker',
        locale: language.language.locale,
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light,
        builder: (context, child) => Stack(
          children: [
            Offstage(
              offstage: _config?.updateRequired == true,
              child: TickerMode(
                enabled: _config?.updateRequired != true,
                child: child!,
              ),
            ),
            // A separate navigator keeps the gate above all previously opened routes.
            if (_config?.updateRequired == true)
              Positioned.fill(
                child: HeroControllerScope.none(
                  child: Navigator(
                    key: ValueKey(
                      'update:${_config!.minSupportedBuild}:${_config!.storeUrl}',
                    ),
                    onGenerateRoute: (_) => MaterialPageRoute<void>(
                      builder: (context) => ForceUpdateScreen(
                        config: _config!,
                        onRetry: _checkUpdate,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        home: _config?.updateRequired == true && !_sessionRestored
            ? const Scaffold()
            : _starting || auth.loading
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : auth.isLoggedIn
            ? MainShell(
                auth: auth,
                league: league,
                api: api,
                config: _config,
                onCheckUpdate: _checkUpdate,
              )
            : AuthScreen(auth: auth),
      ),
    ),
  );
}

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.auth,
    required this.league,
    required this.api,
    this.config,
    this.onCheckUpdate,
  });
  final AuthService auth;
  final LeagueService league;
  final ApiClient api;
  final AppConfig? config;
  final Future<void> Function()? onCheckUpdate;
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _index = 0;
  int _pending = 0;
  int _unread = 0;
  bool _refreshing = false;
  final _ticks = List.filled(5, 0);
  Timer? _timer;
  int? _dismissedUpdate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshBadges();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshBadges(),
    );
  }

  Future<void> _refreshBadges() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final result = await Future.wait([
        widget.league.pendingMatches().then((items) => items.length),
        widget.league.unreadMessageCount(),
      ]);
      if (mounted) {
        setState(() {
          _pending = result[0];
          _unread = result[1];
        });
      }
    } catch (_) {
      // A failed poll must not erase unread indicators or restart every screen.
    } finally {
      _refreshing = false;
    }
  }

  void _select(int index) {
    setState(() {
      _index = index;
      _ticks[index]++;
    });
    _refreshBadges();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startTimer();
      _select(_index);
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _openMessages() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(context.tr("Poruke"))),
          body: MessagesScreen(
            league: widget.league,
            auth: widget.auth,
            api: widget.api,
            onChanged: _refreshBadges,
          ),
        ),
      ),
    );
    _refreshBadges();
  }

  Future<void> _profileAction(String value) async {
    Widget? page;
    switch (value) {
      case 'profile':
        page = ProfileScreen(
          auth: widget.auth,
          league: widget.league,
          api: widget.api,
        );
      case 'status':
        page = PlayStatusScreen(
          auth: widget.auth,
          league: widget.league,
          api: widget.api,
        );
      case 'delete':
        page = DeleteAccountScreen(auth: widget.auth);
      case 'settings':
        if (!widget.auth.isAdmin) return;
        page = Scaffold(
          appBar: AppBar(title: Text(context.tr("Podešavanja lige"))),
          body: SettingsScreen(league: widget.league),
        );
      case 'locations':
        if (!widget.auth.isAdmin) return;
        page = LocationsScreen(league: widget.league);
      case 'logout':
        await widget.auth.logout();
        return;
      case 'version':
        await showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (context) => VersionSheet(
            config: widget.config,
            onCheck: widget.onCheckUpdate,
          ),
        );
        return;
    }
    if (page != null && mounted) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (context) => page!));
      if (mounted) _select(_index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      context.tr("Početna"),
      context.tr("Igrači"),
      context.tr("Turniri"),
      context.tr("Mečevi"),
      context.tr("Rang-lista"),
    ];
    final pages = [
      DashboardScreen(
        auth: widget.auth,
        league: widget.league,
        api: widget.api,
        refreshTick: _ticks[0],
        onNavigate: _select,
      ),
      PlayersScreen(
        league: widget.league,
        api: widget.api,
        auth: widget.auth,
        refreshTick: _ticks[1],
      ),
      TournamentsScreen(
        league: widget.league,
        api: widget.api,
        auth: widget.auth,
        refreshTick: _ticks[2],
      ),
      MatchesScreen(
        league: widget.league,
        auth: widget.auth,
        onChanged: _refreshBadges,
        refreshTick: _ticks[3],
      ),
      RankingsScreen(
        league: widget.league,
        api: widget.api,
        auth: widget.auth,
        refreshTick: _ticks[4],
      ),
    ];
    final config = widget.config;
    return SportBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          toolbarHeight: 76,
          title: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  'assets/images/coa.png',
                  width: 42,
                  height: 42,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _index == 0 ? 'COA Matchmaker' : titles[_index],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _index == 0
                          ? context.tr("Tvoja teniska zajednica")
                          : 'COA Matchmaker',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: .65),
              ),
              tooltip: context.tr("Poruke"),
              onPressed: _openMessages,
              icon: Badge(
                isLabelVisible: _unread > 0,
                label: Text('$_unread'),
                child: const Icon(Icons.chat_bubble_outline),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: context.tr("Profil i podešavanja"),
              onSelected: _profileAction,
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'profile',
                  child: ListTile(
                    leading: Icon(Icons.person_outline),
                    title: Text(context.tr("Moj profil")),
                  ),
                ),
                PopupMenuItem(
                  value: 'status',
                  child: ListTile(
                    leading: Icon(Icons.sports_tennis),
                    title: Text(context.tr("Dostupnost za meč")),
                  ),
                ),
                if (widget.auth.isAdmin)
                  PopupMenuItem(
                    value: 'locations',
                    child: ListTile(
                      leading: Icon(Icons.edit_location_alt_outlined),
                      title: Text(context.tr("Lokacije")),
                    ),
                  ),
                if (widget.auth.isAdmin)
                  PopupMenuItem(
                    value: 'settings',
                    child: ListTile(
                      leading: Icon(Icons.settings_outlined),
                      title: Text(context.tr("Podešavanja lige")),
                    ),
                  ),
                PopupMenuItem(
                  value: 'version',
                  child: ListTile(
                    leading: Icon(Icons.system_update),
                    title: Text(context.tr("Verzija aplikacije")),
                  ),
                ),
                PopupMenuItem(
                  value: 'logout',
                  child: ListTile(
                    leading: Icon(Icons.logout),
                    title: Text(context.tr("Odjavi se")),
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline),
                    title: Text(context.tr("Obriši nalog")),
                  ),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
                child: PlayerAvatar(
                  player: widget.auth.currentPlayer!,
                  api: widget.api,
                  radius: 18,
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            if (config != null &&
                config.updateAvailable &&
                _dismissedUpdate != config.latestBuild)
              MaterialBanner(
                content: Text(
                  context.tr("Dostupna je nova verzija aplikacije."),
                ),
                leading: const Icon(Icons.system_update),
                actions: [
                  IconButton(
                    tooltip: context.tr("Kasnije"),
                    onPressed: () =>
                        setState(() => _dismissedUpdate = config.latestBuild),
                    icon: const Icon(Icons.close),
                  ),
                  TextButton(
                    onPressed: () => openAppStore(context, config),
                    child: Text(context.tr("Ažuriraj")),
                  ),
                ],
              ),
            Expanded(
              child: IndexedStack(index: _index, children: pages),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: FrostedSurface(
                  radius: 36,
                  child: NavigationBar(
                    selectedIndex: _index,
                    onDestinationSelected: _select,
                    destinations: [
                      NavigationDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home),
                        label: context.tr("Početna"),
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.people_outline),
                        selectedIcon: Icon(Icons.people),
                        label: context.tr("Igrači"),
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.emoji_events_outlined),
                        selectedIcon: Icon(Icons.emoji_events),
                        label: context.tr("Turniri"),
                      ),
                      NavigationDestination(
                        icon: Badge(
                          isLabelVisible: _pending > 0,
                          label: Text('$_pending'),
                          child: const Icon(Icons.sports_tennis),
                        ),
                        label: context.tr("Mečevi"),
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.leaderboard_outlined),
                        selectedIcon: Icon(Icons.leaderboard),
                        label: context.tr("Rang-lista"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
