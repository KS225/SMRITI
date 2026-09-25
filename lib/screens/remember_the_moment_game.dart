import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../data/cognitive_session_store.dart';
import '../data/family_store.dart';
import '../data/memory_enhancement_store.dart';
import '../data/memory_store.dart';
import '../models/cognitive_game.dart';
import '../models/cognitive_session.dart';
import '../models/memory.dart';
import '../theme/smriti_theme.dart';
import '../data/memory_question_engine.dart';
import 'memories_screen.dart';
import 'memory_studio_screen.dart';

enum MemoryActivityMode {
  mixed,
  memoryOfDay,
  review,
  newMemories,
  familiar,
  category,
  album,
  person,
  timeline,
  seasonal,
}

extension MemoryActivityModeX on MemoryActivityMode {
  String get title => switch (this) {
    MemoryActivityMode.mixed => 'Mixed Memories',
    MemoryActivityMode.memoryOfDay => 'Memory of the Day',
    MemoryActivityMode.review => 'Review Memories',
    MemoryActivityMode.newMemories => 'New Memories',
    MemoryActivityMode.familiar => 'Familiar Memories',
    MemoryActivityMode.category => 'By Category',
    MemoryActivityMode.album => 'By Album',
    MemoryActivityMode.person => 'With a Family Member',
    MemoryActivityMode.timeline => 'Timeline',
    MemoryActivityMode.seasonal => 'Seasonal Memories',
  };

  String get description => switch (this) {
    MemoryActivityMode.mixed => 'A balanced mix of your saved moments.',
    MemoryActivityMode.memoryOfDay => 'One special memory chosen for today.',
    MemoryActivityMode.review => 'Bring back moments that are due for review.',
    MemoryActivityMode.newMemories => 'Explore memories you have not practiced yet.',
    MemoryActivityMode.familiar => 'Revisit moments that feel familiar.',
    MemoryActivityMode.category => 'Explore one type of memory.',
    MemoryActivityMode.album => 'Explore one memory album or story.',
    MemoryActivityMode.person => 'Focus on memories connected to someone special.',
    MemoryActivityMode.timeline => 'Put life moments into a simple sequence.',
    MemoryActivityMode.seasonal => 'Revisit moments from this time of year.',
  };

  IconData get icon => switch (this) {
    MemoryActivityMode.mixed => Icons.auto_awesome_rounded,
    MemoryActivityMode.memoryOfDay => Icons.today_rounded,
    MemoryActivityMode.review => Icons.refresh_rounded,
    MemoryActivityMode.newMemories => Icons.fiber_new_rounded,
    MemoryActivityMode.familiar => Icons.favorite_rounded,
    MemoryActivityMode.category => Icons.folder_special_rounded,
    MemoryActivityMode.album => Icons.photo_album_rounded,
    MemoryActivityMode.person => Icons.people_alt_rounded,
    MemoryActivityMode.timeline => Icons.timeline_rounded,
    MemoryActivityMode.seasonal => Icons.event_available_rounded,
  };
}

class RememberTheMomentGame extends StatefulWidget {
  final CognitiveGame? game;

  const RememberTheMomentGame({
    super.key,
    this.game,
  });

  @override
  State<RememberTheMomentGame> createState() =>
      _RememberTheMomentGameState();
}

