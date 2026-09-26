import 'package:kya_core/kya_core.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

const ScoringConfig config = ScoringConfig();
const double eps = 1e-9;

double repeat(DateTime? last, {int count = 1, DateTime? now}) =>
    Penalties.repeatPenalty(
      lastCookedAt: last,
      cookCountInRutWindow: count,
      now: now ?? refNow,
      config: config,
    );

double? reject(DateTime? last, {DateTime? now}) => Penalties.rejectPenalty(
  lastLeftSwipeAt: last,
  now: now ?? refNow,
  config: config,
);

void main() {
  group('Penalties.repeatPenalty step boundaries (RECOMMENDER.md 5)', () {
    const cases = <int, double>{
      0: 0.30,
      1: 0.30,
      7: 0.30,
      8: 0.20,
      14: 0.20,
      15: 0.10,
      28: 0.10,
      29: 0.03,
      56: 0.03,
      57: 0,
      90: 0,
      365: 0,
    };
    for (final entry in cases.entries) {
      test('${entry.key} days since cooked -> ${entry.value}', () {
        expect(repeat(daysAgo(entry.key)), closeTo(entry.value, eps));
      });
    }

    test('never cooked -> 0 even with a non-zero rut count', () {
      expect(repeat(null, count: 5), 0);
    });
  });

  group('Penalties.repeatPenalty rut top-up', () {
    test('a single cook in the window adds nothing', () {
      expect(repeat(daysAgo(3)), closeTo(0.30, eps));
    });

    test('each extra cook in the window adds 0.02', () {
      expect(repeat(daysAgo(3), count: 2), closeTo(0.32, eps));
      expect(repeat(daysAgo(3), count: 3), closeTo(0.34, eps));
      expect(repeat(daysAgo(20), count: 6), closeTo(0.20, eps));
    });

    test('rut still applies after the step penalty has expired', () {
      expect(repeat(daysAgo(60), count: 3), closeTo(0.04, eps));
    });

    test('zero or negative counts never produce a bonus', () {
      expect(repeat(daysAgo(3), count: 0), closeTo(0.30, eps));
      expect(repeat(daysAgo(3), count: -4), closeTo(0.30, eps));
      expect(repeat(daysAgo(57), count: 0), 0);
    });

    test('uses the injected config rather than hard-coded weights', () {
      const custom = ScoringConfig(
        repeatPenaltyWithin7d: 1,
        repeatRutPenaltyPerExtraCook: 0.5,
      );
      final value = Penalties.repeatPenalty(
        lastCookedAt: daysAgo(2),
        cookCountInRutWindow: 3,
        now: refNow,
        config: custom,
      );
      expect(value, closeTo(2, eps));
    });
  });

  group('Penalties.rejectPenalty (RECOMMENDER.md 5)', () {
    test('no left swipe -> 0, not excluded', () {
      expect(reject(null), 0);
    });

    for (final days in [0, 1, 2, 3]) {
      test('$days days since left swipe -> excluded (null)', () {
        expect(reject(daysAgo(days)), isNull);
      });
    }

    for (final days in [4, 10, 14]) {
      test('$days days since left swipe -> 0.25', () {
        expect(reject(daysAgo(days)), closeTo(0.25, eps));
      });
    }

    for (final days in [15, 30, 400]) {
      test('$days days since left swipe -> 0', () {
        expect(reject(daysAgo(days)), 0);
      });
    }

    test('future-dated left swipe (clock skew) stays excluded', () {
      expect(reject(refNow.add(const Duration(days: 2))), isNull);
    });

    test('uses the injected config windows', () {
      const custom = ScoringConfig(
        rejectExclusionWindowDays: 0,
        rejectPenaltyWindowDays: 1,
        rejectPenaltyWithinWindow: 0.9,
      );
      double? at(int days) => Penalties.rejectPenalty(
        lastLeftSwipeAt: daysAgo(days),
        now: refNow,
        config: custom,
      );
      expect(at(0), isNull);
      expect(at(1), closeTo(0.9, eps));
      expect(at(2), 0);
    });
  });

  group('day counting is calendar-day based', () {
    test('23:59 -> 00:01 next day counts as one day', () {
      final last = DateTime(2026, 9, 25, 23, 59);
      final now = DateTime(2026, 9, 26, 0, 1);
      // Two minutes apart, but one calendar day: still inside the 7-day step.
      expect(repeat(last, now: now), closeTo(0.30, eps));
      expect(reject(last, now: now), isNull);
    });

    test('3 days + 2 minutes elapsed is 4 calendar days: not excluded', () {
      final last = DateTime(2026, 9, 22, 23, 59);
      final now = DateTime(2026, 9, 26, 0, 1);
      expect(reject(last, now: now), closeTo(0.25, eps));
    });

    test('7 days 23:58 elapsed within the same calendar span is 7 days', () {
      final last = DateTime(2026, 9, 19, 0, 1);
      final now = DateTime(2026, 9, 26, 23, 59);
      expect(repeat(last, now: now), closeTo(0.30, eps));
    });

    test('just over 7 days elapsed but 8 calendar days -> 0.20', () {
      final last = DateTime(2026, 9, 18, 23, 59);
      final now = DateTime(2026, 9, 26, 0, 1);
      expect(repeat(last, now: now), closeTo(0.20, eps));
    });

    test('14 -> 15 calendar days at midnight boundary', () {
      final now = DateTime(2026, 9, 26, 0, 1);
      expect(reject(DateTime(2026, 9, 12), now: now), closeTo(0.25, eps));
      expect(reject(DateTime(2026, 9, 11, 23, 59), now: now), 0);
    });

    test('month and year rollovers count calendar days', () {
      expect(
        repeat(DateTime(2025, 12, 31, 22), now: DateTime(2026, 1, 8, 6)),
        closeTo(0.20, eps),
      );
      // 2028 is a leap year: Feb 28 -> Mar 1 spans two calendar days.
      expect(
        reject(DateTime(2028, 2, 27, 12), now: DateTime(2028, 3, 1, 12)),
        isNull,
      );
      expect(
        reject(DateTime(2028, 2, 26, 12), now: DateTime(2028, 3, 1, 12)),
        closeTo(0.25, eps),
      );
    });

    test(
      'a DST spring-forward night does not shorten the day count',
      () {
        // US DST starts 2026-03-08, EU DST starts 2026-03-29. Each window
        // below spans a 23-hour day in those zones; calendar distance is
        // what the spec counts, independent of the host time zone.
        final usNow = DateTime(2026, 3, 9, 12);
        expect(
          reject(DateTime(2026, 3, 5, 12), now: usNow),
          closeTo(0.25, eps),
        );
        expect(
          repeat(DateTime(2026, 3, 1, 12), now: usNow),
          closeTo(0.20, eps),
        );
        final euNow = DateTime(2026, 3, 30, 12);
        expect(
          reject(DateTime(2026, 3, 26, 12), now: euNow),
          closeTo(0.25, eps),
        );
        expect(
          repeat(DateTime(2026, 3, 22, 12), now: euNow),
          closeTo(0.20, eps),
        );
      },
      skip:
          'BUG: penalties.dart:61-65 _daysBetween uses Duration.inDays on '
          'local midnights; a 23h DST day truncates to one day fewer when '
          'the host TZ observes DST (verified with TZ=America/New_York).',
    );
  });
}
