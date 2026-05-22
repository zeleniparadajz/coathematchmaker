import 'dart:io';

class Env {
  static const bool dev = false;
  static const String productionApiUrl = String.fromEnvironment(
    "API_URL",
    defaultValue: "https://coabackapi.zeleniparadajz.me",
  );
  static const int appBuildNumber = int.fromEnvironment(
    "APP_BUILD_NUMBER",
    defaultValue: 6,
  );

  static String get platform {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'unknown';
  }

  static String get apiUrl {
    return dev ? "http://localhost:4000" : productionApiUrl;
  }
}
