import 'package:coathematchmaker/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import '../models/app_location.dart';
import '../screens/locations_screen.dart';
import '../services/api_client.dart';
import '../services/league_service.dart';
import '../services/place_search_controller.dart';
import 'google_maps_attribution.dart';

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
    builder: (context) => LocationPickerScreen(
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
  final _query = TextEditingController();
  final _resultsScroll = ScrollController();
  late final _search = PlaceSearchController(widget.league)
    ..addListener(_changed);
  late final Map<String, AppLocation> _selected = {
    for (final item in widget.selected) item.id: item,
  };
  late bool _keepLegacy = _selected.isEmpty && widget.legacy.isNotEmpty;
  List<AppLocation> _saved = [];
  bool _loadingSaved = true;
  String? _savedError;
  String? _savingPlace;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loadingSaved = true;
      _savedError = null;
    });
    try {
      final items = await widget.league.locations();
      if (mounted) setState(() => _saved = items);
    } on ApiException catch (error) {
      if (mounted) setState(() => _savedError = error.message);
    } finally {
      if (mounted) setState(() => _loadingSaved = false);
    }
  }

  void _changeQuery(String value) {
    _search.language = Localizations.localeOf(context).languageCode == 'en'
        ? 'en'
        : 'sr';
    _search.update(value);
    if (_resultsScroll.hasClients) _resultsScroll.jumpTo(0);
  }

  bool get _full => widget.multiple && _selected.length >= 20;

  void _toggle(AppLocation item) {
    if (!_selected.containsKey(item.id) && _full) return;
    setState(() {
      _keepLegacy = false;
      if (_selected.containsKey(item.id)) {
        _selected.remove(item.id);
      } else {
        if (!widget.multiple) _selected.clear();
        _selected[item.id] = item;
      }
    });
  }

  void _select(AppLocation item) {
    setState(() {
      _keepLegacy = false;
      if (!widget.multiple) _selected.clear();
      _selected[item.id] = item;
      _saved = [..._saved.where((saved) => saved.id != item.id), item];
    });
  }

  Future<void> _google(GooglePlaceResult place) async {
    if (_savingPlace != null) return;
    final existing = _selected.values
        .where((item) => item.googlePlaceId == place.id)
        .firstOrNull;
    if (existing != null) {
      _toggle(existing);
      return;
    }
    if (_full) return;
    final query = _query.text;
    final token = _search.sessionToken;
    _search.newSession();
    setState(() => _savingPlace = place.id);
    try {
      final item = await widget.league.selectGoogleLocation(
        place.id,
        token,
        language: _search.language,
      );
      if (!mounted) return;
      _select(item);
      if (_query.text == query) {
        _query.clear();
        _changeQuery('');
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.serverMessage(error.message))),
        );
      }
    } finally {
      if (mounted) setState(() => _savingPlace = null);
    }
  }

  Future<void> _manual() async {
    final item = await Navigator.of(context).push<AppLocation>(
      MaterialPageRoute(
        builder: (context) => LocationEditScreen(
          league: widget.league,
          initialName: _query.text.trim(),
        ),
      ),
    );
    if (mounted && item != null) {
      _select(item);
      _query.clear();
      _changeQuery('');
    }
  }

  @override
  void dispose() {
    _query.dispose();
    _resultsScroll.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = {
      for (final item in widget.selected) item.id: item,
      for (final item in _saved) item.id: item,
    };
    final query = _query.text.trim().toLowerCase();
    final items = all.values
        .where((item) => item.label.toLowerCase().contains(query))
        .toList();
    final google = _search.results
        .where((place) => !items.any((item) => item.googlePlaceId == place.id))
        .toList();
    final busy = _savingPlace != null;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final canConfirm =
        !busy && (_selected.isNotEmpty || _keepLegacy || widget.optional);
    void confirm() => Navigator.of(context).pop(
      LocationSelection(
        locations: _selected.values.toList(),
        legacy: _keepLegacy ? widget.legacy : '',
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(widget.multiple ? 'Lokacije turnira' : 'Lokacija'),
          maxLines: 2,
        ),
        toolbarHeight: 64,
        actions: [
          if (keyboardOpen)
            IconButton(
              tooltip: context.tr('Potvrdi izbor'),
              icon: Badge(
                label: Text('${_selected.length + (_keepLegacy ? 1 : 0)}'),
                child: const Icon(Icons.check),
              ),
              onPressed: canConfirm ? confirm : null,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _query,
              maxLength: 200,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: context.tr('Pretraži lokacije'),
                counterText: '',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: context.tr('Obriši pretragu'),
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _query.clear();
                          _changeQuery('');
                        },
                      ),
              ),
              onChanged: _changeQuery,
              onSubmitted: (value) => _search.update(value, immediate: true),
            ),
          ),
          if (!keyboardOpen && (_selected.isNotEmpty || _keepLegacy))
            SizedBox(
              height: MediaQuery.textScalerOf(context).scale(20) + 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  if (_keepLegacy)
                    _chip(
                      'legacy',
                      widget.legacy,
                      () => setState(() => _keepLegacy = false),
                    ),
                  for (final item in _selected.values)
                    _chip(item.id, item.name, () => _toggle(item)),
                ],
              ),
            ),
          SizedBox(
            height: 2,
            child: _search.loading || busy
                ? const LinearProgressIndicator()
                : null,
          ),
          Expanded(
            child: ListView(
              key: const Key('location-results'),
              controller: _resultsScroll,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                if (widget.legacy.isNotEmpty && query.isEmpty)
                  CheckboxListTile(
                    value: _keepLegacy,
                    title: Text(widget.legacy),
                    subtitle: Text(context.tr('Raniji unos')),
                    onChanged: busy
                        ? null
                        : (value) => setState(() {
                            _keepLegacy = value == true;
                            if (_keepLegacy) _selected.clear();
                          }),
                  ),
                if (items.isNotEmpty) _heading(context.tr('Sačuvane lokacije')),
                for (final item in items)
                  CheckboxListTile(
                    key: ValueKey('saved-location-${item.id}'),
                    value: _selected.containsKey(item.id),
                    title: Text(item.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.address.isNotEmpty)
                          Text(
                            item.address,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w400),
                          ),
                        if (!item.active)
                          Text(context.tr('Neaktivna lokacija')),
                        if (item.showsGoogleDetails)
                          GoogleMapsAttribution(
                            providers: item.googleDetails!.attributions,
                          ),
                      ],
                    ),
                    onChanged:
                        busy || (_full && !_selected.containsKey(item.id))
                        ? null
                        : (_) => _toggle(item),
                  ),
                if (_loadingSaved && items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (_savedError != null)
                  ListTile(
                    title: Text(context.tr('Sačuvane lokacije nisu dostupne.')),
                    trailing: IconButton(
                      tooltip: context.tr('Pokušaj ponovo'),
                      icon: const Icon(Icons.refresh),
                      onPressed: _load,
                    ),
                  ),
                if (_search.searched || _search.results.isNotEmpty) ...[
                  const Divider(height: 24),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: GoogleMapsAttribution(),
                  ),
                  for (final place in google)
                    ListTile(
                      key: ValueKey('google-place-${place.id}'),
                      leading: const Icon(Icons.location_on_outlined),
                      title: Text(place.name),
                      subtitle: Text(
                        place.address,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      trailing: Icon(
                        _selected.values.any(
                              (item) => item.googlePlaceId == place.id,
                            )
                            ? Icons.check_circle
                            : Icons.add_circle_outline,
                      ),
                      enabled:
                          !busy &&
                          (!_full ||
                              _selected.values.any(
                                (item) => item.googlePlaceId == place.id,
                              )),
                      onTap: () => _google(place),
                    ),
                  if (_search.error != null)
                    ListTile(
                      title: Text(context.serverMessage(_search.error!)),
                      trailing: IconButton(
                        tooltip: context.tr('Pokušaj ponovo'),
                        icon: const Icon(Icons.refresh),
                        onPressed: () =>
                            _search.update(_query.text, immediate: true),
                      ),
                    ),
                  if (_search.error == null && _search.results.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        context.tr('Nema rezultata na Google mapama.'),
                      ),
                    ),
                ],
                if (!_loadingSaved && items.isEmpty && query.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(context.tr('Nema sačuvanih lokacija.')),
                  ),
                if (widget.canManage) ...[
                  const Divider(height: 24),
                  ListTile(
                    key: const Key('manual-location'),
                    leading: const Icon(Icons.edit_location_alt_outlined),
                    title: Text(context.tr('Dodaj ručno')),
                    subtitle: query.isEmpty ? null : Text(_query.text.trim()),
                    trailing: const Icon(Icons.chevron_right),
                    enabled: !busy && !_full,
                    onTap: _manual,
                  ),
                ],
                if (_full)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      context.tr('Možete izabrati najviše 20 lokacija.'),
                    ),
                  ),
              ],
            ),
          ),
          if (!keyboardOpen)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.check),
                    onPressed: canConfirm ? confirm : null,
                    label: Text(
                      widget.multiple
                          ? context.tr('Potvrdi izbor ({p0})', [
                              _selected.length + (_keepLegacy ? 1 : 0),
                            ])
                          : context.tr('Potvrdi izbor'),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge),
  );

  Widget _chip(String id, String text, VoidCallback remove) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Center(
      child: InputChip(
        key: ValueKey('selected-location-$id'),
        avatar: const Icon(Icons.check, size: 16),
        label: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 210),
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        tooltip: text,
        onDeleted: _savingPlace == null ? remove : null,
        deleteButtonTooltipMessage: context.tr('Ukloni lokaciju'),
      ),
    ),
  );
}
