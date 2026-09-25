import 'package:flutter/material.dart';

import '../models/routine_item.dart';
import '../theme/smriti_theme.dart';

class RoutineScreen extends StatefulWidget {
  const RoutineScreen({super.key});

  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen> {
  final List<RoutineItem> routineItems = [
    const RoutineItem(
      id: 'routine_001',
      title: 'Breakfast',
      description: 'Have your breakfast',
      time: '8:00 AM',
      category: 'meal',
    ),
    const RoutineItem(
      id: 'routine_002',
      title: 'Morning Medicine',
      description: 'Time for your morning medicine',
      time: '9:00 AM',
      category: 'medicine',
    ),
    const RoutineItem(
      id: 'routine_003',
      title: 'Morning Walk',
      description: 'Take a short and comfortable walk',
      time: '10:30 AM',
      category: 'activity',
    ),
    const RoutineItem(
      id: 'routine_004',
      title: 'Lunch',
      description: 'It is lunchtime',
      time: '1:00 PM',
      category: 'meal',
    ),
    const RoutineItem(
      id: 'routine_005',
      title: 'Family Time',
      description: 'Spend some time with your family',
      time: '6:00 PM',
      category: 'family',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Routine'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          children: [
            const Text(
              'Your routine for today 🌿',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: SmritiTheme.textSecondary,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'One step at a time',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: SmritiTheme.textSecondary,
              ),
            ),

            const SizedBox(height: 24),

            ...routineItems.asMap().entries.map(
                  (entry) {
                final index = entry.key;
                final item = entry.value;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: RoutineCard(
                    item: item,
                    isFirst: index == 0,
                    onComplete: () {
                      setState(() {
                        routineItems[index] = RoutineItem(
                          id: item.id,
                          title: item.title,
                          description: item.description,
                          time: item.time,
                          category: item.category,
                          completed: !item.completed,
                        );
                      });
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class RoutineCard extends StatelessWidget {
  final RoutineItem item;
  final bool isFirst;
  final VoidCallback onComplete;

  const RoutineCard({
    super.key,
    required this.item,
    required this.isFirst,
    required this.onComplete,
  });

  IconData _getIcon() {
    switch (item.category) {
      case 'meal':
        return Icons.restaurant_rounded;
      case 'medicine':
        return Icons.medication_rounded;
      case 'activity':
        return Icons.directions_walk_rounded;
      case 'family':
        return Icons.family_restroom_rounded;
      default:
        return Icons.check_circle_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = item.completed
        ? SmritiTheme.softGreen
        : SmritiTheme.surface;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onComplete,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isFirst
                  ? SmritiTheme.primary
                  : SmritiTheme.border,
              width: isFirst ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: SmritiTheme.softGreen,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  _getIcon(),
                  size: 30,
                  color: SmritiTheme.primary,
                ),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.time,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: SmritiTheme.primary,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: SmritiTheme.textPrimary,
                        decoration: item.completed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      item.description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: SmritiTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Icon(
                item.completed
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 30,
                color: item.completed
                    ? SmritiTheme.primary
                    : SmritiTheme.border,
              ),
            ],
          ),
        ),
      ),
    );
  }
}