import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/smriti_theme.dart';
import 'caregiver_dashboard_screen.dart';

class CaregiverAccessScreen extends StatefulWidget {
  const CaregiverAccessScreen({super.key});

  @override
  State<CaregiverAccessScreen> createState() =>
      _CaregiverAccessScreenState();
}

class _CaregiverAccessScreenState
    extends State<CaregiverAccessScreen> {
  static const String _pinKey = 'smriti_caregiver_pin';

  final SharedPreferencesAsync _prefs =
  SharedPreferencesAsync();

  final TextEditingController _pinController =
  TextEditingController();

  final TextEditingController _confirmPinController =
  TextEditingController();

  bool _loading = true;
  bool _hasPin = false;
  bool _obscurePin = true;
  bool _obscureConfirmPin = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadPinState();
  }

  Future<void> _loadPinState() async {
    final pin = await _prefs.getString(_pinKey);

    if (!mounted) return;

    setState(() {
      _hasPin = pin != null && pin.isNotEmpty;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _setupPin() async {
    final pin = _pinController.text.trim();
    final confirm = _confirmPinController.text.trim();

    if (pin.length < 4 || pin.length > 6) {
      _showMessage(
        'PIN must contain 4 to 6 digits.',
      );
      return;
    }

    if (!RegExp(r'^\d+$').hasMatch(pin)) {
      _showMessage(
        'PIN can contain numbers only.',
      );
      return;
    }

    if (pin != confirm) {
      _showMessage(
        'The PINs do not match.',
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    await _prefs.setString(
      _pinKey,
      pin,
    );

    if (!mounted) return;

    setState(() {
      _hasPin = true;
      _saving = false;
      _pinController.clear();
      _confirmPinController.clear();
    });

    _showMessage(
      'Caregiver PIN created successfully.',
    );
  }

  Future<void> _unlock() async {
    final enteredPin =
    _pinController.text.trim();

    if (enteredPin.isEmpty) {
      _showMessage(
        'Please enter your caregiver PIN.',
      );
      return;
    }

    final savedPin =
    await _prefs.getString(_pinKey);

    if (!mounted) return;

    if (savedPin == null || savedPin.isEmpty) {
      setState(() {
        _hasPin = false;
      });
      return;
    }

    if (enteredPin != savedPin) {
      _pinController.clear();

      _showMessage(
        'Incorrect caregiver PIN.',
      );
      return;
    }

    _pinController.clear();

    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const CaregiverDashboardScreen(),
      ),
    );
  }

  Future<void> _resetPin() async {
    final shouldReset =
    await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Reset caregiver PIN?',
          ),
          content: const Text(
            'This will remove the current caregiver PIN and let you create a new one.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                    context,
                    false,
                  ),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(
                    context,
                    true,
                  ),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );

    if (shouldReset != true) {
      return;
    }

    await _prefs.remove(_pinKey);

    if (!mounted) return;

    setState(() {
      _hasPin = false;
      _pinController.clear();
      _confirmPinController.clear();
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: IconButton(
        tooltip:
        obscure ? 'Show PIN' : 'Hide PIN',
        icon: Icon(
          obscure
              ? Icons.visibility_rounded
              : Icons.visibility_off_rounded,
        ),
        onPressed: onToggle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Caregiver Access',
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Caregiver Access',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            22,
            24,
            22,
            30,
          ),
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: SmritiTheme.softGreen,
                borderRadius:
                BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.verified_user_rounded,
                size: 48,
                color: SmritiTheme.primary,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              _hasPin
                  ? 'Welcome, Caregiver'
                  : 'Set Up Caregiver Access',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color:
                SmritiTheme.primaryDark,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              _hasPin
                  ? 'Enter your PIN to access patient information and caregiver tools.'
                  : 'Create a private PIN to protect caregiver controls.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                height: 1.4,
                color:
                SmritiTheme.textSecondary,
              ),
            ),

            const SizedBox(height: 28),

            if (_hasPin) ...[
              TextField(
                controller:
                _pinController,
                obscureText: _obscurePin,
                keyboardType:
                TextInputType.number,
                maxLength: 6,
                decoration:
                _inputDecoration(
                  label: 'Caregiver PIN',
                  icon:
                  Icons.lock_rounded,
                  obscure:
                  _obscurePin,
                  onToggle: () {
                    setState(() {
                      _obscurePin =
                      !_obscurePin;
                    });
                  },
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                height: 54,
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                  _unlock,
                  icon: const Icon(
                    Icons.lock_open_rounded,
                  ),
                  label: const Text(
                    'Open Caregiver Dashboard',
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              TextButton(
                onPressed: _resetPin,
                child: const Text(
                  'Reset Caregiver PIN',
                ),
              ),
            ] else ...[
              TextField(
                controller:
                _pinController,
                obscureText:
                _obscurePin,
                keyboardType:
                TextInputType.number,
                maxLength: 6,
                decoration:
                _inputDecoration(
                  label:
                  'Create PIN',
                  icon:
                  Icons.lock_outline_rounded,
                  obscure:
                  _obscurePin,
                  onToggle: () {
                    setState(() {
                      _obscurePin =
                      !_obscurePin;
                    });
                  },
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller:
                _confirmPinController,
                obscureText:
                _obscureConfirmPin,
                keyboardType:
                TextInputType.number,
                maxLength: 6,
                decoration:
                _inputDecoration(
                  label:
                  'Confirm PIN',
                  icon:
                  Icons.lock_rounded,
                  obscure:
                  _obscureConfirmPin,
                  onToggle: () {
                    setState(() {
                      _obscureConfirmPin =
                      !_obscureConfirmPin;
                    });
                  },
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                height: 54,
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                  _saving
                      ? null
                      : _setupPin,
                  icon: const Icon(
                    Icons.verified_user_rounded,
                  ),
                  label: Text(
                    _saving
                        ? 'Setting up...'
                        : 'Create Caregiver PIN',
                    style: const TextStyle(
                      fontSize: 17,
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 26),

            Container(
              padding:
              const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color:
                SmritiTheme.softGreen,
                borderRadius:
                BorderRadius.circular(18),
                border: Border.all(
                  color:
                  SmritiTheme.border,
                ),
              ),
              child: const Row(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color:
                    SmritiTheme.primary,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Caregiver access is kept separate from the simple patient experience.',
                      style: TextStyle(
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
      ),
    );
  }
}