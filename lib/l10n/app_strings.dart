import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'english.dart';
import 'server_aliases.dart';

class AppStrings {
  const AppStrings(this.locale);
  final Locale locale;
  bool get isEnglish => locale.languageCode == 'en';
  static const delegate = _AppStringsDelegate();
  static const supportedLocales = [
    Locale.fromSubtags(languageCode: 'sr', scriptCode: 'Latn'),
    Locale('en'),
  ];

  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings) ??
      const AppStrings(Locale('sr'));

  String text(String source, [List<Object?> arguments = const []]) {
    final translated = isEnglish ? englishMessages[source] ?? source : source;
    // Only placeholders in the template are replaced, never text in user data.
    return translated.replaceAllMapped(RegExp(r'\{p(\d+)\}'), (match) {
      final index = int.parse(match[1]!);
      return index < arguments.length ? '${arguments[index]}' : match[0]!;
    });
  }

  String serverMessage(String source) {
    source = serverMessageAliases[source] ?? source;
    if (!isEnglish) {
      for (final entry in englishMessages.entries) {
        if (entry.value == source) return entry.key;
      }
      return source;
    }
    final exact = englishMessages[source];
    if (exact != null) return exact;
    for (final template in _serverTemplates) {
      final match = template.pattern.firstMatch(source);
      if (match != null) {
        return text(template.source, [
          for (var i = 1; i <= match.groupCount; i++) match.group(i),
        ]);
      }
    }
    if (englishMessages.containsValue(source)) return source;
    return 'Something went wrong. Please try again.';
  }

  static final _serverTemplates = englishMessages.keys
      .where((source) => source.contains(RegExp(r'\{p\d+\}')))
      .map(_MessageTemplate.new)
      .toList();
}

class _MessageTemplate {
  _MessageTemplate(this.source)
    : pattern = RegExp(
        '^${source.split(RegExp(r'\{p\d+\}')).map(RegExp.escape).join('([\\s\\S]*?)')}\$',
      );
  final String source;
  final RegExp pattern;
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();
  @override
  bool isSupported(Locale locale) => ['sr', 'en'].contains(locale.languageCode);
  @override
  Future<AppStrings> load(Locale locale) =>
      SynchronousFuture(AppStrings(locale));
  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}

extension AppTranslation on BuildContext {
  String tr(String source, [List<Object?> arguments = const []]) =>
      AppStrings.of(this).text(source, arguments);
  String serverMessage(String source) =>
      AppStrings.of(this).serverMessage(source);
}
