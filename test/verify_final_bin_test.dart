// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:arrow_escape/data/level_binary_codec.dart';
import 'package:arrow_escape/data/models/level.dart';
import 'package:arrow_escape/data/models/arrow.dart';
import 'package:arrow_escape/data/level_generator/solver.dart';
import 'package:arrow_escape/core/constants.dart';

void main() {
  test('Verify all 500 levels decoded from levels.bin', () {
    final file = File('assets/levels.bin');
    expect(file.existsSync(), true, reason: 'levels.bin must exist');

    final bytes = file.readAsBytesSync();
    final decoder = LevelBinaryDecoder.fromBytes(bytes);
    expect(decoder.levelCount, equals(500), reason: 'levels.bin must contain exactly 500 levels');

    print('Verifying all 500 levels from levels.bin...');

    for (int lvl = 1; lvl <= 500; lvl++) {
      final level = decoder.decodeLevelByNumber(lvl);
      expect(level, isNotNull, reason: 'Level $lvl failed to decode');
      expect(level!.levelNumber, equals(lvl), reason: 'Level $lvl has incorrect level number');
      expect(level.arrows.isNotEmpty, true, reason: 'Level $lvl has no arrows');
      expect(level.patternName, isNot('fallback'), reason: 'Level $lvl has fallback pattern');

      final type = AppConstants.levelTypeFor(lvl);
      
      // Boss/God level specific checks
      if (type == LevelType.boss || type == LevelType.god) {
        final hasDirDots = level.orphanDots.any((d) => d.type != OrphanDotType.neutral);
        expect(hasDirDots, true, reason: 'Level $lvl (${type.name}) missing direction-change dots');
        
        final hasColors = level.arrows.any((a) => a.colorGroup != null);
        expect(hasColors, true, reason: 'Level $lvl (${type.name}) missing color pairs');
      }

      // Deflection loop check
      final orphanMap = {for (final od in level.orphanDots) od.key: od.type};
      for (final arrow in level.arrows) {
        final otherOccupied = <String>{};
        for (final a in level.arrows) {
          if (a.id == arrow.id) continue;
          for (final pt in a.path) otherOccupied.add('${pt[0]},${pt[1]}');
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
              reason: 'Level $lvl arrow ${arrow.id} has infinite deflection loop at $key');
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
          } else if (otherOccupied.contains(key)) {
            break;
          }

          d = currentDir.delta;
          nr += d[0];
          nc += d[1];
        }
      }

      // Path cycle check
      for (final arrow in level.arrows) {
        expect(_pathFormsCycle(arrow.path), false,
            reason: 'Level $lvl arrow ${arrow.id} forms a closed loop/square');
      }

      // Color group validation
      final colorGroups = <int, List<ArrowModel>>{};
      for (final arrow in level.arrows) {
        if (arrow.colorGroup != null) {
          colorGroups.putIfAbsent(arrow.colorGroup!, () => []).add(arrow);
        }
      }
      for (final entry in colorGroups.entries) {
        expect(entry.value.length, 2,
            reason: 'Level $lvl color group ${entry.key} has ${entry.value.length} arrows (expected 2)');
        final a1 = entry.value[0];
        final a2 = entry.value[1];
        final a1Cells = a1.path.map((p) => '${p[0]},${p[1]}').toSet();
        final a2Cells = a2.path.map((p) => '${p[0]},${p[1]}').toSet();

        final a1Blocked = _isExitBlocked(a1, level.gridSize, a2Cells, orphanMap);
        final a2Blocked = _isExitBlocked(a2, level.gridSize, a1Cells, orphanMap);

        expect(a1Blocked && a2Blocked, false,
            reason: 'Level $lvl color group ${entry.key}: mutual blocking deadlock');
      }

      // Solver verification for small grids (≤20)
      if (level.gridSize <= 20) {
        final solution = LevelSolver.solve(level, 6000);
        expect(solution, isNotNull, reason: 'Level $lvl is UNSOLVABLE');
      }

      if (lvl % 100 == 0) {
        print('  Verified levels 1 to $lvl');
      }
    }

    print('All 500 levels decoded from levels.bin are 100% verified & correct!');
  });
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
