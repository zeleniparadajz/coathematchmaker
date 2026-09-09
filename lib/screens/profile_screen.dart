import 'package:coathematchmaker/l10n/app_strings.dart';
import '../l10n/app_language.dart';
import '../widgets/player_activity.dart';
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

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key, required this.auth});

  final AuthService auth;

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _confirm = TextEditingController();
  bool _deleting = false;

  bool get _canDelete => _confirm.text.trim().toUpperCase() == 'DELETE';

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _deleteAccount() async {
    if (!_canDelete || _deleting) return;

    setState(() => _deleting = true);
    try {
      await widget.auth.deleteAccount();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr("Nalog je obrisan."))),
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.serverMessage(error.message))),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.auth.currentPlayer;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr("Brisanje naloga"))),
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
                      CircleAvatar(
                        backgroundColor: AppTheme.clay.withValues(alpha: .18),
                        child: const Icon(
                          Icons.delete_forever_outlined,
                          color: AppTheme.clay,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.tr("Trajno obriši nalog"),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.tr(
                      "Ova akcija uklanja lične podatke profila, email, profilnu sliku i onemogućava buduću prijavu na nalog.",
                    ),
                    style: TextStyle(
                      color: AppTheme.ink.withValues(alpha: .68),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.tr(
                      "Istorija lige, mečevi i turniri mogu ostati prikazani bez tvojih ličnih podataka kako bi rezultati drugih igrača ostali tačni.",
                    ),
                    style: TextStyle(
                      color: AppTheme.ink.withValues(alpha: .58),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (player != null)
            Card(
              child: ListTile(
                leading: PlayerAvatar(player: player, api: widget.auth.api),
                title: Text(
                  player.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(player.email),
              ),
            ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr("Za potvrdu upiši DELETE"),
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  AppTextField(
                    controller: _confirm,
                    label: context.tr("Potvrda"),
                    hint: 'DELETE',
                    icon: Icons.verified_user_outlined,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.clay,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _canDelete && !_deleting
                          ? _deleteAccount
                          : null,
                      icon: _deleting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_forever),
                      label: Text(context.tr("Obriši nalog")),
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
}

class _PlayStatusScreenState extends State<PlayStatusScreen> {
  bool _saving = false;

  Future<void> _setStatus(String status) async {
    setState(() => _saving = true);
    try {
      await widget.league.updateMyPlayStatus(status);
      await widget.auth.refreshMe();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr("Status je promijenjen"))),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    final player = widget.auth.currentPlayer;
    final status = player?.playStatus ?? 'available';

    return Scaffold(
      appBar: AppBar(title: Text(context.tr("Status"))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (player?.unavailableDueToInactivity == true)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(context.tr('Nedostupan zbog neaktivnosti')),
            ),
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
                          context.tr("Ko smije da te zove na meč?"),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.tr(
                      "Ovo nije status naloga. Nalog ostaje aktivan, a ovdje samo biraš da li želiš da te drugi igrači pozivaju na mečeve.",
                    ),
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
            title: context.tr("Aktivan"),
            subtitle: context.tr(
              "Dostupan si za izazove i dogovore o terminu meča.",
            ),
            onTap: () => _setStatus('available'),
          ),
          const SizedBox(height: 10),
          _PlayStatusOption(
            selected: status == 'unavailable',
            saving: _saving,
            icon: Icons.do_not_disturb_on_outlined,
            title: context.tr("Neaktivan"),
            subtitle: context.tr(
              "Drugi igrači vide da trenutno ne želiš pozive za meč. Profil i nalog ostaju normalno aktivni.",
            ),
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

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector();

  @override
  Widget build(BuildContext context) {
    final controller = AppLanguageScope.maybeOf(context);
    if (controller == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.language),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr('Jezik aplikacije'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<AppLanguage>(
              key: const ValueKey('profile-language'),
              segments: const [
                ButtonSegment(value: AppLanguage.mne, label: Text('MNE')),
                ButtonSegment(value: AppLanguage.eng, label: Text('ENG')),
              ],
              selected: {controller.language},
              onSelectionChanged: controller.saving
                  ? null
                  : (selection) async {
                      try {
                        await controller.select(selection.single);
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                context.tr(
                                  'Izbor jezika nije sačuvan. Pokušaj ponovo.',
                                ),
                              ),
                            ),
                          );
                        }
                      }
                    },
            ),
          ),
        ],
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
  final _city = TextEditingController();
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
    _city.dispose();
    super.dispose();
  }

  void _syncPlayer(Player? player) {
    if (player == null) return;
    _firstName.text = player.firstName;
    _lastName.text = player.lastName;
    _birthDate = player.birthDate;
    _birthYear.text = _dateLabel(player.birthDate);
    _club.text = player.club ?? '';
    _city.text = player.city ?? '';
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
        city: _city.text.trim(),
      );
      await widget.auth.refreshMe();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr("Profil je sačuvan"))),
        );
      }
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
          SnackBar(content: Text(context.tr("Profilna slika je promijenjena"))),
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.serverMessage(error.message))),
        );
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
      appBar: AppBar(title: Text(context.tr("Profil"))),
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
                      PlayerAvatar(
                        player: player,
                        api: widget.api,
                        radius: 62,
                        allowPreview: true,
                      ),
                      IconButton.filled(
                        tooltip: context.tr("Promijeni sliku"),
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
                  Text(player.email),
                  if (player.isAdmin) Text(context.tr("Administrator")),
                  const SizedBox(height: 8),
                  PlayerActivity(lastActiveAt: player.lastActiveAt),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const _LanguageSelector(),
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
                      context.tr("Uredi profil"),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final fields = [
                          _field(_firstName, context.tr("Ime"), Icons.person),
                          _field(_lastName, context.tr("Prezime"), Icons.badge),
                        ];
                        if (constraints.maxWidth < 300 ||
                            MediaQuery.textScalerOf(context).scale(1) > 1.25) {
                          return Column(
                            children: [
                              fields[0],
                              const SizedBox(height: 12),
                              fields[1],
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: fields[0]),
                            const SizedBox(width: 12),
                            Expanded(child: fields[1]),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    AppSelectField(
                      label: context.tr("Datum rođenja"),
                      value: _birthYear.text,
                      icon: Icons.cake,
                      onTap: _pickBirthDate,
                    ),
                    const SizedBox(height: 12),
                    AppSelectField(
                      label: context.tr("Država"),
                      value: _country,
                      icon: Icons.flag,
                      onTap: () async {
                        final value = await showAppOptionPicker<String>(
                          context: context,
                          title: context.tr("Država"),
                          selected: _country,
                          options: _countries,
                          labelBuilder: (value) => value,
                        );
                        if (value != null) setState(() => _country = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    AppSelectField(
                      label: context.tr("Sport"),
                      value: _sportLabel(_sport),
                      icon: Icons.sports_tennis,
                      onTap: () async {
                        final value = await showAppOptionPicker<String>(
                          context: context,
                          title: context.tr("Sport"),
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
                      label: context.tr("Klub"),
                      hint: context.tr("Individualni igrač / klub"),
                      icon: Icons.shield,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _city,
                      label: context.tr("Grad"),
                      icon: Icons.location_city,
                      validator: (value) => (value?.length ?? 0) > 100
                          ? context.tr("Najviše 100 znakova.")
                          : null,
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
                        label: Text(context.tr("Sačuvaj izmjene")),
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
                      context.tr("{p0} poena  |  {p1}-{p2}  |  {p3} mečeva", [
                        player.totalPoints,
                        player.wins,
                        player.losses,
                        player.matchesPlayed,
                      ]),
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
          (value) => value == null || value.trim().isEmpty
              ? context.tr("Obavezno polje")
              : null,
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
      'tennis' => context.tr("Tenis"),
      _ => value,
    };
  }
}
