import 'package:flutter_test/flutter_test.dart';
import 'package:arrow_puzzle/data/level_generator/level_generator.dart';
import 'package:arrow_puzzle/data/level_generator/solver.dart';
import 'package:arrow_puzzle/data/models/arrow.dart';
import 'package:arrow_puzzle/data/models/level.dart';
import 'package:arrow_puzzle/core/constants.dart';

void main() {
  // ── Quick smoke test: first 50 levels ──
  test('First 50 levels generate without errors', () {
    for (int i = 1; i <= 50; i++) {
      final level = LevelGenerator.generateLevel(i);
      expect(level.arrows.isNotEmpty, true, reason: 'Level $i has no arrows');
      expect(level.patternName, isNot('fallback'), reason: 'Level $i fell back');
    }
  });

  // ── Solvability: first 100 levels ──
  test('First 100 levels are solvable', () {
    for (int i = 1; i <= 100; i++) {
      final level = LevelGenerator.generateLevel(i);
      final solution = LevelSolver.solve(level);
      expect(solution, isNotNull, reason: 'Level $i is UNSOLVABLE');
    }
  }, timeout: Timeout(Duration(minutes: 10)));

  // ── No infinite deflection loops ──
  test('No arrows have infinite deflection loops (levels 1-100)', () {
    for (int i = 1; i <= 100; i++) {
      final level = LevelGenerator.generateLevel(i);
      final orphanMap = {for (final od in level.orphanDots) od.key: od.type};

      for (final arrow in level.arrows) {
        final arrowOccupied = <String>{};
        for (final a in level.arrows) {
          if (a.id == arrow.id) continue;
          for (final pt in a.path) arrowOccupied.add('${pt[0]},${pt[1]}');
        }

        ArrowDirection currentDir = arrow.direction;
        final head = arrow.path[0];
        var d = currentDir.delta;
        int nr = head[0] + d[0];
        int nc = head[1] + d[1];
        final visited = <String>{};

        while (nr >= 0 && nr < level.gridSize && nc >= 0 && nc < level.gridSize) {
          final key = '$nr,$nc';
          expect(visited.contains(key), false,
              reason: 'Level $i arrow ${arrow.id} has infinite deflection loop at $key');
          if (visited.contains(key)) break;
          visited.add(key);

          if (orphanMap.containsKey(key)) {
            final dotType = orphanMap[key]!;
            if (dotType == OrphanDotType.up) currentDir = ArrowDirection.up;
            else if (dotType == OrphanDotType.down) currentDir = ArrowDirection.down;
            else if (dotType == OrphanDotType.left) currentDir = ArrowDirection.left;
            else if (dotType == OrphanDotType.right) currentDir = ArrowDirection.right;
          } else if (arrowOccupied.contains(key)) {
            break;
          }

          d = currentDir.delta;
          nr += d[0];
          nc += d[1];
        }
      }
    }
  });

  // ── No arrow paths form closed loops / squares ──
  test('No arrow paths form squares (levels 1-100)', () {
    for (int i = 1; i <= 100; i++) {
      final level = LevelGenerator.generateLevel(i);
      for (final arrow in level.arrows) {
        expect(_pathFormsCycle(arrow.path), false,
            reason: 'Level $i arrow ${arrow.id} forms a closed loop');
      }
    }
  });

  // ── ColorLock pairs don't block each other ──
  test('ColorLock pairs are not mutually blocking (levels 1-100)', () {
    for (int i = 1; i <= 100; i++) {
      final level = LevelGenerator.generateLevel(i);
      final colorGroups = <int, List<ArrowModel>>{};
      for (final arrow in level.arrows) {
        if (arrow.colorGroup != null) {
          colorGroups.putIfAbsent(arrow.colorGroup!, () => []).add(arrow);
        }
      }

      for (final entry in colorGroups.entries) {
        expect(entry.value.length, 2,
            reason: 'Level $i color group ${entry.key} has ${entry.value.length} arrows');
        final a1 = entry.value[0];
        final a2 = entry.value[1];

        final allOccupied = <String>{};
        for (final a in level.arrows) {
          for (final pt in a.path) allOccupied.add('${pt[0]},${pt[1]}');
        }
        for (final pt in a1.path) allOccupied.remove('${pt[0]},${pt[1]}');
        for (final pt in a2.path) allOccupied.remove('${pt[0]},${pt[1]}');

        final orphanMap = {for (final od in level.orphanDots) od.key: od.type};
        final a1Blocked = _isExitBlocked(a1, level.gridSize, allOccupied, orphanMap);
        final a2Blocked = _isExitBlocked(a2, level.gridSize, allOccupied, orphanMap);

        expect(a1Blocked || a2Blocked, false,
            reason: 'Level $i color group ${entry.key}: mutual blocking');
      }
    }
  });

  // ── Arrow length distribution (sample: levels 10-50, non-tutorial) ──
  test('Arrow length distribution is roughly 65% medium / 35% long', () {
    int longCount = 0;
    int medCount = 0;

    for (int i = 10; i <= 50; i++) {
      final level = LevelGenerator.generateLevel(i);
      for (final arrow in level.arrows) {
        final len = arrow.path.length;
        if (len >= 6) longCount++;
        else if (len >= 3) medCount++;
      }
    }

    final total = longCount + medCount;
    if (total > 0) {
      final longPct = longCount / total * 100;
      final medPct = medCount / total * 100;
      // Allow ±15% tolerance since generation is randomized
      expect(longPct, greaterThan(15),
          reason: 'Long arrows too few: $longPct% (expected ~35%)');
      expect(longPct, lessThan(55),
          reason: 'Long arrows too many: $longPct% (expected ~35%)');
      expect(medPct, greaterThan(45),
          reason: 'Medium arrows too few: $medPct% (expected ~65%)');
    }
  });

  // ── Full 500-level generation (no crash/fallback) ──
  test('All 500 levels generate successfully without fallback', () {
    int fallbacks = 0;
    for (int i = 1; i <= 500; i++) {
      final level = LevelGenerator.generateLevel(i);
      if (level.patternName == 'fallback') fallbacks++;
      expect(level.arrows.isNotEmpty, true, reason: 'Level $i has no arrows');
    }
    expect(fallbacks, 0, reason: '$fallbacks levels used fallback');
  }, timeout: Timeout(Duration(minutes: 10)));
}

