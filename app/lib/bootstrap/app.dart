import 'package:flutter/material.dart';

import 'package:kyabnaye/routing/app_router.dart';
import 'package:kyabnaye/theme/app_theme.dart';

/// The root widget: wires the router and the light/dark themes together.
///
/// Kept deliberately thin — dependency overrides and any seed-on-first-run
/// bootstrapping (milestone M3, `AGENTS.md` section 5.6) will be added here
/// as this app grows, rather than in `main.dart`, so `main.dart` stays a
/// one-line entry point.
class KyaBnayeApp extends StatelessWidget {
  const KyaBnayeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'kya-bnaye',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: appRouter,
    );
  }
}
