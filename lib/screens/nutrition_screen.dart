import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/smriti_theme.dart';

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() =>
      _NutritionScreenState();
}

class _NutritionScreenState
    extends State<NutritionScreen> {
  static const String _waterKey =
      'smriti_water_glasses';

  final SharedPreferencesAsync _prefs =
  SharedPreferencesAsync();

  int _waterGlasses = 0;

  final Map<String, bool> _meals = {
    'Breakfast': false,
    'Lunch': false,
    'Snack': false,
    'Dinner': false,
  };

  @override
  void initState() {
    super.initState();
    _loadWater();
  }

  Future<void> _loadWater() async {
    final saved =
    await _prefs.getInt(_waterKey);

    if (!mounted) return;

    setState(() {
      _waterGlasses = saved ?? 0;
    });
  }

  Future<void> _addWater() async {
    if (_waterGlasses >= 12) return;

    setState(() {
      _waterGlasses++;
    });

    await _prefs.setInt(
      _waterKey,
      _waterGlasses,
    );
  }

  Future<void> _removeWater() async {
    if (_waterGlasses <= 0) return;

    setState(() {
      _waterGlasses--;
    });

    await _prefs.setInt(
      _waterKey,
      _waterGlasses,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Nutrition'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: SmritiTheme.softGreen,
                borderRadius:
                BorderRadius.circular(24),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.restaurant_rounded,
                    size: 48,
                    color: SmritiTheme.primary,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Take Care of Yourself',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color:
                      SmritiTheme.primaryDark,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Keep track of meals and water throughout the day.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color:
                      SmritiTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Today\'s Meals',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: SmritiTheme.primaryDark,
              ),
            ),

            const SizedBox(height: 12),

            ..._meals.keys.map(
                  (meal) => _buildMealCard(meal),
            ),

            const SizedBox(height: 24),

            const Text(
              'Water',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: SmritiTheme.primaryDark,
              ),
            ),

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                BorderRadius.circular(22),
                border: Border.all(
                  color: SmritiTheme.border,
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.water_drop_rounded,
                    size: 44,
                    color: SmritiTheme.primary,
                  ),

                  const SizedBox(height: 8),

                  Text(
                    '$_waterGlasses glasses',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color:
                      SmritiTheme.primaryDark,
                    ),
                  ),

                  const SizedBox(height: 4),

                  const Text(
                    'Water tracked today',
                    style: TextStyle(
                      color:
                      SmritiTheme.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: _removeWater,
                        icon: const Icon(
                          Icons.remove_circle_outline,
                        ),
                        iconSize: 32,
                      ),
                      const SizedBox(width: 20),
                      IconButton(
                        onPressed: _addWater,
                        icon: const Icon(
                          Icons.add_circle,
                        ),
                        iconSize: 38,
                        color:
                        SmritiTheme.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            const Text(
              'Note: nutrition information in SMRITI is intended for reminders and personal tracking. Individual dietary needs should be guided by the patient\'s caregiver and healthcare professional.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: SmritiTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealCard(String meal) {
    final completed = _meals[meal] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(18),
        border: Border.all(
          color: SmritiTheme.border,
        ),
      ),
      child: CheckboxListTile(
        value: completed,
        onChanged: (value) {
          setState(() {
            _meals[meal] = value ?? false;
          });
        },
        title: Text(
          meal,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: SmritiTheme.primaryDark,
          ),
        ),
        subtitle: Text(
          completed
              ? 'Completed'
              : 'Not marked yet',
        ),
        secondary: Icon(
          completed
              ? Icons.check_circle_rounded
              : Icons.restaurant_menu_rounded,
          color: completed
              ? SmritiTheme.primary
              : SmritiTheme.textSecondary,
        ),
      ),
    );
  }
}