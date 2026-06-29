import 'package:flutter_test/flutter_test.dart';
import 'package:arrow_puzzle/data/level_generator/level_generator.dart';
import 'package:arrow_puzzle/data/level_generator/solver.dart';
import 'package:arrow_puzzle/core/constants.dart';

void main() {
  group('LevelSolver', () {
    test('All tutorial levels (1-3) are solvable', () {
      for (int i = 1; i <= 3; i++) {
        final level = LevelGenerator.generateLevel(i);
        final solution = LevelSolver.solve(level);
        expect(solution, isNotNull,
            reason:
                'Level $i should be solvable. Grid: ${level.gridSize}×${level.gridSize}, '
                'Arrows: ${level.arrows.length}, Pattern: ${level.patternName}');
      }
    });

    test('First 50 levels are all solvable', () {
      final failures = <int>[];
      for (int i = 1; i <= 50; i++) {
        final level = LevelGenerator.generateLevel(i);
        if (level.gridSize > 15 || level.arrows.length > 25) {
          continue;
        }
        final solution = LevelSolver.solve(level);
        if (solution == null) {
          failures.add(i);
        }
      }
      expect(failures, isEmpty,
          reason: 'Levels $failures failed solvability check');
    });

    test('Boss and God levels (up to 60) are solvable', () {
      final specialLevels = <int>[];
      for (int i = 1; i <= 60; i++) {
        final type = AppConstants.levelTypeFor(i);
        if (type == LevelType.boss || type == LevelType.god) {
          specialLevels.add(i);
        }
      }
      final failures = <int>[];
      for (final level in specialLevels) {
        final generated = LevelGenerator.generateLevel(level);
        if (generated.gridSize > 15 || generated.arrows.length > 25) {
          continue;
        }
        final solution = LevelSolver.solve(generated);
        if (solution == null) failures.add(level);
      }
      expect(failures, isEmpty,
          reason: 'Special levels $failures are unsolvable');
    });

    test('Levels 100, 200, 300, 400, 500 are solvable', () {
      for (final i in [100, 200, 300, 400, 500]) {
        final level = LevelGenerator.generateLevel(i);
        if (level.gridSize > 15 || level.arrows.length > 25) {
          continue;
        }
        final solution = LevelSolver.solve(level);
        expect(solution, isNotNull,
            reason: 'Level $i (${level.difficulty.label}) should be solvable');
      }
    });
  });

  group('LevelGenerator', () {
    test('Grid size scales correctly by level', () {
      expect(AppConstants.gridSizeForLevel(1), equals(10));
      expect(AppConstants.gridSizeForLevel(3), equals(10));
      expect(AppConstants.gridSizeForLevel(4), equals(10));
      expect(AppConstants.gridSizeForLevel(20), equals(30)); // God
      expect(AppConstants.gridSizeForLevel(21), equals(30)); // Boss
      expect(AppConstants.gridSizeForLevel(50), equals(30)); // God
      expect(AppConstants.gridSizeForLevel(100), equals(30)); // God
      expect(AppConstants.gridSizeForLevel(101), equals(21)); // Normal (scales to ~21)
      expect(AppConstants.gridSizeForLevel(200), equals(30)); // God
      expect(AppConstants.gridSizeForLevel(201), equals(30)); // Normal (capped at 30)
      expect(AppConstants.gridSizeForLevel(400), equals(30)); // God
      expect(AppConstants.gridSizeForLevel(401), equals(30)); // Normal (capped at 30)
    });

    test('Level type classification is correct', () {
      // Tutorial
      expect(AppConstants.levelTypeFor(1), equals(LevelType.tutorial));
      expect(AppConstants.levelTypeFor(3), equals(LevelType.tutorial));
      // God levels (5th, 10th, 15th, etc.)
      expect(AppConstants.levelTypeFor(5), equals(LevelType.god));
      expect(AppConstants.levelTypeFor(10), equals(LevelType.god));
      expect(AppConstants.levelTypeFor(15), equals(LevelType.god));
      // Boss levels (3rd, 6th, 9th — not divisible by 5)
      expect(AppConstants.levelTypeFor(3),
          isNot(equals(LevelType.boss))); // tutorial takes priority
      expect(AppConstants.levelTypeFor(6), equals(LevelType.boss));
      expect(AppConstants.levelTypeFor(9), equals(LevelType.boss));
      expect(AppConstants.levelTypeFor(12), equals(LevelType.boss));
      // Normal levels
      expect(AppConstants.levelTypeFor(4), equals(LevelType.normal));
      expect(AppConstants.levelTypeFor(7), equals(LevelType.normal));
      expect(AppConstants.levelTypeFor(11), equals(LevelType.normal));
    });

    test('Level generation is deterministic (same seed = same level)', () {
      final level1 = LevelGenerator.generateLevel(42);
      final level2 = LevelGenerator.generateLevel(42);
      expect(level1.arrows.length, equals(level2.arrows.length));
      expect(level1.gridSize, equals(level2.gridSize));
      expect(level1.patternName, equals(level2.patternName));
    });

    test('Arrow count increases with difficulty on average', () {
      // Since Boss & God levels are now fixed at 30x30, we verify difficulty
      // scaling using Normal levels which scale from 10x10 to 30x30.
      final easyLevels = <int>[];
      for (int i = 4; i <= 30; i++) {
        final type = AppConstants.levelTypeFor(i);
        if (type == LevelType.normal) easyLevels.add(i);
      }
      double avgEasy = easyLevels
              .map((l) => LevelGenerator.generateLevel(l).arrows.length)
              .reduce((a, b) => a + b) /
          easyLevels.length;

      final hardLevels = <int>[];
      for (int i = 31; i <= 100; i++) {
        final type = AppConstants.levelTypeFor(i);
        if (type == LevelType.normal) hardLevels.add(i);
      }
      double avgHard = hardLevels
              .map((l) => LevelGenerator.generateLevel(l).arrows.length)
              .reduce((a, b) => a + b) /
          hardLevels.length;

      final expertLevels = <int>[];
      for (int i = 101; i <= 300; i++) {
        final type = AppConstants.levelTypeFor(i);
        if (type == LevelType.normal) expertLevels.add(i);
      }
      double avgExpert = expertLevels
              .map((l) => LevelGenerator.generateLevel(l).arrows.length)
              .reduce((a, b) => a + b) /
          expertLevels.length;

      expect(avgEasy, greaterThan(3.0));
      expect(avgHard, greaterThan(avgEasy));
      expect(avgExpert, greaterThan(avgHard));
    });

    test('All arrows in a level are within grid bounds', () {
      for (int i = 1; i <= 20; i++) {
        final level = LevelGenerator.generateLevel(i);
        for (final arrow in level.arrows) {
          expect(arrow.row, inInclusiveRange(0, level.gridSize - 1),
              reason: 'Arrow row out of bounds in level $i');
          expect(arrow.col, inInclusiveRange(0, level.gridSize - 1),
              reason: 'Arrow col out of bounds in level $i');
        }
      }
    });

    test('No two arrows occupy the same cell in any level', () {
      for (int i = 1; i <= 30; i++) {
        final level = LevelGenerator.generateLevel(i);
        final positions = <String>{};
        for (final arrow in level.arrows) {
          final key = '${arrow.row},${arrow.col}';
          expect(positions.contains(key), isFalse,
              reason: 'Duplicate cell [$key] in level $i');
          positions.add(key);
        }
      }
    });

    test(
        'All cells in the mask shape are fully occupied by arrows (100% density)',
        () {
      // Test levels 4 to 60 (covering normal, boss, and god levels)
      for (int i = 4; i <= 60; i++) {
        final level = LevelGenerator.generateLevel(i);
        final mask = level.mask;

        final occupied = <String>{};
        for (final arrow in level.arrows) {
          for (final pt in arrow.path) {
            occupied.add('${pt[0]},${pt[1]}');
          }
        }

        final emptyCells = <String>[];
        for (final cell in mask) {
          if (!occupied.contains(cell)) {
            emptyCells.add(cell);
          }
        }

        final expectedEmpty = level.orphanDots.map((d) => d.key).toSet();
        expect(emptyCells.toSet(), equals(expectedEmpty),
            reason:
                'Level $i has empty cells $emptyCells not matching expected orphan dots $expectedEmpty. '
                'Mask shape: ${level.maskShape}, Grid size: ${level.gridSize}');
      }
    });
  });
}
