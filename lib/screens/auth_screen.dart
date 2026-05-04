import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.auth});

  final AuthService auth;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  final _form = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _club = TextEditingController();
  late final AnimationController _logoController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoGlow;
  late final Animation<double> _logoRotation;
  bool _register = false;
  bool _busy = false;
  DateTime _dateOfBirth = DateTime(1995);
  String _country = 'Montenegro';
  String _sport = 'tennis';
  bool _resendingVerification = false;

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
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat(period: const Duration(milliseconds: 4600));
    _logoScale = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(1), weight: 34),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 1.12,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 18,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.12,
          end: 1,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 28,
      ),
      TweenSequenceItem(tween: ConstantTween(1), weight: 20),
    ]).animate(_logoController);
    _logoGlow = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(.22), weight: 34),
      TweenSequenceItem(
        tween: Tween(
          begin: .22,
          end: .72,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 18,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: .72,
          end: .22,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 28,
      ),
      TweenSequenceItem(tween: ConstantTween(.22), weight: 20),
    ]).animate(_logoController);
    _logoRotation = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0), weight: 32),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0,
          end: -0.035,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: -0.035,
          end: 0.035,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 16,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.035,
          end: 0,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 18,
      ),
      TweenSequenceItem(tween: ConstantTween(0), weight: 24),
    ]).animate(_logoController);
  }

  @override
  void dispose() {
    _logoController.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    _club.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);

    try {
      if (_register) {
        final data = await widget.auth.register({
          'firstName': _firstName.text.trim(),
          'lastName': _lastName.text.trim(),
          'email': _email.text.trim(),
          'password': _password.text,
          'birthDate': _dateOfBirth.toIso8601String(),
          'country': _country,
          'club': _club.text.trim().isEmpty ? 'Individual' : _club.text.trim(),
          'sport': _sport,
        });
        if (mounted) {
          final needsVerification = data['emailVerificationRequired'] == true;
          setState(() => _register = false);
          _showInfo(
            needsVerification
                ? 'Poslali smo ti email za potvrdu naloga. Otvori link, pa se prijavi.'
                : 'Nalog je kreiran. Možeš se prijaviti.',
          );
        }
      } else {
        await widget.auth.login(_email.text.trim(), _password.text);
      }
    } on ApiException catch (error) {
      if (mounted) _showAuthError(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resendVerification() async {
    final email = _email.text.trim();
    if (email.isEmpty || _resendingVerification) return;

    setState(() => _resendingVerification = true);
    try {
      await widget.auth.resendVerification(email);
      if (mounted) _showInfo('Poslali smo novi verification link.');
    } on ApiException catch (error) {
      if (mounted) _showInfo(error.message);
    } finally {
      if (mounted) setState(() => _resendingVerification = false);
    }
  }

  void _showAuthError(String message) {
    final needsVerification =
        message.toLowerCase().contains('potvrdi email') ||
        message.toLowerCase().contains('verify');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: needsVerification
            ? SnackBarAction(
                label: _resendingVerification ? 'Šaljem...' : 'Pošalji opet',
                onPressed: _resendVerification,
              )
            : null,
      ),
    );
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 18, 0, 22),
              child: Center(
                child: _AnimatedCoaLogo(
                  scale: _logoScale,
                  glow: _logoGlow,
                  rotation: _logoRotation,
                  size: 152,
                ),
              ),
            ),
            const SizedBox(height: 14),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Login')),
                ButtonSegment(value: true, label: Text('Register')),
              ],
              selected: {_register},
              onSelectionChanged: (value) =>
                  setState(() => _register = value.first),
            ),
            const SizedBox(height: 16),
            _AuthFormCard(
              register: _register,
              formKey: _form,
              firstName: _firstName,
              lastName: _lastName,
              email: _email,
              password: _password,
              phone: _phone,
              club: _club,
              country: _country,
              sport: _sport,
              countries: _countries,
              dateOfBirth: _dateOfBirth,
              busy: _busy,
              onCountryChanged: (value) => setState(() => _country = value),
              onSportChanged: (value) => setState(() => _sport = value),
              onPickBirthDate: _pickBirthDate,
              onSubmit: _submit,
              onSwitchToLogin: () => setState(() => _register = false),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth,
      firstDate: DateTime(now.year - 90),
      lastDate: DateTime(now.year - 8, 12, 31),
    );

    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }
}

class _AuthFormCard extends StatelessWidget {
  const _AuthFormCard({
    required this.register,
    required this.formKey,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.password,
    required this.phone,
    required this.club,
    required this.country,
    required this.sport,
    required this.countries,
    required this.dateOfBirth,
    required this.busy,
    required this.onCountryChanged,
    required this.onSportChanged,
    required this.onPickBirthDate,
    required this.onSubmit,
    required this.onSwitchToLogin,
  });

