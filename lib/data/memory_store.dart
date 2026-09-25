import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/memory.dart';

class MemoryStore extends ChangeNotifier {
  MemoryStore._();

  static final MemoryStore instance = MemoryStore._();

  static const String _storageKey = 'smriti_memories';

  final List<Memory> _memories = [];

  bool _initialized = false;

  List<Memory> get memories => List.unmodifiable(_memories);

  // ============================================================
  // INITIALIZATION
  // ============================================================

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    final prefs = SharedPreferencesAsync();

    try {
      final raw = await prefs.getString(_storageKey);

      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);

        if (decoded is List) {
          _memories
            ..clear()
            ..addAll(
              decoded.whereType<Map>().map(
                    (item) => Memory.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              ),
            );
        }
      }
    } catch (_) {
      _memories.clear();
    }

    if (_memories.isEmpty) {
      _memories.addAll(_defaultMemories);
      await _save();
    }

    _initialized = true;
    notifyListeners();
  }

  // ============================================================
  // MEMORY QUERIES
  // ============================================================

  List<Memory> memoriesForPerson(String personName) {
    final normalized = personName.trim().toLowerCase();

    return _memories.where((memory) {
      return memory.people.any(
            (person) =>
        person.trim().toLowerCase() == normalized,
      );
    }).toList();
  }

  // ============================================================
  // MEMORY CRUD
  // ============================================================

  Future<void> addMemory(Memory memory) async {
    _memories.add(memory);

    await _save();

    notifyListeners();
  }

  Future<void> updateMemory(Memory updatedMemory) async {
    final index = _memories.indexWhere(
          (memory) => memory.id == updatedMemory.id,
    );

    if (index == -1) {
      return;
    }

    _memories[index] = updatedMemory;

    await _save();

    notifyListeners();
  }

  Future<void> removeMemory(String memoryId) async {
    final index = _memories.indexWhere(
          (memory) => memory.id == memoryId,
    );

    if (index == -1) {
      return;
    }

    final memory = _memories[index];

    if (memory.imageUrl != null) {
      await deleteMemoryImage(
        memory.imageUrl!,
      );
    }

    if (memory.voiceMessage != null) {
      await deleteMemoryAudio(
        memory.voiceMessage!,
      );
    }

    _memories.removeAt(index);

    await _save();

    notifyListeners();
  }

  // ============================================================
  // PERSISTENCE
  // ============================================================

  Future<void> _save() async {
    final prefs = SharedPreferencesAsync();

    final encoded = jsonEncode(
      _memories
          .map((memory) => memory.toJson())
          .toList(),
    );

    await prefs.setString(
      _storageKey,
      encoded,
    );
  }

  // ============================================================
  // IMAGE STORAGE
  // ============================================================

  Future<String> saveMemoryImage(
      String sourcePath,
      ) async {
    final directory =
    await getApplicationDocumentsDirectory();

    final memoryDirectory = Directory(
      '${directory.path}/smriti_memories',
    );

    if (!await memoryDirectory.exists()) {
      await memoryDirectory.create(
        recursive: true,
      );
    }

    final extension = _getExtension(sourcePath);

    final fileName =
        'memory_${DateTime.now().millisecondsSinceEpoch}$extension';

    final destination = File(
      '${memoryDirectory.path}/$fileName',
    );

    await File(sourcePath).copy(
      destination.path,
    );

    return destination.path;
  }

  Future<void> deleteMemoryImage(
      String path,
      ) async {
    try {
      final file = File(path);

      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Ignore cleanup errors.
    }
  }

  // ============================================================
  // VOICE STORAGE
  // ============================================================

  Future<String> createMemoryAudioPath({
    String extension = 'm4a',
  }) async {
    final directory =
    await getApplicationDocumentsDirectory();

    final audioDirectory = Directory(
      '${directory.path}/smriti_memory_audio',
    );

    if (!await audioDirectory.exists()) {
      await audioDirectory.create(
        recursive: true,
      );
    }

    final timestamp =
        DateTime.now().millisecondsSinceEpoch;

    return '${audioDirectory.path}/voice_$timestamp.$extension';
  }

  Future<void> deleteMemoryAudio(
      String path,
      ) async {
    try {
      final file = File(path);

      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Ignore cleanup errors.
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _getExtension(String path) {
    final dotIndex = path.lastIndexOf('.');

    if (dotIndex == -1) {
      return '.jpg';
    }

    return path.substring(dotIndex);
  }

  // ============================================================
  // DEFAULT MEMORIES
  // ============================================================

  List<Memory> get _defaultMemories {
    return const [
      Memory(
        id: 'memory_001',
        title: 'Diwali with Family',
        description:
        'A happy Diwali celebration with the family at home.',
        date: '2025-10-20',
        location: 'Home',
        people: [
          'Priya',
          'Raj',
        ],
        tags: [
          'Diwali',
          'Family',
          'Festival',
        ],
      ),
      Memory(
        id: 'memory_002',
        title: 'Family Picnic',
        description:
        'A family picnic and a relaxing afternoon together.',
        date: '2025-01-15',
        location: 'City Park',
        people: [
          'Priya',
          'Raj',
        ],
        tags: [
          'Picnic',
          'Family',
          'Outdoors',
        ],
      ),
    ];
  }
}