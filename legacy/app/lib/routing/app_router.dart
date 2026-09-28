import 'package:go_router/go_router.dart';

import 'package:kyabnaye/features/history/history_screen.dart';
import 'package:kyabnaye/features/home/home_screen.dart';
import 'package:kyabnaye/features/pantry/pantry_screen.dart';
import 'package:kyabnaye/features/recipes/recipes_screen.dart';
import 'package:kyabnaye/features/settings/settings_screen.dart';
import 'package:kyabnaye/features/shopping/shopping_screen.dart';
import 'package:kyabnaye/routing/tab_shell.dart';

/// Route paths, centralised so screens navigate via named constants instead
/// of hand-typed string literals scattered around the codebase.
abstract final class AppRoutes {
  static const home = '/';
  static const pantry = '/pantry';
  static const recipes = '/recipes';
  static const shopping = '/shopping';
  static const history = '/history';
  static const settings = '/settings';
}

/// The app's single [GoRouter] instance.
///
/// Four bottom-nav tabs (Home, Pantry, Recipes, Shopping — `AGENTS.md`
/// section 4) live under a [StatefulShellRoute]; History and Settings are
/// top-level routes pushed from Home's app bar, not tabs.
final appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          TabShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.pantry,
              builder: (context, state) => const PantryScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.recipes,
              builder: (context, state) => const RecipesScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.shopping,
              builder: (context, state) => const ShoppingScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: AppRoutes.history,
      builder: (context, state) => const HistoryScreen(),
    ),
    GoRoute(
      path: AppRoutes.settings,
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
