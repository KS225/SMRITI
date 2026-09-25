class CognitiveSession {
  final String id;
  final String gameId;
  final String gameName;
  final DateTime startedAt;

  final int durationSeconds;
  final int totalQuestions;
  final int attempts;

  final int correctAnswers;
  final int incorrectAnswers;
  final int dontKnowAnswers;

  // Memory interaction responses
  final int memoryRememberedCount;
  final int memoryNotSureCount;

  final List<int> questionDurationsMs;

  final bool completed;

  const CognitiveSession({
    required this.id,
    required this.gameId,
    required this.gameName,
    required this.startedAt,
    required this.durationSeconds,
    required this.totalQuestions,
    required this.attempts,
    required this.correctAnswers,
    required this.incorrectAnswers,
    required this.dontKnowAnswers,
    required this.memoryRememberedCount,
    required this.memoryNotSureCount,
    required this.questionDurationsMs,
    required this.completed,
  });

  // ============================================================
  // ACCURACY
  // ============================================================

  double get accuracy {
    if (totalQuestions == 0) {
      return 0;
    }

    return correctAnswers / totalQuestions;
  }

  // ============================================================
  // AVERAGE QUESTION TIME
  // ============================================================

  double get averageQuestionTimeSeconds {
    if (questionDurationsMs.isEmpty) {
      return 0;
    }

    final totalMs =
    questionDurationsMs.reduce(
          (a, b) => a + b,
    );

    return totalMs /
        questionDurationsMs.length /
        1000;
  }

  // ============================================================
  // FROM JSON
  // ============================================================

  factory CognitiveSession.fromJson(
      Map<String, dynamic> json,
      ) {
    return CognitiveSession(
      id:
      json['id'] as String? ?? '',

      gameId:
      json['gameId'] as String? ?? '',

      gameName:
      json['gameName'] as String? ?? '',

      startedAt:
      DateTime.tryParse(
        json['startedAt']
        as String? ??
            '',
      ) ??
          DateTime.now(),

      durationSeconds:
      (json['durationSeconds']
      as num?)
          ?.toInt() ??
          0,

      totalQuestions:
      (json['totalQuestions']
      as num?)
          ?.toInt() ??
          0,

      attempts:
      (json['attempts'] as num?)
          ?.toInt() ??
          0,

      correctAnswers:
      (json['correctAnswers']
      as num?)
          ?.toInt() ??
          0,

      incorrectAnswers:
      (json['incorrectAnswers']
      as num?)
          ?.toInt() ??
          0,

      dontKnowAnswers:
      (json['dontKnowAnswers']
      as num?)
          ?.toInt() ??
          0,

      // Defaults to 0 so previously saved sessions
      // continue to work correctly.
      memoryRememberedCount:
      (json['memoryRememberedCount']
      as num?)
          ?.toInt() ??
          0,

      memoryNotSureCount:
      (json['memoryNotSureCount']
      as num?)
          ?.toInt() ??
          0,

      questionDurationsMs:
      (json['questionDurationsMs']
      as List?)
          ?.map(
            (item) =>
            (item as num).toInt(),
      )
          .toList() ??
          [],

      completed:
      json['completed'] as bool? ??
          false,
    );
  }

  // ============================================================
  // TO JSON
  // ============================================================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gameId': gameId,
      'gameName': gameName,
      'startedAt':
      startedAt.toIso8601String(),

      'durationSeconds':
      durationSeconds,

      'totalQuestions':
      totalQuestions,

      'attempts': attempts,

      'correctAnswers':
      correctAnswers,

      'incorrectAnswers':
      incorrectAnswers,

      'dontKnowAnswers':
      dontKnowAnswers,

      'memoryRememberedCount':
      memoryRememberedCount,

      'memoryNotSureCount':
      memoryNotSureCount,

      'questionDurationsMs':
      questionDurationsMs,

      'completed': completed,
    };
  }
}