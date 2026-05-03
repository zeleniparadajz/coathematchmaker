import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/player.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/league_service.dart';
import '../theme/app_theme.dart';
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

class _ProfileScreenState extends State<ProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _birthYear = TextEditingController();
  final _club = TextEditingController();
  bool _saving = false;
  bool _uploading = false;
  String _country = 'Montenegro';
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
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
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
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.photo_camera),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  player.fullName,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
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
                      Expanded(child: _field(_firstName, 'Ime', Icons.person)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(_lastName, 'Prezime', Icons.badge),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _field(
                    _birthYear,
                    'Datum rođenja',
                    Icons.cake,
                    readOnly: true,
                    onTap: _pickBirthDate,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _country,
                    decoration: const InputDecoration(
                      labelText: 'Država',
                      prefixIcon: Icon(Icons.flag),
                    ),
                    items: _countries
                        .map(
                          (country) => DropdownMenuItem(
                            value: country,
                            child: Text(country),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _country = value ?? _country),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _club,
                    decoration: const InputDecoration(
                      labelText: 'Klub',
                      hintText: 'Individualni igrač / klub',
                      prefixIcon: Icon(Icons.shield),
                    ),
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
                              child: CircularProgressIndicator(strokeWidth: 2),
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
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator:
          validator ??
          (value) =>
              value == null || value.trim().isEmpty ? 'Obavezno polje' : null,
    );
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate,
      firstDate: DateTime(now.year - 90),
      lastDate: DateTime(now.year - 5, 12, 31),
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
}
