import 'package:flutter/material.dart';

import '../theme/smriti_theme.dart';
import 'caregiver_access_screen.dart';
import 'patient_home_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),

                // Logo / App icon
                Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: SmritiTheme.softGreen,
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      size: 52,
                      color: SmritiTheme.primary,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  'SMRITI',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                    color: SmritiTheme.primaryDark,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  'Memory, comfort and connection',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: SmritiTheme.textSecondary,
                  ),
                ),

                const SizedBox(height: 48),

                const Text(
                  'Welcome to SMRITI',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: SmritiTheme.primaryDark,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'How would you like to continue?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: SmritiTheme.textSecondary,
                  ),
                ),

                const SizedBox(height: 30),

                _buildRoleCard(
                  context: context,
                  icon: Icons.person_rounded,
                  title: 'Continue as Patient',
                  subtitle:
                  'Access memories, games, routine and everyday support.',
                  buttonText: 'Continue as Patient',
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                        const PatientHomeScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 18),

                _buildRoleCard(
                  context: context,
                  icon: Icons.admin_panel_settings_rounded,
                  title: 'Caregiver Login',
                  subtitle:
                  'Manage memories, family information and patient activity.',
                  buttonText: 'Login as Caregiver',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                        const CaregiverAccessScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 30),

                const Text(
                  'Patient access is designed to be simple and passwordless. '
                      'Caregiver controls are protected separately.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: SmritiTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(
          color: SmritiTheme.border,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: SmritiTheme.softGreen,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      icon,
                      size: 30,
                      color: SmritiTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: SmritiTheme.primaryDark,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: SmritiTheme.textSecondary,
                ),
              ),

              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: onTap,
                  child: Text(
                    buttonText,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
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