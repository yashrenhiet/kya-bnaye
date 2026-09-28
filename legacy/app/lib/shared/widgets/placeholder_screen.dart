import 'package:flutter/material.dart';

/// Temporary scaffolding screen used by every feature tab until its real
/// implementation lands (M4–M7 in `AGENTS.md` section 7).
///
/// Deliberately **not** meant to survive long-term: each feature should
/// delete its usage of [PlaceholderScreen] the moment its milestone starts,
/// rather than accumulating special cases here. Centralising it for now (one
/// definition, six call sites) beats copy-pasting the same `Scaffold` six
/// times, per the DRY standard in `AGENTS.md` section 0.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({required this.title, required this.icon, super.key});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text('$title — coming soon', style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
