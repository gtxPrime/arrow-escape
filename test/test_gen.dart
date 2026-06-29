import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:arrow_puzzle/core/constants.dart';
import 'package:arrow_puzzle/data/level_generator/mask_generator.dart';
import 'package:arrow_puzzle/data/models/arrow.dart';
import 'package:arrow_puzzle/data/models/level.dart';

void main() {
  test("Diagnostic Reverse-Placement Generator", () {
    final logFile = File("F:/Source Codes/Arrow game/test_run.log");
    logFile.writeAsStringSync("Testing Reverse-Placement on Level 10...\n");

    final levelNumber = 10;
    final type = LevelType.god;
    final gridSize = 30;
    final seed = levelNumber * 103 + 51;
    final rng = Random(seed);

    final maskShape = MaskShape.hexagon;
    final mask = MaskGenerator.shapeByName(maskShape.name, gridSize, rng);

    logFile.writeAsStringSync("GridSize: $gridSize, MaskShape: ${maskShape.name}, MaskLength: ${mask.length}\n", mode: FileMode.append);

    final params = _paramsFor(levelNumber, type, gridSize, mask);

    for (int attempt = 0; attempt < 10; attempt++) {
      final level = _attemptReversePlacement(
        levelNumber: levelNumber,
        gridSize: gridSize,
        mask: mask,
        params: params,
        type: type,
        rng: rng,
        maskShape: maskShape,
        logFile: logFile,
        attempt: attempt,
      );
      if (level != null) {
        logFile.writeAsStringSync("SUCCESS on attempt $attempt! Arrows: ${level.arrows.length}\n", mode: FileMode.append);
        return;
      }
    }
    logFile.writeAsStringSync("FAILED ALL ATTEMPTS!\n", mode: FileMode.append);
  });
}

class _Params {
  final int arrowCount, avgLen;
  _Params(this.arrowCount, this.avgLen);
}

_Params _paramsFor(int level, LevelType type, int gridSize, Set<String> mask) {
  int avgLen;
  int arrowCount;

  if (level <= 3) {
    avgLen = 3;
    arrowCount = 4;
  } else {
    if (level <= 15) {
      avgLen = 4;
    } else if (level <= 50) {
      avgLen = 5;
    } else {
      avgLen = 6;
    }

    final totalCells = mask.length;
    const double fillRate = 1.0;
    final targetOccupiedCells = (totalCells * fillRate).round();
    arrowCount = (targetOccupiedCells / avgLen).round().clamp(4, 300);
  }

  return _Params(arrowCount, avgLen);
}

