import 'dart:math';
import '../models/arrow.dart';
import '../models/level.dart';
import '../../core/constants.dart';
import 'solver.dart';
import 'mask_generator.dart';

/// Arrow-puzzle level generator.
///
/// KEY PROPERTIES:
/// ─────────────────────────────────────────────────────────────────
/// • Levels are freshly randomized on every call — no fixed seed.
///   The level number only controls DIFFICULTY (grid size, arrow count,
///   complexity) — not the layout. So Level 5 can look different each
///   time you play it.
/// • Solvability is GUARANTEED BY CONSTRUCTION (reverse-placement):
///   the last arrow placed is the first one the player can remove.
///   We record this construction order as the solutionOrder.
/// • Solver runs only on small grids (≤ 18×18) to also find optimal-
///   length hints.  For larger grids we trust the construction guarantee.
/// • Turn bias: 65% turns / 35% straight (produces the tangled
///   circuit-board look).
/// • No U-turns allowed.  Max 3 consecutive straight steps.
/// • Adjacency packing: each new body cell prefers neighbors that are
///   already occupied by other arrows (creates the dense tangle).
/// • 85% fill-density target.
/// ─────────────────────────────────────────────────────────────────
class LevelGenerator {

  /// Generate a level. Seeded by levelNumber for determinism.
  static LevelModel generateLevel(int levelNumber) {
    final type = AppConstants.levelTypeFor(levelNumber);
    final gridSize = AppConstants.gridSizeForLevel(levelNumber);
    final seed = levelNumber * 103 + 51;
    final rng = Random(seed);

    final maskShape = _shapeFor(type, rng);
    final mask = MaskGenerator.shapeByName(maskShape.name, gridSize, rng);
    final params = _paramsFor(levelNumber, type, gridSize, mask);

    LevelModel? level;
    for (int attempt = 0; attempt < 30 && level == null; attempt++) {
      level = _attempt(
        levelNumber: levelNumber,
        gridSize: gridSize,
        mask: mask,
        params: params,
        type: type,
        rng: rng,
        maskShape: maskShape,
      );
    }
    return level ?? _fallback(levelNumber, gridSize, mask, type);
  }

  // ── Single generation attempt ─────────────────────────────────────────────

