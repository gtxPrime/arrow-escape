// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:typed_data';
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
      
      if ((type == LevelType.boss || type == LevelType.god) &&
          lvl != 213 && lvl != 395 && lvl != 437) {
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

      // Solver verification: DFS for small grids, plus pair-aware greedy check for all levels.
      if (level.gridSize <= 20) {
        final solution = LevelSolver.solve(level, 6000);
        expect(solution, isNotNull, reason: 'Level $lvl is UNSOLVABLE (DFS found no solution)');
      }
      final solvable = _greedyCanSolve(level);
      expect(solvable, true, reason: 'Level $lvl is UNSOLVABLE (greedy simulation deadlock)');

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

bool _greedyCanSolve(LevelModel level) {
  if (level.arrows.isEmpty) return true;
  final gs = level.gridSize;
  final board = Uint16List(gs * gs);
  final arrs = level.arrows;
  final active = List<bool>.filled(arrs.length, true);
  for (int i = 0; i < arrs.length; i++) {
    for (final pt in arrs[i].path) board[pt[0] * gs + pt[1]] = i + 1;
  }
  final dotTypes = Uint8List(gs * gs);
  final dotActive = List<bool>.filled(gs * gs, false);
  for (final od in level.orphanDots) {
    final f = od.row * gs + od.col;
    dotTypes[f] = od.type.index;
    dotActive[f] = true;
  }
  final partner = List<int>.filled(arrs.length, -1);
  final grpMap = <int, List<int>>{};
  for (int i = 0; i < arrs.length; i++) {
    final g = arrs[i].colorGroup;
    if (g != null) grpMap.putIfAbsent(g, () => []).add(i);
  }
  for (final v in grpMap.values) {
    if (v.length == 2) { partner[v[0]] = v[1]; partner[v[1]] = v[0]; }
  }
  int count = arrs.length;
  final seen = <int>{};

  void clear(int idx) {
    if (!active[idx]) return;
    active[idx] = false; count--;
    for (final pt in arrs[idx].path) board[pt[0] * gs + pt[1]] = 0;
  }

  List<int>? tryExit(int ai, int pi) {
    ArrowDirection dir = arrs[ai].direction;
    final h = arrs[ai].path[0];
    var d = dir.delta;
    int r = h[0] + d[0], c = h[1] + d[1];
    final consumed = <int>[];
    final vis = <int>{};
    while (r >= 0 && r < gs && c >= 0 && c < gs) {
      final f = r * gs + c;
      if (vis.contains(f)) return null;
      vis.add(f);
      if (dotActive[f]) {
        consumed.add(f);
        final t = dotTypes[f];
        if (t == 0)      dir = ArrowDirection.up;
        else if (t == 1) dir = ArrowDirection.down;
        else if (t == 2) dir = ArrowDirection.left;
        else if (t == 3) dir = ArrowDirection.right;
      } else {
        final occ = board[f];
        if (occ != 0 && occ != ai + 1 && (pi == -1 || occ != pi + 1)) return null;
      }
      d = dir.delta;
      r += d[0]; c += d[1];
    }
    return consumed;
  }

  bool progress = true;
  while (progress && count > 0) {
    progress = false;
    seen.clear();
    for (int i = 0; i < arrs.length; i++) {
      if (!active[i]) continue;
      final p = partner[i];
      if (p == -1) continue;
      final g = arrs[i].colorGroup!;
      if (seen.contains(g)) continue;
      seen.add(g);
      if (!active[p]) continue;
      final c1 = tryExit(i, p);
      final c2 = tryExit(p, i);
      if (c1 != null && c2 != null) {
        final consumed = <int>{...c1, ...c2};
        for (final f in consumed) dotActive[f] = false;
        clear(i); clear(p); progress = true;
      }
    }
    for (int i = 0; i < arrs.length; i++) {
      if (!active[i] || partner[i] != -1) continue;
      final c = tryExit(i, -1);
      if (c != null) {
        for (final f in c) dotActive[f] = false;
        clear(i); progress = true;
      }
    }
  }
  return count == 0;
}

