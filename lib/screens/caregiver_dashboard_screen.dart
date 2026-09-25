import 'dart:io';

import 'package:flutter/material.dart';

import '../data/cognitive_session_store.dart';
import '../data/memory_enhancement_store.dart';
import '../data/memory_store.dart';
import '../models/cognitive_session.dart';
import '../models/memory.dart';
import '../theme/smriti_theme.dart';
import 'cognitive_activity_screen.dart';
import 'family_screen.dart';
import 'memory_studio_screen.dart';

class CaregiverDashboardScreen extends StatefulWidget {
  const CaregiverDashboardScreen({super.key});

  @override
  State<CaregiverDashboardScreen> createState() =>
      _CaregiverDashboardScreenState();
}

class _CaregiverDashboardScreenState
    extends State<CaregiverDashboardScreen> {
  final CognitiveSessionStore _sessionStore =
      CognitiveSessionStore.instance;

  final MemoryEnhancementStore _enhancementStore =
      MemoryEnhancementStore.instance;

  final MemoryStore _memoryStore =
      MemoryStore.instance;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await Future.wait([
      _sessionStore.initialize(),
      _enhancementStore.initialize(),
      _memoryStore.initialize(),
    ]);

    if (!mounted) return;

    setState(() {
      _loading = false;
    });
  }

  Future<void> _refresh() async {
    await Future.wait([
      _sessionStore.initialize(),
      _enhancementStore.initialize(),
      _memoryStore.initialize(),
    ]);

    if (!mounted) return;

    setState(() {});
  }

  List<CognitiveSession> get _sessions {
    return List<CognitiveSession>.from(
      _sessionStore.sessions,
    )..sort(
          (a, b) =>
          b.startedAt.compareTo(a.startedAt),
    );
  }

  List<Memory> get _memories {
    return List<Memory>.from(
      _memoryStore.memories,
    );
  }

  int get _totalSessions => _sessions.length;

  int get _totalQuestions {
    return _sessions.fold(
      0,
          (sum, session) => sum + session.totalQuestions,
    );
  }

  int get _totalCorrect {
    return _sessions.fold(
      0,
          (sum, session) => sum + session.correctAnswers,
    );
  }

  int get _totalIncorrect {
    return _sessions.fold(
      0,
          (sum, session) => sum + session.incorrectAnswers,
    );
  }

  int get _totalDontKnow {
    return _sessions.fold(
      0,
          (sum, session) => sum + session.dontKnowAnswers,
    );
  }

  double get _overallAccuracy {
    if (_totalQuestions == 0) {
      return 0;
    }

    return _totalCorrect / _totalQuestions;
  }

  double get _averageResponseTime {
    final valid = _sessions
        .where(
          (session) =>
      session.questionDurationsMs.isNotEmpty,
    )
        .toList();

    if (valid.isEmpty) {
      return 0;
    }

    double totalSeconds = 0;
    int count = 0;

    for (final session in valid) {
      for (final milliseconds
      in session.questionDurationsMs) {
        totalSeconds += milliseconds / 1000;
        count++;
      }
    }

    if (count == 0) {
      return 0;
    }

    return totalSeconds / count;
  }

  int get _reviewDue {
    return _memories
        .where(
          (memory) => _enhancementStore
          .enhancementFor(memory.id)
          .isDueForReview,
    )
        .length;
  }

  int get _memoriesSeen {
    return _memories.where(
          (memory) =>
      _enhancementStore
          .enhancementFor(memory.id)
          .timesSeen >
          0,
    ).length;
  }

  int get _rememberedCount {
    return _memories.fold(
      0,
          (sum, memory) =>
      sum +
          _enhancementStore
              .enhancementFor(memory.id)
              .rememberedCount,
    );
  }

  int get _notSureCount {
    return _memories.fold(
      0,
          (sum, memory) =>
      sum +
          _enhancementStore
              .enhancementFor(memory.id)
              .notSureCount,
    );
  }

  int get _voiceRecallCount {
    return _memories.fold(
      0,
          (sum, memory) =>
      sum +
          _enhancementStore
              .enhancementFor(memory.id)
              .voiceRecallCount,
    );
  }

  double get _averageFamiliarity {
    if (_memories.isEmpty) {
      return 0;
    }

    double total = 0;

    for (final memory in _memories) {
      total += _enhancementStore
          .enhancementFor(memory.id)
          .familiarityScore;
    }

    return total / _memories.length;
  }

  List<CognitiveSession> get _recentSessions {
    return _sessions.take(6).toList();
  }

  List<CognitiveSession> get _recentThree {
    return _sessions.take(3).toList();
  }

  List<CognitiveSession> get _previousThree {
    return _sessions.skip(3).take(3).toList();
  }

  double? get _recentAccuracy {
    if (_recentThree.isEmpty) {
      return null;
    }

    double total = 0;

    for (final session in _recentThree) {
      total += session.accuracy;
    }

    return total / _recentThree.length;
  }

  double? get _previousAccuracy {
    if (_previousThree.isEmpty) {
      return null;
    }

    double total = 0;

    for (final session in _previousThree) {
      total += session.accuracy;
    }

    return total / _previousThree.length;
  }

  double? get _recentResponseTime {
    final durations = _recentThree
        .expand(
          (session) => session.questionDurationsMs,
    )
        .toList();

    if (durations.isEmpty) {
      return null;
    }

    final total = durations.fold<int>(
      0,
          (sum, value) => sum + value,
    );

    return total / durations.length / 1000;
  }

  String get _activityChangeText {
    final recent = _recentAccuracy;
    final previous = _previousAccuracy;

    if (recent == null ||
        previous == null ||
        _sessions.length < 6) {
      return 'More activity is needed to compare recent sessions with an earlier personal pattern.';
    }

    final difference = recent - previous;

    if (difference.abs() < 0.05) {
      return 'Recent activity is broadly similar to the earlier personal pattern.';
    }

    if (difference > 0) {
      return 'Recent activity accuracy is higher than the earlier personal pattern.';
    }

    return 'Recent activity accuracy is lower than the earlier personal pattern.';
  }

  Color _changeIconColor() {
    final recent = _recentAccuracy;
    final previous = _previousAccuracy;

    if (recent == null ||
        previous == null ||
        _sessions.length < 6) {
      return SmritiTheme.primary;
    }

    if ((recent - previous).abs() < 0.05) {
      return SmritiTheme.primary;
    }

    return recent > previous
        ? SmritiTheme.primary
        : Colors.orange.shade700;
  }

  Future<void> _openAnalytics() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const CognitiveActivityScreen(),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openMemoryStudio() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const MemoryStudioScreen(),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openFamily() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const FamilyScreen(
          userRole: FamilyUserRole.caregiver,
        ),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  ImageProvider? _memoryImage(Memory memory) {
    final path = memory.imageUrl;

    if (path == null || path.isEmpty) {
      return null;
    }

    final file = File(path);

    if (!file.existsSync()) {
      return null;
    }

    return FileImage(file);
  }

  Widget _metricCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SmritiTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: SmritiTheme.border,
        ),
      ),
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
              icon,
              color: SmritiTheme.primary,
              size: 21,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              mainAxisAlignment:
              MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight:
                    FontWeight.bold,
                    color:
                    SmritiTheme.primaryDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 2,
                  overflow:
                  TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color:
                    SmritiTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SmritiTheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: SmritiTheme.border,
        ),
      ),
      child: child,
    );
  }

  Widget _buildRecentActivity() {
    if (_recentSessions.isEmpty) {
      return _sectionCard(
        child: const Text(
          'No completed activities yet.',
          style: TextStyle(
            fontSize: 15,
            color: SmritiTheme.textSecondary,
          ),
        ),
      );
    }

    return _sectionCard(
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: SmritiTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 12),
          ..._recentSessions.map(
                (session) => Padding(
              padding:
              const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color:
                      SmritiTheme.softGreen,
                      borderRadius:
                      BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.psychology_rounded,
                      size: 21,
                      color:
                      SmritiTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.gameName,
                          maxLines: 1,
                          overflow:
                          TextOverflow.ellipsis,
                          style:
                          const TextStyle(
                            fontSize: 15,
                            fontWeight:
                            FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(
                            session.startedAt,
                          ),
                          style:
                          const TextStyle(
                            fontSize: 12,
                            color: SmritiTheme
                                .textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${(session.accuracy * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight:
                      FontWeight.bold,
                      color:
                      SmritiTheme.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceBreakdown() {
    final total =
        _totalCorrect +
            _totalIncorrect +
            _totalDontKnow;

    double fraction(int value) {
      if (total == 0) {
        return 0;
      }
      return value / total;
    }

    return _sectionCard(
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Text(
            'Answer Breakdown',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: SmritiTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 16),
          _progressRow(
            'Correct',
            _totalCorrect,
            fraction(_totalCorrect),
          ),
          const SizedBox(height: 12),
          _progressRow(
            'Incorrect',
            _totalIncorrect,
            fraction(_totalIncorrect),
          ),
          const SizedBox(height: 12),
          _progressRow(
            "Don't know",
            _totalDontKnow,
            fraction(_totalDontKnow),
          ),
        ],
      ),
    );
  }

  Widget _progressRow(
      String label,
      int value,
      double fraction,
      ) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color:
                  SmritiTheme.textSecondary,
                ),
              ),
            ),
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 14,
                fontWeight:
                FontWeight.w600,
                color:
                SmritiTheme.primaryDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius:
          BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value:
            fraction.clamp(0.0, 1.0),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildMemoryEngagement() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Text(
            'Memory Engagement',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: SmritiTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              _smallChip(
                Icons.photo_library_rounded,
                'Memories: ${_memories.length}',
              ),
              _smallChip(
                Icons.visibility_rounded,
                'Seen: $_memoriesSeen',
              ),
              _smallChip(
                Icons.favorite_rounded,
                'Remembered: $_rememberedCount',
              ),
              _smallChip(
                Icons.help_outline_rounded,
                'Not sure: $_notSureCount',
              ),
              _smallChip(
                Icons.mic_rounded,
                'Voice recall: $_voiceRecallCount',
              ),
              _smallChip(
                Icons.refresh_rounded,
                'Review due: $_reviewDue',
              ),
              _smallChip(
                Icons.psychology_rounded,
                'Familiarity: ${_averageFamiliarity.round()}/100',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _smallChip(
      IconData icon,
      String text,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: SmritiTheme.softGreen,
        borderRadius:
        BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: SmritiTheme.primary,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight:
              FontWeight.w600,
              color:
              SmritiTheme.primaryDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBaselineCard() {
    final recentAccuracy = _recentAccuracy;
    final recentTime = _recentResponseTime;

    return _sectionCard(
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: SmritiTheme.softGreen,
                  borderRadius:
                  BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.compare_arrows_rounded,
                  color: _changeIconColor(),
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personal Activity Pattern',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight:
                        FontWeight.bold,
                        color:
                        SmritiTheme.primaryDark,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Based on recent completed sessions.',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                        SmritiTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (recentAccuracy != null)
            Row(
              children: [
                Expanded(
                  child: _baselineValue(
                    '${(recentAccuracy * 100).round()}%',
                    'Recent accuracy',
                  ),
                ),
                if (recentTime != null)
                  Expanded(
                    child: _baselineValue(
                      '${recentTime.toStringAsFixed(1)}s',
                      'Recent response time',
                    ),
                  ),
              ],
            )
          else
            const Text(
              'Complete more activities to build a useful personal activity pattern.',
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: SmritiTheme.textSecondary,
              ),
            ),

          const SizedBox(height: 12),

          Container(
            padding:
            const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SmritiTheme.softGreen,
              borderRadius:
              BorderRadius.circular(15),
            ),
            child: Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 19,
                  color:
                  _changeIconColor(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _activityChangeText,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color:
                      SmritiTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _baselineValue(
      String value,
      String label,
      ) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: SmritiTheme.primaryDark,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: SmritiTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildMemoryHighlights() {
    final memories = List<Memory>.from(
      _memories,
    )..sort(
          (a, b) => _enhancementStore
          .enhancementFor(b.id)
          .familiarityScore
          .compareTo(
        _enhancementStore
            .enhancementFor(a.id)
            .familiarityScore,
      ),
    );

    final shown = memories.take(3).toList();

    if (shown.isEmpty) {
      return const SizedBox.shrink();
    }

    return _sectionCard(
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Text(
            'Memory Highlights',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: SmritiTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 12),
          ...shown.map(
                (memory) {
              final enhancement =
              _enhancementStore
                  .enhancementFor(
                  memory.id);

              final image =
              _memoryImage(memory);

              return Padding(
                padding:
                const EdgeInsets.only(
                  bottom: 10,
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius:
                      BorderRadius.circular(
                          12),
                      child: SizedBox(
                        width: 52,
                        height: 52,
                        child: image != null
                            ? Image(
                          image: image,
                          fit: BoxFit.cover,
                        )
                            : Container(
                          color: SmritiTheme
                              .softGreen,
                          child: const Icon(
                            Icons.photo_rounded,
                            color: SmritiTheme
                                .primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                        children: [
                          Text(
                            memory.title,
                            maxLines: 1,
                            overflow:
                            TextOverflow
                                .ellipsis,
                            style:
                            const TextStyle(
                              fontSize: 15,
                              fontWeight:
                              FontWeight.w600,
                            ),
                          ),
                          const SizedBox(
                            height: 3,
                          ),
                          Text(
                            'Familiarity ${enhancement.familiarityScore.round()}/100',
                            style:
                            const TextStyle(
                              fontSize: 12,
                              color: SmritiTheme
                                  .textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (enhancement
                        .isDueForReview)
                      const Icon(
                        Icons.refresh_rounded,
                        size: 20,
                        color: SmritiTheme.primary,
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day =
    date.day.toString().padLeft(2, '0');
    final month =
    date.month.toString().padLeft(2, '0');
    final year = date.year;

    return '$day/$month/$year';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title:
          const Text('Caregiver Dashboard'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title:
        const Text('Caregiver Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics:
            const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              18,
              12,
              18,
              30,
            ),
            children: [
              const Text(
                'Patient Activity Overview',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: SmritiTheme.primaryDark,
                ),
              ),

              const SizedBox(height: 5),

              const Text(
                'A simple view of daily cognitive activity and memory engagement.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color:
                  SmritiTheme.textSecondary,
                ),
              ),

              const SizedBox(height: 18),

              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics:
                const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.65,
                children: [
                  _metricCard(
                    icon: Icons.play_circle_outline_rounded,
                    value: '$_totalSessions',
                    label: 'Sessions',
                  ),
                  _metricCard(
                    icon: Icons.quiz_outlined,
                    value: '$_totalQuestions',
                    label: 'Questions',
                  ),
                  _metricCard(
                    icon: Icons.check_circle_outline_rounded,
                    value:
                    '${(_overallAccuracy * 100).round()}%',
                    label: 'Overall accuracy',
                  ),
                  _metricCard(
                    icon: Icons.timer_outlined,
                    value:
                    '${_averageResponseTime.toStringAsFixed(1)}s',
                    label: 'Average response',
                  ),
                ],
              ),

              const SizedBox(height: 16),

              _buildPerformanceBreakdown(),

              const SizedBox(height: 16),

              _buildMemoryEngagement(),

              const SizedBox(height: 16),

              _buildBaselineCard(),

              const SizedBox(height: 16),

              _buildRecentActivity(),

              const SizedBox(height: 16),

              _buildMemoryHighlights(),

              const SizedBox(height: 18),

              const Text(
                'Caregiver Tools',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: SmritiTheme.primaryDark,
                ),
              ),

              const SizedBox(height: 10),

              _toolButton(
                icon: Icons.insights_rounded,
                title: 'Cognitive Activity',
                subtitle:
                'Open the complete activity history and analytics.',
                onTap: _openAnalytics,
              ),

              const SizedBox(height: 10),

              _toolButton(
                icon: Icons.photo_library_rounded,
                title: 'Memory Studio',
                subtitle:
                'Manage memories, questions, albums and personalization.',
                onTap: _openMemoryStudio,
              ),

              const SizedBox(height: 10),

              _toolButton(
                icon: Icons.family_restroom_rounded,
                title: 'Family Management',
                subtitle:
                'Manage family members and their information.',
                onTap: _openFamily,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: SmritiTheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius:
        BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius:
            BorderRadius.circular(20),
            border: Border.all(
              color: SmritiTheme.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: SmritiTheme.softGreen,
                  borderRadius:
                  BorderRadius.circular(15),
                ),
                child: Icon(
                  icon,
                  color: SmritiTheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                      const TextStyle(
                        fontSize: 16,
                        fontWeight:
                        FontWeight.w700,
                        color: SmritiTheme
                            .textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style:
                      const TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: SmritiTheme
                            .textSecondary,
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
    );
  }
}