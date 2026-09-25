import 'package:flutter/material.dart';

import '../data/cognitive_session_store.dart';
import '../models/cognitive_session.dart';
import '../theme/smriti_theme.dart';

class CognitiveActivityScreen extends StatefulWidget {
  const CognitiveActivityScreen({
    super.key,
  });

  @override
  State<CognitiveActivityScreen> createState() =>
      _CognitiveActivityScreenState();
}

class _CognitiveActivityScreenState
    extends State<CognitiveActivityScreen> {
  final CognitiveSessionStore _sessionStore =
      CognitiveSessionStore.instance;

  @override
  void initState() {
    super.initState();

    _sessionStore.addListener(_refresh);

    _initialize();
  }

  Future<void> _initialize() async {
    await _sessionStore.initialize();

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _sessionStore.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // DATE
  // ============================================================

  String _formatDate(DateTime date) {
    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final sessionDay = DateTime(
      date.year,
      date.month,
      date.day,
    );

    final difference =
        today.difference(sessionDay).inDays;

    if (difference == 0) {
      return 'Today';
    }

    if (difference == 1) {
      return 'Yesterday';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  // ============================================================
  // TIME
  // ============================================================

  String _formatTime(DateTime date) {
    final hour = date.hour % 12 == 0
        ? 12
        : date.hour % 12;

    final minute =
    date.minute.toString().padLeft(2, '0');

    final period =
    date.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }

  // ============================================================
  // DURATION
  // ============================================================

  String _formatDuration(int seconds) {
    if (seconds < 60) {
      return '${seconds}s';
    }

    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;

    if (remainingSeconds == 0) {
      return '$minutes min';
    }

    return '$minutes min ${remainingSeconds}s';
  }

  // ============================================================
  // BASELINE DATA
  // ============================================================

  List<CognitiveSession> get _whoIsThisSessions {
    return _sessionStore.sessions
        .where(
          (session) =>
      session.gameId == 'who_is_this',
    )
        .toList();
  }

  double? get _baselineAccuracy {
    final sessions = _whoIsThisSessions;

    // Need at least 3 sessions to establish
    // a useful personal baseline.
    if (sessions.length < 3) {
      return null;
    }

    // Use the 3 most recent completed sessions
    // as the initial personal baseline.
    final baselineSessions =
    sessions.take(3).toList();

    final total = baselineSessions.fold<double>(
      0,
          (sum, session) =>
      sum + session.accuracy,
    );

    return total / baselineSessions.length;
  }

  double? get _baselineQuestionTime {
    final sessions = _whoIsThisSessions;

    if (sessions.length < 3) {
      return null;
    }

    final baselineSessions =
    sessions.take(3).toList();

    final total =
    baselineSessions.fold<double>(
      0,
          (sum, session) =>
      sum +
          session.averageQuestionTimeSeconds,
    );

    return total / baselineSessions.length;
  }

  CognitiveSession? get _latestSession {
    final sessions = _whoIsThisSessions;

    if (sessions.isEmpty) {
      return null;
    }

    return sessions.first;
  }

  // ============================================================
  // BASELINE STATUS
  // ============================================================

  Widget _buildBaselineCard() {
    final sessions = _whoIsThisSessions;
    final baselineAccuracy =
        _baselineAccuracy;
    final baselineTime =
        _baselineQuestionTime;
    final latest = _latestSession;

    final int sessionCount =
        sessions.length;

    final bool baselineEstablished =
        baselineAccuracy != null;

    double? accuracyChange;

    if (baselineEstablished &&
        latest != null) {
      accuracyChange =
          latest.accuracy -
              baselineAccuracy;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SmritiTheme.softGreen,
        borderRadius:
        BorderRadius.circular(24),
        border: Border.all(
          color: SmritiTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: SmritiTheme.surface,
                  borderRadius:
                  BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: SmritiTheme.primary,
                  size: 27,
                ),
              ),

              const SizedBox(width: 12),

              const Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personal Baseline',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight:
                        FontWeight.bold,
                        color:
                        SmritiTheme.primaryDark,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Your usual performance',
                      style: TextStyle(
                        fontSize: 14,
                        color:
                        SmritiTheme
                            .textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          if (!baselineEstablished) ...[
            Text(
              sessionCount == 0
                  ? 'Complete 3 sessions to start building your personal baseline.'
                  : 'Baseline is being built. '
                  'Complete ${3 - sessionCount} '
                  '${3 - sessionCount == 1 ? 'more session' : 'more sessions'}.',
              style: const TextStyle(
                fontSize: 15,
                height: 1.4,
                color:
                SmritiTheme.textPrimary,
              ),
            ),

            const SizedBox(height: 14),

            ClipRRect(
              borderRadius:
              BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value:
                (sessionCount / 3)
                    .clamp(0.0, 1.0),
                minHeight: 8,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              '$sessionCount of 3 sessions completed',
              style: const TextStyle(
                fontSize: 13,
                color:
                SmritiTheme.textSecondary,
              ),
            ),
          ] else ...[
            const Text(
              'Baseline established from your recent '
                  'Who Is This? sessions.',
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color:
                SmritiTheme.textPrimary,
              ),
            ),

            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(
                  child: _buildBaselineMetric(
                    value:
                    '${(baselineAccuracy! * 100).round()}%',
                    label:
                    'Average accuracy',
                  ),
                ),

                Container(
                  width: 1,
                  height: 48,
                  color: SmritiTheme.border,
                ),

                Expanded(
                  child: _buildBaselineMetric(
                    value:
                    '${baselineTime!.toStringAsFixed(1)}s',
                    label:
                    'Avg. question time',
                  ),
                ),
              ],
            ),

            if (accuracyChange != null) ...[
              const SizedBox(height: 18),

              Container(
                width: double.infinity,
                padding:
                const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color:
                  SmritiTheme.surface,
                  borderRadius:
                  BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      accuracyChange > 0
                          ? Icons
                          .trending_up_rounded
                          : accuracyChange < 0
                          ? Icons
                          .trending_down_rounded
                          : Icons
                          .trending_flat_rounded,
                      color:
                      SmritiTheme.primary,
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: Text(
                        'Latest accuracy: '
                            '${(latest!.accuracy * 100).round()}% '
                            '(${accuracyChange >= 0 ? '+' : ''}'
                            '${(accuracyChange * 100).round()}% '
                            'from baseline)',
                        style:
                        const TextStyle(
                          fontSize: 14,
                          fontWeight:
                          FontWeight.w600,
                          color:
                          SmritiTheme
                              .textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ============================================================
  // BASELINE METRIC
  // ============================================================

  Widget _buildBaselineMetric({
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
            color: SmritiTheme.primaryDark,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            color:
            SmritiTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SESSION CARD
  // ============================================================

  Widget _buildSessionCard(
      CognitiveSession session,
      ) {
    final accuracy =
    (session.accuracy * 100).round();

    return Container(
      margin: const EdgeInsets.only(
        bottom: 14,
      ),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SmritiTheme.surface,
        borderRadius:
        BorderRadius.circular(20),
        border: Border.all(
          color: SmritiTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color:
                  SmritiTheme.softGreen,
                  borderRadius:
                  BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.family_restroom_rounded,
                  color:
                  SmritiTheme.primary,
                  size: 27,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.gameName,
                      style:
                      const TextStyle(
                        fontSize: 19,
                        fontWeight:
                        FontWeight.bold,
                        color:
                        SmritiTheme
                            .textPrimary,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      _formatTime(
                        session.startedAt,
                      ),
                      style:
                      const TextStyle(
                        fontSize: 14,
                        color:
                        SmritiTheme
                            .textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              if (session.completed)
                const Icon(
                  Icons.check_circle_rounded,
                  color:
                  SmritiTheme.primary,
                  size: 25,
                ),
            ],
          ),

          const SizedBox(height: 18),

          Container(
            width: double.infinity,
            padding:
            const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:
              SmritiTheme.softGreen,
              borderRadius:
              BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${session.correctAnswers}'
                            ' / '
                            '${session.totalQuestions}',
                        style:
                        const TextStyle(
                          fontSize: 25,
                          fontWeight:
                          FontWeight.bold,
                          color:
                          SmritiTheme
                              .primaryDark,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Score',
                        style: TextStyle(
                          fontSize: 13,
                          color:
                          SmritiTheme
                              .textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  width: 1,
                  height: 40,
                  color:
                  SmritiTheme.border,
                ),

                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '$accuracy%',
                        style:
                        const TextStyle(
                          fontSize: 25,
                          fontWeight:
                          FontWeight.bold,
                          color:
                          SmritiTheme
                              .primaryDark,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Accuracy',
                        style: TextStyle(
                          fontSize: 13,
                          color:
                          SmritiTheme
                              .textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInfoChip(
                Icons.touch_app_rounded,
                'Attempts: ${session.attempts}',
              ),

              _buildInfoChip(
                Icons.help_outline_rounded,
                "Don't know: "
                    '${session.dontKnowAnswers}',
              ),

              _buildInfoChip(
                Icons.favorite_rounded,
                'Remembered: '
                    '${session.memoryRememberedCount}',
              ),

              _buildInfoChip(
                Icons.help_outline_rounded,
                'Memory unsure: '
                    '${session.memoryNotSureCount}',
              ),

              _buildInfoChip(
                Icons.timer_outlined,
                'Duration: '
                    '${_formatDuration(session.durationSeconds)}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INFO CHIP
  // ============================================================

  Widget _buildInfoChip(
      IconData icon,
      String text,
      ) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: SmritiTheme.background,
        borderRadius:
        BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: SmritiTheme.primary,
          ),

          const SizedBox(width: 5),

          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
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
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final sessions =
        _sessionStore.sessions;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Cognitive Activity',
        ),
      ),

      body: SafeArea(
        child: sessions.isEmpty
            ? _buildEmptyState()
            : ListView(
          padding:
          const EdgeInsets.fromLTRB(
            20,
            10,
            20,
            30,
          ),
          children: [
            const Text(
              'Your Activity',
              textAlign:
              TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight:
                FontWeight.bold,
                color:
                SmritiTheme
                    .primaryDark,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'SMRITI keeps track of your '
                  'completed activities to understand '
                  'your personal progress over time.',
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

            const SizedBox(height: 22),

            // ==================================================
            // PERSONAL BASELINE
            // ==================================================

            _buildBaselineCard(),

            const SizedBox(height: 26),

            // ==================================================
            // HISTORY
            // ==================================================

            const Text(
              'Activity History',
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                FontWeight.bold,
                color:
                SmritiTheme
                    .primaryDark,
              ),
            ),

            const SizedBox(height: 12),

            ...sessions.map(
                  (session) => Column(
                crossAxisAlignment:
                CrossAxisAlignment
                    .start,
                children: [
                  Padding(
                    padding:
                    const EdgeInsets
                        .only(
                      bottom: 10,
                      left: 2,
                    ),
                    child: Text(
                      _formatDate(
                        session.startedAt,
                      ),
                      style:
                      const TextStyle(
                        fontSize: 18,
                        fontWeight:
                        FontWeight.bold,
                        color:
                        SmritiTheme
                            .primaryDark,
                      ),
                    ),
                  ),

                  _buildSessionCard(
                    session,
                  ),

                  const SizedBox(
                    height: 4,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color:
                SmritiTheme.softGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.insights_rounded,
                size: 52,
                color:
                SmritiTheme.primary,
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'No activities yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight:
                FontWeight.bold,
                color:
                SmritiTheme.primaryDark,
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              'Complete a cognitive game and '
                  'your activity will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                height: 1.4,
                color:
                SmritiTheme
                    .textSecondary,
              ),
            ),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(
                  Icons.arrow_back_rounded,
                ),
                label: const Text(
                  'Back to Games',
                  style: TextStyle(
                    fontSize: 17,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}