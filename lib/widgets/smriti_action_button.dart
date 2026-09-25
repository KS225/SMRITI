import 'package:flutter/material.dart';

import '../theme/smriti_theme.dart';

class SmritiActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isEmergency;

  const SmritiActionButton({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isEmergency = false,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isEmergency
        ? SmritiTheme.softRed
        : SmritiTheme.softGreen;

    final iconColor = isEmergency
        ? SmritiTheme.emergency
        : SmritiTheme.primary;

    final titleColor = isEmergency
        ? const Color(0xFF8F3933)
        : SmritiTheme.primaryDark;

    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 34,
                  color: iconColor,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 14,
                          color: SmritiTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 18,
                  color: iconColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}