bool _isExitBlocked(ArrowModel arrow, int gridSize,
    Set<String> occupied, Map<String, OrphanDotType> orphanDots) {
  ArrowDirection currentDir = arrow.direction;
  final head = arrow.path[0];
  var d = currentDir.delta;
  int nr = head[0] + d[0];
  int nc = head[1] + d[1];
  final visited = <String>{};

  while (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
    final key = '$nr,$nc';
    if (visited.contains(key)) return true;
    visited.add(key);

    if (orphanDots.containsKey(key)) {
      final dotType = orphanDots[key]!;
      if (dotType == OrphanDotType.up) currentDir = ArrowDirection.up;
      else if (dotType == OrphanDotType.down) currentDir = ArrowDirection.down;
      else if (dotType == OrphanDotType.left) currentDir = ArrowDirection.left;
      else if (dotType == OrphanDotType.right) currentDir = ArrowDirection.right;
    } else if (occupied.contains(key)) {
      return true;
    }

    d = currentDir.delta;
    nr += d[0];
    nc += d[1];
  }
  return false;
}

bool _pathFormsCycle(List<List<int>> path) {
  if (path.length < 4) return false;
  for (int i = 0; i < path.length; i++) {
    final r = path[i][0], c = path[i][1];
    for (final nb in [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
      final nr = r + nb[0], nc = c + nb[1];
      for (int j = 0; j < path.length; j++) {
        if (path[j][0] == nr && path[j][1] == nc && (i - j).abs() > 1) {
          return true;
        }
      }
    }
  }
  return false;
}
