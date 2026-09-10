import 'package:coathematchmaker/l10n/app_strings.dart';
import 'package:flutter/material.dart';

import '../models/app_location.dart';
import '../services/api_client.dart';
import '../services/league_service.dart';
import '../services/maps_service.dart';
import '../services/place_search_controller.dart';
import '../widgets/google_maps_attribution.dart';
import '../widgets/location_picker.dart';
import '../widgets/load_error.dart';

class LocationsScreen extends StatefulWidget {
  const LocationsScreen({super.key, required this.league});
  final LeagueService league;
  @override
  State<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends State<LocationsScreen> {
  late Future<List<AppLocation>> _future = widget.league.locations(
    includeInactive: true,
  );
  String _query = '';

  Future<void> _edit([AppLocation? location]) async {
    if (location == null) {
      await showLocationPicker(
        context: context,
        league: widget.league,
        canManage: true,
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute<AppLocation>(
          builder: (context) =>
              LocationEditScreen(league: widget.league, location: location),
        ),
      );
    }
    if (mounted) {
      setState(() => _future = widget.league.locations(includeInactive: true));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.tr("Lokacije")),
      actions: [
        IconButton(
          onPressed: _edit,
          icon: const Icon(Icons.add_location_alt_outlined),
          tooltip: context.tr("Dodaj lokaciju"),
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              labelText: context.tr("Pretraži lokacije"),
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
                  onRetry: () => setState(
                    () => _future = widget.league.locations(
                      includeInactive: true,
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snapshot.data!
                  .where((item) => item.label.toLowerCase().contains(_query))
                  .toList();
              if (items.isEmpty) {
                return Center(
                  child: Text(
                    _query.isEmpty
                        ? context.tr("Nema sačuvanih lokacija.")
                        : context.tr("Nema rezultata."),
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () async {
                  setState(
                    () => _future = widget.league.locations(
                      includeInactive: true,
                    ),
                  );
                  await _future;
                },
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final item = items[index];
                    return ListTile(
                      leading: Icon(
                        item.active
                            ? Icons.location_on_outlined
                            : Icons.location_off_outlined,
                      ),
                      title: Text(item.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.address.isNotEmpty) Text(item.address),
                          if (!item.active) Text(context.tr("Neaktivna")),
                          GoogleVenueAttributions(locations: [item]),
                        ],
                      ),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _edit(item),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

class LocationEditScreen extends StatefulWidget {
  const LocationEditScreen({
    super.key,
    required this.league,
    this.location,
    this.initialName = '',
  });
  final LeagueService league;
  final AppLocation? location;
  final String initialName;
  @override
  State<LocationEditScreen> createState() => _LocationEditScreenState();
}

class _LocationEditScreenState extends State<LocationEditScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.location?.customName ?? widget.initialName,
  );
  late final _address = TextEditingController(
    text: widget.location?.customAddress ?? '',
  );
  late String? _placeId = widget.location?.googlePlaceId;
  late bool _active = widget.location?.active ?? true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final item = await widget.league.saveLocation(
        id: widget.location?.id,
        name: _name.text.trim(),
        address: _address.text.trim(),
        googlePlaceId: _placeId,
        active: _active,
      );
      if (mounted) Navigator.of(context).pop(item);
    } on ApiException catch (error) {
      if (mounted) {
        setState(
          () => _error = error.statusCode == 409
              ? context.tr(
                  "Ovo mjesto sa Google mapa već je dodato u lokacije.",
                )
              : error.message,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.location == null
            ? context.tr("Nova lokacija")
            : context.tr("Uredi lokaciju"),
      ),
    ),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextFormField(
            controller: _name,
            maxLength: 160,
            maxLines: null,
            decoration: InputDecoration(
              labelText: context.tr("Naziv u aplikaciji"),
              prefixIcon: Icon(Icons.place_outlined),
            ),
            validator: (value) =>
                (value == null || value.trim().isEmpty) &&
                    !(widget.location?.googleOnly == true && _placeId != null)
                ? context.tr("Unesite naziv lokacije.")
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _address,
            maxLength: 300,
            maxLines: null,
            decoration: InputDecoration(
              labelText: context.tr("Adresa / grad"),
              prefixIcon: Icon(Icons.signpost_outlined),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _saving
                ? null
                : () async {
                    final placeId = await Navigator.of(context).push<String>(
                      MaterialPageRoute(
                        builder: (context) => GooglePlaceSearchScreen(
                          league: widget.league,
                          initialQuery: [
                            _name.text,
                            _address.text,
                          ].where((v) => v.isNotEmpty).join(', '),
                        ),
                      ),
                    );
                    if (mounted && placeId != null) {
                      setState(() => _placeId = placeId);
                    }
                  },
            icon: const Icon(Icons.travel_explore),
            label: Text(
              _placeId == null
                  ? context.tr("Pronađi na Google mapama")
                  : context.tr("Promijeni povezano mjesto"),
            ),
          ),
          if (_placeId != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.location_on),
              title: Text(context.tr("Povezano sa Google mapama")),
              onTap: () async {
                try {
                  await MapsService.openLocation(
                    _name.text.trim().isEmpty
                        ? context.tr("Lokacija")
                        : _name.text,
                    googlePlaceId: _placeId,
                  );
                } catch (_) {
                  if (mounted) {
                    setState(
                      () => _error = context.tr("Mapu nije moguće otvoriti."),
                    );
                  }
                }
              },
              trailing: IconButton(
                onPressed: _saving
                    ? null
                    : () => setState(() => _placeId = null),
                icon: const Icon(Icons.link_off),
                tooltip: context.tr("Ukloni vezu sa Google mapama"),
              ),
            ),
          if (widget.location != null)
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr("Aktivna lokacija")),
              value: _active,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _active = value),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                context.serverMessage(_error!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(
              _saving
                  ? context.tr("Čuvanje...")
                  : context.tr("Sačuvaj lokaciju"),
            ),
          ),
        ],
      ),
    ),
  );
}

class GooglePlaceSearchScreen extends StatefulWidget {
  const GooglePlaceSearchScreen({
    super.key,
    required this.league,
    this.initialQuery = '',
  });
  final LeagueService league;
  final String initialQuery;
  @override
  State<GooglePlaceSearchScreen> createState() =>
      _GooglePlaceSearchScreenState();
}

class _GooglePlaceSearchScreenState extends State<GooglePlaceSearchScreen> {
  late final _query = TextEditingController(text: widget.initialQuery);
  late final _search = PlaceSearchController(widget.league)
    ..addListener(_changed);
  bool _choosing = false;
  String? _choiceError;

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _update(_query.text);
    });
  }

  void _update(String value) {
    _search.language = Localizations.localeOf(context).languageCode == 'en'
        ? 'en'
        : 'sr';
    _search.update(value);
  }

  Future<void> _choose(GooglePlaceResult place) async {
    if (_choosing) return;
    final token = _search.sessionToken;
    _search.newSession();
    setState(() {
      _choosing = true;
      _choiceError = null;
    });
    try {
      await widget.league.placeDetails(
        place.id,
        token,
        language: _search.language,
      );
      if (mounted) Navigator.of(context).pop(place.id);
    } on ApiException catch (error) {
      if (mounted) setState(() => _choiceError = error.message);
    } finally {
      if (mounted) setState(() => _choosing = false);
    }
  }

  @override
  void dispose() {
    _query.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Pronađi mjesto'))),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _query,
            maxLength: 200,
            textInputAction: TextInputAction.search,
            onChanged: _update,
            onSubmitted: (value) => _search.update(value, immediate: true),
            decoration: InputDecoration(
              labelText: context.tr('Naziv mjesta i grad'),
              counterText: '',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: context.tr('Obriši pretragu'),
                icon: const Icon(Icons.close),
                onPressed: () {
                  _query.clear();
                  _update('');
                },
              ),
            ),
          ),
        ),
        SizedBox(
          height: 2,
          child: _search.loading || _choosing
              ? const LinearProgressIndicator()
              : null,
        ),
        Expanded(
          child: ListView(
            children: [
              if (_search.searched)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: GoogleMapsAttribution(),
                ),
              if (_search.error != null || _choiceError != null)
                ListTile(
                  title: Text(
                    context.serverMessage(_choiceError ?? _search.error!),
                  ),
                  trailing: IconButton(
                    tooltip: context.tr('Pokušaj ponovo'),
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      setState(() => _choiceError = null);
                      _search.update(_query.text, immediate: true);
                    },
                  ),
                ),
              if (_search.searched &&
                  _search.error == null &&
                  _search.results.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(context.tr('Nema rezultata na Google mapama.')),
                ),
              for (final place in _search.results)
                ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: Text(place.name),
                  subtitle: Text(place.address),
                  trailing: const Icon(Icons.check_circle_outline),
                  enabled: !_choosing,
                  onTap: () => _choose(place),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
