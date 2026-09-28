import 'package:kya_core/kya_core.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

RankingContext contextFor(
  List<Recipe> recipes, {
  List<SwipeEvent> events = const [],
}) => RankingContext.build(
  allRecipes: recipes,
  pantry: const [],
  catalog: const [],
  events: events,
  mealLogs: const [],
  now: refNow,
);

void main() {
  group('isHardExcluded', () {
    final plain = recipe('plain');
    final hidden = recipe('hidden', isHidden: true);
    final nevered = recipe('nevered');
    final undone = recipe('undone');
    final lefted = recipe('lefted');
    final all = [plain, hidden, nevered, undone, lefted];

    final ctx = contextFor(
      all,
      events: [
        swipe('e1', nevered.id, SwipeAction.neverShow, daysAgo(200)),
        swipe('e2', undone.id, SwipeAction.neverShow, refNow),
        undo('u2', 'e2', refNow),
        swipe('e3', lefted.id, SwipeAction.left, refNow),
      ],
    );

    test('a recipe with no history is eligible', () {
      expect(isHardExcluded(plain, ctx), isFalse);
    });

    test('isHidden alone excludes (Settings flag, no swipe needed)', () {
      expect(isHardExcluded(hidden, ctx), isTrue);
    });

    test('a never-show swipe excludes regardless of age', () {
      expect(isHardExcluded(nevered, ctx), isTrue);
    });

    test('an undone never-show does not exclude', () {
      expect(isHardExcluded(undone, ctx), isFalse);
    });

    test('a recent left swipe is not a hard exclusion (penalty owns it)', () {
      expect(isHardExcluded(lefted, ctx), isFalse);
      expect(
        Penalties.rejectPenalty(
          lastLeftSwipeAt: ctx.lastLeftSwipeAtByRecipe[lefted.id],
          now: ctx.now,
          config: ctx.config,
        ),
        isNull,
      );
    });

    test('un-hiding the flag restores eligibility', () {
      expect(isHardExcluded(hidden.copyWith(isHidden: false), ctx), isFalse);
    });

    test('never-show matches by id even for a recipe not in the context', () {
      final stranger = recipe(nevered.id, tags: otherTags);
      expect(isHardExcluded(stranger, contextFor(const [])), isFalse);
      expect(isHardExcluded(stranger, ctx), isTrue);
    });
  });

  group('ScoredRecipe', () {
    final r = recipe('r');
    final base = ScoredRecipe(
      recipe: r,
      score: 0.42,
      explanation: 'Nothing missing.',
      missingIngredientIds: const ['paneer'],
      tier: RecipeTier.missing1,
    );

    test('defaults: not explore; tier null when omitted', () {
      final craving = ScoredRecipe(
        recipe: r,
        score: 0,
        explanation: 'x',
        missingIngredientIds: const [],
      );
      expect(craving.isExplore, isFalse);
      expect(craving.tier, isNull);
      expect(base.isExplore, isFalse);
    });

    test('copyWith with no arguments preserves every field', () {
      final copy = base.copyWith();
      expect(copy.recipe, same(r));
      expect(copy.score, closeTo(0.42, 1e-12));
      expect(copy.explanation, 'Nothing missing.');
      expect(copy.missingIngredientIds, ['paneer']);
      expect(copy.tier, RecipeTier.missing1);
      expect(copy.isExplore, isFalse);
    });

    test('copyWith replaces only explanation and isExplore', () {
      final copy = base.copyWith(
        explanation: 'Something different: Gujarati.',
        isExplore: true,
      );
      expect(copy.explanation, 'Something different: Gujarati.');
      expect(copy.isExplore, isTrue);
      expect(copy.score, closeTo(0.42, 1e-12));
      expect(copy.tier, RecipeTier.missing1);
      expect(copy.missingIngredientIds, ['paneer']);
      expect(base.explanation, 'Nothing missing.', reason: 'immutable');
      expect(base.isExplore, isFalse);
    });
  });

  group('RecipeTier', () {
    test('declares display priority: use-it-up, ready, missing 1, 2', () {
      expect(RecipeTier.values, [
        RecipeTier.useItUp,
        RecipeTier.readyNow,
        RecipeTier.missing1,
        RecipeTier.missing2,
      ]);
    });
  });
}
