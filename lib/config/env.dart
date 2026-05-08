class Env {
  static const bool dev = false;
  static const String productionApiUrl = String.fromEnvironment(
    "API_URL",
    defaultValue: "http://161.97.74.146:4000",
  );
  static const int appBuildNumber = int.fromEnvironment(
    "APP_BUILD_NUMBER",
    defaultValue: 2,
  );

  static String get apiUrl {
    return dev ? "http://localhost:4000" : productionApiUrl;
  }
}
