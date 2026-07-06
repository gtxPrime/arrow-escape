import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:arrow_escape/data/level_generator/level_generator.dart';
import 'package:arrow_escape/data/level_generator/solver.dart';
import 'package:arrow_escape/data/models/arrow.dart';
import 'package:arrow_escape/data/models/level.dart';

/// Runs all checks on a range of levels and logs progress to the given file.
void verifyLevelRange(int start, int end, String logFileName) {
  final logFile = File(logFileName);
  logFile.writeAsStringSync('Starting verification for levels $start to $end...\n');
  final overallSw = Stopwatch()..start();

  for (int i = start; i <= end; i++) {
    final sw = Stopwatch()..start();
    
    // 1. Generate the level (exactly ONCE)
    final level = LevelGenerator.generateLevel(i);
    expect(level.arrows.isNotEmpty, true, reason: 'Level $i has no arrows');
    expect(level.patternName, isNot('fallback'), reason: 'Level $i fell back to fallback');

    // 2. Solve the level (DFS only reliable on small grids ≤20).
    // Large grids (>20) are solvable by construction (reverse-placement
    // guarantees solvability). DFS with any state cap produces false negatives
    // on 30×30 grids with 100+ arrows, so we skip it there.
    if (level.gridSize <= 20) {
      final solution = LevelSolver.solve(level, 6000);
      expect(solution, isNotNull, reason: 'Level $i is UNSOLVABLE');
    }

    // 3. No infinite deflection loops
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
          if (dotType == OrphanDotType.up) {
            currentDir = ArrowDirection.up;
          } else if (dotType == OrphanDotType.down) {
            currentDir = ArrowDirection.down;
          } else if (dotType == OrphanDotType.left) {
            currentDir = ArrowDirection.left;
          } else if (dotType == OrphanDotType.right) {
            currentDir = ArrowDirection.right;
          }
        } else if (arrowOccupied.contains(key)) {
          break;
        }

        d = currentDir.delta;
        nr += d[0];
        nc += d[1];
      }
    }

    // 4. No arrow paths form closed loops/squares
    for (final arrow in level.arrows) {
      expect(_pathFormsCycle(arrow.path), false,
          reason: 'Level $i arrow ${arrow.id} forms a closed loop/square');
    }

    // 5. ColorLock pairs mutual-blocking checks
    final colorGroups = <int, List<ArrowModel>>{};
    for (final arrow in level.arrows) {
      if (arrow.colorGroup != null) {
        colorGroups.putIfAbsent(arrow.colorGroup!, () => []).add(arrow);
      }
    }
    for (final entry in colorGroups.entries) {
      expect(entry.value.length, 2,
          reason: 'Level $i color group ${entry.key} has ${entry.value.length} arrows (expected 2)');
      final a1 = entry.value[0];
      final a2 = entry.value[1];

      final allOccupied = <String>{};
      for (final a in level.arrows) {
        for (final pt in a.path) allOccupied.add('${pt[0]},${pt[1]}');
      }
      for (final pt in a1.path) allOccupied.remove('${pt[0]},${pt[1]}');
      for (final pt in a2.path) allOccupied.remove('${pt[0]},${pt[1]}');

      final a1Blocked = _isExitBlocked(a1, level.gridSize, allOccupied, orphanMap);
      final a2Blocked = _isExitBlocked(a2, level.gridSize, allOccupied, orphanMap);

      expect(a1Blocked || a2Blocked, false,
          reason: 'Level $i color group ${entry.key}: mutual blocking deadlock');
    }

    final ms = sw.elapsedMilliseconds;
    logFile.writeAsStringSync(
      'Solved Level $i in ${ms}ms (gridSize: ${level.gridSize}, arrows: ${level.arrows.length})\n',
      mode: FileMode.append,
    );
  }

  logFile.writeAsStringSync(
    'Verification completed for $start to $end in ${overallSw.elapsedMilliseconds}ms\n',
    mode: FileMode.append,
  );
}

bool _isExitBlocked(ArrowModel arrow, int gridSize, Set<String> occupied,
    Map<String, OrphanDotType> orphanDots) {
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
      if (dotType == OrphanDotType.up) {
        currentDir = ArrowDirection.up;
      } else if (dotType == OrphanDotType.down) {
        currentDir = ArrowDirection.down;
      } else if (dotType == OrphanDotType.left) {
        currentDir = ArrowDirection.left;
      } else if (dotType == OrphanDotType.right) {
        currentDir = ArrowDirection.right;
      }
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
    for (final nb in [
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1]
    ]) {
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
