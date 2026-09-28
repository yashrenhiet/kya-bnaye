import 'package:flutter/material.dart';

import 'package:kyabnaye/shared/widgets/placeholder_screen.dart';

/// Meal history — reached from Home's app bar (`AGENTS.md` section 4), not a
/// bottom tab. Becomes a real by-date meal log in milestone M6 (F5).
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(title: 'History', icon: Icons.history);
  }
}
