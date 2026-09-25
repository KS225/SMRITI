import 'package:flutter/material.dart';

import '../screens/role_selection_screen.dart';
import '../theme/smriti_theme.dart';

class SmritiApp extends StatelessWidget {
  const SmritiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SMRITI',
      debugShowCheckedModeBanner: false,
      theme: SmritiTheme.lightTheme(),
      home: const RoleSelectionScreen(),
    );
  }
}