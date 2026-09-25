import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import '../data/cognitive_session_store.dart';
import '../data/memory_enhancement_store.dart';
import '../data/memory_store.dart';
import '../models/cognitive_session.dart';
import '../models/memory.dart';
import '../theme/smriti_theme.dart';

class PicturePuzzleGame extends StatefulWidget {
  const PicturePuzzleGame({super.key});

  @override
  State<PicturePuzzleGame> createState() => _PicturePuzzleGameState();
}

class _PicturePuzzleGameState extends State<PicturePuzzleGame> {
  final MemoryStore _memoryStore = MemoryStore.instance;
  final MemoryEnhancementStore _enhancementStore =
      MemoryEnhancementStore.instance;
  final CognitiveSessionStore _sessionStore = CognitiveSessionStore.instance;
  final Random _random = Random();

  bool _loading = true;
  bool _finished = false;
  bool _solved = false;
  bool _dontKnow = false;

  String _difficulty = 'Easy';
  List<Memory> _imageMemories = [];
  List<Memory> _queue = [];
  int _index = 0;
  int _score = 0;
  int _dontKnowAnswers = 0;
  int _incorrectAnswers = 0;
  int _moves = 0;
  int _gridSize = 3;

  List<int> _tiles = [];
  int? _selectedTile;

