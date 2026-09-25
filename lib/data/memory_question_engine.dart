import 'dart:math';

import '../data/memory_enhancement_store.dart';
import '../data/memory_store.dart';
import '../models/memory.dart';

class MemoryGameQuestion {
  final Memory memory;
  final String type;
  final String prompt;
  final List<String> options;
  final String correctAnswer;
  final String hint;
  final List<Memory> relatedMemories;

  const MemoryGameQuestion({
    required this.memory,
    required this.type,
    required this.prompt,
    required this.options,
    required this.correctAnswer,
    required this.hint,
    this.relatedMemories = const [],
  });
}

class MemoryQuestionEngine {
  MemoryQuestionEngine({
    MemoryStore? memoryStore,
    MemoryEnhancementStore? enhancementStore,
    Random? random,
  })  : _memoryStore = memoryStore ?? MemoryStore.instance,
        _enhancementStore =
            enhancementStore ?? MemoryEnhancementStore.instance,
        _random = random ?? Random();

  final MemoryStore _memoryStore;
  final MemoryEnhancementStore _enhancementStore;
  final Random _random;

  List<MemoryGameQuestion> generateSuggestedQuestions(
      Memory memory, {
        required String difficulty,
        int count = 4,
      }) {
    final types = <String>[
      'who',
      'where',
      'what',
      'when',
      'trueFalse',
      'related',
      'timeline',
    ];

    final available = <MemoryGameQuestion>[];

    for (final type in types) {
      final question = _generate(
        memory,
        type: type,
      );
      if (question != null) {
        available.add(question);
      }
    }

    available.shuffle(_random);
    return available.take(count).toList();
  }

  MemoryGameQuestion? generateForMemory(
      Memory memory, {
        required String difficulty,
        String? preferredType,
      }) {
    final customQuestions =
    _enhancementStore.questionsForMemory(memory.id);

    if (customQuestions.isNotEmpty &&
        (preferredType == null || preferredType == 'custom')) {
      final matching = customQuestions
          .where(
            (question) =>
        question.difficulty.toLowerCase() ==
            difficulty.toLowerCase(),
      )
          .toList();

      final source = matching.isNotEmpty
          ? matching
          : customQuestions;

      final selected = source[_random.nextInt(source.length)];

      return MemoryGameQuestion(
        memory: memory,
        type: 'custom',
        prompt: selected.prompt,
        options: selected.options,
        correctAnswer: selected.correctAnswer,
        hint: selected.hint,
      );
    }

    final possibleTypes = _possibleTypesFor(
      memory,
      difficulty,
    );

    if (preferredType != null &&
        possibleTypes.contains(preferredType)) {
      final preferred = _generate(
        memory,
        type: preferredType,
      );
      if (preferred != null) {
        return preferred;
      }
    }

    final shuffled = List<String>.from(possibleTypes)
      ..shuffle(_random);

    for (final type in shuffled) {
      final question = _generate(
        memory,
        type: type,
      );
      if (question != null) {
        return question;
      }
    }

    return _fallback(memory);
  }

  List<String> _possibleTypesFor(
      Memory memory,
      String difficulty,
      ) {
    final result = <String>[
      if (memory.people.isNotEmpty) 'who',
      if (memory.location.isNotEmpty) 'where',
      if (memory.date.isNotEmpty) 'when',
      'what',
      'trueFalse',
    ];

    final related = _enhancementStore
        .enhancementFor(memory.id)
        .relatedMemoryIds;

    if (related.isNotEmpty) {
      result.add('related');
    }

    if (_memoryStore.memories.length >= 3 &&
        memory.date.isNotEmpty) {
      result.add('timeline');
    }

    if (difficulty == 'Challenging') {
      result.add('timeline');
      if (related.isNotEmpty) {
        result.add('related');
      }
    }

    return result.toSet().toList();
  }

  MemoryGameQuestion? _generate(
      Memory memory, {
        required String type,
      }) {
    switch (type) {
      case 'who':
        return _whoQuestion(memory);
      case 'where':
        return _whereQuestion(memory);
      case 'when':
        return _whenQuestion(memory);
      case 'what':
        return _whatQuestion(memory);
      case 'trueFalse':
        return _trueFalseQuestion(memory);
      case 'related':
        return _relatedQuestion(memory);
      case 'timeline':
        return _timelineQuestion(memory);
      default:
        return null;
    }
  }

  MemoryGameQuestion? _whoQuestion(
      Memory memory,
      ) {
    if (memory.people.isEmpty) return null;

    final correct = memory.people[
    _random.nextInt(memory.people.length)
    ];

    final pool = _memoryStore.memories
        .expand((item) => item.people)
        .where((name) => name.trim().isNotEmpty)
        .toSet()
        .toList();

    pool.remove(correct);
    pool.shuffle(_random);

    final options = <String>{
    correct,
    ...pool.take(2),
    }.toList()
    ..shuffle(_random);

    if (options.length < 2) {
    options.add('Someone else');
    }

    return MemoryGameQuestion(
    memory: memory,
    type: 'who',
    prompt: 'Who is connected to this memory?',
    options: options,
    correctAnswer: correct,
    hint: memory.people.length == 1
    ? 'Think about the person you know in this memory.'
    : 'Think about the people connected to this moment.',
    );
  }

  MemoryGameQuestion? _whereQuestion(
      Memory memory,
      ) {
    final correct = memory.location.trim();
    if (correct.isEmpty) return null;

    final pool = _memoryStore.memories
        .map((item) => item.location.trim())
        .where(
          (value) => value.isNotEmpty && value != correct,
    )
        .toSet()
        .toList()
      ..shuffle(_random);

    final options = <String>{
      correct,
      ...pool.take(2),
    }.toList()
      ..shuffle(_random);

    if (options.length < 2) {
      options.add('Another place');
    }

    return MemoryGameQuestion(
      memory: memory,
      type: 'where',
      prompt: 'Where did this memory happen?',
      options: options,
      correctAnswer: correct,
      hint: 'Think about the place connected to this memory.',
    );
  }

