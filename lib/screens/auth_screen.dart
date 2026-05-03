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
  bool _register = false;
  bool _busy = false;
  DateTime _dateOfBirth = DateTime(1995);
  String _country = 'Montenegro';

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
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true, period: const Duration(milliseconds: 6200));
    _logoScale = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(1), weight: 48),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 1.045,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.045,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 20,
      ),
      TweenSequenceItem(tween: ConstantTween(1), weight: 12),
    ]).animate(_logoController);
    _logoGlow = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(.22), weight: 48),
      TweenSequenceItem(
        tween: Tween(
          begin: .22,
          end: .48,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: .48,
          end: .22,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
      TweenSequenceItem(tween: ConstantTween(.22), weight: 12),
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
        await widget.auth.register({
          'firstName': _firstName.text.trim(),
          'lastName': _lastName.text.trim(),
          'email': _email.text.trim(),
          'password': _password.text,
          'birthDate': _dateOfBirth.toIso8601String(),
          'country': _country,
          'club': _club.text.trim().isEmpty ? 'Individual' : _club.text.trim(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Provjeri email i potvrdi nalog.')),
          );
        }
      } else {
        await widget.auth.login(_email.text.trim(), _password.text);
      }
    } on ApiException catch (error) {
      if (mounted) _showError(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
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
                  size: 122,
                ),
              ),
            ),
            const SizedBox(height: 22),
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
              countries: _countries,
              dateOfBirth: _dateOfBirth,
              busy: _busy,
              onCountryChanged: (value) => setState(() => _country = value),
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
    required this.countries,
    required this.dateOfBirth,
    required this.busy,
    required this.onCountryChanged,
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
  final List<String> countries;
  final DateTime dateOfBirth;
  final bool busy;
  final ValueChanged<String> onCountryChanged;
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
    this.size = 78,
  });

  final Animation<double> scale;
  final Animation<double> glow;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: scale,
      builder: (context, child) {
        return Transform.scale(
          scale: scale.value,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.ink.withValues(alpha: glow.value * .45),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: AppTheme.ink.withValues(alpha: .16),
                  blurRadius: 18,
                  offset: const Offset(0, 12),
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
        );
      },
    );
  }
}
