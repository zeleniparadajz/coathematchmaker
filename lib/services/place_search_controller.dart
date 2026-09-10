import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/app_location.dart';
import 'api_client.dart';
import 'league_service.dart';

class PlaceSearchController extends ChangeNotifier {
  PlaceSearchController(this.league);
  final LeagueService league;
  Timer? _timer;
  int _generation = 0;
  bool _disposed = false;
  String query = '';
  String language = 'sr';
  String sessionToken = _token();
  bool loading = false;
  bool searched = false;
  String? error;
  List<GooglePlaceResult> results = [];

  static String _token() {
    final random = Random.secure();
    return base64Url.encode(List.generate(24, (_) => random.nextInt(256)));
  }

  void newSession() => sessionToken = _token();

  void update(String value, {bool immediate = false}) {
    _timer?.cancel();
    final generation = ++_generation;
    query = value.trim();
    results = [];
    error = null;
    searched = false;
    loading = query.length >= 3;
    if (query.isEmpty) newSession();
    notifyListeners();
    if (!loading) return;
    if (immediate) {
      unawaited(_search(generation));
    } else {
      _timer = Timer(
        const Duration(milliseconds: 400),
        () => _search(generation),
      );
    }
  }

  Future<void> _search(int generation) async {
    try {
      final found = await league.autocompletePlaces(
        query,
        sessionToken,
        language: language,
      );
      if (!_disposed && generation == _generation) results = found;
    } on ApiException catch (failure) {
      if (!_disposed && generation == _generation) error = failure.message;
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        searched = true;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
