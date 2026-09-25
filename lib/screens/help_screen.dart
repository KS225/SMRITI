import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/family_store.dart';
import '../models/family_member.dart';
import '../theme/smriti_theme.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() =>
      _HelpScreenState();
}

class _HelpScreenState
    extends State<HelpScreen> {
  final FamilyStore _familyStore =
      FamilyStore.instance;

  FamilyMember? _caregiver;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCaregiver();
  }

  Future<void> _loadCaregiver() async {
    await _familyStore.initialize();

    if (!mounted) return;

    FamilyMember? caregiver;

    for (final member in _familyStore.members) {
      final relationship =
      member.relationship.toLowerCase();

      if (relationship == 'caregiver' ||
          relationship.contains('caregiver')) {
        caregiver = member;
        break;
      }
    }

    caregiver ??= _familyStore.members
        .where(
          (member) =>
      member.phoneNumber != null &&
          member.phoneNumber!.trim().isNotEmpty,
    )
        .cast<FamilyMember?>()
        .firstOrNull;

    setState(() {
      _caregiver = caregiver;
      _loading = false;
    });
  }

  Future<void> _callNumber(String number) async {
    final uri = Uri(
      scheme: 'tel',
      path: number,
    );

    final launched = await launchUrl(uri);

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to open the phone dialer.',
          ),
        ),
      );
    }
  }

  Future<void> _callCaregiver() async {
    final number = _caregiver?.phoneNumber;

    if (number == null || number.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No caregiver phone number has been added yet.',
          ),
        ),
      );
      return;
    }

    await _callNumber(number);
  }

  Future<void> _callEmergencyServices() async {
    await _callNumber('112');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('I Need Help'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
          child: CircularProgressIndicator(),
        )
            : ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding:
              const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: SmritiTheme.softGreen,
                borderRadius:
                BorderRadius.circular(26),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.favorite_rounded,
                    size: 52,
                    color: SmritiTheme.primary,
                  ),
                  SizedBox(height: 14),
                  Text(
                    'You are not alone',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight:
                      FontWeight.bold,
                      color:
                      SmritiTheme.primaryDark,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Choose the kind of help you need.',
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

            const SizedBox(height: 28),

            _buildHelpCard(
              icon: Icons.person_rounded,
              title: _caregiver == null
                  ? 'My Caregiver'
                  : _caregiver!.name,
              subtitle: _caregiver
                  ?.phoneNumber ==
                  null
                  ? 'Caregiver contact is not configured'
                  : _caregiver!.phoneNumber!,
              buttonText: 'Call Caregiver',
              onPressed: _callCaregiver,
            ),

            const SizedBox(height: 18),

            _buildHelpCard(
              icon: Icons.emergency_rounded,
              title: 'Emergency Services',
              subtitle:
              'For urgent emergencies in India',
              buttonText: 'Call 112',
              emergency: true,
              onPressed:
              _callEmergencyServices,
            ),

            const SizedBox(height: 24),

            const Text(
              'The caregiver number is taken from the family information configured in SMRITI.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color:
                SmritiTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onPressed,
    bool emergency = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: emergency
              ? Colors.red.shade200
              : SmritiTheme.border,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: emergency
                  ? Colors.red.shade50
                  : SmritiTheme.softGreen,
              borderRadius:
              BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              size: 36,
              color: emergency
                  ? Colors.red.shade700
                  : SmritiTheme.primary,
            ),
          ),

          const SizedBox(height: 14),

          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: SmritiTheme.primaryDark,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: SmritiTheme.textSecondary,
            ),
          ),

          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: onPressed,
              style: emergency
                  ? FilledButton.styleFrom(
                backgroundColor:
                Colors.red.shade700,
              )
                  : null,
              icon: const Icon(
                Icons.phone_rounded,
              ),
              label: Text(
                buttonText,
                style: const TextStyle(
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension FirstOrNullExtension<T>
on Iterable<T> {
  T? get firstOrNull {
    if (isEmpty) return null;
    return first;
  }
}