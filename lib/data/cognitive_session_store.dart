import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/cognitive_session.dart';

class CognitiveSessionStore extends ChangeNotifier {
  CognitiveSessionStore._();

  static final CognitiveSessionStore instance =
  CognitiveSessionStore._();

  static const String _storageKey = 'smriti_cognitive_sessions';

  final List<CognitiveSession> _sessions = [];
  bool _initialized = false;

  List<CognitiveSession> get sessions =>
      List.unmodifiable(_sessions);

  Future<void> initialize() async {
    if (_initialized) return;

    final prefs = SharedPreferencesAsync();

    try {
      final raw = await prefs.getString(_storageKey);

      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);

        if (decoded is List) {
          _sessions
            ..clear()
            ..addAll(
              decoded.whereType<Map>().map(
                    (item) => CognitiveSession.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              ),
            );
        }
      }
    } catch (_) {
      _sessions.clear();
    }

    _initialized = true;
    notifyListeners();
  }

  Future<void> addSession(CognitiveSession session) async {
    await initialize();

    _sessions.insert(0, session);
    await _save();
    notifyListeners();
  }

  List<CognitiveSession> sessionsForGame(String gameId) {
    return _sessions
        .where((session) => session.gameId == gameId)
        .toList();
  }

  Future<void> _save() async {
    final prefs = SharedPreferencesAsync();

    await prefs.setString(
      _storageKey,
      jsonEncode(
        _sessions.map((session) => session.toJson()).toList(),
      ),
    );
  }
}