  DateTime? _sessionStartedAt;
  DateTime? _puzzleStartedAt;
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
      _sessionStore.initialize(),
    ]);

    if (!mounted) return;

    _determineDifficulty();
    _configureDifficulty();
    _sessionStartedAt = DateTime.now();
    _imageMemories = _memoryStore.memories.where(_hasUsableImage).toList();

    setState(() => _loading = false);
    _prepareGame();
  }

  bool _hasUsableImage(Memory memory) {
    final path = memory.imageUrl;
    if (path == null || path.isEmpty) return false;
    return File(path).existsSync();
  }

  void _determineDifficulty() {
    final sessions = _sessionStore.sessionsForGame('picture_puzzle');
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

  void _configureDifficulty() {
    // Keep the visual puzzle consistently 3×3.
    // Difficulty still adapts through the number of puzzles and performance history.
    _gridSize = 3;
  }

  int get _questionLimit => switch (_difficulty) {
        'Standard' => 4,
        'Challenging' => 5,
        _ => 3,
      };

  void _prepareGame() {
    if (_imageMemories.isEmpty) {
      setState(() => _queue = []);
      return;
    }

    final shuffled = List<Memory>.from(_imageMemories)..shuffle(_random);
    final count = min(_questionLimit, shuffled.length);

    setState(() {
      _queue = shuffled.take(count).toList();
      _index = 0;
      _score = 0;
      _dontKnowAnswers = 0;
      _incorrectAnswers = 0;
      _finished = false;
    });

    _loadPuzzle();
  }

  void _loadPuzzle() {
    if (_index >= _queue.length) {
      _saveSessionAndFinish();
      return;
    }

    final total = _gridSize * _gridSize;
    final tiles = List<int>.generate(total, (index) => index);

    do {
      tiles.shuffle(_random);
    } while (_isSolved(tiles) && total > 1);

    setState(() {
      _tiles = tiles;
      _selectedTile = null;
      _solved = false;
      _dontKnow = false;
      _moves = 0;
      _puzzleStartedAt = DateTime.now();
    });
  }

  bool _isSolved(List<int> tiles) {
    for (var i = 0; i < tiles.length; i++) {
      if (tiles[i] != i) return false;
    }
    return true;
  }

  Future<void> _tapTile(int index) async {
    if (_solved || _dontKnow) return;

    if (_selectedTile == null) {
      setState(() => _selectedTile = index);
      return;
    }

    if (_selectedTile == index) {
      setState(() => _selectedTile = null);
      return;
    }

    final first = _selectedTile!;
    final next = List<int>.from(_tiles);
    final temp = next[first];
    next[first] = next[index];
    next[index] = temp;

    final solved = _isSolved(next);

    setState(() {
      _tiles = next;
      _moves++;
      _selectedTile = null;
      if (solved) {
        _solved = true;
        _score++;
      }
    });

    if (solved) {
      _questionDurationsMs.add(
        DateTime.now()
            .difference(_puzzleStartedAt ?? DateTime.now())
            .inMilliseconds,
      );
      await _enhancementStore.recordInteraction(
        _queue[_index].id,
        correct: true,
      );
    }
  }

  Future<void> _dontKnowPressed() async {
    if (_solved || _dontKnow) return;

    _questionDurationsMs.add(
      DateTime.now()
          .difference(_puzzleStartedAt ?? DateTime.now())
          .inMilliseconds,
    );

    setState(() {
      _dontKnow = true;
      _dontKnowAnswers++;
    });

    await _enhancementStore.recordInteraction(
      _queue[_index].id,
      dontKnow: true,
    );
  }

  void _shuffleCurrentPuzzle() {
    if (_solved || _dontKnow) return;
    final next = List<int>.from(_tiles)..shuffle(_random);
    if (_isSolved(next) && next.length > 1) {
      if (next.length >= 2) {
        final temp = next[0];
        next[0] = next[1];
        next[1] = temp;
      }
    }
    setState(() {
      _tiles = next;
      _selectedTile = null;
      _moves++;
    });
  }

  Future<void> _next() async {
    if (!_solved && !_dontKnow) return;
    _index++;
    if (_index >= _queue.length) {
      await _saveSessionAndFinish();
    } else {
      _loadPuzzle();
    }
  }

  Future<void> _saveSessionAndFinish() async {
    if (_sessionSaved) return;
    _sessionSaved = true;

    final started = _sessionStartedAt ?? DateTime.now();
    await _sessionStore.addSession(
      CognitiveSession(
        id: 'picture_puzzle_${DateTime.now().millisecondsSinceEpoch}',
        gameId: 'picture_puzzle',
        gameName: 'Picture Puzzle',
        startedAt: started,
        durationSeconds: DateTime.now().difference(started).inSeconds,
        totalQuestions: _queue.length,
        attempts: _score + _dontKnowAnswers,
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

  ImageProvider? _imageFor(Memory memory) {
    final path = memory.imageUrl;
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    return FileImage(file);
  }

  void _showMemoryPreview() {
    final memory = _queue[_index];
    final image = _imageFor(memory);
    if (image == null) return;

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Memory Preview'),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image(image: image, fit: BoxFit.cover),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('Picture Puzzle')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_finished) return _buildCompletion();
    if (_queue.isEmpty) return _buildEmptyState();

    final memory = _queue[_index];
    final image = _imageFor(memory);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Picture Puzzle'),
        actions: [
          IconButton(
            tooltip: 'Preview memory',
            onPressed: _showMemoryPreview,
            icon: const Icon(Icons.visibility_rounded),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Text(
                '${_index + 1}/${_queue.length}',
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
              memory.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: SmritiTheme.primaryDark,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap two pieces to swap them and rebuild the 3×3 picture.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: SmritiTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                'Difficulty: $_difficulty • Moves: $_moves',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: SmritiTheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (image != null)
              LayoutBuilder(
                builder: (context, constraints) {
                  final boardSize = min(constraints.maxWidth, 360.0);
                  const gap = 2.0;
                  final tileSize =
                      (boardSize - gap * (_gridSize - 1)) / _gridSize;

                  return Center(
                    child: SizedBox(
                      width: boardSize,
                      height: boardSize,
                      child: GridView.builder(
                        padding: EdgeInsets.zero,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _tiles.length,
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _gridSize,
                          crossAxisSpacing: 2,
                          mainAxisSpacing: 2,
                        ),
                        itemBuilder: (context, index) {
                          final tileId = _tiles[index];
                          final row = tileId ~/ _gridSize;
                          final col = tileId % _gridSize;
                          final selected = _selectedTile == index;

                          final sourceCellSize = boardSize / _gridSize;

                          return GestureDetector(
                            onTap: () => _tapTile(index),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(
                                  color: selected
                                      ? SmritiTheme.primary
                                      : SmritiTheme.surface,
                                  width: selected ? 3 : 1,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Positioned(
                                    left: -col * sourceCellSize,
                                    top: -row * sourceCellSize,
                                    width: boardSize,
                                    height: boardSize,
                                    child: Image(
                                      image: image,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  if (selected)
                                    Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: SmritiTheme.primary,
                                          width: 3,
                                        ),
                                        borderRadius: BorderRadius.circular(7),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 18),
            if (_solved)
              _statusCard(
                icon: Icons.check_circle_rounded,
                text: 'Beautiful! You rebuilt the memory.',
              )
            else if (_dontKnow)
              _statusCard(
                icon: Icons.favorite_rounded,
                text: 'That is okay. We can revisit this memory later.',
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        (_solved || _dontKnow) ? null : _shuffleCurrentPuzzle,
                    icon: const Icon(Icons.shuffle_rounded),
                    label: const Text('Shuffle'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        (_solved || _dontKnow) ? null : _showMemoryPreview,
                    icon: const Icon(Icons.lightbulb_outline_rounded),
                    label: const Text('Hint'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (!_solved && !_dontKnow)
              SizedBox(
                height: 52,
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
                    _index + 1 >= _queue.length ? 'Finish' : 'Next Picture',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusCard({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: SmritiTheme.softGreen,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SmritiTheme.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: SmritiTheme.primary, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: SmritiTheme.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Scaffold(
      appBar: AppBar(title: const Text('Picture Puzzle')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.extension_rounded,
                  size: 82, color: SmritiTheme.primary),
              const SizedBox(height: 18),
              const Text(
                'Add a memory with a photo to play Picture Puzzle.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: SmritiTheme.primaryDark,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'SMRITI uses your real memories instead of generic puzzle images.',
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
    final total = _queue.length;
    final accuracy = total == 0 ? 0 : (_score / total * 100).round();

    return Scaffold(
      appBar: AppBar(title: const Text('Puzzle Complete')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 30),
          children: [
            const Icon(Icons.celebration_rounded,
                size: 78, color: SmritiTheme.primary),
            const SizedBox(height: 18),
            const Text(
              'Great work! ❤️',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: SmritiTheme.primaryDark,
              ),
            ),
            const SizedBox(height: 22),
            _scoreCard('Solved', '$_score / $total'),
            const SizedBox(height: 10),
            _scoreCard('Accuracy', '$accuracy%'),
            const SizedBox(height: 10),
            _scoreCard("I don't know", '$_dontKnowAnswers'),
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