class _RememberTheMomentGameState
    extends State<RememberTheMomentGame> {
  final MemoryStore _memoryStore = MemoryStore.instance;
  final MemoryEnhancementStore _enhancementStore =
      MemoryEnhancementStore.instance;
  final CognitiveSessionStore _sessionStore =
      CognitiveSessionStore.instance;
  final FamilyStore _familyStore = FamilyStore.instance;

  late final MemoryQuestionEngine _questionEngine = MemoryQuestionEngine(
    memoryStore: _memoryStore,
    enhancementStore: _enhancementStore,
  );

  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _tts = FlutterTts();
  final SpeechToText _speech = SpeechToText();
  late final LanguageIdentifier _languageIdentifier =
  LanguageIdentifier(confidenceThreshold: 0.5);
  final TextEditingController _recallController =
  TextEditingController();
  final Random _random = Random();

  bool _loading = true;
  bool _showModes = true;
  bool _gameFinished = false;
  bool _showMemoryIntro = true;
  bool _answered = false;
  bool _correct = false;
  bool _dontKnow = false;
  bool _reflectionGiven = false;
  bool _isListening = false;
  bool _isVoicePlaying = false;
  bool _isSpeaking = false;

  MemoryActivityMode _mode = MemoryActivityMode.mixed;
  String _difficulty = 'Easy';
  String _language = 'en-IN';
  String? _category;
  String? _album;
  String? _person;

  List<Memory> _queue = [];
  int _index = 0;
  int _score = 0;
  int _incorrectCount = 0;
  int _dontKnowCount = 0;
  int _rememberedCount = 0;
  int _notSureCount = 0;
  int _voiceRecallCount = 0;
  int _recallDetailTotal = 0;

  MemoryGameQuestion? _question;
  String? _selectedAnswer;
  String? _voiceTranscript;
  String? _detectedLanguage;
  int _recallDetails = 0;
  int _recallTurn = 0;

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
      _sessionStore.initialize(),
      _familyStore.initialize(),
      _initSpeech(),
      _initTts(),
    ]);

    if (!mounted) return;

    _determineDifficulty();
    setState(() => _loading = false);
  }

  Future<void> _initSpeech() async {
    try {
      await _speech.initialize(
        onStatus: (status) {
          if (mounted) {
            setState(() => _isListening = status == 'listening');
          }
        },
        onError: (_) {
          if (mounted) setState(() => _isListening = false);
        },
      );
    } catch (_) {}
  }

  Future<void> _initTts() async {
    try {
      await _tts.setSpeechRate(0.42);
      await _tts.setVolume(1);
      await _tts.setPitch(1);
      _tts.setStartHandler(() {
        if (mounted) setState(() => _isSpeaking = true);
      });
      _tts.setCompletionHandler(() {
        if (mounted) setState(() => _isSpeaking = false);
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _tts.stop();
    _speech.stop();
    _languageIdentifier.close();
    _recallController.dispose();
    super.dispose();
  }

  void _determineDifficulty() {
    final sessions = _sessionStore.sessionsForGame(
      'remember_the_moment',
    );

    if (sessions.length < 3) {
      _difficulty = 'Easy';
      return;
    }

    final recent = sessions.take(3).toList();
    final averageAccuracy = recent.fold<double>(
      0,
          (sum, item) => sum + item.accuracy,
    ) /
        recent.length;

    _difficulty = averageAccuracy < 0.60
        ? 'Easy'
        : averageAccuracy <= 0.85
        ? 'Standard'
        : 'Challenging';
  }

  int get _questionLimit => switch (_difficulty) {
    'Standard' => 4,
    'Challenging' => 5,
    _ => 3,
  };

  List<String> get _categories {
    final data = _memoryStore.memories.map(
          (memory) => _enhancementStore.enhancementFor(memory.id).category,
    );
    return _enhancementStore.categoriesForMemoryData(data);
  }

  List<String> get _albums => _enhancementStore.allAlbums;

  List<String> get _people {
    final result = <String>{};
    for (final member in _familyStore.members) {
      if (member.name.trim().isNotEmpty) result.add(member.name.trim());
    }
    for (final memory in _memoryStore.memories) {
      result.addAll(memory.people.where((p) => p.trim().isNotEmpty));
    }
    return result.toList()..sort();
  }

  Future<void> _chooseMode(MemoryActivityMode mode) async {
    if (mode == MemoryActivityMode.category) {
      final value = await _pickValue(
        'Choose a category',
        _categories,
      );
      if (value == null) return;
      _category = value;
    }

    if (mode == MemoryActivityMode.album) {
      final value = await _pickValue(
        'Choose an album',
        _albums,
      );
      if (value == null) return;
      _album = value;
    }

    if (mode == MemoryActivityMode.person) {
      final value = await _pickValue(
        'Choose a family member',
        _people,
      );
      if (value == null) return;
      _person = value;
    }

    _mode = mode;
    await _prepareQueue();
  }

  Future<String?> _pickValue(
      String title,
      List<String> values,
      ) async {
    if (values.isEmpty) {
      _message('No options are available yet.');
      return null;
    }

    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: SmritiTheme.primaryDark,
                ),
              ),
            ),
            ...values.map(
                  (value) => ListTile(
                title: Text(value),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(context, value),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _prepareQueue() async {
    final memories = List<Memory>.from(_memoryStore.memories);
    if (memories.isEmpty) {
      setState(() {
        _showModes = false;
        _gameFinished = true;
      });
      return;
    }

    List<Memory> candidates;

    switch (_mode) {
      case MemoryActivityMode.mixed:
        candidates = memories..shuffle(_random);
        break;
      case MemoryActivityMode.memoryOfDay:
        candidates = memories..sort((a, b) => a.id.compareTo(b.id));
        final dayIndex = DateTime.now()
            .difference(DateTime(DateTime.now().year, 1, 1))
            .inDays %
            candidates.length;
        candidates = [candidates[dayIndex]];
        break;
      case MemoryActivityMode.review:
        candidates = memories
            .where((memory) => _enhancementStore
            .enhancementFor(memory.id)
            .isDueForReview)
            .toList()
          ..sort(
                (a, b) => _reviewPriority(b).compareTo(_reviewPriority(a)),
          );
        if (candidates.isEmpty) candidates = memories..shuffle(_random);
        break;
      case MemoryActivityMode.newMemories:
        candidates = memories
            .where(
              (memory) =>
          _enhancementStore.enhancementFor(memory.id).timesSeen == 0,
        )
            .toList()
          ..shuffle(_random);
        if (candidates.isEmpty) candidates = memories..shuffle(_random);
        break;
      case MemoryActivityMode.familiar:
        candidates = memories
            .where((memory) {
          final item = _enhancementStore.enhancementFor(memory.id);
          return item.timesSeen >= 2 || item.familiarityScore >= 35;
        })
            .toList()
          ..shuffle(_random);
        if (candidates.isEmpty) candidates = memories..shuffle(_random);
        break;
      case MemoryActivityMode.category:
        final selected = _category ?? 'Family';
        candidates = memories
            .where(
              (memory) =>
          _enhancementStore
              .enhancementFor(memory.id)
              .category
              .toLowerCase() ==
              selected.toLowerCase(),
        )
            .toList()
          ..shuffle(_random);
        if (candidates.isEmpty) candidates = memories..shuffle(_random);
        break;
      case MemoryActivityMode.album:
        final selected = _album ?? '';
        candidates = memories
            .where(
              (memory) =>
          _enhancementStore
              .enhancementFor(memory.id)
              .album
              .toLowerCase() ==
              selected.toLowerCase(),
        )
            .toList()
          ..shuffle(_random);
        if (candidates.isEmpty) candidates = memories..shuffle(_random);
        break;
      case MemoryActivityMode.person:
        final selected = _person;
        candidates = selected == null
            ? memories
            : memories
            .where(
              (memory) => memory.people.any(
                (person) =>
            person.toLowerCase() == selected.toLowerCase(),
          ),
        )
            .toList();
        candidates.shuffle(_random);
        if (candidates.isEmpty) candidates = memories..shuffle(_random);
        break;
      case MemoryActivityMode.timeline:
        candidates = memories
            .where(
              (memory) =>
          DateTime.tryParse(memory.date) != null,
        )
            .toList()
          ..sort(
                (a, b) => DateTime.parse(a.date)
                .compareTo(DateTime.parse(b.date)),
          );
        break;
      case MemoryActivityMode.seasonal:
        final month = DateTime.now().month;
        candidates = memories
            .where((memory) {
          final date = DateTime.tryParse(memory.date);
          return date?.month == month;
        })
            .toList()
          ..shuffle(_random);
        if (candidates.isEmpty) candidates = memories..shuffle(_random);
        break;
    }

    final limit = min(_questionLimit, candidates.length);
    _queue = candidates.take(limit).toList();
    if (_mode == MemoryActivityMode.timeline && _queue.length < 3) {
      _queue = candidates.take(limit).toList();
    }

    _index = 0;
    _score = 0;
    _incorrectCount = 0;
    _dontKnowCount = 0;
    _rememberedCount = 0;
    _notSureCount = 0;
    _voiceRecallCount = 0;
    _recallDetailTotal = 0;
    _sessionStartedAt = DateTime.now();
    _sessionSaved = false;
    _gameFinished = false;

    setState(() => _showModes = false);
    await _beginMemory();
  }

  int _reviewPriority(Memory memory) {
    final e = _enhancementStore.enhancementFor(memory.id);
    return (e.isDueForReview ? 100 : 0) +
        e.dontKnowCount * 20 +
        e.incorrectCount * 12 +
        (50 - e.familiarityScore).round();
  }

  String get _modeLabel {
    if (_mode == MemoryActivityMode.category && _category != null) {
      return '${_mode.title} · $_category';
    }
    if (_mode == MemoryActivityMode.album && _album != null) {
      return '${_mode.title} · $_album';
    }
    if (_mode == MemoryActivityMode.person && _person != null) {
      return '${_mode.title} · $_person';
    }
    return _mode.title;
  }

  Future<void> _beginMemory() async {
    if (_index >= _queue.length) {
      await _finishGame();
      return;
    }

    final memory = _queue[_index];
    _question = null;
    _answered = false;
    _correct = false;
    _dontKnow = false;
    _reflectionGiven = false;
    _selectedAnswer = null;
    _voiceTranscript = null;
    _detectedLanguage = null;
    _recallDetails = 0;
    _recallTurn = 0;
    _recallController.clear();
    _showMemoryIntro = true;

    await _enhancementStore.recordInteraction(
      memory.id,
      seen: true,
    );

    if (mounted) setState(() {});
  }

  Future<void> _startQuestion() async {
    final memory = _queue[_index];
    _question = _questionEngine.generateForMemory(
      memory,
      difficulty: _difficulty,
      preferredType:
      _mode == MemoryActivityMode.timeline ? 'timeline' : null,
    );

    _questionStartedAt = DateTime.now();
    _showMemoryIntro = false;
    _answered = false;
    _selectedAnswer = null;

    if (mounted) setState(() {});

    if (_question != null) {
      await _speak(_localizedPrompt(_question!));
    }
  }

  String _localizedPrompt(MemoryGameQuestion question) {
    final isHindi = _language == 'hi-IN';
    final isMarathi = _language == 'mr-IN';

    if (!isHindi && !isMarathi) return question.prompt;

    if (isHindi) {
      return switch (question.type) {
        'who' => 'इस याद से कौन जुड़ा है?',
        'where' => 'यह याद कहाँ हुई थी?',
        'when' => 'यह याद किस साल की है?',
        'what' => 'इस याद का सही नाम कौन सा है?',
        'trueFalse' => question.prompt == 'True' || question.prompt == 'False'
            ? question.prompt
            : 'सही या गलत?',
        'related' => 'इस पल से जुड़ी दूसरी याद कौन सी है?',
        'timeline' => 'इन यादों में सबसे पहले कौन सी हुई?',
        _ => question.prompt,
      };
    }

    return switch (question.type) {
      'who' => 'या आठवणीशी कोण जोडलेले आहे?',
      'where' => 'ही आठवण कुठे घडली?',
      'when' => 'ही आठवण कोणत्या वर्षाची आहे?',
      'what' => 'या आठवणीचे योग्य नाव कोणते?',
      'trueFalse' => 'बरोबर की चूक?',
      'related' => 'या क्षणाशी जोडलेली आठवण कोणती?',
      'timeline' => 'या आठवणींपैकी सर्वात आधी कोणती घडली?',
      _ => question.prompt,
    };
  }

  void _recordQuestionTime() {
    if (_questionStartedAt == null) return;
    _questionDurationsMs.add(
      DateTime.now().difference(_questionStartedAt!).inMilliseconds,
    );
    _questionStartedAt = null;
  }

  Future<void> _answer(String option) async {
    if (_answered || _question == null) return;
    _recordQuestionTime();

    final question = _question!;
    final correct = option == question.correctAnswer;
    final memory = _queue[_index];

    setState(() {
      _answered = true;
      _selectedAnswer = option;
      _correct = correct;
    });

    if (correct) {
      _score++;
    } else {
      _incorrectCount++;
    }

    await _enhancementStore.recordInteraction(
      memory.id,
      correct: correct,
    );

    await _speak(
      correct
          ? _localizedFeedback(true)
          : _localizedFeedback(false, answer: question.correctAnswer),
    );
  }

  Future<void> _dontKnowAnswer() async {
    if (_answered || _question == null) return;
    _recordQuestionTime();

    final memory = _queue[_index];
    setState(() {
      _answered = true;
      _dontKnow = true;
      _correct = false;
    });

    _dontKnowCount++;
    await _enhancementStore.recordInteraction(
      memory.id,
      dontKnow: true,
    );

    await _speak(
      _language == 'en-IN'
          ? 'That is okay. You do not have to remember everything.'
          : 'That is okay. Take your time.',
    );
  }

  String _localizedFeedback(
      bool correct, {
        String answer = '',
      }) {
    if (_language == 'hi-IN') {
      return correct
          ? 'बहुत अच्छा। यह सही है।'
          : 'कोई बात नहीं। सही उत्तर है $answer।';
    }
    if (_language == 'mr-IN') {
      return correct
          ? 'छान! हे बरोबर आहे.'
          : 'काही हरकत नाही. योग्य उत्तर $answer आहे.';
    }
    return correct
        ? 'Well done. That is right.'
        : 'That is okay. The answer is $answer.';
  }

  Future<void> _respondToMemory(bool remembered) async {
    if (_reflectionGiven) return;

    final memory = _queue[_index];
    setState(() {
      _reflectionGiven = true;
      if (remembered) {
        _rememberedCount++;
      } else {
        _notSureCount++;
      }
    });

    await _enhancementStore.recordInteraction(
      memory.id,
      remembered: remembered,
      notSure: !remembered,
    );
  }

  Future<void> _next() async {
    if (!_answered) return;

    if (!_reflectionGiven) {
      await _respondToMemory(false);
    }

    if (_index + 1 >= _queue.length) {
      await _finishGame();
      return;
    }

    _index++;
    await _beginMemory();
  }

  Future<void> _finishGame() async {
    await _saveSession();
    if (!mounted) return;
    setState(() {
      _gameFinished = true;
      _showMemoryIntro = false;
    });
  }

  Future<void> _saveSession() async {
    if (_sessionSaved) return;
    _sessionSaved = true;

    final started = _sessionStartedAt ?? DateTime.now();
    final session = CognitiveSession(
      id: 'session_${DateTime.now().millisecondsSinceEpoch}',
      gameId: 'remember_the_moment',
      gameName: 'Remember the Moment',
      startedAt: started,
      durationSeconds: DateTime.now().difference(started).inSeconds,
      totalQuestions: _queue.length,
      attempts: _score + _incorrectCount + _dontKnowCount,
      correctAnswers: _score,
      incorrectAnswers: _incorrectCount,
      dontKnowAnswers: _dontKnowCount,
      memoryRememberedCount: _rememberedCount,
      memoryNotSureCount: _notSureCount,
      questionDurationsMs: List<int>.from(_questionDurationsMs),
      completed: true,
    );

    await _sessionStore.addSession(session);
  }

  Future<void> _playVoice(Memory memory) async {
    final path = memory.voiceMessage;
    if (path == null || path.isEmpty) return;

    final file = File(path);
    if (!await file.exists()) {
      _message('This voice memory could not be found.');
      return;
    }

    try {
      if (_isVoicePlaying) {
        await _audioPlayer.stop();
        if (mounted) setState(() => _isVoicePlaying = false);
        return;
      }

      await _audioPlayer.play(DeviceFileSource(path));
      if (mounted) setState(() => _isVoicePlaying = true);

      _audioPlayer.onPlayerComplete.first.then((_) {
        if (mounted) setState(() => _isVoicePlaying = false);
      });
    } catch (_) {
      _message('Unable to play this voice memory.');
    }
  }

  Future<void> _speak(String text) async {
    try {
      await _tts.setLanguage(
        _language == 'hi-IN'
            ? 'hi-IN'
            : _language == 'mr-IN'
            ? 'mr-IN'
            : 'en-IN',
      );
      await _tts.speak(text);
    } catch (_) {}
  }

  Future<void> _listenToRecall() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    try {
      final available = await _speech.initialize();
      if (!available) {
        _message('Voice input is not available on this device.');
        return;
      }

      setState(() {
        _isListening = true;
        _voiceTranscript = '';
      });

      await _speech.listen(
        onResult: (result) async {
          if (!mounted) return;
          setState(() {
            _voiceTranscript = result.recognizedWords;
            _recallController.text = result.recognizedWords;
            _recallController.selection = TextSelection.fromPosition(
              TextPosition(offset: _recallController.text.length),
            );
          });

          if (result.finalResult) {
            await _handleRecall(result.recognizedWords);
          }
        },
        listenOptions: SpeechListenOptions(
          localeId: _language,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _isListening = false);
        _message('Voice input could not be started.');
      }
    }
  }

  Future<void> _handleRecall(String text) async {
    final value = text.trim();
    if (value.isEmpty) return;

    await _speech.stop();

    final detected = await _languageIdentifier.identifyLanguage(value);
    final memory = _queue[_index];
    final terms = <String>{};

    for (final source in <String>[
      memory.title,
      memory.description,
      memory.location,
      ...memory.people,
      _enhancementStore.enhancementFor(memory.id).category,
      _enhancementStore.enhancementFor(memory.id).album,
    ]) {
      terms.addAll(
        source
            .toLowerCase()
            .split(RegExp(r'[^a-zA-Z0-9\u0900-\u097F]+'))
            .where((word) => word.length >= 3),
      );
    }

    final normalized = value.toLowerCase();
    var detailCount = 0;
    for (final term in terms) {
      if (normalized.contains(term)) detailCount++;
    }

    setState(() {
      _voiceTranscript = value;
      _detectedLanguage = detected == 'und' ? null : detected;
      _recallDetails = detailCount;
      _voiceRecallCount++;
      _recallDetailTotal += detailCount;
      _isListening = false;
    });

    await _enhancementStore.recordInteraction(
      memory.id,
      recallDetailCount: detailCount,
    );

    if (detailCount > 0) {
      await _speak(
        _language == 'hi-IN'
            ? 'आपने $detailCount परिचित विवरण बताए।'
            : _language == 'mr-IN'
            ? 'तुम्ही $detailCount ओळखीचे तपशील सांगितले.'
            : 'You mentioned $detailCount familiar details.',
      );
    }
  }

  Future<void> _submitRecall() async {
    await _handleRecall(_recallController.text);
  }

  ImageProvider? _imageFor(Memory memory) {
    final path = memory.imageUrl;
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    return FileImage(file);
  }

  String _date(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> _chooseLanguage() async {
    final value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Activity language',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: SmritiTheme.primaryDark,
                  ),
                ),
              ),
            ),
            _languageTile('en-IN', 'English'),
            _languageTile('hi-IN', 'हिन्दी'),
            _languageTile('mr-IN', 'मराठी'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (value != null && mounted) {
      setState(() => _language = value);
    }
  }

  Widget _languageTile(String value, String label) {
    return ListTile(
      title: Text(label),
      trailing: _language == value
          ? const Icon(Icons.check_circle_rounded)
          : null,
      onTap: () => Navigator.pop(context, value),
    );
  }

  Future<void> _openStudio() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MemoryStudioScreen(),
      ),
    );
    if (mounted) setState(() {});
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
        appBar: AppBar(title: const Text('Remember the Moment')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_memoryStore.memories.isEmpty) return _noMemories();
    if (_showModes) return _modeScreen();
    if (_gameFinished) return _completionScreen();

    if (_showMemoryIntro) {
      return _memoryScreen(_queue[_index]);
    }

    final question = _question;
    if (question == null) {
      return _noQuestion(_queue[_index]);
    }

    return _questionScreen(_queue[_index], question);
  }

  Widget _noMemories() {
    return Scaffold(
      appBar: AppBar(title: const Text('Remember the Moment')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.photo_album_rounded,
              size: 80,
              color: SmritiTheme.primary,
            ),
            const SizedBox(height: 18),
            const Text(
              'Add a memory first',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: SmritiTheme.primaryDark,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Remember the Moment uses your saved family memories.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                color: SmritiTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MemoriesScreen(),
                    ),
                  );
                  if (mounted) {
                    await _memoryStore.initialize();
                    setState(() {});
                  }
                },
                child: const Text('Open My Memories'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Remember the Moment'),
        actions: [
          IconButton(
            onPressed: _openStudio,
            tooltip: 'Memory Studio',
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        children: [
          const Text(
            'Choose how you would like to explore your memories ❤️',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: SmritiTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Activity level: $_difficulty',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: SmritiTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Material(
            color: SmritiTheme.softGreen,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              onTap: _chooseLanguage,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Row(
                  children: [
                    const Icon(
                      Icons.translate_rounded,
                      color: SmritiTheme.primary,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Voice language',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: SmritiTheme.primaryDark,
                        ),
                      ),
                    ),
                    Text(
                      _language == 'hi-IN'
                          ? 'हिन्दी'
                          : _language == 'mr-IN'
                          ? 'मराठी'
                          : 'English',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: SmritiTheme.primaryDark,
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...MemoryActivityMode.values.map(
                (mode) => Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: Material(
                color: SmritiTheme.surface,
                borderRadius: BorderRadius.circular(21),
                child: InkWell(
                  onTap: () => _chooseMode(mode),
                  borderRadius: BorderRadius.circular(21),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(21),
                      border: Border.all(
                        color: SmritiTheme.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: SmritiTheme.softGreen,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            mode.icon,
                            color: SmritiTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                mode.title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: SmritiTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                mode.description,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.3,
                                  color: SmritiTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: SmritiTheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: _openStudio,
            icon: const Icon(Icons.auto_fix_high_rounded),
            label: const Text('Open Memory Studio'),
          ),
        ],
      ),
    );
  }

  Widget _memoryScreen(Memory memory) {
    final image = _imageFor(memory);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Remember the Moment'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${_index + 1}/${_queue.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: SmritiTheme.primaryDark,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        children: [
          Text(
            _modeLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: SmritiTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SmritiTheme.softGreen,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: SmritiTheme.border),
            ),
            child: Column(
              children: [
                if (image != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(21),
                    child: Image(
                      image: image,
                      width: double.infinity,
                      height: 275,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    height: 220,
                    decoration: BoxDecoration(
                      color: SmritiTheme.surface,
                      borderRadius: BorderRadius.circular(21),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.photo_rounded,
                        size: 80,
                        color: SmritiTheme.primary,
                      ),
                    ),
                  ),
                const SizedBox(height: 17),
                Text(
                  memory.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: SmritiTheme.primaryDark,
                  ),
                ),
                if (memory.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Text(
                    memory.description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.4,
                      color: SmritiTheme.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (memory.date.isNotEmpty)
                      _chip(
                        Icons.calendar_month_rounded,
                        _date(memory.date),
                      ),
                    if (memory.location.isNotEmpty)
                      _chip(
                        Icons.location_on_rounded,
                        memory.location,
                      ),
                  ],
                ),
                if (memory.people.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _chip(
                    Icons.people_alt_rounded,
                    memory.people.join(', '),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: memory.voiceMessage == null
                            ? null
                            : () => _playVoice(memory),
                        icon: Icon(
                          _isVoicePlaying
                              ? Icons.stop_rounded
                              : Icons.volume_up_rounded,
                        ),
                        label: Text(
                          _isVoicePlaying
                              ? 'Stop Voice'
                              : 'Voice Memory',
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _speak(_memorySpeech(memory)),
                        icon: const Icon(
                          Icons.record_voice_over_rounded,
                        ),
                        label: const Text('Hear Memory'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 17),
          const Text(
            'Take a moment to look at this memory. ❤️',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: SmritiTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 56,
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _startQuestion,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text(
                'Continue',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _memorySpeech(Memory memory) {
    final buffer = StringBuffer(memory.title);
    if (memory.location.isNotEmpty) {
      buffer.write('. This memory happened in ${memory.location}.');
    }
    if (memory.people.isNotEmpty) {
      buffer.write('. People connected to it include ${memory.people.join(', ')}.');
    }
    if (memory.description.isNotEmpty) {
      buffer.write('. ${memory.description}');
    }
    return buffer.toString();
  }

  Widget _questionScreen(
      Memory memory,
      MemoryGameQuestion question,
      ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Remember the Moment'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_index + 1}/${_queue.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: SmritiTheme.textSecondary,
                ),
              ),
              Text(
                'Score: $_score',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: SmritiTheme.primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Activity level: $_difficulty',
            style: const TextStyle(
              fontSize: 13,
              color: SmritiTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: (_index + 1) / _queue.length,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 18),
          if (_imageFor(memory) != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(21),
              child: Image(
                image: _imageFor(memory)!,
                height: 185,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: 16),
          Text(
            _localizedPrompt(question),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.bold,
              color: SmritiTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _speak(_localizedPrompt(question)),
            icon: Icon(
              _isSpeaking
                  ? Icons.volume_up_rounded
                  : Icons.record_voice_over_rounded,
            ),
            label: const Text('Hear Question'),
          ),
          const SizedBox(height: 16),
          ...question.options.map(
                (option) => Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: _answerButton(
                option,
                question.correctAnswer,
              ),
            ),
          ),
          if (!_answered)
            SizedBox(
              height: 54,
              child: OutlinedButton.icon(
                onPressed: _dontKnowAnswer,
                icon: const Icon(Icons.help_outline_rounded),
                label: const Text(
                  "I don't know",
                  style: TextStyle(fontSize: 17),
                ),
              ),
            ),
          if (_answered) ...[
            const SizedBox(height: 8),
            _feedback(question),
            const SizedBox(height: 15),
            _recallPanel(memory),
            const SizedBox(height: 14),
            _reflectionPanel(),
            const SizedBox(height: 14),
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: _next,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(
                  _index + 1 >= _queue.length
                      ? 'Finish'
                      : 'Next Memory',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _answerButton(String option, String correctAnswer) {
    final selected = _selectedAnswer == option;
    final showCorrect = _answered && option == correctAnswer;
    final showWrong = _answered && selected && option != correctAnswer;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _answered ? null : () => _answer(option),
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 13,
          ),
          side: BorderSide(
            color: showCorrect || showWrong
                ? SmritiTheme.primary
                : SmritiTheme.border,
            width: showCorrect || showWrong ? 2 : 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: SmritiTheme.softGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.touch_app_rounded,
                size: 20,
                color: SmritiTheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                option,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: SmritiTheme.textPrimary,
                ),
              ),
            ),
            if (showCorrect)
              const Icon(Icons.check_circle_rounded),
            if (showWrong)
              const Icon(Icons.cancel_rounded),
          ],
        ),
      ),
    );
  }

  Widget _feedback(MemoryGameQuestion question) {
    final title = _dontKnow
        ? "That's okay. ❤️"
        : _correct
        ? 'Well done! ❤️'
        : "That's okay. ❤️";
    final message = _dontKnow
        ? 'The answer was "${question.correctAnswer}".'
        : _correct
        ? 'You recognized an important detail from this memory.'
        : 'The correct answer was "${question.correctAnswer}".';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SmritiTheme.softGreen,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SmritiTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _correct
                ? Icons.check_circle_rounded
                : Icons.favorite_rounded,
            color: SmritiTheme.primary,
            size: 30,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: SmritiTheme.primaryDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: SmritiTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _recallPanel(Memory memory) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: SmritiTheme.softGreen,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SmritiTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _recallTurn == 0
                ? 'Tell me about this moment'
                : 'Tell me one more detail',
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: SmritiTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'You can speak or type. SMRITI compares the response with details already saved for this memory.',
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: SmritiTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _listenToRecall,
                  icon: Icon(
                    _isListening
                        ? Icons.stop_rounded
                        : Icons.mic_rounded,
                  ),
                  label: Text(
                    _isListening ? 'Stop' : 'Speak',
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _speak(
                    _recallTurn == 0
                        ? 'Tell me about ${memory.title}.'
                        : 'Tell me one more thing about ${memory.title}.',
                  ),
                  icon: const Icon(
                    Icons.record_voice_over_rounded,
                  ),
                  label: const Text('Prompt Me'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _recallController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Or type what you remember...',
              suffixIcon: IconButton(
                onPressed: _submitRecall,
                icon: const Icon(Icons.send_rounded),
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          if (_voiceTranscript != null &&
              _voiceTranscript!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SmritiTheme.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your response',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: SmritiTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _voiceTranscript!,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                  if (_detectedLanguage != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      'Detected language: ${_languageName(_detectedLanguage!)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: SmritiTheme.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 5),
                  Text(
                    _recallDetails > 0
                        ? 'Familiar details mentioned: $_recallDetails'
                        : 'Thank you for sharing this memory. ❤️',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: SmritiTheme.primaryDark,
                    ),
                  ),
                  if (_recallTurn == 0)
                    TextButton.icon(
                      onPressed: () {
                        setState(() => _recallTurn = 1);
                        _recallController.clear();
                        _voiceTranscript = null;
                      },
                      icon: const Icon(Icons.forum_outlined),
                      label: const Text('Tell me one more detail'),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _languageName(String code) => switch (code) {
    'hi' => 'Hindi',
    'mr' => 'Marathi',
    'en' => 'English',
    _ => code,
  };

  Widget _reflectionPanel() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: SmritiTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SmritiTheme.border),
      ),
      child: Column(
        children: [
          const Text(
            'Do you remember this moment?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: SmritiTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _reflectionGiven
                      ? null
                      : () => _respondToMemory(true),
                  icon: const Icon(Icons.favorite_rounded),
                  label: const Text('Yes, I remember'),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _reflectionGiven
                      ? null
                      : () => _respondToMemory(false),
                  icon: const Icon(Icons.help_outline_rounded),
                  label: const Text('Not sure'),
                ),
              ),
            ],
          ),
          if (_reflectionGiven)
            const Padding(
              padding: EdgeInsets.only(top: 7),
              child: Text(
                'Thank you for sharing. ❤️',
                style: TextStyle(
                  color: SmritiTheme.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _completionScreen() {
    final total = _queue.length;
    final accuracy = total == 0 ? 0.0 : _score / total;
    final sessions = _sessionStore.sessionsForGame(
      'remember_the_moment',
    );

    Memory? familiar;
    Memory? review;
    if (_queue.isNotEmpty) {
      final byFamiliarity = List<Memory>.from(_queue)
        ..sort(
              (a, b) => _enhancementStore
              .enhancementFor(b.id)
              .familiarityScore
              .compareTo(
            _enhancementStore
                .enhancementFor(a.id)
                .familiarityScore,
          ),
        );
      familiar = byFamiliarity.first;

      final byReview = List<Memory>.from(_queue)
        ..sort(
              (a, b) => _reviewPriority(b).compareTo(_reviewPriority(a)),
        );
      review = byReview.first;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Remember the Moment'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            size: 68,
            color: SmritiTheme.primary,
          ),
          const SizedBox(height: 12),
          const Text(
            'Beautiful work. ❤️',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: SmritiTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            _modeLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: SmritiTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: SmritiTheme.softGreen,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: SmritiTheme.border),
            ),
            child: Column(
              children: [
                const Text(
                  'Session score',
                  style: TextStyle(
                    color: SmritiTheme.textSecondary,
                  ),
                ),
                Text(
                  '$_score / $total',
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    color: SmritiTheme.primaryDark,
                  ),
                ),
                Text(
                  '${(accuracy * 100).round()}% accuracy',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: SmritiTheme.primaryDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Activity level: $_difficulty',
                  style: const TextStyle(
                    color: SmritiTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              _chip(Icons.check_circle_rounded, 'Correct: $_score'),
              _chip(Icons.help_outline_rounded, "Don't know: $_dontKnowCount"),
              _chip(Icons.favorite_rounded, 'Remembered: $_rememberedCount'),
              _chip(Icons.question_mark_rounded, 'Not sure: $_notSureCount'),
              _chip(Icons.mic_rounded, 'Voice recall: $_voiceRecallCount'),
              _chip(Icons.psychology_rounded, 'Details: $_recallDetailTotal'),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SmritiTheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: SmritiTheme.border),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.insights_rounded,
                  color: SmritiTheme.primary,
                  size: 30,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    sessions.length < 3
                        ? 'Your personal baseline is still being built.'
                        : 'This activity level uses your recent personal history.',
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      color: SmritiTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (familiar != null) ...[
            const SizedBox(height: 12),
            _memoryInsight(
              'A familiar moment',
              familiar,
              Icons.favorite_rounded,
            ),
          ],
          if (review != null) ...[
            const SizedBox(height: 12),
            _memoryInsight(
              'Good for another review',
              review,
              Icons.refresh_rounded,
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            height: 55,
            child: FilledButton.icon(
              onPressed: () {
                setState(() {
                  _showModes = true;
                  _gameFinished = false;
                });
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
    );
  }

  Widget _memoryInsight(
      String title,
      Memory memory,
      IconData icon,
      ) {
    final score = _enhancementStore
        .enhancementFor(memory.id)
        .familiarityScore
        .round();
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: SmritiTheme.softGreen,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: SmritiTheme.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: SmritiTheme.primary, size: 27),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: SmritiTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  memory.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: SmritiTheme.primaryDark,
                  ),
                ),
                Text(
                  'Familiarity: $score/100',
                  style: const TextStyle(
                    fontSize: 12,
                    color: SmritiTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _noQuestion(Memory memory) {
    return Scaffold(
      appBar: AppBar(title: const Text('Remember the Moment')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lightbulb_outline_rounded,
                size: 70,
                color: SmritiTheme.primary,
              ),
              const SizedBox(height: 16),
              const Text(
                'This memory needs a little more detail.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: SmritiTheme.primaryDark,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                memory.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: SmritiTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _openStudio,
                child: const Text('Open Memory Studio'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: SmritiTheme.softGreen,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: SmritiTheme.primary),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: SmritiTheme.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}
