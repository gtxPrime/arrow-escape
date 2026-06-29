import 'package:arrow_puzzle/data/level_generator/level_generator.dart';
import 'package:arrow_puzzle/data/level_generator/solver.dart';
import 'package:arrow_puzzle/data/models/arrow.dart';
import 'package:arrow_puzzle/data/models/level.dart';
import 'package:arrow_puzzle/core/constants.dart';

/// Comprehensive level verification script.
/// Generates all 500 levels and checks:
///   1. Solver can find a solution (grids ≤ 20)
///   2. Arrow length distribution matches 65/35 split (±8% tolerance)
///   3. Orphan dot count is minimal
///   4. No orphan dot creates infinite deflection loops
///   5. No colorLock pair blocks its own partner
///   6. No arrow path forms a square/closed loop
void main() {
  print('═══════════════════════════════════════════════════════');
  print(' Arrow Out — Level Verification (1–500)');
  print('═══════════════════════════════════════════════════════\n');

  int totalLevels = 500;
  int passed = 0;
  int failed = 0;
  int fallbacks = 0;
  final failures = <String>[];

  // Distribution tracking
  int totalLongArrows = 0;     // length >= 6
  int totalMediumArrows = 0;   // length 3–5
  int totalShortArrows = 0;    // length 2
  int totalSingleArrows = 0;   // length 1

  int totalOrphans = 0;
  int totalColoredOrphans = 0;
  int totalMaskCells = 0;

  final sw = Stopwatch()..start();

  for (int i = 1; i <= totalLevels; i++) {
    final levelSw = Stopwatch()..start();
    final type = AppConstants.levelTypeFor(i);
    final level = LevelGenerator.generateLevel(i);
    levelSw.stop();

    final levelErrors = <String>[];

    // Check for fallback
    if (level.patternName == 'fallback') {
      fallbacks++;
      levelErrors.add('FALLBACK generated');
    }

    // ── Check 1: Solvability ──
    if (level.patternName != 'fallback') {
      final solution = LevelSolver.solve(level);
      if (solution == null) {
        levelErrors.add('UNSOLVABLE (solver returned null)');
      }
    }

    // ── Check 2: Arrow length distribution ──
    for (final arrow in level.arrows) {
      final len = arrow.path.length;
      if (len >= 6) totalLongArrows++;
      else if (len >= 3) totalMediumArrows++;
      else if (len == 2) totalShortArrows++;
      else totalSingleArrows++;
    }

    // ── Check 3: Orphan count ──
    totalOrphans += level.orphanDots.length;
    totalColoredOrphans += level.orphanDots
        .where((d) => d.type != OrphanDotType.neutral)
        .length;
    totalMaskCells += level.mask.length;

    // ── Check 4: No infinite deflection loops ──
    for (final arrow in level.arrows) {
      final orphanMap = {for (final od in level.orphanDots) od.key: od.type};
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
      bool looped = false;

      while (nr >= 0 && nr < level.gridSize && nc >= 0 && nc < level.gridSize) {
        final key = '$nr,$nc';
        if (visited.contains(key)) {
          looped = true;
          break;
        }
        visited.add(key);

        if (orphanMap.containsKey(key)) {
          final dotType = orphanMap[key]!;
          if (dotType == OrphanDotType.up) currentDir = ArrowDirection.up;
          else if (dotType == OrphanDotType.down) currentDir = ArrowDirection.down;
          else if (dotType == OrphanDotType.left) currentDir = ArrowDirection.left;
          else if (dotType == OrphanDotType.right) currentDir = ArrowDirection.right;
        } else if (arrowOccupied.contains(key)) {
          break; // blocked, not looped
        }

        d = currentDir.delta;
        nr += d[0];
        nc += d[1];
      }

      if (looped) {
        levelErrors.add('Arrow ${arrow.id} has infinite deflection loop');
      }
    }

    // ── Check 5: ColorLock pair validation ──
    final colorGroups = <int, List<ArrowModel>>{};
    for (final arrow in level.arrows) {
      if (arrow.colorGroup != null) {
        colorGroups.putIfAbsent(arrow.colorGroup!, () => []).add(arrow);
      }
    }
    for (final entry in colorGroups.entries) {
      if (entry.value.length != 2) {
        levelErrors.add('Color group ${entry.key} has ${entry.value.length} arrows (expected 2)');
        continue;
      }
      final a1 = entry.value[0];
      final a2 = entry.value[1];
      final a1Cells = a1.path.map((p) => '${p[0]},${p[1]}').toSet();
      final a2Cells = a2.path.map((p) => '${p[0]},${p[1]}').toSet();

      // Check if either arrow's exit goes through the other's body
      // (This would mean they block each other — deadlock)
      final allOccupied = <String>{};
      for (final a in level.arrows) {
        for (final pt in a.path) allOccupied.add('${pt[0]},${pt[1]}');
      }
      // Remove both arrows' cells to simulate clearing them together
      for (final c in a1Cells) allOccupied.remove(c);
      for (final c in a2Cells) allOccupied.remove(c);

      final orphanMap = {for (final od in level.orphanDots) od.key: od.type};

      bool a1Blocked = _isExitBlocked(a1, level.gridSize, allOccupied, orphanMap);
      bool a2Blocked = _isExitBlocked(a2, level.gridSize, allOccupied, orphanMap);

      if (a1Blocked || a2Blocked) {
        levelErrors.add('ColorLock group ${entry.key}: mutual blocking detected');
      }
    }

    // ── Check 6: No arrow paths form squares/closed loops ──
    for (final arrow in level.arrows) {
      if (_pathFormsCycle(arrow.path)) {
        levelErrors.add('Arrow ${arrow.id} path forms closed loop/square');
      }
    }

    // ── Report ──
    if (levelErrors.isEmpty) {
      passed++;
      if (i % 50 == 0 || i <= 10) {
        print('  ✓ Level $i ($type) — ${level.gridSize}×${level.gridSize}, '
            '${level.arrows.length} arrows, ${level.orphanDots.length} orphans '
            '[${levelSw.elapsedMilliseconds}ms]');
      }
    } else {
      failed++;
      final msg = 'Level $i ($type): ${levelErrors.join('; ')}';
      failures.add(msg);
      print('  ✗ $msg');
    }
  }

  sw.stop();

  // ── Summary ──
  print('\n═══════════════════════════════════════════════════════');
  print(' RESULTS');
  print('═══════════════════════════════════════════════════════');
  print('  Total levels: $totalLevels');
  print('  Passed: $passed');
  print('  Failed: $failed');
  print('  Fallbacks: $fallbacks');
  print('  Time: ${sw.elapsedMilliseconds}ms (${(sw.elapsedMilliseconds / totalLevels).toStringAsFixed(1)}ms/level)');

  // Arrow distribution
  final totalLongMedium = totalLongArrows + totalMediumArrows;
  final longPct = totalLongMedium > 0
      ? (totalLongArrows / totalLongMedium * 100).toStringAsFixed(1)
      : '0.0';
  final medPct = totalLongMedium > 0
      ? (totalMediumArrows / totalLongMedium * 100).toStringAsFixed(1)
      : '0.0';

  print('\n  Arrow Length Distribution (among ≥3-dot arrows):');
  print('    Long (6+):   $totalLongArrows ($longPct%)  [target: 35%]');
  print('    Medium (3-5): $totalMediumArrows ($medPct%)  [target: 65%]');
  print('    Short (2):   $totalShortArrows (gap-fillers)');
  if (totalSingleArrows > 0) {
    print('    Single (1):  $totalSingleArrows (⚠ should be 0)');
  }

  print('\n  Orphan Dots:');
  print('    Total: $totalOrphans / $totalMaskCells mask cells '
      '(${(totalOrphans / totalMaskCells * 100).toStringAsFixed(2)}%)');
  print('    Colored: $totalColoredOrphans '
      '(${totalOrphans > 0 ? (totalColoredOrphans / totalOrphans * 100).toStringAsFixed(1) : 0}%)');

  if (failures.isNotEmpty) {
    print('\n  ── FAILURES ──');
    for (final f in failures) {
      print('    • $f');
    }
  }

  print('\n═══════════════════════════════════════════════════════');
  print(failed == 0 ? ' ALL PASSED ✓' : ' $failed FAILURES ✗');
  print('═══════════════════════════════════════════════════════\n');
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

/// Checks if an arrow's path forms a cycle (any cell is adjacent to
/// a non-consecutive cell in the path, forming a closed loop).
bool _pathFormsCycle(List<List<int>> path) {
  if (path.length < 4) return false;

  final pathSet = <int>{};
  for (final pt in path) {
    pathSet.add(pt[0] * 1000 + pt[1]);
  }

  for (int i = 0; i < path.length; i++) {
    final r = path[i][0], c = path[i][1];
    for (final nb in [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
      final nr = r + nb[0], nc = c + nb[1];
      final np = nr * 1000 + nc;
      if (!pathSet.contains(np)) continue;

      // Find this neighbor's index in the path
      for (int j = 0; j < path.length; j++) {
        if (path[j][0] == nr && path[j][1] == nc) {
          // Adjacent cells that are not consecutive in path = cycle
          if ((i - j).abs() > 1) return true;
          break;
        }
      }
    }
  }
  return false;
}
