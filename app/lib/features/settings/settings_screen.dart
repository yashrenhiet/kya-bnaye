import 'package:flutter/material.dart';

import 'package:kyabnaye/shared/widgets/placeholder_screen.dart';

/// Settings — reached from Home's app bar (`AGENTS.md` section 4), not a
/// bottom tab. Backup export/import (F7) lands here in milestone M7.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Settings',
      icon: Icons.settings_outlined,
    );
  }
}
