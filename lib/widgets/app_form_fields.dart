import 'package:coathematchmaker/l10n/app_strings.dart';
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
      errorBuilder: (context, error) => Text(
        context.serverMessage(error),
        style: TextStyle(
          color: Theme.of(context).colorScheme.error,
          fontSize: 12,
        ),
      ),
      onChanged: onChanged,
      maxLines: maxLines,
      decoration: appInputDecoration(
        context,
        label,
        icon ?? Icons.edit,
        hint: hint,
      ),
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
          decoration: appInputDecoration(context, label, icon),
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
  BuildContext context,
  String label,
  IconData icon, {
  String? hint,
}) {
  return InputDecoration(
    labelText: context.tr(label),
    hintText: hint == null ? null : context.tr(hint),
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
    builder: (context) => _BirthDatePickerSheet(
      initialDate: initialDate,
      firstYear: now.year - 90,
      lastYear: now.year - minimumAge,
    ),
  );
}

Future<DateTime?> showAppDateTimePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String title = 'Datum i vrijeme',
  String actionLabel = 'Sačuvaj termin',
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _DateTimePickerSheet(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      title: title,
      actionLabel: actionLabel,
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
                      context.tr(title),
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
                context.tr("Datum rođenja"),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _pickerDropdown<int>(
                      label: context.tr("Dan"),
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
                      label: context.tr("Mjesec"),
                      value: _month,
                      values: List.generate(12, (index) => index + 1),
                      labelFor: (value) => context.tr(_months[value - 1]),
                      onChanged: (value) => setState(() => _month = value),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _pickerDropdown<int>(
                      label: context.tr("Godina"),
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
                  child: Text(context.tr("Sačuvaj datum")),
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
      decoration: appInputDecoration(context, label, Icons.expand_more),
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

class _DateTimePickerSheet extends StatefulWidget {
  const _DateTimePickerSheet({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.title,
    required this.actionLabel,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final String title;
  final String actionLabel;

  @override
  State<_DateTimePickerSheet> createState() => _DateTimePickerSheetState();
}

class _DateTimePickerSheetState extends State<_DateTimePickerSheet> {
  late final DateTime _first = _dateOnly(widget.firstDate);
  late final DateTime _last = _dateOnly(widget.lastDate);
  late final DateTime _initial = _clampDateTime(widget.initialDate);
  late int _day = _initial.day;
  late int _month = _initial.month;
  late int _year = _initial.year;
  late int _hour = _initial.hour;
  late int _minute = (_initial.minute ~/ 5) * 5;

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

  List<int> get _years => [
    for (var year = _first.year; year <= _last.year; year++) year,
  ];

  List<int> get _monthsForYear {
    final start = _year == _first.year ? _first.month : 1;
    final end = _year == _last.year ? _last.month : 12;
    return [for (var month = start; month <= end; month++) month];
  }

  List<int> get _daysForMonth {
    final currentMonthDays = _daysInMonth;
    final start = _year == _first.year && _month == _first.month
        ? _first.day
        : 1;
    final end = _year == _last.year && _month == _last.month
        ? _last.day
        : currentMonthDays;
    return [for (var day = start; day <= end; day++) day];
  }

  @override
  Widget build(BuildContext context) {
    _normalizeParts();

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
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppTheme.court.withValues(alpha: .12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.event_available,
                      color: AppTheme.court,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr(widget.title),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _previewLabel,
                          style: TextStyle(
                            color: AppTheme.ink.withValues(alpha: .58),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _pickerDropdown<int>(
                      label: context.tr("Dan"),
                      value: _day,
                      values: _daysForMonth,
                      labelFor: (value) => value.toString().padLeft(2, '0'),
                      onChanged: (value) => setState(() => _day = value),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: _pickerDropdown<int>(
                      label: context.tr("Mjesec"),
                      value: _month,
                      values: _monthsForYear,
                      labelFor: (value) => context.tr(_months[value - 1]),
                      onChanged: (value) => setState(() => _month = value),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _pickerDropdown<int>(
                      label: context.tr("Godina"),
                      value: _year,
                      values: _years,
                      labelFor: (value) => value.toString(),
                      onChanged: (value) => setState(() => _year = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _pickerDropdown<int>(
                      label: context.tr("Sat"),
                      value: _hour,
                      values: List.generate(24, (index) => index),
                      labelFor: (value) => value.toString().padLeft(2, '0'),
                      onChanged: (value) => setState(() => _hour = value),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _pickerDropdown<int>(
                      label: context.tr("Minut"),
                      value: _minute,
                      values: List.generate(60, (index) => index),
                      labelFor: (value) => value.toString().padLeft(2, '0'),
                      onChanged: (value) => setState(() => _minute = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(_selected),
                  icon: const Icon(Icons.check),
                  label: Text(context.tr(widget.actionLabel)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  DateTime get _selected =>
      _clampDateTime(DateTime(_year, _month, _day, _hour, _minute));

  String get _previewLabel {
    final selected = _selected;
    final day = selected.day.toString().padLeft(2, '0');
    final month = selected.month.toString().padLeft(2, '0');
    final hour = selected.hour.toString().padLeft(2, '0');
    final minute = selected.minute.toString().padLeft(2, '0');
    return context.tr("{p0}.{p1}.{p2} u {p3}:{p4}", [
      day,
      month,
      selected.year,
      hour,
      minute,
    ]);
  }

  void _normalizeParts() {
    if (!_years.contains(_year)) _year = _years.first;
    if (!_monthsForYear.contains(_month)) _month = _monthsForYear.first;
    if (_day > _daysInMonth) _day = _daysInMonth;
    if (!_daysForMonth.contains(_day)) _day = _daysForMonth.first;
    final clamped = _selected;
    _year = clamped.year;
    _month = clamped.month;
    _day = clamped.day;
    _hour = clamped.hour;
    _minute = clamped.minute;
  }

  DateTime _clampDateTime(DateTime value) {
    final min = widget.firstDate;
    final max = widget.lastDate;
    if (value.isBefore(min)) return min;
    if (value.isAfter(max)) return max;
    return value;
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
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
      decoration: appInputDecoration(context, label, Icons.expand_more),
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
