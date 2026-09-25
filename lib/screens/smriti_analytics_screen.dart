import 'package:flutter/material.dart';

import '../data/cognitive_session_store.dart';
import '../data/memory_enhancement_store.dart';
import '../data/memory_store.dart';
import '../models/cognitive_session.dart';
import '../models/memory.dart';
import '../theme/smriti_theme.dart';

enum AnalyticsSection {
  overview,
  games,
  memories,
  history,
}

class SmritiAnalyticsScreen extends StatefulWidget {
  final AnalyticsSection initialSection;

  const SmritiAnalyticsScreen({
    super.key,
    this.initialSection = AnalyticsSection.overview,
  });

  @override
  State<SmritiAnalyticsScreen> createState() =>
      _SmritiAnalyticsScreenState();
}

class _SmritiAnalyticsScreenState extends State<SmritiAnalyticsScreen> {
  final CognitiveSessionStore _sessionStore = CognitiveSessionStore.instance;
  final MemoryEnhancementStore _enhancementStore =
      MemoryEnhancementStore.instance;
  final MemoryStore _memoryStore = MemoryStore.instance;

  bool _loading = true;
  List<CognitiveSession> _sessions = [];
  List<Memory> _memories = [];
  late AnalyticsSection _selectedSection;

  static const _knownGames = <_GameDescriptor>[
    _GameDescriptor('who_is_this', 'Who Is This?'),
    _GameDescriptor('remember_the_moment', 'Remember the Moment'),
    _GameDescriptor('what_comes_next', 'What Comes Next?'),
    _GameDescriptor('picture_puzzle', 'Picture Puzzle'),
    _GameDescriptor('memory_chain', 'Memory Chain'),
  ];

  @override
  void initState() {
    super.initState();
    _selectedSection = widget.initialSection;
    _initialize();
  }

