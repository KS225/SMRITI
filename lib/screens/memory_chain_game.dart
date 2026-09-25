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

class MemoryChainGame extends StatefulWidget {
  const MemoryChainGame({super.key});

  @override
  State<MemoryChainGame> createState() => _MemoryChainGameState();
}

class _MemoryChainGameState extends State<MemoryChainGame> {
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
  bool _showHint = false;

  String _difficulty = 'Easy';
  List<MemoryChainQuestion> _questions = [];
  List<String> _currentOrder = [];
  int _index = 0;
  int _score = 0;
  int _incorrectAnswers = 0;
  int _dontKnowAnswers = 0;

  int? _selectedIndex;
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
    final sessions = _sessionStore.sessionsForGame('memory_chain');
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

  List<Memory> get _memories => _memoryStore.memories;

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
    final shuffled = List<String>.from(question.orderedMemoryIds);
    if (shuffled.length > 1) {
      // Never let a new round start already solved.
      do {
        shuffled.shuffle(_random);
      } while (_listEquals(shuffled, question.orderedMemoryIds));
    }

    setState(() {
      _currentOrder = shuffled;
      _selectedIndex = null;
      _answered = false;
      _dontKnow = false;
      _showHint = false;
      _questionStartedAt = DateTime.now();
    });
  }

  Memory? _memoryFor(String id) {
    for (final memory in _memories) {
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

  void _selectCard(int index) {
    if (_answered) return;

    if (_selectedIndex == null) {
      setState(() => _selectedIndex = index);
      return;
    }

    if (_selectedIndex == index) {
      setState(() => _selectedIndex = null);
      return;
    }

    final first = _selectedIndex!;
    final next = List<String>.from(_currentOrder);
    final temp = next[first];
    next[first] = next[index];
    next[index] = temp;

    setState(() {
      _currentOrder = next;
      _selectedIndex = null;
    });
  }

  Future<void> _submitOrder() async {
    if (_answered || _questions.isEmpty) return;

    final question = _questions[_index];
    final correct = _listEquals(_currentOrder, question.orderedMemoryIds);
    if (correct) {
      _questionDurationsMs.add(
        DateTime.now()
            .difference(_questionStartedAt ?? DateTime.now())
            .inMilliseconds,
      );
      setState(() {
        _answered = true;
        _score++;
      });
      await _recordTargetOutcome(question.answerMemoryId, correct: true);
      return;
    }

    setState(() {
      _incorrectAnswers++;
      _showHint = _incorrectAnswers >= 2;
    });

    _message('Not quite. Try moving the cards into a different order.');
  }

  Future<void> _dontKnowPressed() async {
    if (_answered || _questions.isEmpty) return;

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

    await _recordTargetOutcome(question.answerMemoryId, dontKnow: true);
  }

  Future<void> _recordTargetOutcome(
    String memoryId, {
    bool correct = false,
    bool dontKnow = false,
  }) async {
    await _enhancementStore.recordInteraction(
      memoryId,
      correct: correct ? true : null,
      dontKnow: dontKnow ? true : null,
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
        id: 'memory_chain_${DateTime.now().millisecondsSinceEpoch}',
        gameId: 'memory_chain',
        gameName: 'Memory Chain',
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

    if (mounted) {
      setState(() => _finished = true);
    }
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('Memory Chain')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_finished) return _buildCompletion();

    if (_questions.isEmpty) {
      return _buildEmptyState();
    }

    final question = _questions[_index];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory Chain'),
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
            const SizedBox(height: 8),
            const Text(
              'Put these moments in the order they happened.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: SmritiTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
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
            const SizedBox(height: 20),
            ...List.generate(
              _currentOrder.length,
              (position) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildMemoryCard(
                  memory: _memoryFor(_currentOrder[position]),
                  position: position,
                  selected: _selectedIndex == position,
                  enabled: !_answered,
                  onTap: () => _selectCard(position),
                ),
              ),
            ),
            if (_showHint)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: SmritiTheme.softGreen,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: SmritiTheme.border),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lightbulb_rounded,
                        color: SmritiTheme.primary),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Hint: start with the earliest date and move forward.',
                        style: TextStyle(fontSize: 14, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            if (_answered)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: SmritiTheme.softGreen,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: SmritiTheme.border),
                ),
                child: Text(
                  _dontKnow
                      ? 'That is okay. We can come back to this memory later.'
                      : 'Great! You put the memories in the right order.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: SmritiTheme.primaryDark,
                  ),
                ),
              ),
            if (!_answered)
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: _submitOrder,
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text(
                    'Check Order',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            if (!_answered)
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _dontKnowPressed,
                  icon: const Icon(Icons.help_outline_rounded),
                  label: const Text("I don't know"),
                ),
              )
            else
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
        ),
      ),
    );
  }

  Widget _buildMemoryCard({
    required Memory? memory,
    required int position,
    required bool selected,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final image = memory == null ? null : _imageFor(memory);

    return Material(
      color: SmritiTheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? SmritiTheme.primary
                  : SmritiTheme.border,
              width: selected ? 2.5 : 1,
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
                    ? Center(
                        child: Text(
                          '${position + 1}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: SmritiTheme.primary,
                          ),
                        ),
                      )
                    : Image(image: image, fit: BoxFit.cover),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      memory?.title ?? 'Memory unavailable',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: SmritiTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              CircleAvatar(
                radius: 17,
                backgroundColor: SmritiTheme.softGreen,
                child: Text(
                  '${position + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: SmritiTheme.primaryDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Scaffold(
      appBar: AppBar(title: const Text('Memory Chain')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.timeline_rounded,
                size: 80,
                color: SmritiTheme.primary,
              ),
              const SizedBox(height: 18),
              const Text(
                'Add at least 3 memories to play Memory Chain.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: SmritiTheme.primaryDark,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Albums, related memories and dates are used to build the sequences.',
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
      appBar: AppBar(title: const Text('Memory Chain Complete')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 30),
          children: [
            const Icon(
              Icons.celebration_rounded,
              size: 78,
              color: SmritiTheme.primary,
            ),
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
            const SizedBox(height: 8),
            Text(
              'You completed $total memory sequences.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                color: SmritiTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            _scoreCard('Score', '$_score / $total'),
            const SizedBox(height: 10),
            _scoreCard('Accuracy', '$accuracy%'),
            const SizedBox(height: 10),
            _scoreCard('I don\'t know', '$_dontKnowAnswers'),
            const SizedBox(height: 10),
            _scoreCard('Difficulty', _difficulty),
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
                label: const Text(
                  'Play Again',
                  style: TextStyle(fontSize: 18),
                ),
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
