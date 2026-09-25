import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/smriti_theme.dart';

class FindMyPhoneScreen extends StatefulWidget {
  const FindMyPhoneScreen({super.key});

  @override
  State<FindMyPhoneScreen> createState() =>
      _FindMyPhoneScreenState();
}

class _FindMyPhoneScreenState
    extends State<FindMyPhoneScreen> {
  Timer? _alertTimer;
  Timer? _stopTimer;

  bool _isSearching = false;

  @override
  void dispose() {
    _stopAlert();
    super.dispose();
  }

  void _startAlert() {
    if (_isSearching) return;

    setState(() {
      _isSearching = true;
    });

    _playAlert();

    _alertTimer = Timer.periodic(
      const Duration(seconds: 2),
          (_) => _playAlert(),
    );

    _stopTimer = Timer(
      const Duration(seconds: 20),
      _stopAlert,
    );
  }

  void _playAlert() {
    SystemSound.play(
      SystemSoundType.alert,
    );

    HapticFeedback.heavyImpact();
  }

  void _stopAlert() {
    _alertTimer?.cancel();
    _stopTimer?.cancel();

    _alertTimer = null;
    _stopTimer = null;

    if (!mounted) return;

    setState(() {
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find My Phone'),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment:
              MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration:
                  const Duration(milliseconds: 300),
                  width: _isSearching ? 150 : 130,
                  height: _isSearching ? 150 : 130,
                  decoration: BoxDecoration(
                    color: SmritiTheme.softGreen,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isSearching
                        ? Icons.notifications_active_rounded
                        : Icons.phone_android_rounded,
                    size: 70,
                    color: SmritiTheme.primary,
                  ),
                ),

                const SizedBox(height: 30),

                Text(
                  _isSearching
                      ? 'Your phone is ringing'
                      : 'Can\'t find your phone?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: SmritiTheme.primaryDark,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  _isSearching
                      ? 'Follow the alert sound to find your phone.'
                      : 'Press the button below to play an alert on this phone.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.4,
                    color: SmritiTheme.textSecondary,
                  ),
                ),

                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: FilledButton.icon(
                    onPressed:
                    _isSearching
                        ? _stopAlert
                        : _startAlert,
                    icon: Icon(
                      _isSearching
                          ? Icons.stop_circle_outlined
                          : Icons.notifications_active_rounded,
                    ),
                    label: Text(
                      _isSearching
                          ? 'Stop Alert'
                          : 'Ring My Phone',
                      style: const TextStyle(
                        fontSize: 17,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'Future SMRITI companion devices can trigger this alert remotely when the phone is misplaced.',
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
}