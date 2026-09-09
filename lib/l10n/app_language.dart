import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage {
  mne('mne', 'MNE', Locale.fromSubtags(languageCode: 'sr', scriptCode: 'Latn')),
  eng('en', 'ENG', Locale('en'));

  const AppLanguage(this.code, this.label, this.locale);
  final String code;
  final String label;
  final Locale locale;
}

class AppLanguageController extends ChangeNotifier {
  static const preferenceKey = 'app_language';
  AppLanguage _language = AppLanguage.mne;
  bool _saving = false;
  bool _disposed = false;
  AppLanguage get language => _language;
  bool get saving => _saving;

  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _language = prefs.getString(preferenceKey) == 'en'
          ? AppLanguage.eng
          : AppLanguage.mne;
    } catch (_) {
      _language = AppLanguage.mne;
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> select(AppLanguage value) async {
    if (_saving || value == _language) return;
    _saving = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(preferenceKey, value.code)) {
        throw StateError('Language preference was not saved');
      }
      _language = value;
    } finally {
      _saving = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class AppLanguageScope extends InheritedNotifier<AppLanguageController> {
  const AppLanguageScope({
    super.key,
    required AppLanguageController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppLanguageController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppLanguageScope>()?.notifier;
}
