import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_strings.dart';
import '../models/deletion_preview.dart';
import '../services/api_client.dart';
import '../services/league_service.dart';
import '../widgets/load_error.dart';

class DeletionScreen extends StatefulWidget {
  const DeletionScreen({
    super.key,
    required this.league,
    required this.id,
    required this.title,
    required this.tournament,
  });

  final LeagueService league;
  final String id;
  final String title;
  final bool tournament;

  @override
  State<DeletionScreen> createState() => _DeletionScreenState();
}

class _DeletionScreenState extends State<DeletionScreen> {
  late Future<DeletionPreview> _future;
  final _form = GlobalKey<FormState>();
  final _matchPoints = <String, TextEditingController>{};
  final _tournamentPoints = TextEditingController();
  bool? _awardApplied;
  bool _confirmed = false;
  bool _saving = false;
  String? _error;
  bool _stale = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<DeletionPreview> _load() async {
    final preview = await widget.league.deletionPreview(
      widget.id,
      tournament: widget.tournament,
    );
    if (mounted) {
      for (final controller in _matchPoints.values) {
        controller.dispose();
      }
      _matchPoints.clear();
      for (final id in preview.legacyMatches.keys) {
        _matchPoints[id] = TextEditingController();
      }
    }
    return preview;
  }

  void _reload() => setState(() {
    _confirmed = false;
    _awardApplied = null;
    _stale = false;
    _error = null;
    _tournamentPoints.clear();
    _future = _load();
  });

  @override
  void dispose() {
    for (final controller in _matchPoints.values) {
      controller.dispose();
    }
    _tournamentPoints.dispose();
    super.dispose();
  }

  Future<void> _delete(DeletionPreview preview) async {
    if (_saving || !_confirmed) return;
    final validForm = _form.currentState!.validate();
    bool validPoints(TextEditingController controller) {
      final value = int.tryParse(controller.text);
      return value != null && value >= 0 && value <= 1000000;
    }

    if (!_matchPoints.values.every(validPoints)) {
      setState(
        () =>
            _error = 'Unesite ranije dodijeljene poene za svaki označeni meč.',
      );
      return;
    }
    if (preview.needsLegacyTournamentAward && _awardApplied == null) {
      setState(
        () => _error =
            'Potvrdite da li su ranije dodijeljeni titula i poeni za turnir.',
      );
      return;
    }
    if (_awardApplied == true && !validPoints(_tournamentPoints)) {
      setState(
        () => _error = 'Unesite ranije dodijeljene poene za osvajanje turnira.',
      );
      return;
    }
    if (!validForm) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.league.deleteCompetition(
        widget.id,
        tournament: widget.tournament,
        revision: preview.revision,
        legacyMatchPoints: {
          for (final entry in _matchPoints.entries)
            entry.key: int.parse(entry.value.text),
        },
        legacyTournamentAwardApplied: _awardApplied,
        legacyTournamentPoints: _awardApplied == true
            ? int.parse(_tournamentPoints.text)
            : null,
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _stale = error.statusCode == 409;
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _pointsField(
    TextEditingController controller,
    String label,
    String key,
  ) => TextFormField(
    key: ValueKey(key),
    controller: controller,
    enabled: !_saving,
    decoration: InputDecoration(labelText: context.tr(label)),
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    validator: (value) {
      final points = int.tryParse(value ?? '');
      return points == null || points < 0 || points > 1000000
          ? context.tr('Unesite broj od 0 do 1000000.')
          : null;
    },
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Text(
          context.tr(widget.tournament ? 'Obriši turnir' : 'Obriši meč'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: FutureBuilder<DeletionPreview>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) return LoadError(onRetry: _reload);
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final preview = snapshot.data!;
          return Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                if (preview.blockedReason != null) ...[
                  Text(context.serverMessage(preview.blockedReason!)),
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.tr('Nazad')),
                  ),
                ] else ...[
                  Text(
                    context.tr(
                      widget.tournament
                          ? 'Turnir, svi njegovi mečevi, rezultati i slike biće trajno obrisani. Poeni i statistika iz tih mečeva i turnira biće poništeni.'
                          : 'Meč, rezultat i njegove slike biće trajno obrisani. Poeni i statistika iz ovog meča biće poništeni.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.tr('Mečevi: {p0} · Slike: {p1}', [
                      preview.matchCount,
                      preview.imageCount,
                    ]),
                  ),
                  if (preview.clearsTournamentWinner)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        context.tr(
                          'Poništava se i pobjednik turnira. Turnir se vraća u aktivno stanje.',
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    context.tr(
                      'Nalozi igrača i zajedničke lokacije neće biti obrisani.',
                    ),
                  ),
                  if (preview.legacyMatches.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      context.tr(
                        'Za starije mečeve unesite poene koji su tada dodijeljeni za jednu pobjedu.',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    for (final entry in preview.legacyMatches.entries) ...[
                      const SizedBox(height: 16),
                      Text(entry.value),
                      const SizedBox(height: 8),
                      _pointsField(
                        _matchPoints[entry.key]!,
                        'Ranije dodijeljeni poeni',
                        'delete-points-${entry.key}',
                      ),
                    ],
                  ],
                  if (preview.needsLegacyTournamentAward) ...[
                    const SizedBox(height: 24),
                    Text(
                      context.tr(
                        'Da li su ranije dodijeljeni titula i poeni za osvajanje turnira?',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<bool>(
                      key: const ValueKey('delete-legacy-award'),
                      isExpanded: true,
                      hint: Text(context.tr('Izaberi')),
                      initialValue: _awardApplied,
                      items: [
                        DropdownMenuItem(
                          value: true,
                          child: Text(context.tr('Da')),
                        ),
                        DropdownMenuItem(
                          value: false,
                          child: Text(context.tr('Ne')),
                        ),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _awardApplied = value),
                      validator: (value) =>
                          value == null ? context.tr('Obavezno polje') : null,
                    ),
                    if (_awardApplied == true) ...[
                      const SizedBox(height: 16),
                      _pointsField(
                        _tournamentPoints,
                        'Poeni za osvajanje turnira',
                        'delete-tournament-points',
                      ),
                    ],
                  ],
                  const SizedBox(height: 20),
                  CheckboxListTile(
                    key: const ValueKey('delete-confirmation'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _confirmed,
                    onChanged: _saving
                        ? null
                        : (value) =>
                              setState(() => _confirmed = value ?? false),
                    title: Text(
                      context.tr(
                        'Razumijem da je brisanje trajno i da se ne može poništiti.',
                      ),
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        context.serverMessage(_error!),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (_stale)
                    OutlinedButton(
                      onPressed: _saving ? null : _reload,
                      child: Text(context.tr('Osvježi pregled')),
                    ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    key: const ValueKey('delete-permanently'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: _confirmed && !_saving && !_stale
                        ? () => _delete(preview)
                        : null,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_forever_outlined),
                    label: Text(
                      context.tr(_saving ? 'Brisanje...' : 'Trajno obriši'),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    ),
  );
}
