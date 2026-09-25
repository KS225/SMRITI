import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/memory_chain.dart';

class MemoryChainStore extends ChangeNotifier {
  MemoryChainStore._();

  static final MemoryChainStore instance = MemoryChainStore._();

  static const String _storageKey = 'smriti_memory_chains_v1';

  final List<MemoryChain> _chains = [];
  bool _initialized = false;
  Future<void>? _initializationFuture;

  List<MemoryChain> get chains => List.unmodifiable(_chains);

  Future<void> initialize() {
    if (_initialized) return Future.value();
    return _initializationFuture ??= _load();
  }

  Future<void> _load() async {
    final prefs = SharedPreferencesAsync();
    try {
      final raw = await prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _chains
            ..clear()
            ..addAll(
              decoded.whereType<Map>().map(
                    (item) => MemoryChain.fromJson(
                      Map<String, dynamic>.from(item),
                    ),
                  ),
            );
        }
      }
    } catch (_) {
      _chains.clear();
    }

    _initialized = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = SharedPreferencesAsync();
    await prefs.setString(
      _storageKey,
      jsonEncode(_chains.map((chain) => chain.toJson()).toList()),
    );
  }

  Future<void> addChain(MemoryChain chain) async {
    await initialize();
    _chains.removeWhere((item) => item.id == chain.id);
    _chains.add(chain);
    await _save();
    notifyListeners();
  }

  Future<void> updateChain(MemoryChain chain) async {
    await addChain(chain);
  }

  Future<void> removeChain(String chainId) async {
    await initialize();
    _chains.removeWhere((item) => item.id == chainId);
    await _save();
    notifyListeners();
  }
}
