import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import '../data/cognitive_session_store.dart';
import '../data/memory_chain_engine.dart';
import '../data/memory_chain_store.dart';
import '../data/memory_enhancement_store.dart';
import '../data/memory_store.dart';
import '../models/cognitive_session.dart';
import '../models/memory.dart';
import '../theme/smriti_theme.dart';

class WhatComesNextGame extends StatefulWidget {
  const WhatComesNextGame({super.key});

  @override
  State<WhatComesNextGame> createState() => _WhatComesNextGameState();
}

class _WhatComesNextGameState extends State<WhatComesNextGame> {
  final MemoryStore _memoryStore = MemoryStore.instance;
  final MemoryEnhancementStore _enhancementStore =
      MemoryEnhancementStore.instance;
  final MemoryChainStore _chainStore = MemoryChainStore.instance;
  final CognitiveSessionStore _sessionStore = CognitiveSessionStore.instance;

  late final MemoryChainEngine _engine = MemoryChainEngine(
    memoryStore: _memoryStore,
    enhancementStore: _enhancementStore,
    chainStore: _chainStore,
  );

  final Random _random = Random();

  bool _loading = true;
  bool _finished = false;
  bool _answered = false;
  bool _dontKnow = false;

  String _difficulty = 'Easy';
  List<MemoryChainQuestion> _questions = [];
  List<Memory> _options = [];
  int _index = 0;
  int _score = 0;
  int _incorrectAnswers = 0;
  int _dontKnowAnswers = 0;

  DateTime? _sessionStartedAt;
  DateTime? _questionStartedAt;
  final List<int> _questionDurationsMs = [];
  bool _sessionSaved = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await Future.wait([
      _memoryStore.initialize(),
      _enhancementStore.initialize(),
      _chainStore.initialize(),
      _sessionStore.initialize(),
    ]);

    if (!mounted) return;