  MemoryGameQuestion? _whenQuestion(
      Memory memory,
      ) {
    final parsed = DateTime.tryParse(memory.date);
    if (parsed == null) return null;

    final correct = parsed.year.toString();

    final pool = _memoryStore.memories
        .map((item) => DateTime.tryParse(item.date)?.year.toString())
        .whereType<String>()
        .where((value) => value != correct)
        .toSet()
        .toList()
      ..shuffle(_random);

    final options = <String>{
      correct,
      ...pool.take(2),
    }.toList()
      ..shuffle(_random);

    if (options.length < 2) {
      options.add('Another year');
    }

    return MemoryGameQuestion(
      memory: memory,
      type: 'when',
      prompt: 'What year was this memory from?',
      options: options,
      correctAnswer: correct,
      hint: 'Think about when this moment happened.',
    );
  }

  MemoryGameQuestion? _whatQuestion(
      Memory memory,
      ) {
    final correct = memory.title.trim();
    if (correct.isEmpty) return null;

    final pool = _memoryStore.memories
        .map((item) => item.title.trim())
        .where(
          (value) => value.isNotEmpty && value != correct,
    )
        .toSet()
        .toList()
      ..shuffle(_random);

    final options = <String>{
      correct,
      ...pool.take(2),
    }.toList()
      ..shuffle(_random);

    if (options.length < 2) {
      options.add('Another special moment');
    }

    return MemoryGameQuestion(
      memory: memory,
      type: 'what',
      prompt: 'Which title belongs to this memory?',
      options: options,
      correctAnswer: correct,
      hint: 'Think about what this special moment was called.',
    );
  }

  MemoryGameQuestion? _trueFalseQuestion(
      Memory memory,
      ) {
    final useTrue = _random.nextBool() || memory.location.isEmpty;

    if (useTrue) {
      final statement = memory.location.isEmpty
          ? 'This is one of your saved special memories.'
          : 'This memory happened in ${memory.location}.';

      return MemoryGameQuestion(
        memory: memory,
        type: 'trueFalse',
        prompt: statement,
        options: const ['True', 'False'],
        correctAnswer: 'True',
        hint: 'Think about the information attached to this memory.',
      );
    }

    final alternatives = _memoryStore.memories
        .map((item) => item.location.trim())
        .where(
          (value) =>
      value.isNotEmpty && value != memory.location.trim(),
    )
        .toList()
      ..shuffle(_random);

    if (alternatives.isEmpty) return null;

    final falseLocation = alternatives.first;
    return MemoryGameQuestion(
      memory: memory,
      type: 'trueFalse',
      prompt: 'This memory happened in $falseLocation.',
      options: const ['True', 'False'],
      correctAnswer: 'False',
      hint: 'Check the place connected to this memory.',
    );
  }

  MemoryGameQuestion? _relatedQuestion(
      Memory memory,
      ) {
    final ids = _enhancementStore
        .enhancementFor(memory.id)
        .relatedMemoryIds;

    if (ids.isEmpty) return null;

    final related = <Memory>[];
    for (final id in ids) {
      for (final item in _memoryStore.memories) {
        if (item.id == id) {
          related.add(item);
          break;
        }
      }
    }

    if (related.isEmpty) return null;

    final correct = related[_random.nextInt(related.length)];

    final pool = _memoryStore.memories
        .where(
          (item) => item.id != memory.id && item.id != correct.id,
    )
        .toList()
      ..shuffle(_random);

    final options = <String>{
      correct.title,
      ...pool.map((item) => item.title).take(2),
    }.toList()
      ..shuffle(_random);

    if (options.length < 2) {
      options.add('Another memory');
    }

    return MemoryGameQuestion(
      memory: memory,
      type: 'related',
      prompt: 'Which memory is connected to this moment?',
      options: options,
      correctAnswer: correct.title,
      hint: 'Think about other moments that belong with this one.',
      relatedMemories: [correct],
    );
  }

  MemoryGameQuestion? _timelineQuestion(
      Memory memory,
      ) {
    final dated = _memoryStore.memories
        .where(
          (item) =>
      item.date.trim().isNotEmpty &&
          DateTime.tryParse(item.date) != null,
    )
        .toList()
      ..sort(
            (a, b) => DateTime.parse(a.date)
            .compareTo(DateTime.parse(b.date)),
      );

    if (dated.length < 3) return null;

    final visible = <Memory>[memory];
    for (final item in dated) {
      if (item.id != memory.id) {
        visible.add(item);
      }
      if (visible.length == 3) break;
    }

    if (visible.length < 3) return null;

    final earliest = visible.reduce(
          (a, b) => DateTime.parse(a.date).isBefore(
        DateTime.parse(b.date),
      )
          ? a
          : b,
    );

    final options = visible.map((item) => item.title).toList()
      ..shuffle(_random);

    return MemoryGameQuestion(
      memory: memory,
      type: 'timeline',
      prompt: 'Which of these memories happened first?',
      options: options,
      correctAnswer: earliest.title,
      hint: 'Think about the dates of these memories.',
      relatedMemories: visible,
    );
  }

  MemoryGameQuestion _fallback(
      Memory memory,
      ) {
    return MemoryGameQuestion(
      memory: memory,
      type: 'what',
      prompt: 'Which title belongs to this memory?',
      options: [memory.title, 'Another special moment'],
      correctAnswer: memory.title,
      hint: 'Look at the name of this memory.',
    );
  }
}
