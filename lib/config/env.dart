class Env {
  static const bool dev = false;

  static String get apiUrl {
    return dev ? "http://localhost:4000" : "http://161.97.74.146:4000";
  }
}
