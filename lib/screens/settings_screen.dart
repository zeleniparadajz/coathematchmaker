import 'package:coathematchmaker/l10n/app_strings.dart';
import 'package:flutter/material.dart';

import '../models/league_settings.dart';
import '../models/match.dart';
import '../services/api_client.dart';
import '../services/league_service.dart';
import '../widgets/app_form_fields.dart';
import 'matches_screen.dart';

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
  final _inactivityDays = TextEditingController(text: '30');
  final _form = GlobalKey<FormState>();
  bool _autoAvailability = false;
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
    if (!mounted) return _SettingsData(settings, disputed);
    _delay.text = '${settings.resultEntryDelayMinutes}';
    _matchPoints.text = '${settings.matchWinPoints}';
    _tournamentPoints.text = '${settings.tournamentWinPoints}';
    _autoAvailability = settings.inactivityDays > 0;
    _inactivityDays.text =
        '${_autoAvailability ? settings.inactivityDays : 30}';
    return _SettingsData(settings, disputed);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.league.updateSettings(
        resultEntryDelayMinutes: int.tryParse(_delay.text) ?? 60,
        matchWinPoints: int.tryParse(_matchPoints.text) ?? 10,
        tournamentWinPoints: int.tryParse(_tournamentPoints.text) ?? 50,
        inactivityDays: _autoAvailability
            ? int.parse(_inactivityDays.text.trim())
            : 0,
      );
      if (!mounted) return;
      setState(() {
        _future = _load();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Podešavanja su sačuvana.'))),
      );
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

  Future<void> _resolve(TennisMatch match) async {
    final updated = await Navigator.of(context).push<TennisMatch>(
      MaterialPageRoute(
        builder: (_) => AdminResolveScreen(league: widget.league, match: match),
      ),
    );
    if (mounted && updated != null) setState(() => _future = _load());
  }

  @override
  void dispose() {
    _delay.dispose();
    _matchPoints.dispose();
    _tournamentPoints.dispose();
    _inactivityDays.dispose();
    super.dispose();
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
                    context.tr("Podešavanja nije moguće učitati."),
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.serverMessage(snapshot.error.toString()),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () {
                      setState(() {
                        _future = _load();
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: Text(context.tr("Pokušaj opet")),
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
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr("Podešavanja lige"),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _numberField(
                        _delay,
                        context.tr("Minute do unosa rezultata"),
                      ),
                      const SizedBox(height: 12),
                      _numberField(
                        _matchPoints,
                        context.tr("Poeni za pobjedu"),
                      ),
                      const SizedBox(height: 12),
                      _numberField(
                        _tournamentPoints,
                        context.tr("Poeni za osvajanje turnira"),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        key: const ValueKey('auto-unavailable'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(context.tr('Automatska nedostupnost')),
                        value: _autoAvailability,
                        onChanged: _saving
                            ? null
                            : (value) =>
                                  setState(() => _autoAvailability = value),
                      ),
                      if (_autoAvailability)
                        AppTextField(
                          controller: _inactivityDays,
                          label: context.tr('Dani bez aktivnosti'),
                          icon: Icons.event_busy,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            final days = int.tryParse(value?.trim() ?? '');
                            return days == null || days < 1 || days > 365
                                ? context.tr('Unesi cijeli broj od 1 do 365.')
                                : null;
                          },
                        ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: const Icon(Icons.save),
                          label: Text(context.tr("Sačuvaj podešavanja")),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              context.tr("Disputed mečevi"),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            if (snapshot.data!.disputed.isEmpty)
              Card(
                child: ListTile(title: Text(context.tr("Nema spornih mečeva"))),
              ),
            ...snapshot.data!.disputed.map(
              (match) => Card(
                child: ListTile(
                  title: Text('${match.team1Name} - ${match.team2Name}'),
                  subtitle: Text(
                    match.scoreText.isEmpty
                        ? context.tr("Bez rezultata")
                        : match.scoreText,
                  ),
                  trailing: IconButton(
                    tooltip: context.tr('Upravljanje rezultatom'),
                    icon: const Icon(Icons.manage_history),
                    onPressed: () => _resolve(match),
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
