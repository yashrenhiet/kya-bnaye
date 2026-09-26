import 'package:flutter/material.dart';

import 'package:kyabnaye/shared/widgets/placeholder_screen.dart';

/// Pantry tab — becomes the category-grouped stock list in milestone M4
/// (F2 in `AGENTS.md` section 3). Placeholder until then.
class PantryScreen extends StatelessWidget {
  const PantryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Pantry',
      icon: Icons.kitchen_outlined,
    );
  }
}
