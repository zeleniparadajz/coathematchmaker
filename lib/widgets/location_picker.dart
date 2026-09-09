import 'package:flutter/material.dart';
import '../models/app_location.dart';
import '../screens/locations_screen.dart';
import '../services/league_service.dart';
import 'load_error.dart';

class LocationSelection {
  const LocationSelection({this.locations = const [], this.legacy = ''});
  final List<AppLocation> locations;
  final String legacy;
  String get label => locations.isEmpty
      ? legacy
      : locations.map((item) => item.label).join('; ');
}

Future<LocationSelection?> showLocationPicker({
  required BuildContext context,
  required LeagueService league,
  List<AppLocation> selected = const [],
  String legacy = '',
  bool multiple = false,
  bool canManage = false,
  bool optional = false,
}) => Navigator.of(context).push<LocationSelection>(
  MaterialPageRoute(
    builder: (_) => LocationPickerScreen(
      league: league,
      selected: selected,
      legacy: legacy,
      multiple: multiple,
      canManage: canManage,
      optional: optional,
    ),
  ),
);

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({
    super.key,
    required this.league,
    this.selected = const [],
    this.legacy = '',
    this.multiple = false,
    this.canManage = false,
    this.optional = false,
  });
  final LeagueService league;
  final List<AppLocation> selected;
  final String legacy;
  final bool multiple;
  final bool canManage;
  final bool optional;
  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late Future<List<AppLocation>> _future = widget.league.locations();
  late final Map<String, AppLocation> _selected = {
    for (final item in widget.selected) item.id: item,
  };
  late bool _keepLegacy = _selected.isEmpty && widget.legacy.isNotEmpty;
  String _query = '';

  void _toggle(AppLocation item) {
    setState(() {
      _keepLegacy = false;
      if (_selected.containsKey(item.id)) {
        _selected.remove(item.id);
      } else {
        if (!widget.multiple) _selected.clear();
        if (_selected.length < 20) _selected[item.id] = item;
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.multiple ? 'Lokacije turnira' : 'Lokacija'),
      actions: [
        if (widget.canManage)
          IconButton(
            tooltip: 'Dodaj lokaciju',
            icon: const Icon(Icons.add_location_alt_outlined),
            onPressed: () async {
              final item = await Navigator.of(context).push<AppLocation>(
                MaterialPageRoute(
                  builder: (_) => LocationEditScreen(league: widget.league),
                ),
              );
              if (mounted && item != null) {
                _toggle(item);
                setState(() => _future = widget.league.locations());
              }
            },
          ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Pretrazi lokacije',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) =>
                setState(() => _query = value.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<AppLocation>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return LoadError(
                  onRetry: () =>
                      setState(() => _future = widget.league.locations()),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final all = {
                for (final item in widget.selected) item.id: item,
                for (final item in snapshot.data!) item.id: item,
              };
              final items = all.values
                  .where((item) => item.label.toLowerCase().contains(_query))
                  .toList();
              return ListView(
                children: [
                  if (widget.legacy.isNotEmpty)
                    CheckboxListTile(
                      value: _keepLegacy,
                      title: Text(widget.legacy),
                      subtitle: const Text('Raniji unos'),
                      onChanged: (value) => setState(() {
                        _keepLegacy = value == true;
                        if (_keepLegacy) _selected.clear();
                      }),
                    ),
                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Nema lokacija za ovaj izbor.'),
                    ),
                  for (final item in items)
                    CheckboxListTile(
                      value: _selected.containsKey(item.id),
                      title: Text(item.name),
                      subtitle: Text(
                        [
                          if (item.address.isNotEmpty) item.address,
                          if (!item.active) 'Neaktivna lokacija',
                        ].join('\n'),
                      ),
                      onChanged:
                          (!_selected.containsKey(item.id) &&
                              _selected.length >= 20 &&
                              widget.multiple)
                          ? null
                          : (_) => _toggle(item),
                    ),
                ],
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.check),
                onPressed: _selected.isEmpty && !_keepLegacy && !widget.optional
                    ? null
                    : () => Navigator.of(context).pop(
                        LocationSelection(
                          locations: _selected.values.toList(),
                          legacy: _keepLegacy ? widget.legacy : '',
                        ),
                      ),
                label: Text(
                  widget.multiple
                      ? 'Potvrdi izbor (${_selected.length + (_keepLegacy ? 1 : 0)})'
                      : 'Potvrdi izbor',
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
