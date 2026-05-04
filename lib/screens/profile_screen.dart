import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/player.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/league_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_form_fields.dart';
import '../widgets/player_avatar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.auth,
    required this.league,
    required this.api,
  });

  final AuthService auth;
  final LeagueService league;
  final ApiClient api;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class PlayStatusScreen extends StatefulWidget {
  const PlayStatusScreen({
    super.key,
    required this.auth,
    required this.league,
    required this.api,
  });

  final AuthService auth;
  final LeagueService league;
  final ApiClient api;

  @override
  State<PlayStatusScreen> createState() => _PlayStatusScreenState();
}

class _PlayStatusScreenState extends State<PlayStatusScreen> {
  bool _saving = false;

  Future<void> _setStatus(String status) async {
    setState(() => _saving = true);
    try {
      await widget.league.updateMyPlayStatus(status);
      await widget.auth.refreshMe();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Status je promijenjen')));
      }
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

  @override
  Widget build(BuildContext context) {
    final player = widget.auth.currentPlayer;
    final status = player?.playStatus ?? 'available';

    return Scaffold(
      appBar: AppBar(title: const Text('Status')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (player != null)
                        PlayerAvatar(player: player, api: widget.api),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Ko smije da te zove na meč?',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Ovo nije status naloga. Nalog ostaje aktivan, a ovdje samo biraš da li želiš da te drugi igrači pozivaju na mečeve.',
                    style: TextStyle(
                      color: AppTheme.ink.withValues(alpha: .62),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _PlayStatusOption(
            selected: status == 'available',
            saving: _saving,
            icon: Icons.sports_tennis,
            title: 'Aktivan',
            subtitle:
                'Prikazuješ se kao igrač koji je voljan i spreman da primi challenge ili dogovor za termin.',
            onTap: () => _setStatus('available'),
          ),
          const SizedBox(height: 10),
          _PlayStatusOption(
            selected: status == 'unavailable',
            saving: _saving,
            icon: Icons.do_not_disturb_on_outlined,
            title: 'Neaktivan',
            subtitle:
                'Drugi igrači vide da trenutno ne želiš pozive za meč. Profil i nalog ostaju normalno aktivni.',
            onTap: () => _setStatus('unavailable'),
          ),
        ],
      ),
    );
  }
}

class _PlayStatusOption extends StatelessWidget {
  const _PlayStatusOption({
    required this.selected,
    required this.saving,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final bool saving;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: saving ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppTheme.lime : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected
                ? AppTheme.court
                : AppTheme.ink.withValues(alpha: .08),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: selected ? AppTheme.court : AppTheme.mist,
              child: Icon(icon, color: AppTheme.ink),
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
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppTheme.ink.withValues(alpha: .62),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected
                  ? AppTheme.court
                  : AppTheme.ink.withValues(alpha: .34),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _birthYear = TextEditingController();
  final _club = TextEditingController();
  bool _saving = false;
  bool _uploading = false;
  String _country = 'Montenegro';
  String _sport = 'tennis';
  DateTime _birthDate = DateTime(1995);

  static const _countries = [
    'Montenegro',
    'Serbia',
    'Croatia',
    'Bosnia and Herzegovina',
    'Slovenia',
    'North Macedonia',
    'Albania',
    'Italy',
    'Germany',
    'France',
    'Spain',
    'United States',
    'Austria',
    'Switzerland',
    'United Kingdom',
    'Netherlands',
    'Belgium',
    'Greece',
    'Turkey',
    'Australia',
    'Canada',
  ];

  @override
  void initState() {
    super.initState();
    _syncPlayer(widget.auth.currentPlayer);
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _birthYear.dispose();
    _club.dispose();
    super.dispose();
  }

  void _syncPlayer(Player? player) {
    if (player == null) return;
    _firstName.text = player.firstName;
    _lastName.text = player.lastName;
    _birthDate = player.birthDate;
    _birthYear.text = _dateLabel(player.birthDate);
    _club.text = player.club ?? '';
    _sport = player.sport;
    _country = _countries.contains(player.country)
        ? player.country
        : 'Montenegro';
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.league.updateMyProfile(
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        birthDate: _birthDate,
        country: _country,
        sport: _sport,
        club: _club.text.trim(),
      );
      await widget.auth.refreshMe();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profil je sačuvan')));
      }
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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
    );
    if (file == null) return;

    setState(() => _uploading = true);
    try {
      await widget.league.uploadProfileImage(file);
      await widget.auth.refreshMe();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profilna slika je promijenjena')),
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.auth.currentPlayer;

    if (player == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      PlayerAvatar(player: player, api: widget.api, radius: 62),
                      IconButton.filled(
                        tooltip: 'Promijeni sliku',
                        onPressed: _uploading ? null : _pickImage,
                        icon: _uploading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.photo_camera),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    player.fullName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text('${player.email}  |  ${player.role}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Uredi profil',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _field(_firstName, 'Ime', Icons.person),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _field(_lastName, 'Prezime', Icons.badge),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AppSelectField(
                      label: 'Datum rođenja',
                      value: _birthYear.text,
                      icon: Icons.cake,
                      onTap: _pickBirthDate,
                    ),
                    const SizedBox(height: 12),
                    AppSelectField(
                      label: 'Država',
                      value: _country,
                      icon: Icons.flag,
                      onTap: () async {
                        final value = await showAppOptionPicker<String>(
                          context: context,
                          title: 'Država',
                          selected: _country,
                          options: _countries,
                          labelBuilder: (value) => value,
                        );
                        if (value != null) setState(() => _country = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    AppSelectField(
                      label: 'Sport',
                      value: _sportLabel(_sport),
                      icon: Icons.sports_tennis,
                      onTap: () async {
                        final value = await showAppOptionPicker<String>(
                          context: context,
                          title: 'Sport',
                          selected: _sport,
                          options: const ['tennis'],
                          labelBuilder: _sportLabel,
                        );
                        if (value != null) setState(() => _sport = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _club,
                      label: 'Klub',
                      hint: 'Individualni igrač / klub',
                      icon: Icons.shield,
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: const Text('Sačuvaj izmjene'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            color: AppTheme.ink,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.sports_tennis, color: AppTheme.lime),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${player.totalPoints} pts  |  ${player.wins}-${player.losses}  |  ${player.matchesPlayed} mečeva',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return AppTextField(
      controller: controller,
      label: label,
      icon: icon,
      keyboardType: keyboardType,
      validator:
          validator ??
          (value) =>
              value == null || value.trim().isEmpty ? 'Obavezno polje' : null,
    );
  }

  Future<void> _pickBirthDate() async {
    final picked = await showAppBirthDatePicker(
      context: context,
      initialDate: _birthDate,
      minimumAge: 5,
    );

    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _birthYear.text = _dateLabel(picked);
      });
    }
  }

  String _dateLabel(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  String _sportLabel(String value) {
    return switch (value) {
      'tennis' => 'Tenis',
      _ => value,
    };
  }
}
