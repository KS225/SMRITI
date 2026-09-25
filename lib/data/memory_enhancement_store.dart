import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemoryEnhancement {
  final String memoryId;
  final String category;
  final String album;
  final List<String> relatedMemoryIds;

  final int timesSeen;
  final int correctCount;
  final int incorrectCount;
  final int dontKnowCount;
  final int rememberedCount;
  final int notSureCount;

  final int voiceRecallCount;
  final int recallDetailCount;

  final DateTime? firstSeenAt;
  final DateTime? lastSeenAt;
  final DateTime? reviewDueAt;
  final int reviewIntervalDays;
  final int reviewStreak;
  final int lapseCount;

  const MemoryEnhancement({
    required this.memoryId,
    this.category = 'Family',
    this.album = '',
    this.relatedMemoryIds = const [],
    this.timesSeen = 0,
    this.correctCount = 0,
    this.incorrectCount = 0,
    this.dontKnowCount = 0,
    this.rememberedCount = 0,
    this.notSureCount = 0,
    this.voiceRecallCount = 0,
    this.recallDetailCount = 0,
    this.firstSeenAt,
    this.lastSeenAt,
    this.reviewDueAt,
    this.reviewIntervalDays = 1,
    this.reviewStreak = 0,
    this.lapseCount = 0,
  });

  double get answerAccuracy {
    final answered = correctCount + incorrectCount;
    if (answered == 0) return 0;
    return correctCount / answered;
  }

  double get familiarityScore {
    final correctPart = (correctCount * 12).clamp(0, 48);
    final seenPart = (timesSeen * 6).clamp(0, 24);
    final rememberedPart = (rememberedCount * 8).clamp(0, 24);
    final recallPart = (recallDetailCount * 2).clamp(0, 10);
    return (correctPart + seenPart + rememberedPart + recallPart)
        .clamp(0, 100)
        .toDouble();
  }

  bool get isDueForReview =>
      reviewDueAt == null || !reviewDueAt!.isAfter(DateTime.now());

  MemoryEnhancement copyWith({
    String? category,
    String? album,
    List<String>? relatedMemoryIds,
    int? timesSeen,
    int? correctCount,
    int? incorrectCount,
    int? dontKnowCount,
    int? rememberedCount,
    int? notSureCount,
    int? voiceRecallCount,
    int? recallDetailCount,
    DateTime? firstSeenAt,
    DateTime? lastSeenAt,
    DateTime? reviewDueAt,
    int? reviewIntervalDays,
    int? reviewStreak,
    int? lapseCount,
  }) {
    return MemoryEnhancement(
      memoryId: memoryId,
      category: category ?? this.category,
      album: album ?? this.album,
      relatedMemoryIds: relatedMemoryIds ?? this.relatedMemoryIds,
      timesSeen: timesSeen ?? this.timesSeen,
      correctCount: correctCount ?? this.correctCount,
      incorrectCount: incorrectCount ?? this.incorrectCount,
      dontKnowCount: dontKnowCount ?? this.dontKnowCount,
      rememberedCount: rememberedCount ?? this.rememberedCount,
      notSureCount: notSureCount ?? this.notSureCount,
      voiceRecallCount: voiceRecallCount ?? this.voiceRecallCount,
      recallDetailCount: recallDetailCount ?? this.recallDetailCount,
      firstSeenAt: firstSeenAt ?? this.firstSeenAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      reviewDueAt: reviewDueAt ?? this.reviewDueAt,
      reviewIntervalDays: reviewIntervalDays ?? this.reviewIntervalDays,
      reviewStreak: reviewStreak ?? this.reviewStreak,
      lapseCount: lapseCount ?? this.lapseCount,
    );
  }

  factory MemoryEnhancement.fromJson(Map<String, dynamic> json) {
    return MemoryEnhancement(
      memoryId: json['memoryId'] as String? ?? '',
      category: json['category'] as String? ?? 'Family',
      album: json['album'] as String? ?? '',
      relatedMemoryIds: (json['relatedMemoryIds'] as List?)
              ?.map((item) => item.toString())
              .toList() ??
          const [],
      timesSeen: (json['timesSeen'] as num?)?.toInt() ?? 0,
      correctCount: (json['correctCount'] as num?)?.toInt() ?? 0,
      incorrectCount: (json['incorrectCount'] as num?)?.toInt() ?? 0,
      dontKnowCount: (json['dontKnowCount'] as num?)?.toInt() ?? 0,
      rememberedCount: (json['rememberedCount'] as num?)?.toInt() ?? 0,
      notSureCount: (json['notSureCount'] as num?)?.toInt() ?? 0,
      voiceRecallCount:
          (json['voiceRecallCount'] as num?)?.toInt() ?? 0,
      recallDetailCount:
          (json['recallDetailCount'] as num?)?.toInt() ?? 0,
      firstSeenAt: _tryParse(json['firstSeenAt']),
      lastSeenAt: _tryParse(json['lastSeenAt']),
      reviewDueAt: _tryParse(json['reviewDueAt']),
      reviewIntervalDays: (json['reviewIntervalDays'] as num?)?.toInt() ?? 1,
      reviewStreak: (json['reviewStreak'] as num?)?.toInt() ?? 0,
      lapseCount: (json['lapseCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'memoryId': memoryId,
      'category': category,
      'album': album,
      'relatedMemoryIds': relatedMemoryIds,
      'timesSeen': timesSeen,
      'correctCount': correctCount,
      'incorrectCount': incorrectCount,
      'dontKnowCount': dontKnowCount,
      'rememberedCount': rememberedCount,
      'notSureCount': notSureCount,
      'voiceRecallCount': voiceRecallCount,
      'recallDetailCount': recallDetailCount,
      'firstSeenAt': firstSeenAt?.toIso8601String(),
      'lastSeenAt': lastSeenAt?.toIso8601String(),
      'reviewDueAt': reviewDueAt?.toIso8601String(),
      'reviewIntervalDays': reviewIntervalDays,
      'reviewStreak': reviewStreak,
      'lapseCount': lapseCount,
    };
  }

  static DateTime? _tryParse(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}

class MemoryQuestion {
  final String id;
  final String memoryId;
  final String type;
  final String prompt;
  final List<String> options;
  final String correctAnswer;
  final String hint;
  final String difficulty;
  final bool enabled;
  final DateTime createdAt;

  const MemoryQuestion({
    required this.id,
    required this.memoryId,
    required this.type,
    required this.prompt,
    required this.options,
    required this.correctAnswer,
    this.hint = '',
    this.difficulty = 'Easy',
    this.enabled = true,
    required this.createdAt,
  });

  MemoryQuestion copyWith({
    String? prompt,
    List<String>? options,
    String? correctAnswer,
    String? hint,
    String? difficulty,
    bool? enabled,
  }) {
    return MemoryQuestion(
      id: id,
      memoryId: memoryId,
      type: type,
      prompt: prompt ?? this.prompt,
      options: options ?? this.options,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      hint: hint ?? this.hint,
      difficulty: difficulty ?? this.difficulty,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt,
    );
  }

  factory MemoryQuestion.fromJson(Map<String, dynamic> json) {
    return MemoryQuestion(
      id: json['id'] as String? ?? '',
      memoryId: json['memoryId'] as String? ?? '',
      type: json['type'] as String? ?? 'custom',
      prompt: json['prompt'] as String? ?? '',
      options: (json['options'] as List?)
              ?.map((item) => item.toString())
              .toList() ??
          const [],
      correctAnswer: json['correctAnswer'] as String? ?? '',
      hint: json['hint'] as String? ?? '',
      difficulty: json['difficulty'] as String? ?? 'Easy',
      enabled: json['enabled'] as bool? ?? true,
      createdAt: MemoryEnhancement._tryParse(json['createdAt']) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'memoryId': memoryId,
      'type': type,
      'prompt': prompt,
      'options': options,
      'correctAnswer': correctAnswer,
      'hint': hint,
      'difficulty': difficulty,
      'enabled': enabled,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class MemoryEnhancementStore extends ChangeNotifier {
  MemoryEnhancementStore._();

  static final MemoryEnhancementStore instance =
      MemoryEnhancementStore._();

  static const String _storageKey =
      'smriti_memory_enhancements_v1';

  final Map<String, MemoryEnhancement> _enhancements = {};
  final Map<String, List<MemoryQuestion>> _questions = {};

  bool _initialized = false;
  Future<void>? _initializationFuture;

  bool get isInitialized => _initialized;

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
        if (decoded is Map) {
          final rawEnhancements = decoded['enhancements'];
          if (rawEnhancements is Map) {
            for (final entry in rawEnhancements.entries) {
              if (entry.value is Map) {
                final enhancement = MemoryEnhancement.fromJson(
                  Map<String, dynamic>.from(entry.value as Map),
                );
                if (enhancement.memoryId.isNotEmpty) {
                  _enhancements[enhancement.memoryId] = enhancement;
                }
              }
            }
          }

          final rawQuestions = decoded['questions'];
          if (rawQuestions is Map) {
            for (final entry in rawQuestions.entries) {
              if (entry.value is List) {
                _questions[entry.key.toString()] =
                    (entry.value as List)
                        .whereType<Map>()
                        .map(
                          (item) => MemoryQuestion.fromJson(
                            Map<String, dynamic>.from(item),
                          ),
                        )
                        .toList();
              }
            }
          }
        }
      }
    } catch (_) {
      _enhancements.clear();
      _questions.clear();
    }

    _initialized = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = SharedPreferencesAsync();
    final payload = {
      'enhancements': _enhancements.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'questions': _questions.map(
        (key, value) => MapEntry(
          key,
          value.map((question) => question.toJson()).toList(),
        ),
      ),
    };

    await prefs.setString(
      _storageKey,
      jsonEncode(payload),
    );
  }

  Future<MemoryEnhancement> ensureForMemory(
    String memoryId, {
    String? defaultCategory,
  }) async {
    await initialize();

    final existing = _enhancements[memoryId];
    if (existing != null) return existing;

    final created = MemoryEnhancement(
      memoryId: memoryId,
      category: defaultCategory?.trim().isNotEmpty == true
          ? defaultCategory!.trim()
          : 'Family',
    );

    _enhancements[memoryId] = created;
    await _save();
    notifyListeners();
    return created;
  }

  MemoryEnhancement enhancementFor(String memoryId) =>
      _enhancements[memoryId] ??
      MemoryEnhancement(memoryId: memoryId);

  List<MemoryEnhancement> get enhancements =>
      List.unmodifiable(_enhancements.values);

  List<MemoryQuestion> questionsForMemory(
    String memoryId, {
    bool enabledOnly = true,
  }) {
    final list = _questions[memoryId] ?? const [];
    if (!enabledOnly) return List.unmodifiable(list);
    return List.unmodifiable(
      list.where((question) => question.enabled),
    );
  }

  Future<void> updateMetadata(
    String memoryId, {
    required String category,
    required String album,
    required List<String> relatedMemoryIds,
  }) async {
    final existing = await ensureForMemory(memoryId);
    _enhancements[memoryId] = existing.copyWith(
      category: category.trim().isEmpty ? 'Family' : category.trim(),
      album: album.trim(),
      relatedMemoryIds: List<String>.from(
        relatedMemoryIds.where((id) => id != memoryId),
      ),
    );
    await _save();
    notifyListeners();
  }

  Future<void> recordInteraction(
    String memoryId, {
    bool seen = false,
    bool? correct,
    bool? dontKnow,
    bool? remembered,
    bool? notSure,
    int? recallDetailCount,
  }) async {
    final existing = await ensureForMemory(memoryId);
    var next = existing;

    if (seen) {
      final now = DateTime.now();
      next = next.copyWith(
        timesSeen: next.timesSeen + 1,
        firstSeenAt: next.firstSeenAt ?? now,
        lastSeenAt: now,
      );
    }

    // A correct/incorrect/don't-know answer is treated as a review event.
    // Reflection (remembered/not sure) deliberately does not reschedule the
    // card because it is often recorded immediately after the answer.
    if (correct == true) {
      next = _applyReviewOutcome(next, quality: 4);
      next = next.copyWith(
        correctCount: next.correctCount + 1,
        lastSeenAt: DateTime.now(),
      );
    }

    if (correct == false) {
      next = _applyReviewOutcome(next, quality: 1);
      next = next.copyWith(
        incorrectCount: next.incorrectCount + 1,
        lastSeenAt: DateTime.now(),
      );
    }

    if (dontKnow == true) {
      next = _applyReviewOutcome(next, quality: 0);
      next = next.copyWith(
        dontKnowCount: next.dontKnowCount + 1,
        lastSeenAt: DateTime.now(),
      );
    }

    if (remembered == true) {
      next = next.copyWith(
        rememberedCount: next.rememberedCount + 1,
        lastSeenAt: DateTime.now(),
      );
    }

    if (notSure == true) {
      next = next.copyWith(
        notSureCount: next.notSureCount + 1,
        lastSeenAt: DateTime.now(),
      );
    }

    if (recallDetailCount != null && recallDetailCount > 0) {
      next = next.copyWith(
        voiceRecallCount: next.voiceRecallCount + 1,
        recallDetailCount:
            next.recallDetailCount + recallDetailCount,
        lastSeenAt: DateTime.now(),
      );
    }

    _enhancements[memoryId] = next;
    await _save();
    notifyListeners();
  }

  Future<void> recordReviewOutcome(
    String memoryId, {
    required int quality,
  }) async {
    final existing = await ensureForMemory(memoryId);
    final safeQuality = quality.clamp(0, 5).toInt();
    final next = _applyReviewOutcome(
      existing,
      quality: safeQuality,
    );
    _enhancements[memoryId] = next.copyWith(
      lastSeenAt: DateTime.now(),
    );
    await _save();
    notifyListeners();
  }

  MemoryEnhancement _applyReviewOutcome(
    MemoryEnhancement current, {
    required int quality,
  }) {
    final now = DateTime.now();

    // 0-1: forgot/lapse. 2: difficult/uncertain. 3-5: successful recall.
    if (quality <= 1) {
      return current.copyWith(
        reviewDueAt: now.add(const Duration(days: 1)),
        reviewIntervalDays: 1,
        reviewStreak: 0,
        lapseCount: current.lapseCount + 1,
      );
    }

    if (quality == 2) {
      final shortened = current.reviewIntervalDays <= 1
          ? 1
          : max(1, (current.reviewIntervalDays / 2).round());
      return current.copyWith(
        reviewDueAt: now.add(Duration(days: shortened)),
        reviewIntervalDays: shortened,
      );
    }

    final streak = current.reviewStreak + 1;
    final days = switch (streak) {
      1 => 2,
      2 => 4,
      3 => 7,
      4 => 14,
      5 => 30,
      _ => min(90, max(30, (current.reviewIntervalDays * 1.8).round())),
    };

    return current.copyWith(
      reviewDueAt: now.add(Duration(days: days)),
      reviewIntervalDays: days,
      reviewStreak: streak,
    );
  }

  Future<void> addQuestion(
    MemoryQuestion question,
  ) async {
    await initialize();
    final list = List<MemoryQuestion>.from(
      _questions[question.memoryId] ?? const [],
    );
    list.removeWhere((item) => item.id == question.id);
    list.add(question);
    _questions[question.memoryId] = list;
    await _save();
    notifyListeners();
  }

  Future<void> updateQuestion(
    MemoryQuestion question,
  ) async {
    await addQuestion(question);
  }

  Future<void> removeQuestion(
    String memoryId,
    String questionId,
  ) async {
    await initialize();
    final list = List<MemoryQuestion>.from(
      _questions[memoryId] ?? const [],
    );
    list.removeWhere((item) => item.id == questionId);
    _questions[memoryId] = list;
    await _save();
    notifyListeners();
  }

  List<String> categoriesForMemoryData(
    Iterable<String> existingCategories,
  ) {
    final result = <String>{
      'Family',
      'Travel',
      'Birthday',
      'Festival',
      'Wedding',
      'Childhood',
      'Friends',
      'Home',
      'Work',
      'Other',
      ...existingCategories.where(
        (item) => item.trim().isNotEmpty,
      ),
    };
    final list = result.toList()..sort();
    return list;
  }

  List<String> get allCategories {
    final result = <String>{'Family'};
    for (final item in _enhancements.values) {
      if (item.category.trim().isNotEmpty) {
        result.add(item.category.trim());
      }
    }
    final list = result.toList()..sort();
    return list;
  }

  List<String> get allAlbums {
    final result = <String>{};
    for (final item in _enhancements.values) {
      if (item.album.trim().isNotEmpty) {
        result.add(item.album.trim());
      }
    }
    final list = result.toList()..sort();
    return list;
  }

}
