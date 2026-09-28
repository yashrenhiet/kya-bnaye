import 'package:flutter/material.dart';

import 'package:kyabnaye/shared/widgets/placeholder_screen.dart';

/// Home tab — will become the Kitchen/Craving swipe deck in milestone M6
/// (F4/F4b/F4c in `AGENTS.md` section 3). Placeholder until then.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Kya Bnaye?',
      icon: Icons.restaurant_menu,
    );
  }
}
