import 'package:coathematchmaker/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_location.dart';
import '../services/api_client.dart';
import '../services/league_service.dart';
import '../services/maps_service.dart';
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
    await Navigator.of(context).push(
      MaterialPageRoute<AppLocation>(
        builder: (context) =>
            LocationEditScreen(league: widget.league, location: location),
      ),
    );
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
                      subtitle: Text(
                        [
                          if (item.address.isNotEmpty) item.address,
                          if (!item.active) context.tr("Neaktivna"),
                        ].join('\n'),
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
  const LocationEditScreen({super.key, required this.league, this.location});
  final LeagueService league;
  final AppLocation? location;
  @override
  State<LocationEditScreen> createState() => _LocationEditScreenState();
}

class _LocationEditScreenState extends State<LocationEditScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.location?.name ?? '');
  late final _address = TextEditingController(
    text: widget.location?.address ?? '',
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
            validator: (value) => value == null || value.trim().isEmpty
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
  List<GooglePlaceResult>? _results;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_loading) return;
    final query = _query.text.trim();
    if (query.length < 3) {
      setState(() => _error = context.tr("Unesite najmanje 3 znaka."));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _results = null;
    });
    try {
      final results = await widget.league.searchPlaces(query);
      if (mounted) setState(() => _results = results);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr("Pronađi mjesto"))),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _query,
            maxLength: 200,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              labelText: context.tr("Naziv mjesta i grad"),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                onPressed: _loading ? null : _search,
                icon: const Icon(Icons.arrow_forward),
                tooltip: context.tr("Pretraži"),
              ),
            ),
          ),
        ),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              context.serverMessage(_error!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const Divider(height: 1),
        if (_results != null)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Google Maps',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF5E5E5E),
                ),
              ),
            ),
          ),
        Expanded(
          child: ListView(
            children: [
              if (_results?.isEmpty == true)
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    context.tr(
                      "Nema rezultata. Pokušajte sa gradom ili adresom.",
                    ),
                  ),
                ),
              for (final place in _results ?? <GooglePlaceResult>[]) ...[
                ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: Text(place.name),
                  subtitle: Text(place.address),
                  trailing: const Icon(Icons.add_location_alt_outlined),
                  onTap: () => Navigator.of(context).pop(place.id),
                ),
                for (final attribution in place.attributions)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextButton(
                      onPressed: () async {
                        final uri = Uri.tryParse(
                          attribution['providerUri'] ?? '',
                        );
                        if (uri != null && uri.scheme == 'https') {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                      child: Text(attribution['provider'] ?? ''),
                    ),
                  ),
                const Divider(height: 1),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}