LevelModel? _attemptReversePlacement({
  required int levelNumber,
  required int gridSize,
  required Set<String> mask,
  required _Params params,
  required LevelType type,
  required Random rng,
  required MaskShape maskShape,
  required File logFile,
  required int attempt,
}) {
  final bool fillEntireGrid = type != LevelType.tutorial;
  final int targetCount = fillEntireGrid ? mask.length : params.arrowCount;

  final maskPacked = <int>{};
  for (final k in mask) {
    final parts = k.split(',');
    maskPacked.add(int.parse(parts[0]) * 1000 + int.parse(parts[1]));
  }

  for (int layoutAttempt = 0; layoutAttempt < 15; layoutAttempt++) {
    final arrows = <ArrowModel>[];
    final occupiedPacked = <int>{};
    int placementFailures = 0;
    int counter = 0;

    while ((fillEntireGrid ? occupiedPacked.length : arrows.length) < targetCount && placementFailures < 150) {
      final available = <int>[];
      for (final packed in maskPacked) {
        if (occupiedPacked.contains(packed)) continue;
        final r = packed ~/ 1000, c = packed % 1000;
        bool hasFreeNeighbor = false;
        for (final nb in [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
          final np = (r + nb[0]) * 1000 + (c + nb[1]);
          if (maskPacked.contains(np) && !occupiedPacked.contains(np)) {
            hasFreeNeighbor = true;
            break;
          }
        }
        if (hasFreeNeighbor) {
          available.add(packed);
        }
      }

      if (available.isEmpty) break;

      final startPacked = available[rng.nextInt(available.length)];
      final r = startPacked ~/ 1000, c = startPacked % 1000;

      final double fillRatio = occupiedPacked.length / maskPacked.length;
      final int targetLen = fillRatio >= 0.80
          ? 2
          : _pickLength(params, type, rng);

      final path = <List<int>>[[r, c]];
      int cr = r, cc = c;
      for (int step = 1; step < targetLen; step++) {
        final neighbors = <List<int>>[];
        for (final nb in [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
          final nr = cr + nb[0], nc = cc + nb[1];
          final np = nr * 1000 + nc;
          if (maskPacked.contains(np) && !occupiedPacked.contains(np) && !path.any((p) => p[0] == nr && p[1] == nc)) {
            neighbors.add([nr, nc]);
          }
        }
        if (neighbors.isEmpty) break;
        final nextCell = neighbors[rng.nextInt(neighbors.length)];
        cr = nextCell[0];
        cc = nextCell[1];
        path.add([cr, cc]);
      }

      if (path.length >= 2) {
        // Reverse-Placement: choose head and exit direction
        // Try head at start
        final head1 = path.first;
        final next1 = path[1];
        final dir1 = _getDirectionFromDelta(head1[0] - next1[0], head1[1] - next1[1]);
        
        // Try head at end
        final head2 = path.last;
        final next2 = path[path.length - 2];
        final dir2 = _getDirectionFromDelta(head2[0] - next2[0], head2[1] - next2[1]);

        bool headAtStart = true;
        ArrowDirection? finalDir;

        // Shuffle choices to avoid patterns
        final choices = [[true, dir1], [false, dir2]]..shuffle(rng);
        for (final choice in choices) {
          final isStart = choice[0] as bool;
          final d = choice[1] as ArrowDirection;
          final h = isStart ? head1 : head2;

          // Check if exit path is clear of currently placed arrows (occupiedPacked)
          if (_isExitPathClearPacked(h, d, occupiedPacked, gridSize)) {
            headAtStart = isStart;
            finalDir = d;
            break;
          }
        }

        if (finalDir != null) {
          final finalPath = headAtStart ? path : path.reversed.toList();
          final head = finalPath.first;

          arrows.add(ArrowModel(
            id: 'a_${levelNumber}_${counter++}',
            row: head[0],
            col: head[1],
            direction: finalDir,
            isPartOfPattern: true,
            path: finalPath,
            mechanic: SnakeMechanic.standard,
          ));
          for (final pt in finalPath) occupiedPacked.add(pt[0] * 1000 + pt[1]);
        } else {
          placementFailures++;
        }
      } else {
        placementFailures++;
      }
    }

    final occupied = occupiedPacked.map((val) => '${val ~/ 1000},${val % 1000}').toSet();

    if (fillEntireGrid) {
      _fillRemainingCellsReverse(arrows, occupied, occupiedPacked, mask, levelNumber, counter, gridSize, rng);
      _absorbOrphans(arrows, occupied, mask);
    }

    final emptyCount = mask.length - occupied.length;
    if (emptyCount > 1) {
      continue;
    }

    final orphanDots = <OrphanDot>[];
    if (emptyCount == 1) {
      final orphanKey = mask.firstWhere((k) => !occupied.contains(k));
      final parts = orphanKey.split(',');
      final r = int.parse(parts[0]), c = int.parse(parts[1]);
      orphanDots.add(OrphanDot(
        row: r, col: c,
        type: rng.nextBool() ? OrphanDotType.red : OrphanDotType.blue,
      ));
      occupied.add(orphanKey);
    }

    logFile.writeAsStringSync("    Layout $layoutAttempt success! emptyCount=$emptyCount\n", mode: FileMode.append);

    // Guaranteed solvable!
    return LevelModel(
      levelNumber: levelNumber,
      gridSize: gridSize,
      arrows: arrows.reversed.toList(), // reverse order of placement is solution order!
      patternName: maskShape.name,
      difficulty: Difficulty.expert,
      orphanDots: orphanDots,
    );
  }
  return null;
}

int _pickLength(_Params p, LevelType type, Random rng) {
  final roll = rng.nextDouble();
  if (roll < 0.55) {
    final medMax = max(6, p.avgLen);
    return 3 + rng.nextInt(medMax - 3 + 1);
  } else if (roll < 0.85) {
    return p.avgLen + 2 + rng.nextInt(p.avgLen ~/ 2 + 2);
  } else {
    return 2;
  }
}

void _fillRemainingCellsReverse(List<ArrowModel> arrows, Set<String> occupied, Set<int> occupiedPacked, Set<String> mask, int levelNumber, int counter, int gridSize, Random rng) {
  int localCounter = counter;
  int passCount = 0;
  while (passCount < 3) {
    bool progress = false;
    passCount++;

    final remaining = mask.where((k) => !occupied.contains(k)).toSet();
    if (remaining.isEmpty) return;

    for (final cellKey in remaining.toList()) {
      if (!remaining.contains(cellKey)) continue;

      final parts = cellKey.split(',');
      final r = int.parse(parts[0]), c = int.parse(parts[1]);

      String? neighborKey;
      int headRow = r, headCol = c, tailRow = r, tailCol = c;
      ArrowDirection dir = ArrowDirection.up;

      for (final nb in [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
        final tr = r + nb[0];
        final tc = c + nb[1];
        final tk = '$tr,$tc';
        if (remaining.contains(tk)) {
          neighborKey = tk;
          if (nb[0] == 1) {
            dir = ArrowDirection.down; headRow = tr; headCol = tc; tailRow = r; tailCol = c;
          } else if (nb[0] == -1) {
            dir = ArrowDirection.up; headRow = tr; headCol = tc; tailRow = r; tailCol = c;
          } else if (nb[1] == 1) {
            dir = ArrowDirection.right; headRow = tr; headCol = tc; tailRow = r; tailCol = c;
          } else {
            dir = ArrowDirection.left; headRow = tr; headCol = tc; tailRow = r; tailCol = c;
          }
          break;
        }
      }

      if (neighborKey != null) {
        // Reverse check: make sure the exit path is clear
        if (_isExitPathClearPacked([headRow, headCol], dir, occupiedPacked, gridSize)) {
          arrows.add(ArrowModel(
            id: 'a_${levelNumber}_${localCounter++}',
            row: headRow,
            col: headCol,
            direction: dir,
            isPartOfPattern: true,
            path: [[headRow, headCol], [tailRow, tailCol]],
            mechanic: SnakeMechanic.standard,
          ));
          occupied.add(cellKey);
          occupied.add(neighborKey);
          occupiedPacked.add(headRow * 1000 + headCol);
          occupiedPacked.add(tailRow * 1000 + tailCol);
          remaining.remove(cellKey);
          remaining.remove(neighborKey);
          progress = true;
        }
      }
    }
    if (!progress) break;
  }
}

void _absorbOrphans(List<ArrowModel> arrows, Set<String> occupied, Set<String> mask) {
  final orphans = mask.where((k) => !occupied.contains(k)).toList();
  for (final cellKey in orphans) {
    final parts = cellKey.split(',');
    final r = int.parse(parts[0]), c = int.parse(parts[1]);

    for (int i = 0; i < arrows.length; i++) {
      final arrow = arrows[i];
      
      // Check tail
      final tail = arrow.path.last;
      final distTail = (tail[0] - r).abs() + (tail[1] - c).abs();
      if (distTail == 1) {
        final newPath = List<List<int>>.from(arrow.path)..add([r, c]);
        arrows[i] = arrow.copyWith(path: newPath);
        occupied.add(cellKey);
        break;
      }

      // Check head
      final head = arrow.path.first;
      final distHead = (head[0] - r).abs() + (head[1] - c).abs();
      if (distHead == 1) {
        final newPath = [[r, c]]..addAll(arrow.path);
        arrows[i] = arrow.copyWith(row: r, col: c, path: newPath);
        occupied.add(cellKey);
        break;
      }
    }
  }
}

ArrowDirection _getDirectionFromDelta(int dr, int dc) {
  if (dr == -1 && dc == 0) return ArrowDirection.up;
  if (dr == 1 && dc == 0) return ArrowDirection.down;
  if (dr == 0 && dc == -1) return ArrowDirection.left;
  return ArrowDirection.right;
}

bool _isExitPathClearPacked(
  List<int> head,
  ArrowDirection dir,
  Set<int> occupiedPacked,
  int gridSize,
) {
  var d = dir.delta;
  int nr = head[0] + d[0];
  int nc = head[1] + d[1];

  while (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
    final key = nr * 1000 + nc;
    if (occupiedPacked.contains(key)) {
      return false;
    }
    nr += d[0];
    nc += d[1];
  }
  return true;
}
