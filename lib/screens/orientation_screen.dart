import 'dart:async';

import 'package:flutter/material.dart';

import '../models/patient_profile.dart';
import '../theme/smriti_theme.dart';

class OrientationScreen extends StatefulWidget {
  const OrientationScreen({super.key});

  @override
  State<OrientationScreen> createState() =>
      _OrientationScreenState();
}

class _OrientationScreenState
    extends State<OrientationScreen> {
  static const PatientProfile patient = PatientProfile(
    id: 'patient_demo',
    name: 'Your Name',
    preferredLanguage: 'English',
  );

  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(
      const Duration(seconds: 30),
          (_) {
        if (!mounted) return;

        setState(() {
          _now = DateTime.now();
        });
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _dayName() {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    return days[_now.weekday - 1];
  }

  String _monthName() {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return months[_now.month - 1];
  }

  String _formatTime() {
    final hour = _now.hour == 0
        ? 12
        : _now.hour > 12
        ? _now.hour - 12
        : _now.hour;

    final minute =
    _now.minute.toString().padLeft(2, '0');

    final period = _now.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Where Am I?'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: SmritiTheme.softGreen,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                      BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.home_rounded,
                      size: 42,
                      color: SmritiTheme.primary,
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'You are safe',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: SmritiTheme.primaryDark,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'This is your SMRITI orientation page.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color:
                      SmritiTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            _buildInfoCard(
              icon: Icons.person_rounded,
              title: 'You',
              value: patient.name,
            ),

            const SizedBox(height: 12),

            _buildInfoCard(
              icon: Icons.calendar_today_rounded,
              title: 'Today',
              value:
              '${_dayName()}, ${_now.day} ${_monthName()} ${_now.year}',
            ),

            const SizedBox(height: 12),

            _buildInfoCard(
              icon: Icons.access_time_rounded,
              title: 'Current Time',
              value: _formatTime(),
            ),

            const SizedBox(height: 12),

            _buildInfoCard(
              icon: Icons.home_work_rounded,
              title: 'Familiar Place',
              value: 'Home',
            ),

            const SizedBox(height: 22),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: SmritiTheme.border,
                ),
              ),
              child: const Row(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    color: SmritiTheme.primary,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You can use this page whenever you feel confused '
                          'about the day, time or where you are.',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        color: SmritiTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(
                  Icons.check_circle_outline_rounded,
                ),
                label: const Text(
                  'I Understand',
                  style: TextStyle(fontSize: 17),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
              icon,
              color: SmritiTheme.primary,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color:
                    SmritiTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color:
                    SmritiTheme.primaryDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}