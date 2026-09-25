
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import '../data/family_store.dart';
import '../data/memory_store.dart';
import '../models/family_member.dart';
import '../models/memory.dart';
import '../data/cognitive_session_store.dart';
import '../models/cognitive_session.dart';
import '../theme/smriti_theme.dart';

class WhoIsThisGame extends StatefulWidget {
  const WhoIsThisGame({super.key});

  @override
  State<WhoIsThisGame> createState() =>
      _WhoIsThisGameState();
}

class _WhoIsThisGameState
    extends State<WhoIsThisGame> {
  final FamilyStore _familyStore =
      FamilyStore.instance;

  final MemoryStore _memoryStore =
      MemoryStore.instance;

  final CognitiveSessionStore _sessionStore =
      CognitiveSessionStore.instance;

  final Random _random = Random();

  List<FamilyMember> _members = [];
  List<FamilyMember> _questionOrder = [];

  bool _isLoading = true;

  List<FamilyMember> _options = [];

  int _currentQuestion = 0;
  int _score = 0;
  int _incorrectAnswers = 0;
  int _dontKnowAnswers = 0;
  int _memoryRememberedCount = 0;
  int _memoryNotSureCount = 0;

  // Adaptive activity level.
  String _difficulty = 'Easy';

  DateTime? _sessionStartedAt;
  DateTime? _questionStartedAt;
  final List<int> _questionDurationsMs = [];
  bool _sessionSaved = false;

  bool _answered = false;
  bool _isCorrect = false;
  bool _showHint = false;
  bool _gameFinished = false;
  bool _didNotKnow = false;

  String? _selectedAnswerId;

  // ============================================================
  // MEMORY CONNECTION STATE
  // ============================================================

  Memory? _connectedMemory;

  bool _showMemoryConnection = false;

  bool _memoryResponseGiven = false;

  @override
  void initState() {
    super.initState();

    _initializeGame();
  }

  Future<void> _initializeGame() async {
    // Initialize both stores before using their data.
    await Future.wait([
      _familyStore.initialize(),
      _memoryStore.initialize(),
      _sessionStore.initialize(),
    ]);

    if (!mounted) {
      return;
    }

    final members = _familyStore.members;

    _determineDifficulty();

    _sessionStartedAt = DateTime.now();

    setState(() {
      _members = List<FamilyMember>.from(members);
      _isLoading = false;
    });

    await _prepareGame();
  }

  // ============================================================
  // ADAPTIVE DIFFICULTY
  // ============================================================

  void _determineDifficulty() {
    final sessions = _sessionStore
        .sessionsForGame('who_is_this');

    // Until there are enough sessions to establish
    // a meaningful personal baseline, stay gentle.
    if (sessions.length < 3) {
      _difficulty = 'Easy';
      return;
    }

    // Use the 3 most recent completed sessions.
    final recentSessions = sessions.take(3).toList();

    final averageAccuracy =
        recentSessions.fold<double>(
          0,
              (sum, session) =>
          sum + session.accuracy,
        ) /
            recentSessions.length;

    if (averageAccuracy < 0.60) {
      _difficulty = 'Easy';
    } else if (averageAccuracy <= 0.85) {
      _difficulty = 'Standard';
    } else {
      _difficulty = 'Challenging';
    }
  }

  int _questionLimitForDifficulty() {
    switch (_difficulty) {
      case 'Standard':
        return 4;
      case 'Challenging':
        return 5;
      case 'Easy':
      default:
        return 3;
    }
  }

  int _optionCountForDifficulty() {
    switch (_difficulty) {
      case 'Standard':
      case 'Challenging':
        return _members.length == 2 ? 2 : 3;
      case 'Easy':
      default:
        return 2;
    }
  }

  // ============================================================
  // PREPARE GAME
  // ============================================================

  Future<void> _prepareGame() async {
    if (_members.length < 2) {
      return;
    }

    final shuffled =
    List<FamilyMember>.from(_members)
      ..shuffle(_random);

    final questionLimit =
    _questionLimitForDifficulty();

    final questionCount =
    min(questionLimit, shuffled.length);

    _questionOrder =
        shuffled.take(questionCount).toList();

    await _loadQuestion();
  }
  // ============================================================
  // LOAD QUESTION
  // ============================================================

  Future<void> _loadQuestion() async {
    if (_currentQuestion >=
        _questionOrder.length) {
      await _saveSession();

      if (!mounted) {
        return;
      }

      setState(() {
        _gameFinished = true;
      });

      return;
    }

    final correctMember =
    _questionOrder[_currentQuestion];

    final wrongMembers =
    _members
        .where(
          (member) =>
      member.id !=
          correctMember.id,
    )
        .toList()
      ..shuffle(_random);

    // Adaptive number of choices.
    final optionCount =
    _optionCountForDifficulty();

    final wrongCount = min(
      optionCount - 1,
      wrongMembers.length,
    );

    final options = [
      correctMember,
      ...wrongMembers.take(wrongCount),
    ]..shuffle(_random);

    _questionStartedAt = DateTime.now();

    setState(() {
      _options = options;

      _answered = false;
      _isCorrect = false;
      _showHint = false;
      _didNotKnow = false;
      _selectedAnswerId = null;

      _connectedMemory = null;
      _showMemoryConnection = false;
      _memoryResponseGiven = false;
    });
  }

  // ============================================================
  // SELECT ANSWER
  // ============================================================

  void _selectAnswer(
      FamilyMember selectedMember,
      ) {
    if (_answered) {
      return;
    }

    final correctMember =
    _questionOrder[_currentQuestion];

    final correct =
        selectedMember.id ==
            correctMember.id;

    _recordQuestionTime();

    setState(() {
      _answered = true;
      _isCorrect = correct;
      _selectedAnswerId =
          selectedMember.id;

      if (correct) {
        _score++;
      } else {
        _incorrectAnswers++;
      }
    });

    // Only connect a memory when the
    // patient correctly identifies the person.
    if (correct) {
      _prepareMemoryConnection(
        correctMember,
      );
    }
  }

  // ============================================================
  // I DON'T KNOW
  // ============================================================

  void _selectDontKnow() {
    if (_answered) {
      return;
    }

    _recordQuestionTime();

    setState(() {
      _answered = true;
      _isCorrect = false;
      _didNotKnow = true;
      _selectedAnswerId = null;
      _dontKnowAnswers++;

      _showMemoryConnection = false;
      _connectedMemory = null;
      _memoryResponseGiven = false;
    });
  }

  // ============================================================
  // PREPARE MEMORY CONNECTION
  // ============================================================

  void _prepareMemoryConnection(
      FamilyMember member,
      ) {
    final memories =
    _memoryStore.memoriesForPerson(
      member.name,
    );

    if (memories.isEmpty) {
      return;
    }

    final memory =
    memories[_random.nextInt(
      memories.length,
    )];

    setState(() {
      _connectedMemory = memory;
      _showMemoryConnection = true;
      _memoryResponseGiven = false;
    });
  }

  // ============================================================
  // MEMORY RESPONSE
  // ============================================================

  void _respondToMemory(bool remembered) {
    if (_memoryResponseGiven) {
      return;
    }

    setState(() {
      _memoryResponseGiven = true;

      if (remembered) {
        _memoryRememberedCount++;
      } else {
        _memoryNotSureCount++;
      }
    });
  }

  // ============================================================
  // SESSION TRACKING
  // ============================================================

  void _recordQuestionTime() {
    if (_questionStartedAt == null) {
      return;
    }

    final elapsed =
        DateTime.now().difference(_questionStartedAt!).inMilliseconds;

    _questionDurationsMs.add(elapsed);
    _questionStartedAt = null;
  }

  Future<void> _saveSession() async {
    if (_sessionSaved) {
      return;
    }

    _sessionSaved = true;

    final startedAt = _sessionStartedAt ?? DateTime.now();
    final durationSeconds =
        DateTime.now().difference(startedAt).inSeconds;

    final totalQuestions = _questionOrder.length;
    final attempts =
        _score + _incorrectAnswers + _dontKnowAnswers;

    final session = CognitiveSession(
      id: 'session_${DateTime.now().millisecondsSinceEpoch}',
      gameId: 'who_is_this',
      gameName: 'Who Is This?',
      startedAt: startedAt,
      durationSeconds: durationSeconds,
      totalQuestions: totalQuestions,
      attempts: attempts,
      correctAnswers: _score,
      incorrectAnswers: _incorrectAnswers,
      dontKnowAnswers: _dontKnowAnswers,
      memoryRememberedCount: _memoryRememberedCount,
      memoryNotSureCount: _memoryNotSureCount,
      questionDurationsMs: List<int>.from(_questionDurationsMs),
      completed: true,
    );

    await _sessionStore.addSession(session);
  }

  // ============================================================
  // NEXT QUESTION
  // ============================================================

  Future<void> _nextQuestion() async {
    if (!_answered) {
      return;
    }

    // Last question.
    if (_currentQuestion + 1 >= _questionOrder.length) {
      await _saveSession();

      if (!mounted) {
        return;
      }

      setState(() {
        _gameFinished = true;
      });

      return;
    }

    // Move to the next question.
    setState(() {
      _currentQuestion++;
    });

    await _loadQuestion();
  }
  // ============================================================
  // GET IMAGE
  // ============================================================

  ImageProvider? _getImage(
      FamilyMember member,
      ) {
    final path = member.photoUrl;

    if (path == null ||
        path.isEmpty) {
      return null;
    }

    final file = File(path);

    if (!file.existsSync()) {
      return null;
    }

    return FileImage(file);
  }

  // ============================================================
  // GET MEMORY IMAGE
  // ============================================================

  ImageProvider? _getMemoryImage(
      Memory memory,
      ) {
    final path = memory.imageUrl;

    if (path == null ||
        path.isEmpty) {
      return null;
    }

    final file = File(path);

    if (!file.existsSync()) {
      return null;
    }

    return FileImage(file);
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Who Is This?'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_gameFinished) {
      return _buildCompletionScreen();
    }

    if (_members.length < 2) {
      return _buildNotEnoughPeople();
    }

    final correctMember =
    _questionOrder[_currentQuestion];

    return Scaffold(
      appBar: AppBar(
        title:
        const Text('Who Is This?'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
          const EdgeInsets.fromLTRB(
            20,
            10,
            20,
            30,
          ),
          child: Column(
            children: [
              // =================================================
              // PROGRESS
              // =================================================

              Row(
                mainAxisAlignment:
                MainAxisAlignment
                    .spaceBetween,
                children: [
                  Text(
                    'Question '
                        '${_currentQuestion + 1} '
                        'of '
                        '${_questionOrder.length}',
                    style:
                    const TextStyle(
                      fontSize: 16,
                      fontWeight:
                      FontWeight.w600,
                      color:
                      SmritiTheme
                          .textSecondary,
                    ),
                  ),
                  Text(
                    'Score: $_score',
                    style:
                    const TextStyle(
                      fontSize: 16,
                      fontWeight:
                      FontWeight.bold,
                      color:
                      SmritiTheme
                          .primaryDark,
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 8,
              ),

              Text(
                'Activity level: $_difficulty',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: SmritiTheme.textSecondary,
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              ClipRRect(
                borderRadius:
                BorderRadius.circular(
                  20,
                ),
                child:
                LinearProgressIndicator(
                  value:
                  (_currentQuestion + 1) /
                      _questionOrder.length,
                  minHeight: 8,
                ),
              ),

              const SizedBox(
                height: 28,
              ),

              // =================================================
              // QUESTION
              // =================================================

              const Text(
                'Who is this?',
                textAlign:
                TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight:
                  FontWeight.bold,
                  color:
                  SmritiTheme.primaryDark,
                ),
              ),

              const SizedBox(
                height: 8,
              ),

              const Text(
                'Take your time. '
                    'There is no hurry. ❤️',
                textAlign:
                TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  color:
                  SmritiTheme
                      .textSecondary,
                ),
              ),

              const SizedBox(
                height: 24,
              ),

              // =================================================
              // MAIN PHOTO
              // =================================================

              _buildPersonDisplay(
                correctMember,
              ),

              const SizedBox(
                height: 22,
              ),

              // =================================================
              // HINT
              // =================================================

              if (!_answered &&
                  !_showHint)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showHint = true;
                    });
                  },
                  icon: const Icon(
                    Icons
                        .lightbulb_outline_rounded,
                  ),
                  label: const Text(
                    'Need a hint?',
                  ),
                ),

              if (_showHint) ...[
                Container(
                  width:
                  double.infinity,
                  padding:
                  const EdgeInsets.all(
                    16,
                  ),
                  decoration:
                  BoxDecoration(
                    color:
                    SmritiTheme
                        .softGreen,
                    borderRadius:
                    BorderRadius.circular(
                      18,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons
                            .lightbulb_rounded,
                        color:
                        SmritiTheme
                            .primary,
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      Expanded(
                        child: Text(
                          'Hint: This person is your '
                              '${correctMember.relationship.toLowerCase()}.',
                          style:
                          const TextStyle(
                            fontSize: 16,
                            fontWeight:
                            FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  height: 14,
                ),
              ],

              // =================================================
              // CHOOSE PERSON
              // =================================================

              const Text(
                'Choose the person',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight:
                  FontWeight.w600,
                  color:
                  SmritiTheme.textPrimary,
                ),
              ),

              const SizedBox(
                height: 14,
              ),

              ..._options.map(
                    (member) => Padding(
                  padding:
                  const EdgeInsets.only(
                    bottom: 12,
                  ),
                  child:
                  _buildAnswerButton(
                    member,
                    correctMember,
                  ),
                ),
              ),

              // =================================================
              // I DON'T KNOW
              // =================================================

              if (!_answered)
                SizedBox(
                  width:
                  double.infinity,
                  height: 54,
                  child:
                  OutlinedButton.icon(
                    onPressed:
                    _selectDontKnow,
                    icon: const Icon(
                      Icons
                          .help_outline_rounded,
                    ),
                    label: const Text(
                      "I don't know",
                      style: TextStyle(
                        fontSize: 17,
                      ),
                    ),
                  ),
                ),

              // =================================================
              // FEEDBACK
              // =================================================

              if (_answered) ...[
                const SizedBox(
                  height: 8,
                ),

                _buildFeedback(
                  correctMember,
                ),

                // =================================================
                // MEMORY CONNECTION
                // =================================================

                if (_showMemoryConnection &&
                    _connectedMemory !=
                        null) ...[
                  const SizedBox(
                    height: 20,
                  ),

                  _buildMemoryConnection(
                    _connectedMemory!,
                    correctMember,
                  ),
                ],

                const SizedBox(
                  height: 18,
                ),

                SizedBox(
                  width:
                  double.infinity,
                  height: 56,
                  child:
                  FilledButton.icon(
                    onPressed:
                    _nextQuestion,
                    icon: const Icon(
                      Icons
                          .arrow_forward_rounded,
                    ),
                    label: Text(
                      _currentQuestion + 1 >=
                          _questionOrder
                              .length
                          ? 'Finish'
                          : 'Next Question',
                      style:
                      const TextStyle(
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PERSON DISPLAY
  // ============================================================

  Widget _buildPersonDisplay(
      FamilyMember member,
      ) {
    final image =
    _getImage(member);

    return Container(
      width:
      double.infinity,
      padding:
      const EdgeInsets.symmetric(
        vertical: 24,
        horizontal: 20,
      ),
      decoration:
      BoxDecoration(
        color:
        SmritiTheme.softGreen,
        borderRadius:
        BorderRadius.circular(
          28,
        ),
        border: Border.all(
          color:
          SmritiTheme.border,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 230,
            height: 230,
            decoration:
            BoxDecoration(
              color:
              SmritiTheme.surface,
              borderRadius:
              BorderRadius.circular(
                24,
              ),
            ),
            clipBehavior:
            Clip.antiAlias,
            child: image != null
                ? Image(
              image: image,
              fit: BoxFit.cover,
            )
                : Center(
              child:
              CircleAvatar(
                radius: 62,
                backgroundColor:
                SmritiTheme
                    .softGreen,
                child: Text(
                  member.name
                      .substring(
                    0,
                    1,
                  )
                      .toUpperCase(),
                  style:
                  const TextStyle(
                    fontSize: 52,
                    fontWeight:
                    FontWeight.bold,
                    color:
                    SmritiTheme
                        .primary,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(
            height: 16,
          ),

          const Text(
            'A familiar person',
            style: TextStyle(
              fontSize: 16,
              color:
              SmritiTheme
                  .textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ANSWER BUTTON
  // ============================================================

  Widget _buildAnswerButton(
      FamilyMember member,
      FamilyMember correctMember,
      ) {
    final bool isCorrect =
        member.id ==
            correctMember.id;

    final bool isSelected =
        member.id ==
            _selectedAnswerId;

    final bool showCorrect =
        _answered && isCorrect;

    final bool showWrong =
        _answered &&
            isSelected &&
            !isCorrect;

    IconData? trailingIcon;

    if (showCorrect) {
      trailingIcon =
          Icons.check_circle_rounded;
    } else if (showWrong) {
      trailingIcon =
          Icons.cancel_rounded;
    }

    final image =
    _getImage(member);

    return SizedBox(
      width:
      double.infinity,
      height: 68,
      child: OutlinedButton(
        onPressed: _answered
            ? null
            : () {
          _selectAnswer(
            member,
          );
        },
        style:
        OutlinedButton.styleFrom(
          alignment:
          Alignment.centerLeft,
          padding:
          const EdgeInsets.symmetric(
            horizontal: 16,
          ),
          side: BorderSide(
            color: showCorrect ||
                showWrong
                ? SmritiTheme.primary
                : SmritiTheme.border,
            width: showCorrect ||
                showWrong
                ? 2
                : 1,
          ),
          shape:
          RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(
              18,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: SmritiTheme.softGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                color: SmritiTheme.primary,
              ),
            ),

            const SizedBox(
              width: 14,
            ),

            Expanded(
              child: Text(
                member.name,
                style:
                const TextStyle(
                  fontSize: 18,
                  fontWeight:
                  FontWeight.w600,
                  color:
                  SmritiTheme
                      .textPrimary,
                ),
              ),
            ),

            if (trailingIcon !=
                null)
              Icon(
                trailingIcon,
                size: 28,
                color:
                SmritiTheme.primary,
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FEEDBACK
  // ============================================================

  Widget _buildFeedback(
      FamilyMember correctMember,
      ) {
    String title;
    String message;
    IconData icon;

    if (_didNotKnow) {
      title =
      'That\'s okay. ❤️';

      message =
      'The person in the picture is '
          '${correctMember.name}.';

      icon =
          Icons.favorite_rounded;
    } else if (_isCorrect) {
      title =
      'Wonderful! ❤️';

      message =
      'You recognized '
          '${correctMember.name}!';

      icon =
          Icons.favorite_rounded;
    } else {
      title =
      'That\'s okay. ❤️';

      message =
      'The person in the picture is '
          '${correctMember.name}. '
          'Let\'s try the next one.';

      icon =
          Icons
              .sentiment_satisfied_alt_rounded;
    }

    return Container(
      width:
      double.infinity,
      padding:
      const EdgeInsets.all(18),
      decoration:
      BoxDecoration(
        color:
        SmritiTheme.softGreen,
        borderRadius:
        BorderRadius.circular(
          20,
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 32,
            color:
            SmritiTheme.primary,
          ),

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                  const TextStyle(
                    fontSize: 19,
                    fontWeight:
                    FontWeight.bold,
                    color:
                    SmritiTheme
                        .primaryDark,
                  ),
                ),

                const SizedBox(
                  height: 6,
                ),

                Text(
                  message,
                  style:
                  const TextStyle(
                    fontSize: 16,
                    height: 1.35,
                    color:
                    SmritiTheme
                        .textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MEMORY CONNECTION
  // ============================================================

  Widget _buildMemoryConnection(
      Memory memory,
      FamilyMember member,
      ) {
    final image =
    _getMemoryImage(memory);

    return Container(
      width:
      double.infinity,
      decoration:
      BoxDecoration(
        color:
        SmritiTheme.surface,
        borderRadius:
        BorderRadius.circular(
          24,
        ),
        border: Border.all(
          color:
          SmritiTheme.border,
        ),
      ),
      clipBehavior:
      Clip.antiAlias,
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.stretch,
        children: [
          // =====================================================
          // HEADER
          // =====================================================

          Padding(
            padding:
            const EdgeInsets.fromLTRB(
              20,
              20,
              20,
              12,
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.favorite_rounded,
                  size: 34,
                  color:
                  SmritiTheme.primary,
                ),

                const SizedBox(
                  height: 8,
                ),

                const Text(
                  'A special memory ❤️',
                  textAlign:
                  TextAlign.center,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight:
                    FontWeight.bold,
                    color:
                    SmritiTheme
                        .primaryDark,
                  ),
                ),

                const SizedBox(
                  height: 6,
                ),

                Text(
                  'A moment with ${member.name}',
                  textAlign:
                  TextAlign.center,
                  style:
                  const TextStyle(
                    fontSize: 15,
                    color:
                    SmritiTheme
                        .textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // =====================================================
          // MEMORY IMAGE
          // =====================================================

          if (image != null)
            Padding(
              padding:
              const EdgeInsets.symmetric(
                horizontal: 16,
              ),
              child: ClipRRect(
                borderRadius:
                BorderRadius.circular(
                  18,
                ),
                child: Image(
                  image: image,
                  height: 190,
                  fit: BoxFit.cover,
                ),
              ),
            ),

          // =====================================================
          // MEMORY DETAILS
          // =====================================================

          Padding(
            padding:
            const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  memory.title,
                  textAlign:
                  TextAlign.center,
                  style:
                  const TextStyle(
                    fontSize: 22,
                    fontWeight:
                    FontWeight.bold,
                    color:
                    SmritiTheme
                        .textPrimary,
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                Text(
                  memory.description,
                  textAlign:
                  TextAlign.center,
                  style:
                  const TextStyle(
                    fontSize: 16,
                    height: 1.4,
                    color:
                    SmritiTheme
                        .textSecondary,
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                Text(
                  '${memory.date} • '
                      '${memory.location}',
                  textAlign:
                  TextAlign.center,
                  style:
                  const TextStyle(
                    fontSize: 14,
                    color:
                    SmritiTheme
                        .textSecondary,
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),

                const Text(
                  'Do you remember this moment?',
                  textAlign:
                  TextAlign.center,
                  style:
                  TextStyle(
                    fontSize: 18,
                    fontWeight:
                    FontWeight.w600,
                    color:
                    SmritiTheme
                        .textPrimary,
                  ),
                ),

                const SizedBox(
                  height: 14,
                ),

                // =================================================
                // MEMORY RESPONSE BUTTONS
                // =================================================

                Row(
                  children: [
                    Expanded(
                      child:
                      FilledButton.icon(
                        onPressed:
                        _memoryResponseGiven
                            ? null
                            : () => _respondToMemory(true),
                        icon:
                        const Icon(
                          Icons
                              .favorite_rounded,
                        ),
                        label:
                        const Text(
                          'Yes, I remember',
                          textAlign:
                          TextAlign.center,
                        ),
                      ),
                    ),

                    const SizedBox(
                      width: 10,
                    ),

                    Expanded(
                      child:
                      OutlinedButton.icon(
                        onPressed:
                        _memoryResponseGiven
                            ? null
                            : () => _respondToMemory(false),
                        icon:
                        const Icon(
                          Icons
                              .help_outline_rounded,
                        ),
                        label:
                        const Text(
                          'Not sure',
                          textAlign:
                          TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),

                // =================================================
                // RESPONSE MESSAGE
                // =================================================

                if (_memoryResponseGiven) ...[
                  const SizedBox(
                    height: 14,
                  ),

                  const Text(
                    'Thank you for sharing this '
                        'moment with SMRITI. ❤️',
                    textAlign:
                    TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      color:
                      SmritiTheme
                          .textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // NOT ENOUGH FAMILY MEMBERS
  // ============================================================

  Widget _buildNotEnoughPeople() {
    return Scaffold(
      appBar: AppBar(
        title:
        const Text('Who Is This?'),
      ),
      body: SafeArea(
        child: Padding(
          padding:
          const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: [
              const Icon(
                Icons
                    .family_restroom_rounded,
                size: 90,
                color:
                SmritiTheme.primary,
              ),

              const SizedBox(
                height: 24,
              ),

              const Text(
                'Let\'s add some family members first.',
                textAlign:
                TextAlign.center,
                style:
                TextStyle(
                  fontSize: 25,
                  fontWeight:
                  FontWeight.bold,
                  color:
                  SmritiTheme
                      .primaryDark,
                ),
              ),

              const SizedBox(
                height: 14,
              ),

              const Text(
                'Who Is This? needs at least '
                    'two family members to create '
                    'recognition questions.',
                textAlign:
                TextAlign.center,
                style:
                TextStyle(
                  fontSize: 17,
                  height: 1.4,
                  color:
                  SmritiTheme
                      .textSecondary,
                ),
              ),

              const SizedBox(
                height: 30,
              ),

              SizedBox(
                width:
                double.infinity,
                height: 54,
                child:
                FilledButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                    );
                  },
                  child:
                  const Text(
                    'Back to Family',
                    style:
                    TextStyle(
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // COMPLETION SCREEN
  // ============================================================

  Widget _buildCompletionScreen() {
    final total =
        _questionOrder.length;

    return Scaffold(
      appBar: AppBar(
        title:
        const Text('Well Done!'),
        automaticallyImplyLeading:
        false,
      ),
      body: SafeArea(
        child: Padding(
          padding:
          const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.favorite_rounded,
                size: 85,
                color:
                SmritiTheme.primary,
              ),

              const SizedBox(
                height: 24,
              ),

              const Text(
                'Well Done! ❤️',
                textAlign:
                TextAlign.center,
                style:
                TextStyle(
                  fontSize: 32,
                  fontWeight:
                  FontWeight.bold,
                  color:
                  SmritiTheme
                      .primaryDark,
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              const Text(
                'You finished today\'s game!',
                textAlign:
                TextAlign.center,
                style:
                TextStyle(
                  fontSize: 19,
                  color:
                  SmritiTheme
                      .textSecondary,
                ),
              ),

              const SizedBox(
                height: 26,
              ),

              Container(
                width:
                double.infinity,
                padding:
                const EdgeInsets.all(
                  22,
                ),
                decoration:
                BoxDecoration(
                  color:
                  SmritiTheme
                      .softGreen,
                  borderRadius:
                  BorderRadius.circular(
                    24,
                  ),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Your session',
                      style:
                      TextStyle(
                        fontSize: 16,
                        color:
                        SmritiTheme
                            .textSecondary,
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    Text(
                      '$_score out of $total',
                      style:
                      const TextStyle(
                        fontSize: 34,
                        fontWeight:
                        FontWeight.bold,
                        color:
                        SmritiTheme
                            .primaryDark,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      'Accuracy: ${total == 0 ? 0 : ((_score / total) * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 16,
                        color: SmritiTheme.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      'Attempts: ${_score + _incorrectAnswers + _dontKnowAnswers}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: SmritiTheme.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      "Don't know: $_dontKnowAnswers",
                      style: const TextStyle(
                        fontSize: 16,
                        color: SmritiTheme.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      'Yes, I remember: $_memoryRememberedCount',
                      style: const TextStyle(
                        fontSize: 16,
                        color: SmritiTheme.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      'Not sure: $_memoryNotSureCount',
                      style: const TextStyle(
                        fontSize: 16,
                        color: SmritiTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              Text(
                'Activity level: $_difficulty',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: SmritiTheme.textSecondary,
                ),
              ),

              const SizedBox(
                height: 24,
              ),

              const Text(
                'Thank you for spending some time '
                    'with SMRITI today. ❤️',
                textAlign:
                TextAlign.center,
                style:
                TextStyle(
                  fontSize: 17,
                  height: 1.4,
                  color:
                  SmritiTheme
                      .textSecondary,
                ),
              ),

              const SizedBox(
                height: 30,
              ),

              SizedBox(
                width:
                double.infinity,
                height: 56,
                child:
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(
                      context,
                    );
                  },
                  icon: const Icon(
                    Icons
                        .arrow_back_rounded,
                  ),
                  label:
                  const Text(
                    'Back to Games',
                    style:
                    TextStyle(
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

