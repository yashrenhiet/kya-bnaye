import 'package:flutter/material.dart';

import 'package:kyabnaye/shared/widgets/placeholder_screen.dart';

/// Recipes tab — becomes the searchable recipe book in milestone M5
/// (F3 in `AGENTS.md` section 3). Placeholder until then.
class RecipesScreen extends StatelessWidget {
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Recipes',
      icon: Icons.menu_book_outlined,
    );
  }
}
