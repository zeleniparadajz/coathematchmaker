import 'package:flutter/material.dart';

import '../models/league_settings.dart';
import '../models/match.dart';
import '../services/api_client.dart';
import '../services/league_service.dart';
import '../widgets/app_form_fields.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.league, this.refreshTick = 0});

  final LeagueService league;
  final int refreshTick;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<_SettingsData> _future;
  final _delay = TextEditingController();
  final _matchPoints = TextEditingController();
  final _tournamentPoints = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) {
      setState(() {
        _future = _load();
      });
    }
  }

  Future<_SettingsData> _load() async {
    final settings = await widget.league.settings();
    final disputed = await widget.league.disputedMatches();
    _delay.text = '${settings.resultEntryDelayMinutes}';
    _matchPoints.text = '${settings.matchWinPoints}';
    _tournamentPoints.text = '${settings.tournamentWinPoints}';
    return _SettingsData(settings, disputed);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.league.updateSettings(
        resultEntryDelayMinutes: int.tryParse(_delay.text) ?? 60,
        matchWinPoints: int.tryParse(_matchPoints.text) ?? 10,
        tournamentWinPoints: int.tryParse(_tournamentPoints.text) ?? 50,
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
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _resolve(TennisMatch match, String action) async {
    try {
      await widget.league.adminResolve(
        matchId: match.id,
        action: action,
        winner: action == 'confirm'
            ? match.winner?.id ?? match.player1.id
            : null,
        sets: action == 'confirm' ? match.sets : null,
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_SettingsData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 42),
                  const SizedBox(height: 12),
                  Text(
                    'Ne mogu učitati podešavanja.',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(snapshot.error.toString(), textAlign: TextAlign.center),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () {
                      setState(() {
                        _future = _load();
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Pokušaj opet'),
                  ),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Liga podešavanja',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _numberField(_delay, 'Minute do unosa rezultata'),
                    const SizedBox(height: 12),
                    _numberField(_matchPoints, 'Poeni za pobjedu'),
                    const SizedBox(height: 12),
                    _numberField(
                      _tournamentPoints,
                      'Poeni za osvajanje turnira',
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.save),
                        label: const Text('Sačuvaj podešavanja'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Disputed mečevi',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            if (snapshot.data!.disputed.isEmpty)
              const Card(child: ListTile(title: Text('Nema spornih mečeva'))),
            ...snapshot.data!.disputed.map(
              (match) => Card(
                child: ListTile(
                  title: Text(
                    '${match.player1.fullName} vs ${match.player2.fullName}',
                  ),
                  subtitle: Text(
                    match.scoreText.isEmpty ? 'Bez rezultata' : match.scoreText,
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) => _resolve(match, action),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'confirm', child: Text('Potvrdi')),
                      PopupMenuItem(value: 'reject', child: Text('Odbij')),
                      PopupMenuItem(value: 'cancel', child: Text('Poništi')),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _numberField(TextEditingController controller, String label) {
    return AppTextField(
      controller: controller,
      label: label,
      icon: Icons.tune,
      keyboardType: TextInputType.number,
    );
  }
}

class _SettingsData {
  const _SettingsData(this.settings, this.disputed);

  final LeagueSettings settings;
  final List<TennisMatch> disputed;
}
