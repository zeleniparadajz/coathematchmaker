import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_form_fields.dart';

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
  bool _sendingPasswordReset = false;

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

  Future<void> _forgotPassword() async {
    if (_sendingPasswordReset) return;
    final email = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ForgotPasswordSheet(initialEmail: _email.text.trim()),
    );
    if (email == null || email.isEmpty) return;

    setState(() => _sendingPasswordReset = true);
    try {
      await widget.auth.forgotPassword(email);
      if (mounted) {
        _showInfo('Ako nalog postoji, poslali smo email za reset passworda.');
      }
    } on ApiException catch (error) {
      if (mounted) _showInfo(error.message);
    } finally {
      if (mounted) setState(() => _sendingPasswordReset = false);
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
              onPickBirthDate: () => _pickBirthDate(context),
              onSubmit: _submit,
              onForgotPassword: _forgotPassword,
              onSwitchToLogin: () => setState(() => _register = false),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickBirthDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BirthDatePickerSheet(
        initialDate: _dateOfBirth,
        firstYear: now.year - 90,
        lastYear: now.year - 8,
      ),
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
    required this.onForgotPassword,
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
  final VoidCallback onForgotPassword;
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
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
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
                      const SizedBox(height: 20),
                      if (register) ...[
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 360;
                            final fields = [
                              _field(
                                firstName,
                                'Ime',
                                icon: Icons.person,
                                validator: _required,
                              ),
                              _field(
                                lastName,
                                'Prezime',
                                icon: Icons.badge,
                                validator: _required,
                              ),
                            ];

                            if (compact) {
                              return Column(
                                children: [
                                  fields[0],
                                  const SizedBox(height: 14),
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
                        AppSelectField(
                          label: 'Datum rođenja',
                          value: _dateLabel(dateOfBirth),
                          icon: Icons.cake,
                          onTap: onPickBirthDate,
                        ),
                        const SizedBox(height: 14),
                        AppSelectField(
                          label: 'Država',
                          value: country,
                          icon: Icons.flag,
                          onTap: () async {
                            final value = await _pickStringOption(
                              context: context,
                              title: 'Država',
                              selected: country,
                              options: countries,
                            );
                            if (value != null) onCountryChanged(value);
                          },
                        ),
                        const SizedBox(height: 14),
                        AppSelectField(
                          label: 'Sport',
                          value: _sportLabel(sport),
                          icon: Icons.sports_tennis,
                          onTap: () async {
                            final value = await _pickStringOption(
                              context: context,
                              title: 'Sport',
                              selected: sport,
                              options: const ['tennis'],
                              labelBuilder: _sportLabel,
                            );
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
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
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
                      ] else ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: onForgotPassword,
                            child: const Text('Zaboravljen password?'),
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

  static Future<String?> _pickStringOption({
    required BuildContext context,
    required String title,
    required String selected,
    required List<String> options,
    String Function(String value)? labelBuilder,
  }) {
    return showAppOptionPicker<String>(
      context: context,
      title: title,
      selected: selected,
      options: options,
      labelBuilder: labelBuilder ?? (value) => value,
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

  static String _sportLabel(String value) {
    return switch (value) {
      'tennis' => 'Tenis',
      _ => value,
    };
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
    return AppTextField(
      controller: controller,
      label: label,
      icon: icon ?? Icons.edit,
      obscureText: obscure,
      keyboardType: keyboardType,
      hint: hint,
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

class _BirthDatePickerSheet extends StatefulWidget {
  const _BirthDatePickerSheet({
    required this.initialDate,
    required this.firstYear,
    required this.lastYear,
  });

  final DateTime initialDate;
  final int firstYear;
  final int lastYear;

  @override
  State<_BirthDatePickerSheet> createState() => _BirthDatePickerSheetState();
}

class _ForgotPasswordSheet extends StatefulWidget {
  const _ForgotPasswordSheet({required this.initialEmail});

  final String initialEmail;

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _email = TextEditingController(
    text: widget.initialEmail,
  );

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    Navigator.of(context).pop(_email.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xfff7faf4),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            10,
            18,
            MediaQuery.of(context).viewInsets.bottom + 18,
          ),
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.ink.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Reset passworda',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  'Upiši email naloga. Poslaćemo link za novi password.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.ink.withValues(alpha: .62),
                  ),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _email,
                  label: 'Email adresa',
                  icon: Icons.mail,
                  keyboardType: TextInputType.emailAddress,
                  validator: _AuthFormCard._emailValidator,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.mark_email_read),
                    label: const Text('Pošalji reset link'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BirthDatePickerSheetState extends State<_BirthDatePickerSheet> {
  late int _day = widget.initialDate.day;
  late int _month = widget.initialDate.month;
  late int _year = widget.initialDate.year.clamp(
    widget.firstYear,
    widget.lastYear,
  );

  static const _months = [
    'Januar',
    'Februar',
    'Mart',
    'April',
    'Maj',
    'Jun',
    'Jul',
    'Avgust',
    'Septembar',
    'Oktobar',
    'Novembar',
    'Decembar',
  ];

  int get _daysInMonth => DateTime(_year, _month + 1, 0).day;

  @override
  Widget build(BuildContext context) {
    if (_day > _daysInMonth) {
      _day = _daysInMonth;
    }

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xfff7faf4),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.ink.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Datum rođenja',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _pickerDropdown<int>(
                      label: 'Dan',
                      value: _day,
                      values: List.generate(_daysInMonth, (index) => index + 1),
                      labelFor: (value) => value.toString().padLeft(2, '0'),
                      onChanged: (value) => setState(() => _day = value),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: _pickerDropdown<int>(
                      label: 'Mjesec',
                      value: _month,
                      values: List.generate(12, (index) => index + 1),
                      labelFor: (value) => _months[value - 1],
                      onChanged: (value) => setState(() => _month = value),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _pickerDropdown<int>(
                      label: 'Godina',
                      value: _year,
                      values: [
                        for (
                          var year = widget.lastYear;
                          year >= widget.firstYear;
                          year--
                        )
                          year,
                      ],
                      labelFor: (value) => value.toString(),
                      onChanged: (value) => setState(() => _year = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pop(DateTime(_year, _month, _day)),
                  child: const Text('Sačuvaj datum'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pickerDropdown<T>({
    required String label,
    required T value,
    required List<T> values,
    required String Function(T value) labelFor,
    required ValueChanged<T> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      items: values
          .map(
            (item) => DropdownMenuItem<T>(
              value: item,
              child: Text(labelFor(item), overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
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
