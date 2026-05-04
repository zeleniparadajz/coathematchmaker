import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.icon,
    this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final String? hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      maxLines: maxLines,
      decoration: appInputDecoration(label, icon ?? Icons.edit, hint: hint),
    );
  }
}

class AppSelectField extends StatelessWidget {
  const AppSelectField({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.court.withValues(alpha: .035),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: InputDecorator(
          decoration: appInputDecoration(label, icon),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down,
                color: AppTheme.ink.withValues(alpha: .58),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

InputDecoration appInputDecoration(
  String label,
  IconData icon, {
  String? hint,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: Icon(icon, size: 22),
    filled: true,
    fillColor: AppTheme.court.withValues(alpha: .035),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: AppTheme.ink.withValues(alpha: .08)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppTheme.court, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppTheme.clay, width: 1.2),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppTheme.clay, width: 1.4),
    ),
  );
}

Future<T?> showAppOptionPicker<T>({
  required BuildContext context,
  required String title,
  required T selected,
  required List<T> options,
  required String Function(T value) labelBuilder,
  Widget Function(T value)? leadingBuilder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _OptionPickerSheet<T>(
      title: title,
      selected: selected,
      options: options,
      labelBuilder: labelBuilder,
      leadingBuilder: leadingBuilder,
    ),
  );
}

Future<String?> showAppLocationPicker({
  required BuildContext context,
  required String initialValue,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _LocationPickerSheet(initialValue: initialValue),
  );
}

Future<DateTime?> showAppBirthDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  int minimumAge = 8,
}) {
  final now = DateTime.now();
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BirthDatePickerSheet(
      initialDate: initialDate,
      firstYear: now.year - 90,
      lastYear: now.year - minimumAge,
    ),
  );
}

class _OptionPickerSheet<T> extends StatelessWidget {
  const _OptionPickerSheet({
    required this.title,
    required this.selected,
    required this.options,
    required this.labelBuilder,
    this.leadingBuilder,
  });

  final String title;
  final T selected;
  final List<T> options;
  final String Function(T value) labelBuilder;
  final Widget Function(T value)? leadingBuilder;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * .78,
      ),
      decoration: const BoxDecoration(
        color: Color(0xfff7faf4),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.ink.withValues(alpha: .16),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                itemCount: options.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final value = options[index];
                  final active = value == selected;
                  return ListTile(
                    leading: leadingBuilder?.call(value),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    tileColor: active
                        ? AppTheme.court.withValues(alpha: .10)
                        : Colors.white,
                    title: Text(
                      labelBuilder(value),
                      style: TextStyle(
                        fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                        letterSpacing: 0,
                      ),
                    ),
                    trailing: active
                        ? const Icon(Icons.check_circle, color: AppTheme.court)
                        : null,
                    onTap: () => Navigator.of(context).pop(value),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationPickerSheet extends StatefulWidget {
  const _LocationPickerSheet({required this.initialValue});

  final String initialValue;

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  late final TextEditingController _query = TextEditingController(
    text: widget.initialValue,
  );

  static const _suggestions = [
    'Teniski klub Eminent, Podgorica',
    'SC Morača, Podgorica',
    'Tennis Club As, Podgorica',
    'Teniski tereni Topolica, Bar',
    'Teniski klub Budva',
    'Teniski klub Herceg Novi',
    'Teniski klub Nikšić',
    'Tereni pod Goricom',
    'Sportski centar Igalo',
    'Ada Ciganlija, Beograd',
    'Teniski centar Novak, Beograd',
    'TK Partizan, Beograd',
  ];

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _suggestions
        : _suggestions
              .where((item) => item.toLowerCase().contains(query))
              .toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * .82,
      ),
      decoration: const BoxDecoration(
        color: Color(0xfff7faf4),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 10,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.ink.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Lokacija',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              AppTextField(
                controller: _query,
                label: 'Pretraži ili ukucaj lokaciju',
                icon: Icons.place,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _query.text.trim().isEmpty
                      ? null
                      : () => Navigator.of(context).pop(_query.text.trim()),
                  icon: const Icon(Icons.check),
                  label: const Text('Koristi ovu lokaciju'),
                ),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final value = filtered[index];
                    return ListTile(
                      leading: const Icon(Icons.location_on_outlined),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      tileColor: Colors.white,
                      title: Text(
                        value,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onTap: () => Navigator.of(context).pop(value),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
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
      decoration: appInputDecoration(label, Icons.expand_more),
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