    _determineDifficulty();
    _sessionStartedAt = DateTime.now();
    setState(() => _loading = false);
    _prepareGame();
  }

  void _determineDifficulty() {
    final sessions = _sessionStore.sessionsForGame('what_comes_next');
    if (sessions.length < 3) {
      _difficulty = 'Easy';
      return;
    }

    final recent = sessions.take(3).toList();
    final average = recent.fold<double>(
          0,
          (sum, item) => sum + item.accuracy,
        ) /
        recent.length;

    _difficulty = average < 0.60
        ? 'Easy'
        : average <= 0.85
            ? 'Standard'
            : 'Challenging';
  }

  int get _questionLimit => switch (_difficulty) {
        'Standard' => 4,
        'Challenging' => 5,
        _ => 3,
      };

  int get _optionLimit => switch (_difficulty) {
        'Standard' => 3,
        'Challenging' => 4,
        _ => 2,
      };

  void _prepareGame() {
    final questions = _engine.buildQuestions(
      limit: _questionLimit,
      random: _random,
    );

    if (!mounted) return;

    setState(() {
      _questions = questions;
      _index = 0;
      _score = 0;
      _incorrectAnswers = 0;
      _dontKnowAnswers = 0;
      _finished = false;
    });

    if (questions.isNotEmpty) {
      _loadQuestion();
    }
  }

  void _loadQuestion() {
    if (_index >= _questions.length) {
      _saveSessionAndFinish();
      return;
    }

    final question = _questions[_index];
    final correct = _memoryFor(question.answerMemoryId);
    if (correct == null) {
      _loadQuestion();
      return;
    }

    final candidates = _memoryStore.memories
        .where((memory) => memory.id != correct.id)
        .toList();

    candidates.sort((a, b) {
      final aCategory = _enhancementStore.enhancementFor(a.id).category;
      final bCategory = _enhancementStore.enhancementFor(b.id).category;
      final targetCategory = _enhancementStore
          .enhancementFor(correct.id)
          .category;
      final aSame = aCategory == targetCategory ? 0 : 1;
      final bSame = bCategory == targetCategory ? 0 : 1;
      return aSame.compareTo(bSame);
    });

    final options = <Memory>[correct];
    for (final candidate in candidates) {
      if (options.any((item) => item.id == candidate.id)) continue;
      options.add(candidate);
      if (options.length >= _optionLimit) break;
    }
    options.shuffle(_random);

    setState(() {
      _options = options;
      _answered = false;
      _dontKnow = false;
      _questionStartedAt = DateTime.now();
    });
  }

  Memory? _memoryFor(String id) {
    for (final memory in _memoryStore.memories) {
      if (memory.id == id) return memory;
    }
    return null;
  }

  ImageProvider? _imageFor(Memory memory) {
    final path = memory.imageUrl;
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    return FileImage(file);
  }

  Future<void> _answer(Memory memory) async {
    if (_answered) return;

    final question = _questions[_index];
    final correct = memory.id == question.answerMemoryId;
    _questionDurationsMs.add(
      DateTime.now()
          .difference(_questionStartedAt ?? DateTime.now())
          .inMilliseconds,
    );

    setState(() {
      _answered = true;
      if (correct) {
        _score++;
      } else {
        _incorrectAnswers++;
      }
    });

    await _enhancementStore.recordInteraction(
      question.answerMemoryId,
      correct: correct,
    );
  }

  Future<void> _dontKnowPressed() async {
    if (_answered) return;

    final question = _questions[_index];
    _questionDurationsMs.add(
      DateTime.now()
          .difference(_questionStartedAt ?? DateTime.now())
          .inMilliseconds,
    );

    setState(() {
      _answered = true;
      _dontKnow = true;
      _dontKnowAnswers++;
    });

    await _enhancementStore.recordInteraction(
      question.answerMemoryId,
      dontKnow: true,
    );
  }

  Future<void> _next() async {
    if (!_answered) return;
    _index++;
    if (_index >= _questions.length) {
      await _saveSessionAndFinish();
    } else {
      _loadQuestion();
    }
  }

  Future<void> _saveSessionAndFinish() async {
    if (_sessionSaved) return;
    _sessionSaved = true;

    final started = _sessionStartedAt ?? DateTime.now();
    await _sessionStore.addSession(
      CognitiveSession(
        id: 'what_next_${DateTime.now().millisecondsSinceEpoch}',
        gameId: 'what_comes_next',
        gameName: 'What Comes Next?',
        startedAt: started,
        durationSeconds: DateTime.now().difference(started).inSeconds,
        totalQuestions: _questions.length,
        attempts: _score + _incorrectAnswers + _dontKnowAnswers,
        correctAnswers: _score,
        incorrectAnswers: _incorrectAnswers,
        dontKnowAnswers: _dontKnowAnswers,
        memoryRememberedCount: 0,
        memoryNotSureCount: 0,
        questionDurationsMs: List<int>.from(_questionDurationsMs),
        completed: true,
      ),
    );

    if (mounted) setState(() => _finished = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('What Comes Next?')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_finished) return _buildCompletion();

    if (_questions.isEmpty) return _buildEmptyState();

    final question = _questions[_index];
    final first = _memoryFor(question.orderedMemoryIds[0]);
    final second = _memoryFor(question.orderedMemoryIds[1]);
    final answer = _memoryFor(question.answerMemoryId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('What Comes Next?'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_index + 1}/${_questions.length}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          children: [
            Text(
              question.chain.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: SmritiTheme.primaryDark,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Look at the memories, then choose what comes next.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: SmritiTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 9),
            Center(
              child: Text(
                'Difficulty: $_difficulty',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: SmritiTheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 22),
            _sequenceCard(first, 1),
            _arrow(),
            _sequenceCard(second, 2),
            _arrow(),
            _missingCard(),
            const SizedBox(height: 24),
            const Text(
              'What comes next?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: SmritiTheme.primaryDark,
              ),
            ),
            const SizedBox(height: 13),
            ..._options.map(
              (option) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _optionCard(
                  option,
                  correct: option.id == answer?.id,
                ),
              ),
            ),
            if (_answered) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: SmritiTheme.softGreen,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: SmritiTheme.border),
                ),
                child: Text(
                  _dontKnow
                      ? 'That is okay. We can practice this memory again later.'
                      : (answer == null
                          ? 'Question complete.'
                          : 'The next memory is “${answer.title}”.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: SmritiTheme.primaryDark,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: _next,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(
                    _index + 1 >= _questions.length ? 'Finish' : 'Next',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
            if (!_answered)
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _dontKnowPressed,
                  icon: const Icon(Icons.help_outline_rounded),
                  label: const Text("I don't know"),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sequenceCard(Memory? memory, int number) {
    final image = memory == null ? null : _imageFor(memory);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SmritiTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SmritiTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: SmritiTheme.softGreen,
              borderRadius: BorderRadius.circular(15),
            ),
            clipBehavior: Clip.antiAlias,
            child: image == null
                ? const Icon(Icons.photo_rounded,
                    color: SmritiTheme.primary)
                : Image(image: image, fit: BoxFit.cover),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              memory?.title ?? 'Memory unavailable',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: SmritiTheme.textPrimary,
              ),
            ),
          ),
          CircleAvatar(
            backgroundColor: SmritiTheme.softGreen,
            child: Text(
              '$number',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: SmritiTheme.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _missingCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: SmritiTheme.softGreen,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SmritiTheme.primary.withAlpha(80)),
      ),
      child: const Column(
        children: [
          Icon(Icons.help_outline_rounded,
              size: 42, color: SmritiTheme.primary),
          SizedBox(height: 5),
          Text(
            'NEXT',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: SmritiTheme.primaryDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _arrow() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Icon(
        Icons.arrow_downward_rounded,
        size: 28,
        color: SmritiTheme.primary,
      ),
    );
  }

  Widget _optionCard(Memory memory, {required bool correct}) {
    final image = _imageFor(memory);
    final enabled = !_answered;

    return Material(
      color: SmritiTheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: enabled ? () => _answer(memory) : null,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _answered && correct
                  ? SmritiTheme.primary
                  : SmritiTheme.border,
              width: _answered && correct ? 2.2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: SmritiTheme.softGreen,
                  borderRadius: BorderRadius.circular(15),
                ),
                clipBehavior: Clip.antiAlias,
                child: image == null
                    ? const Icon(Icons.photo_rounded,
                        color: SmritiTheme.primary)
                    : Image(image: image, fit: BoxFit.cover),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  memory.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: SmritiTheme.textPrimary,
                  ),
                ),
              ),
              if (_answered && correct)
                const Icon(
                  Icons.check_circle_rounded,
                  color: SmritiTheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Scaffold(
      appBar: AppBar(title: const Text('What Comes Next?')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.format_list_numbered_rounded,
                  size: 80, color: SmritiTheme.primary),
              const SizedBox(height: 18),
              const Text(
                'Add at least 3 connected memories to play this game.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: SmritiTheme.primaryDark,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'SMRITI builds sequences from dates, albums and related memories.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: SmritiTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back to Games'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletion() {
    final total = _questions.length;
    final accuracy = total == 0 ? 0 : (_score / total * 100).round();

    return Scaffold(
      appBar: AppBar(title: const Text('Game Complete')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 30),
          children: [
            const Icon(Icons.celebration_rounded,
                size: 78, color: SmritiTheme.primary),
            const SizedBox(height: 18),
            const Text(
              'Well done! ❤️',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: SmritiTheme.primaryDark,
              ),
            ),
            const SizedBox(height: 22),
            _scoreCard('Score', '$_score / $total'),
            const SizedBox(height: 10),
            _scoreCard('Accuracy', '$accuracy%'),
            const SizedBox(height: 10),
            _scoreCard('Incorrect', '$_incorrectAnswers'),
            const SizedBox(height: 10),
            _scoreCard("I don't know", '$_dontKnowAnswers'),
            const SizedBox(height: 24),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: () {
                  _sessionSaved = false;
                  _sessionStartedAt = DateTime.now();
                  _prepareGame();
                },
                icon: const Icon(Icons.replay_rounded),
                label: const Text('Play Again',
                    style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back to Games'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scoreCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      decoration: BoxDecoration(
        color: SmritiTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SmritiTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                color: SmritiTheme.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: SmritiTheme.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}