  final bool register;
  final GlobalKey<FormState> formKey;
  final TextEditingController firstName;
  final TextEditingController lastName;
  final TextEditingController email;
  final TextEditingController password;
  final TextEditingController phone;
  final TextEditingController club;
  final String country;
  final String sport;
  final List<String> countries;
  final DateTime dateOfBirth;
  final bool busy;
  final ValueChanged<String> onCountryChanged;
  final ValueChanged<String> onSportChanged;
  final VoidCallback onPickBirthDate;
  final VoidCallback onSubmit;
  final VoidCallback onSwitchToLogin;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.court.withValues(alpha: .10)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.ink.withValues(alpha: .06),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            children: [
              Container(
                height: 5,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.court, AppTheme.clay],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        register ? 'Registracija igrača' : 'Prijava',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        register
                            ? 'Napravi profil'
                            : 'Uđi u svoj teniski dashboard.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.ink.withValues(alpha: .62),
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (register) ...[
                        Row(
                          children: [
                            Expanded(
                              child: _field(
                                firstName,
                                'Ime',
                                icon: Icons.person,
                                validator: _required,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _field(
                                lastName,
                                'Prezime',
                                icon: Icons.badge,
                                validator: _required,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],
                      _field(
                        email,
                        'Email adresa',
                        icon: Icons.mail,
                        keyboardType: TextInputType.emailAddress,
                        validator: _emailValidator,
                      ),
                      const SizedBox(height: 14),
                      _field(
                        password,
                        'Password',
                        icon: Icons.lock,
                        obscure: true,
                        validator: _passwordValidator,
                      ),
                      if (register) ...[
                        const SizedBox(height: 14),
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: onPickBirthDate,
                          child: InputDecorator(
                            decoration: _decoration(
                              'Datum rođenja',
                              Icons.cake,
                            ),
                            child: Text(_dateLabel(dateOfBirth)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: country,
                          decoration: _decoration('Država', Icons.flag),
                          items: countries
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(item),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) onCountryChanged(value);
                          },
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: sport,
                          decoration: _decoration('Sport', Icons.sports_tennis),
                          items: const [
                            DropdownMenuItem(
                              value: 'tennis',
                              child: Text('Tenis'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) onSportChanged(value);
                          },
                        ),
                        const SizedBox(height: 14),
                        _field(
                          club,
                          'Klub',
                          hint: 'Individualni igrač / klub',
                          icon: Icons.shield,
                          required: false,
                        ),
                        const SizedBox(height: 14),
                        _field(
                          phone,
                          'Telefon',
                          hint: 'Nije obavezno',
                          icon: Icons.phone,
                          keyboardType: TextInputType.phone,
                          required: false,
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: busy ? null : onSubmit,
                          icon: busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.arrow_forward),
                          label: Text(register ? 'Registruj se' : 'Prijavi se'),
                        ),
                      ),
                      if (register) ...[
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton(
                            onPressed: onSwitchToLogin,
                            child: const Text('Već imaš nalog? Prijavi se'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Obavezno polje' : null;
  }

  static String? _emailValidator(String? value) {
    final text = value?.trim() ?? '';
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text);
    return valid ? null : 'Unesi validan email';
  }

  static String? _passwordValidator(String? value) {
    return (value ?? '').length >= 8 ? null : 'Minimum 8 karaktera';
  }

  static String _dateLabel(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  static InputDecoration _decoration(
    String label,
    IconData icon, {
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppTheme.court.withValues(alpha: .08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.court, width: 1.3),
      ),
    );
  }

  static Widget _field(
    TextEditingController controller,
    String label, {
    bool obscure = false,
    bool required = true,
    TextInputType? keyboardType,
    IconData? icon,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      decoration: _decoration(label, icon ?? Icons.edit, hint: hint),
      validator:
          validator ??
          (required
              ? (value) => value == null || value.trim().isEmpty
                    ? 'Obavezno polje'
                    : null
              : null),
    );
  }
}

class _AnimatedCoaLogo extends StatelessWidget {
  const _AnimatedCoaLogo({
    required this.scale,
    required this.glow,
    required this.rotation,
    this.size = 78,
  });

  final Animation<double> scale;
  final Animation<double> glow;
  final Animation<double> rotation;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: scale,
      builder: (context, child) {
        return Transform.rotate(
          angle: rotation.value,
          child: Transform.scale(
            scale: scale.value,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.clay.withValues(alpha: glow.value * .34),
                    blurRadius: 42,
                    spreadRadius: 5,
                  ),
                  BoxShadow(
                    color: AppTheme.court.withValues(alpha: glow.value * .30),
                    blurRadius: 34,
                    spreadRadius: 3,
                  ),
                  BoxShadow(
                    color: AppTheme.ink.withValues(alpha: .18),
                    blurRadius: 22,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/coa.png',
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
