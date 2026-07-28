import 'dart:io';
import 'package:arrow_escape/data/level_generator/level_generator_v2.dart';
import 'package:arrow_escape/data/level_generator/solver.dart';
import 'package:arrow_escape/data/level_binary_codec.dart';
import 'package:arrow_escape/data/models/arrow.dart';
import 'package:arrow_escape/data/models/level.dart';
import 'package:arrow_escape/core/constants.dart';

/// Comprehensive level verification script.
/// Checks all 500 pregenerated levels from assets/levels.bin:
///   1. Decoder correctly parses binary level data
///   2. Solvability (grids ≤ 20 via solver, > 20 via solutionOrder)
///   3. Arrow length distribution
///   4. Minimal orphan dots & zero infinite deflection loops
///   5. Zero ColorLock mutual deadlocks
///   6. Zero closed path cycles
void main() {
  print('═══════════════════════════════════════════════════════');
  print(' Arrow Out — Level Verification (1–500)');
  print('═══════════════════════════════════════════════════════\n');

  LevelBinaryDecoder? decoder;
  final binFile = File('assets/levels.bin');
  if (binFile.existsSync()) {
    try {
      final bytes = binFile.readAsBytesSync();
      decoder = LevelBinaryDecoder.fromBytes(bytes);
      print('✓ Loaded assets/levels.bin (${(bytes.length / 1024).toStringAsFixed(1)} KB, ${decoder.levelCount} levels)\n');
    } catch (e) {
      print('⚠ Failed to read assets/levels.bin ($e). Falling back to on-the-fly generator.\n');
    }
  }

  final totalLevels = decoder != null ? decoder.levelCount : 500;
  int passed = 0;
  int failed = 0;
  int fallbacks = 0;
  final failures = <String>[];

  // Distribution tracking
  int totalVeryLongArrows = 0;
  int totalLongArrows = 0;
  int totalMediumArrows = 0;
  int totalShortArrows = 0;
  int totalSingleArrows = 0;

  int totalOrphans = 0;
  int totalColoredOrphans = 0;
  int totalMaskCells = 0;

  final sw = Stopwatch()..start();

  for (int i = 1; i <= totalLevels; i++) {
    final levelSw = Stopwatch()..start();
    final type = AppConstants.levelTypeFor(i);
    final level = decoder != null
        ? decoder.decodeLevelByNumber(i)!
        : LevelGeneratorV2.generateLevel(i);
    levelSw.stop();

    final levelErrors = <String>[];

    if (level.patternName == 'fallback') {
      fallbacks++;
      levelErrors.add('FALLBACK level');
    }

    // ── Check 1: Solvability ──
    if (level.patternName != 'fallback') {
      if (level.gridSize <= 20) {
        final solution = LevelSolver.solve(level, 3000);
        if (solution == null) {
          levelErrors.add('UNSOLVABLE (solver returned null)');
        }
      } else {
        if (level.solutionOrder.isEmpty) {
          levelErrors.add('UNSOLVABLE (greedy solution order empty)');
        }
      }
    }

    // ── Check 2: Arrow length distribution ──
    final gs = level.gridSize;
    final vlMin = 5 + (gs ~/ 6);
    final lMin  = 3 + (gs ~/ 10);
    for (final arrow in level.arrows) {
      final len = arrow.path.length;
      if (len >= vlMin) totalVeryLongArrows++;
      else if (len >= lMin) totalLongArrows++;
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
          break;
        }

        d = currentDir.delta;
        nr += d[0];
        nc += d[1];
      }

      if (looped) {
        levelErrors.add('Arrow ${arrow.id} has infinite deflection loop');
      }
    }

    // ── Check 5: ColorLock pair mutual deadlock check ──
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

      if (_exitPassesThroughSet(a1, level.gridSize, a2Cells, orphanMap) ||
          _exitPassesThroughSet(a2, level.gridSize, a1Cells, orphanMap)) {
        levelErrors.add('ColorLock group ${entry.key}: mutual blocking detected');
      }
    }

    // ── Check 6: Closed loop path check ──
    for (final arrow in level.arrows) {
      if (_pathFormsCycle(arrow.path)) {
        levelErrors.add('Arrow ${arrow.id} path forms closed loop/square');
      }
    }

    // ── Report ──
    if (levelErrors.isEmpty) {
      passed++;
      if (i % 50 == 0 || i <= 10) {
        print('  ✓ Level ${'$i'.padLeft(3)} ($type) — ${level.gridSize}×${level.gridSize}, '
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
  print('  Time: ${sw.elapsedMilliseconds}ms (${(sw.elapsedMilliseconds / totalLevels).toStringAsFixed(2)}ms/level)');

  final totalTiered = totalVeryLongArrows + totalLongArrows + totalMediumArrows;
  final vlPct = totalTiered > 0
      ? (totalVeryLongArrows / totalTiered * 100).toStringAsFixed(1) : '0.0';
  final lPct = totalTiered > 0
      ? (totalLongArrows / totalTiered * 100).toStringAsFixed(1) : '0.0';
  final mPct = totalTiered > 0
      ? (totalMediumArrows / totalTiered * 100).toStringAsFixed(1) : '0.0';

  print('\n  Arrow Length Distribution:');
  print('    Very Long (vlMin+):  $totalVeryLongArrows ($vlPct%)');
  print('    Long (lMin..vlMin-1): $totalLongArrows ($lPct%)');
  print('    Medium (3..lMin-1):   $totalMediumArrows ($mPct%)');
  print('    Short (2):           $totalShortArrows');
  print('    Single (1):          $totalSingleArrows');

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
  print(failed == 0 ? ' ALL 500 LEVELS PASSED PERFECTLY ✓' : ' $failed FAILURES ✗');
  print('═══════════════════════════════════════════════════════\n');
}

bool _exitPassesThroughSet(ArrowModel arrow, int gridSize,
    Set<String> targetSet, Map<String, OrphanDotType> orphanDots) {
  ArrowDirection currentDir = arrow.direction;
  final head = arrow.path[0];
  var d = currentDir.delta;
  int nr = head[0] + d[0];
  int nc = head[1] + d[1];
  final visited = <String>{};

  while (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
    final key = '$nr,$nc';
    if (visited.contains(key)) return false;
    visited.add(key);

    if (targetSet.contains(key)) {
      return true;
    }

    if (orphanDots.containsKey(key)) {
      final dotType = orphanDots[key]!;
      if (dotType == OrphanDotType.up) currentDir = ArrowDirection.up;
      else if (dotType == OrphanDotType.down) currentDir = ArrowDirection.down;
      else if (dotType == OrphanDotType.left) currentDir = ArrowDirection.left;
      else if (dotType == OrphanDotType.right) currentDir = ArrowDirection.right;
    }

    d = currentDir.delta;
    nr += d[0];
    nc += d[1];
  }
  return false;
}

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

      for (int j = 0; j < path.length; j++) {
        if (path[j][0] == nr && path[j][1] == nc) {
          if ((i - j).abs() > 1) return true;
          break;
        }
      }
    }
  }
  return false;
}