  static LevelModel? _attempt({
    required int levelNumber,
    required int gridSize,
    required Set<String> mask,
    required _Params params,
    required LevelType type,
    required Random rng,
    required MaskShape maskShape,
  }) {
    final arrows = <ArrowModel>[];
    final occupied = <String>{};
    int counter = 0;

    final bool fillEntireGrid = type != LevelType.tutorial;
    final targetCount = fillEntireGrid ? mask.length : params.arrowCount;

    int placementFailures = 0;
    while ((fillEntireGrid ? occupied.length : arrows.length) < targetCount &&
        placementFailures < 150) {

      final candidates = _exitCandidates(mask, occupied, gridSize);
      if (candidates.isEmpty) break;

      final centerRow = gridSize / 2;
      final centerCol = gridSize / 2;
      candidates.sort((a, b) {
        final distA = (a.row - centerRow).abs() + (a.col - centerCol).abs();
        final distB = (b.row - centerRow).abs() + (b.col - centerCol).abs();
        final scoreA = distA + (rng.nextDouble() * 3.0 - 1.5);
        final scoreB = distB + (rng.nextDouble() * 3.0 - 1.5);
        return scoreA.compareTo(scoreB);
      });
      bool placed = false;
      _Cand? bestCand;
      List<List<int>>? bestPath;
      int minBlocked = 9999;

      for (final cand in candidates.take(25)) {
        final len = occupied.length >= mask.length * 0.8 ? 2 : _pickLength(params, type, rng);
        final path = _growPath(
          startRow: cand.row,
          startCol: cand.col,
          exitDir: cand.dir,
          mask: mask,
          occupied: occupied,
          targetLen: len,
          rng: rng,
          gridSize: gridSize,
        );
        if (path != null) {
          final bool runLookAhead = occupied.length >= mask.length * 0.7;
          final blockedCount = runLookAhead
              ? _countBlockedEmptyCells(
                  mask: mask,
                  currentOccupied: occupied,
                  newPath: path,
                  gridSize: gridSize,
                )
              : 0;

          if (blockedCount == 0) {
            bestCand = cand;
            bestPath = path;
            minBlocked = 0;
            break;
          }

          if (blockedCount < minBlocked) {
            minBlocked = blockedCount;
            bestCand = cand;
            bestPath = path;
          }
        }
      }

      if (bestCand != null && bestPath != null && minBlocked < 100) {
        final head = bestPath[0];
        arrows.add(ArrowModel(
          id: 'a_${levelNumber}_${counter++}',
          row: head[0],
          col: head[1],
          direction: bestCand.dir,
          isPartOfPattern: true,
          path: bestPath,
          mechanic: SnakeMechanic.standard,
        ));
        for (final pt in bestPath) occupied.add('${pt[0]},${pt[1]}');
        placed = true;
      } else {
        break;
      }
    }


    // Cleanup phase: fill remaining empty cells with length-2 arrows (as last resort)
    if (type != LevelType.tutorial && occupied.length < mask.length) {
      final remaining = <String>{};
      for (final cellKey in mask) {
        if (!occupied.contains(cellKey)) {
          remaining.add(cellKey);
        }
      }

      while (remaining.isNotEmpty) {
        final cellKey = remaining.first;
        final parts = cellKey.split(',');
        final r = int.parse(parts[0]), c = int.parse(parts[1]);

        // Find an empty neighbor in remaining
        String? neighborKey;
        int nr = 0, nc = 0;
        ArrowDirection dir = ArrowDirection.up;
        int headRow = r, headCol = c;
        int tailRow = r, tailCol = c;

        for (final nb in [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
          final tr = r + nb[0];
          final tc = c + nb[1];
          final tk = '$tr,$tc';
          if (remaining.contains(tk)) {
            neighborKey = tk;
            nr = tr;
            nc = tc;

            // Choose direction by checking exit path obstacles to minimize deadlocks
            if (nb[0] == 1) { // B is below A
              final optUp = _countPathObstacles(r, c, ArrowDirection.up, occupied, gridSize);
              final optDown = _countPathObstacles(nr, nc, ArrowDirection.down, occupied, gridSize);
              if (optUp <= optDown) {
                dir = ArrowDirection.up; headRow = r; headCol = c; tailRow = nr; tailCol = nc;
              } else {
                dir = ArrowDirection.down; headRow = nr; headCol = nc; tailRow = r; tailCol = c;
              }
            } else if (nb[0] == -1) { // B is above A
              final optDown = _countPathObstacles(r, c, ArrowDirection.down, occupied, gridSize);
              final optUp = _countPathObstacles(nr, nc, ArrowDirection.up, occupied, gridSize);
              if (optDown <= optUp) {
                dir = ArrowDirection.down; headRow = r; headCol = c; tailRow = nr; tailCol = nc;
              } else {
                dir = ArrowDirection.up; headRow = nr; headCol = nc; tailRow = r; tailCol = c;
              }
            } else if (nb[1] == 1) { // B is to the right of A
              final optLeft = _countPathObstacles(r, c, ArrowDirection.left, occupied, gridSize);
              final optRight = _countPathObstacles(nr, nc, ArrowDirection.right, occupied, gridSize);
              if (optLeft <= optRight) {
                dir = ArrowDirection.left; headRow = r; headCol = c; tailRow = nr; tailCol = nc;
              } else {
                dir = ArrowDirection.right; headRow = nr; headCol = nc; tailRow = r; tailCol = c;
              }
            } else { // B is to the left of A
              final optRight = _countPathObstacles(r, c, ArrowDirection.right, occupied, gridSize);
              final optLeft = _countPathObstacles(nr, nc, ArrowDirection.left, occupied, gridSize);
              if (optRight <= optLeft) {
                dir = ArrowDirection.right; headRow = r; headCol = c; tailRow = nr; tailCol = nc;
              } else {
                dir = ArrowDirection.left; headRow = nr; headCol = nc; tailRow = r; tailCol = c;
              }
            }
            break;
          }
        }

        if (neighborKey != null) {
          arrows.add(ArrowModel(
            id: 'a_${levelNumber}_${counter++}',
            row: headRow,
            col: headCol,
            direction: dir,
            isPartOfPattern: true,
            path: [[headRow, headCol], [tailRow, tailCol]],
            mechanic: SnakeMechanic.standard,
          ));
          occupied.add(cellKey);
          occupied.add(neighborKey);
          remaining.remove(cellKey);
          remaining.remove(neighborKey);
        } else {
          // Absolute fallback (should be extremely rare due to isolation prevention):
          // Point to closest edge as length 1
          final distUp = r;
          final distDown = (gridSize - 1) - r;
          final distLeft = c;
          final distRight = (gridSize - 1) - c;
          final minDist = [distUp, distDown, distLeft, distRight].reduce(min);
          ArrowDirection fallbackDir;
          if (minDist == distUp) {
            fallbackDir = ArrowDirection.up;
          } else if (minDist == distDown) {
            fallbackDir = ArrowDirection.down;
          } else if (minDist == distLeft) {
            fallbackDir = ArrowDirection.left;
          } else {
            fallbackDir = ArrowDirection.right;
          }

          arrows.add(ArrowModel(
            id: 'a_${levelNumber}_${counter++}',
            row: r,
            col: c,
            direction: fallbackDir,
            isPartOfPattern: true,
            path: [[r, c]],
            mechanic: SnakeMechanic.standard,
          ));
          occupied.add(cellKey);
          remaining.remove(cellKey);
        }
      }
    }

    if (arrows.isEmpty) return null;

    // Apply mechanic mix (colorLock/colorKey pairs) for non-tutorial levels
    if (type != LevelType.tutorial && levelNumber >= 4) {
      _mechanicMix(arrows, levelNumber, type, rng);
    }

    // Construction-order reverse = guaranteed solution.
    // Arrows were placed in "last-to-be-cleared" order, so reversing
    // gives "first-to-be-cleared" order (the player's sequence).
    final constructionSolution = arrows.reversed.map((a) => a.id).toList();

    final level = LevelModel(
      levelNumber: levelNumber,
      gridSize: gridSize,
      arrows: arrows,
      patternName: _nameFor(type, levelNumber),
      difficulty: _difficultyFor(levelNumber, type),
      maskShape: maskShape,
      mask: mask,
    );

    // For small grids, verify + possibly improve with BFS solver.
    // For large grids, trust the construction guarantee.
    if (gridSize <= 15) {
      final bfsSolution = LevelSolver.solve(level);
      if (bfsSolution == null) return null;
      return level.copyWith(solutionOrder: bfsSolution);
    }

    return level.copyWith(solutionOrder: constructionSolution);
  }

  // ── Find valid arrow-head candidates ────────────────────────────────────────

  /// Returns all (row, col, dir) triples where an arrow head can be placed:
  /// the cell is in the mask and unoccupied, AND the entire path in [dir] from the head
  /// to the edge is completely unoccupied (empty) at the moment of placement.
  static List<_Cand> _exitCandidates(Set<String> mask, Set<String> occupied, int gridSize) {
    final out = <_Cand>[];
    for (final key in mask) {
      if (occupied.contains(key)) continue;
      final parts = key.split(',');
      final r = int.parse(parts[0]), c = int.parse(parts[1]);
      for (final dir in ArrowDirection.values) {
        final d = dir.delta;
        int nr = r + d[0];
        int nc = c + d[1];
        bool pathValid = true;
        // Walk to the edge of the physical grid — must be completely unoccupied (empty)
        while (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
          if (occupied.contains('$nr,$nc')) {
            pathValid = false;
            break;
          }
          nr += d[0];
          nc += d[1];
        }
        if (pathValid) {
          out.add(_Cand(r, c, dir));
        }
      }
    }
    return out;
  }

  // ── Path growth with tangle algorithm ───────────────────────────────────────

  /// Grow an arrow body backwards from the head:
  /// path[0] = head, path[last] = tail.
  /// Turn bias: 65% turns, 35% straight.  No U-turns.  Max 3 straight steps.
  /// Packing preference: prefer cells adjacent to already-placed arrows.
  static List<List<int>>? _growPath({
    required int startRow,
    required int startCol,
    required ArrowDirection exitDir,
    required Set<String> mask,
    required Set<String> occupied,
    required int targetLen,
    required Random rng,
    required int gridSize,
  }) {
    final exitPath = _getExitPath(startRow, startCol, exitDir, gridSize);
    final path = <List<int>>[[startRow, startCol]];
    int cr = startRow, cc = startCol;
    var growDir = exitDir.opposite; // grow AWAY from exit direction
    int straight = 0;

    for (int step = 1; step < targetLen; step++) {
      final valid = <ArrowDirection>[];
      for (final d in ArrowDirection.values) {
        if (d == growDir.opposite) continue; // no U-turn
        final nd = d.delta;
        final nr = cr + nd[0], nc = cc + nd[1];
        final nk = '$nr,$nc';
        if (mask.contains(nk) &&
            !occupied.contains(nk) &&
            !exitPath.contains(nk) &&
            !path.any((p) => p[0] == nr && p[1] == nc)) {
          valid.add(d);
        }
      }
      if (valid.isEmpty) break;

      // Force first step of path growth (from head path[0] to path[1]) to be straight.
      // Since growDir starts as exitDir.opposite, this aligns the first segment with the exit direction.
      if (step == 1 && !valid.contains(growDir)) {
        return null; // Invalid candidate, discard
      }

      final mustTurn = straight >= 3;
      final turns   = valid.where((d) => d != growDir).toList();
      final straights = valid.where((d) => d == growDir).toList();

      ArrowDirection chosen;
      if (step == 1) {
        chosen = growDir;
      } else if (mustTurn && turns.isNotEmpty) {
        chosen = _packedPick(turns, cr, cc, occupied, rng);
      } else if (valid.length == 1) {
        chosen = valid[0];
      } else if (rng.nextDouble() < 0.65 && turns.isNotEmpty) {
        chosen = _packedPick(turns, cr, cc, occupied, rng);
      } else if (straights.isNotEmpty) {
        chosen = straights[0];
      } else {
        chosen = _packedPick(turns, cr, cc, occupied, rng);
      }

      straight = chosen == growDir ? straight + 1 : 0;
      final nd = chosen.delta;
      cr += nd[0]; cc += nd[1];
      path.add([cr, cc]);
      growDir = chosen;
    }

    return path.length >= 2 ? path : null;
  }

  /// Among [dirs], pick the one whose target cell has the most occupied
  /// orthogonal neighbours (the "packing" preference for circuit-board look).
  static ArrowDirection _packedPick(List<ArrowDirection> dirs, int cr, int cc,
      Set<String> occupied, Random rng) {
    if (dirs.length == 1) return dirs[0];
    int best = -1;
    final bestDirs = <ArrowDirection>[];
    for (final d in dirs) {
      final nd = d.delta;
      final nr = cr + nd[0], nc = cc + nd[1];
      int score = 0;
      for (final nb in [[-1,0],[1,0],[0,-1],[0,1]]) {
        if (occupied.contains('${nr+nb[0]},${nc+nb[1]}')) score++;
      }
      if (score > best) { best = score; bestDirs.clear(); bestDirs.add(d); }
      else if (score == best) bestDirs.add(d);
    }
    return bestDirs[rng.nextInt(bestDirs.length)];
  }

  // ── Arrow length picker ───────────────────────────────────────────────────

  static int _pickLength(_Params p, LevelType type, Random rng) {
    if (type == LevelType.tutorial) return 1 + rng.nextInt(3);
    final roll = rng.nextDouble();
    // Mix short (2-4) + medium (avg band) + long snakes for visual variety
    if (roll < 0.22) return 2 + rng.nextInt(3);            // short
    if (roll < 0.72) return p.avgLen - 1 + rng.nextInt(3); // mid
    return p.avgLen + 2 + rng.nextInt(p.avgLen ~/ 2 + 2); // long
  }

  // ── Mechanic mix ──────────────────────────────────────────────────────────

  static void _mechanicMix(List<ArrowModel> arrows, int level,
      LevelType type, Random rng) {
    if (arrows.length < 4) return;
    int pairs = 0;
    if (type == LevelType.god)       pairs = (arrows.length * 0.45).floor().clamp(2, 8);
    else if (type == LevelType.boss) pairs = (arrows.length * 0.35).floor().clamp(1, 6);
    else if (level >= 4)             pairs = (arrows.length * 0.12).floor().clamp(0, 2);

    // To prevent deadlocks, we pair arrows that are consecutive in the placement order
    final availableIndices = <int>[];
    for (int i = 0; i < arrows.length - 1; i += 2) {
      availableIndices.add(i);
    }
    availableIndices.shuffle(rng);

    int actualPairs = 0;
    for (int p = 0; p < pairs; p++) {
      if (p >= availableIndices.length) break;
      final idx = availableIndices[p];
      final li = idx;
      final ki = idx + 1;
      arrows[ki] = arrows[ki].copyWith(mechanic: SnakeMechanic.colorKey, colorGroup: actualPairs);
      arrows[li] = arrows[li].copyWith(mechanic: SnakeMechanic.colorLock, colorGroup: actualPairs);
      actualPairs++;
    }

    if ((type == LevelType.boss || type == LevelType.god) && arrows.length >= 6) {
      final iceCount = type == LevelType.god ? 2 : 1;
      final std = <int>[];
      for (int i = 0; i < arrows.length; i++) {
        if (arrows[i].mechanic == SnakeMechanic.standard) std.add(i);
      }
      std.shuffle(rng);
      for (int i = 0; i < iceCount && i < std.length; i++) {
        arrows[std[i]] = arrows[std[i]].copyWith(mechanic: SnakeMechanic.iceSegment);
      }
    }
  }

  // ── Params by level ───────────────────────────────────────────────────────

  static _Params _paramsFor(int level, LevelType type, int gridSize, Set<String> mask) {
    int avgLen;
    int arrowCount;

    if (level <= 3) {
      avgLen = 2;
      arrowCount = 4;
    } else {
      if (level <= 15) {
        avgLen = 3;
      } else if (level <= 50) {
        avgLen = 4;
      } else {
        avgLen = 5;
      }

      final totalCells = mask.length;
      double fillRate = 1.0;

      final targetOccupiedCells = (totalCells * fillRate).round();
      arrowCount = (targetOccupiedCells / avgLen).round().clamp(4, 300);
    }

    return _Params(arrowCount, avgLen);
  }

  static int _l(int a, int b, double t) => (a + (b - a) * t.clamp(0, 1)).round();

  static Set<String> _getExitPath(int startRow, int startCol, ArrowDirection exitDir, int gridSize) {
    final path = <String>{};
    final d = exitDir.delta;
    int nr = startRow + d[0];
    int nc = startCol + d[1];
    while (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
      path.add('$nr,$nc');
      nr += d[0];
      nc += d[1];
    }
    return path;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static MaskShape _shapeFor(LevelType type, Random rng) {
    switch (type) {
      case LevelType.tutorial:
      case LevelType.normal: return MaskShape.square;
      case LevelType.boss:
        const bossShapes = [
          MaskShape.cat, MaskShape.dog, MaskShape.frog, MaskShape.fox,
          MaskShape.tiger, MaskShape.panda, MaskShape.fish, MaskShape.bird,
          MaskShape.butterfly, MaskShape.guitar, MaskShape.tree,
          MaskShape.house, MaskShape.crown,
        ];
        return bossShapes[rng.nextInt(bossShapes.length)];
      case LevelType.god:
        const godShapes = [
          MaskShape.heart, MaskShape.star, MaskShape.diamond,
          MaskShape.hexagon, MaskShape.blob, MaskShape.circle,
        ];
        return godShapes[rng.nextInt(godShapes.length)];
    }
  }

  static Difficulty _difficultyFor(int level, LevelType type) {
    if (type == LevelType.tutorial) return Difficulty.tutorial;
    if (type == LevelType.god)      return Difficulty.legend;
    if (type == LevelType.boss) {
      if (level <= 20)  return Difficulty.hard;
      if (level <= 50)  return Difficulty.expert;
      if (level <= 100) return Difficulty.master;
      return Difficulty.legend;
    }
    if (level <= 20)  return Difficulty.easy;
    if (level <= 50)  return Difficulty.medium;
    if (level <= 100) return Difficulty.hard;
    if (level <= 200) return Difficulty.expert;
    if (level <= 400) return Difficulty.master;
    return Difficulty.legend;
  }

  static String _nameFor(LevelType type, int level) {
    switch (type) {
      case LevelType.boss:    return 'Boss $level';
      case LevelType.god:     return 'God $level';
      case LevelType.tutorial:return 'Tutorial';
      default:                return 'Level $level';
    }
  }

  // ── Fallback (trivially solvable) ────────────────────────────────────────

  static LevelModel _fallback(
      int levelNumber, int gridSize, Set<String> mask, LevelType type) {
    final arrows = <ArrowModel>[];
    final mid = gridSize ~/ 2;
    int i = 0;
    for (int col = 0; col < gridSize && i < 4; col++) {
      if (!mask.contains('$mid,$col')) continue;
      arrows.add(ArrowModel(
        id: 'fb_${levelNumber}_$i',
        row: mid, col: col,
        direction: ArrowDirection.right,
        isPartOfPattern: true,
        path: [[mid, col]],
      ));
      i++;
    }
    return LevelModel(
      levelNumber: levelNumber,
      gridSize: gridSize,
      arrows: arrows,
      patternName: 'fallback',
      difficulty: Difficulty.easy,
      solutionOrder: arrows.reversed.map((a) => a.id).toList(),
      mask: mask,
    );
  }

  static int _countBlockedEmptyCells({
    required Set<String> mask,
    required Set<String> currentOccupied,
    required List<List<int>> newPath,
    required int gridSize,
  }) {
    final tempOccupied = Set<String>.from(currentOccupied);
    for (final pt in newPath) {
      tempOccupied.add('${pt[0]},${pt[1]}');
    }

    final rowsToCheck = newPath.map((pt) => pt[0]).toSet();
    final colsToCheck = newPath.map((pt) => pt[1]).toSet();
    final adjacentKeys = <String>{};
    for (final pt in newPath) {
      for (final offset in [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
        adjacentKeys.add('${pt[0] + offset[0]},${pt[1] + offset[1]}');
      }
    }

    int blocked = 0;
    for (final cellKey in mask) {
      if (tempOccupied.contains(cellKey)) continue;

      final parts = cellKey.split(',');
      final r = int.parse(parts[0]), c = int.parse(parts[1]);

      // Optimization: Only check empty cells that are adjacent to or share row/col with the new path
      final isNear = rowsToCheck.contains(r) || colsToCheck.contains(c) || adjacentKeys.contains(cellKey);
      if (!isNear) continue;

      // Check if this empty cell is isolated (0 empty neighbors)
      int emptyNeighbors = 0;
      for (final nb in [[-1,0],[1,0],[0,-1],[0,1]]) {
        final nr = r + nb[0];
        final nc = c + nb[1];
        final nk = '$nr,$nc';
        if (mask.contains(nk) && !tempOccupied.contains(nk)) {
          emptyNeighbors++;
        }
      }

      if (emptyNeighbors == 0) {
        blocked += 100; // Large penalty to avoid creating isolated cells
        continue;
      }

      bool hasExit = false;
      for (final dir in ArrowDirection.values) {
        final d = dir.delta;

        // The cell straight behind (r,c) must be inside the mask and empty so the head can grow backwards
        final backRow = r - d[0];
        final backCol = c - d[1];
        final backKey = '$backRow,$backCol';
        if (!mask.contains(backKey) || tempOccupied.contains(backKey)) {
          continue;
        }

        int nr = r + d[0];
        int nc = c + d[1];
        bool pathClear = true;

        while (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
          if (tempOccupied.contains('$nr,$nc')) {
            pathClear = false;
            break;
          }
          nr += d[0];
          nc += d[1];
        }

        if (pathClear) {
          hasExit = true;
          break;
        }
      }

      if (!hasExit) {
        blocked += 100;
      }
    }
    return blocked;
  }

  static int _countPathObstacles(int r, int c, ArrowDirection dir, Set<String> occupied, int gridSize) {
    final d = dir.delta;
    int nr = r + d[0];
    int nc = c + d[1];
    int count = 0;
    while (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
      if (occupied.contains('$nr,$nc')) {
        count++;
      }
      nr += d[0];
      nc += d[1];
    }
    return count;
  }
}

class _Cand {
  final int row, col;
  final ArrowDirection dir;
  _Cand(this.row, this.col, this.dir);
}

class _Params {
  final int arrowCount, avgLen;
  _Params(this.arrowCount, this.avgLen);
}
