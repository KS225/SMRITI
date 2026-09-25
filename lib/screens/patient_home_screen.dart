import 'package:flutter/material.dart';

import '../models/patient_profile.dart';
import '../theme/smriti_theme.dart';
import '../widgets/smriti_action_button.dart';
import '../widgets/smriti_feature_card.dart';
import 'family_screen.dart';
import 'memories_screen.dart';
import 'routine_screen.dart';
import 'games_screen.dart';
import 'find_my_phone_screen.dart';
import 'help_screen.dart';
import 'nutrition_screen.dart';
import 'orientation_screen.dart';
import 'smriti_companion_screen.dart';

class PatientHomeScreen extends StatelessWidget {
  const PatientHomeScreen({super.key});

  static const PatientProfile patient = PatientProfile(
    id: 'patient_demo',
    name: 'Your Name',
    preferredLanguage: 'English',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'SMRITI',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: SmritiTheme.primaryDark,
                ),
              ),

              const SizedBox(height: 24),

              _buildGreetingCard(),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: SmritiFeatureCard(
                      icon: Icons.access_time_rounded,
                      title: 'My Routine',
                      subtitle: 'Today',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RoutineScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: SmritiFeatureCard(
                      icon: Icons.family_restroom_rounded,
                      title: 'My Family',
                      subtitle: 'People I love',
                      onTap: () {
                    Navigator.push(
                    context,
                    MaterialPageRoute(
                    builder: (context) => const FamilyScreen(),
                    ),
                    );
                    },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: SmritiFeatureCard(
                      icon: Icons.photo_library_rounded,
                      title: 'My Memories',
                      subtitle: 'Special moments',
                      onTap: ()  {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MemoriesScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: SmritiFeatureCard(
                      icon: Icons.extension_rounded,
                      title: "Let's Play",
                      subtitle: 'Fun & games',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const GamesScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              SmritiActionButton(
                icon: Icons.location_on_rounded,
                title: 'Where am I?',
                subtitle: 'Help me understand where I am',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                      const OrientationScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 14),

              SmritiActionButton(
                icon: Icons.restaurant_rounded,
                title: 'My Nutrition',
                subtitle: 'Meals and water for today',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                      const NutritionScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 14),

              SmritiActionButton(
                icon: Icons.favorite_rounded,
                title: 'I Need Help',
                subtitle: 'Contact my caregiver',
                isEmergency: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                      const HelpScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),

              const SizedBox(height: 14),

              SmritiActionButton(
                icon: Icons.phone_android_rounded,
                title: 'Find My Phone',
                subtitle: 'Make my phone play an alert',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                      const FindMyPhoneScreen(),
                    ),
                  );
                },
              ),

              SmritiActionButton(
                icon: Icons.mic_rounded,
                title: 'Talk to SMRITI',
                subtitle: 'Ask me something',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                      const SmritiCompanionScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreetingCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: SmritiTheme.softGreen,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Text(
            'Good Morning ❤️',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: SmritiTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            patient.name,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: SmritiTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'What would you like to do?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: SmritiTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}