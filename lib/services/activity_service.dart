import 'dart:async';
import 'package:flutter/widgets.dart';
import 'auth_service.dart';

class AppActivityTracker with WidgetsBindingObserver {
  AppActivityTracker(this.auth);
  final AuthService auth;
  Timer? _timer;
  bool _started = false;
  bool _foreground = false;
  bool _sending = false;

  void start() {
    if (_started) return;
    _started = true;
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    auth.addListener(_sync);
    _sync();
  }

  void _sync() {
    if (!_started || !_foreground || !auth.isLoggedIn) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    if (_timer != null) return;
    _send();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _send());
  }

  Future<void> _send() async {
    if (_sending || !_started || !_foreground || !auth.isLoggedIn) return;
    _sending = true;
    try {
      await auth.api.postJson('/api/players/me/activity', {});
    } catch (_) {
      // Retry on the next foreground tick; an offline visit is not server activity.
    } finally {
      _sending = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  void dispose() {
    _started = false;
    _timer?.cancel();
    _timer = null;
    auth.removeListener(_sync);
    WidgetsBinding.instance.removeObserver(this);
  }
}
