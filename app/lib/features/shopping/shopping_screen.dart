import 'package:flutter/material.dart';

import 'package:kyabnaye/shared/widgets/placeholder_screen.dart';

/// Shopping tab — becomes the auto-built, vendor-grouped shopping list in
/// milestone M7 (F6 in `AGENTS.md` section 3). Placeholder until then.
class ShoppingScreen extends StatelessWidget {
  const ShoppingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Shopping',
      icon: Icons.shopping_basket_outlined,
    );
  }
}