  Future<void> _initialize() async {
    if (mounted) setState(() => _loading = true);

    await Future.wait([
      _sessionStore.initialize(),
      _enhancementStore.initialize(),
      _memoryStore.initialize(),
    ]);

    final sessions = <CognitiveSession>[];
    for (final game in _knownGames) {
      sessions.addAll(_sessionStore.sessionsForGame(game.id));
    }
    sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));

    if (!mounted) return;
    setState(() {
      _sessions = sessions;
      _memories = List<Memory>.from(_memoryStore.memories);
      _loading = false;
    });
  }

  int get _totalQuestions =>
      _sessions.fold(0, (sum, session) => sum + session.totalQuestions);

  int get _totalCorrect =>
      _sessions.fold(0, (sum, session) => sum + session.correctAnswers);

  int get _totalIncorrect =>
      _sessions.fold(0, (sum, session) => sum + session.incorrectAnswers);

  int get _totalDontKnow =>
      _sessions.fold(0, (sum, session) => sum + session.dontKnowAnswers);

  double get _overallAccuracy =>
      _totalQuestions == 0 ? 0 : _totalCorrect / _totalQuestions;

  double get _averageQuestionTime {
    var totalMs = 0;
    var count = 0;
    for (final session in _sessions) {
      for (final value in session.questionDurationsMs) {
        totalMs += value;
        count++;
      }
    }
    return count == 0 ? 0 : totalMs / count / 1000;
  }

  Map<String, List<CognitiveSession>> get _sessionsByGame {
    final result = <String, List<CognitiveSession>>{};
    for (final descriptor in _knownGames) {
      result[descriptor.id] = _sessions
          .where((session) => session.gameId == descriptor.id)
          .toList();
    }
    return result;
  }

  List<MemoryEnhancement> get _memoryStats =>
      _enhancementStore.enhancements
          .where((item) => _memories.any((memory) => memory.id == item.memoryId))
          .toList();

  int get _memoriesDue =>
      _memoryStats.where((item) => item.isDueForReview).length;

  int get _remembered =>
      _memoryStats.fold(0, (sum, item) => sum + item.rememberedCount);

  int get _notSure =>
      _memoryStats.fold(0, (sum, item) => sum + item.notSureCount);

  double get _averageFamiliarity {
    if (_memoryStats.isEmpty) return 0;
    final total = _memoryStats.fold<double>(
      0,
      (sum, item) => sum + item.familiarityScore,
    );
    return total / _memoryStats.length;
  }

  String _formatDuration(double seconds) {
    if (seconds < 60) return '${seconds.toStringAsFixed(1)}s';
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '${minutes}m ${remainder.toStringAsFixed(0)}s';
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics & Insights'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _initialize,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionSelector(),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: KeyedSubtree(
                  key: ValueKey(_selectedSection),
                  child: _buildSelectedSection(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionSelector() {
    const sections = [
      (AnalyticsSection.overview, 'Overall', Icons.insights_rounded),
      (AnalyticsSection.games, 'Games', Icons.sports_esports_rounded),
      (AnalyticsSection.memories, 'Memories', Icons.photo_library_rounded),
      (AnalyticsSection.history, 'History', Icons.history_rounded),
    ];

    return _card(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: sections.map((section) {
          final selected = _selectedSection == section.$1;
          return ChoiceChip(
            selected: selected,
            avatar: Icon(section.$3, size: 17),
            label: Text(section.$2),
            onSelected: (_) {
              setState(() => _selectedSection = section.$1);
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSelectedSection() {
    switch (_selectedSection) {
      case AnalyticsSection.games:
        return _gamesSection();
      case AnalyticsSection.memories:
        return _memoriesSection();
      case AnalyticsSection.history:
        return _historySection();
      case AnalyticsSection.overview:
        return _overviewSection();
    }
  }

  Widget _overviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionIntro(
          Icons.insights_rounded,
          'Overall Performance',
          'A simple view of SMRITI activity across all completed cognitive games.',
        ),
        const SizedBox(height: 14),
        _metricGrid([
          _Metric('Sessions', '${_sessions.length}', Icons.play_circle_outline_rounded),
          _Metric('Questions', '$_totalQuestions', Icons.quiz_outlined),
          _Metric('Accuracy', '${(_overallAccuracy * 100).round()}%', Icons.check_circle_outline_rounded),
          _Metric('Avg. response', _formatDuration(_averageQuestionTime), Icons.timer_outlined),
        ]),
        const SizedBox(height: 16),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Answer breakdown',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _barRow('Correct', _totalCorrect, _totalQuestions),
              _barRow('Incorrect', _totalIncorrect, _totalQuestions),
              _barRow("Don't know", _totalDontKnow, _totalQuestions),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _card(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, color: SmritiTheme.primary),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'These insights describe activity and change from personal history. They are not a medical diagnosis.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: SmritiTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _gamesSection() {
    final grouped = _sessionsByGame;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionIntro(
          Icons.sports_esports_rounded,
          'Game Performance',
          'Compare activity across every cognitive game in SMRITI.',
        ),
        const SizedBox(height: 14),
        ..._knownGames.map((game) {
          final sessions = grouped[game.id] ?? const <CognitiveSession>[];
          final questions = sessions.fold(0, (sum, item) => sum + item.totalQuestions);
          final correct = sessions.fold(0, (sum, item) => sum + item.correctAnswers);
          final accuracy = questions == 0 ? 0.0 : correct / questions;
          final avgTime = _averageTimeFor(sessions);
          final lastPlayed = sessions.isEmpty ? null : sessions.first.startedAt;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          game.name,
                          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                        ),
                      ),
                      _smallBadge(
                        sessions.isEmpty ? 'Not played' : '${sessions.length} sessions',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 18,
                    runSpacing: 10,
                    children: [
                      _inlineStat('Accuracy', '${(accuracy * 100).round()}%'),
                      _inlineStat('Questions', '$questions'),
                      _inlineStat('Avg. time', _formatDuration(avgTime)),
                    ],
                  ),
                  if (lastPlayed != null) ...[
                    const SizedBox(height: 9),
                    Text(
                      'Last played: ${_formatDate(lastPlayed)}',
                      style: const TextStyle(color: SmritiTheme.textSecondary, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  double _averageTimeFor(List<CognitiveSession> sessions) {
    var totalMs = 0;
    var count = 0;
    for (final session in sessions) {
      for (final value in session.questionDurationsMs) {
        totalMs += value;
        count++;
      }
    }
    return count == 0 ? 0 : totalMs / count / 1000;
  }

  Widget _memoriesSection() {
    final stats = List<MemoryEnhancement>.from(_memoryStats)
      ..sort((a, b) => b.familiarityScore.compareTo(a.familiarityScore));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionIntro(
          Icons.photo_library_rounded,
          'Memory Engagement',
          'See which saved moments are being revisited and which are due for review.',
        ),
        const SizedBox(height: 14),
        _metricGrid([
          _Metric('Memories', '${_memories.length}', Icons.photo_album_outlined),
          _Metric('Review due', '$_memoriesDue', Icons.refresh_rounded),
          _Metric('Remembered', '$_remembered', Icons.favorite_outline_rounded),
          _Metric('Not sure', '$_notSure', Icons.help_outline_rounded),
        ]),
        const SizedBox(height: 16),
        _card(
          child: Row(
            children: [
              const Icon(Icons.psychology_rounded, color: SmritiTheme.primary, size: 30),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  'Average familiarity: ${_averageFamiliarity.round()}/100',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (stats.isEmpty)
          _card(
            child: const Text(
              'Play a memory activity to start building memory engagement insights.',
              style: TextStyle(fontSize: 15, color: SmritiTheme.textSecondary),
            ),
          )
        else
          ...stats.take(8).map((stat) {
            Memory? memory;
            for (final item in _memories) {
              if (item.id == stat.memoryId) {
                memory = item;
                break;
              }
            }
            if (memory == null) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _card(
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: SmritiTheme.softGreen,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.photo_rounded, color: SmritiTheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            memory.title,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Familiarity ${stat.familiarityScore.round()}/100 • Seen ${stat.timesSeen}×',
                            style: const TextStyle(fontSize: 13, color: SmritiTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (stat.isDueForReview) _smallBadge('Review due'),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _historySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionIntro(
          Icons.history_rounded,
          'Recent Activity',
          'Every completed cognitive-game session recorded by SMRITI appears here.',
        ),
        const SizedBox(height: 14),
        if (_sessions.isEmpty)
          _card(
            child: const Text(
              'No completed sessions yet.',
              style: TextStyle(fontSize: 15, color: SmritiTheme.textSecondary),
            ),
          )
        else
          ..._sessions.take(30).map(
            (session) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _card(
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: SmritiTheme.softGreen,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.play_circle_outline_rounded, color: SmritiTheme.primary),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.gameName,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_formatDate(session.startedAt)} • ${session.durationSeconds}s',
                            style: const TextStyle(fontSize: 13, color: SmritiTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${(session.accuracy * 100).round()}%',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: SmritiTheme.primaryDark),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _sectionIntro(IconData icon, String title, String subtitle) {
    return _card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: SmritiTheme.softGreen,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: SmritiTheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: SmritiTheme.primaryDark,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
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

  Widget _metricGrid(List<_Metric> metrics) {
    return GridView.builder(
      itemCount: metrics.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: 105,
      ),
      itemBuilder: (context, index) {
        final metric = metrics[index];

        return _card(
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: SmritiTheme.softGreen,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  metric.icon,
                  color: SmritiTheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metric.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                        color: SmritiTheme.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      metric.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
      },
    );
  }

  Widget _barRow(String label, int value, int total) {
    final fraction = total == 0 ? 0.0 : (value / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text(label), Text('$value')],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: fraction, minHeight: 8),
          ),
        ],
      ),
    );
  }

  Widget _inlineStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: SmritiTheme.primaryDark,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: SmritiTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _smallBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: SmritiTheme.softGreen,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: SmritiTheme.primaryDark,
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SmritiTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SmritiTheme.border),
      ),
      child: child,
    );
  }
}

class _GameDescriptor {
  final String id;
  final String name;

  const _GameDescriptor(this.id, this.name);
}

class _Metric {
  final String label;
  final String value;
  final IconData icon;

  const _Metric(this.label, this.value, this.icon);
}
