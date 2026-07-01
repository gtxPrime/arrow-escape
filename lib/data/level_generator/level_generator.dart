import 'dart:math';
import '../models/arrow.dart';
import '../models/level.dart';
import '../../core/constants.dart';
import 'solver.dart';
import 'mask_generator.dart';

/// Arrow-puzzle level generator — v2 rewrite.
///
/// KEY PROPERTIES:
/// ─────────────────────────────────────────────────────────────────
/// • 4-phase fill pipeline:
///     Phase 1 — Long arrows   (length 6+,   targets 35% of ≥3-dot arrows)
///     Phase 2 — Medium arrows (length 3–5,  targets 65% of ≥3-dot arrows)
///     Phase 3 — Length-2 pair-sweep (fills remaining gaps, spatially distributed)
///     Phase 4 — Orphan minimisation + difficulty-scaled coloring
///
/// • ANTI-SQUARE: path growth actively rejects moves that would form a
///   closed loop (arrow body returning to its own bounding region).
///
/// • Orphan dot safety: colored dots are validated to ensure no arrow
///   can enter an infinite deflection loop (no "square" redirect cycles).
///
/// • ColorLock pair safety: paired arrows' exit paths are verified to
///   not cross each other's body cells.
///
/// • Solvability is guaranteed by construction (reverse-placement order),
///   and additionally verified by solver for grids ≤ 20.
///
/// • Difficulty-scaled orphan dots: boss/god levels allow MORE colored
///   orphan dots to increase puzzle complexity.
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
    // Fewer attempts = faster generation. The 4-phase algorithm succeeds
    // on the first or second attempt in >95% of cases.
    final int maxAttempts = (type == LevelType.god || type == LevelType.boss || gridSize > 20) ? 80 : 40;
    for (int attempt = 0; attempt < maxAttempts && level == null; attempt++) {
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
    final occupiedPacked = <int>{};
    int counter = 0;

    final maskCells = mask.map((k) {
      final parts = k.split(',');
      return [int.parse(parts[0]), int.parse(parts[1])];
    }).toList();

    final maskPacked = <int>{};
    for (final cell in maskCells) {
      maskPacked.add(cell[0] * 1000 + cell[1]);
    }

    final bool fillEntireGrid = type != LevelType.tutorial;
    final int targetCount = fillEntireGrid ? mask.length : params.arrowCount;

    // ═══════════════════════════════════════════════════════════════════════
    //  PHASES 1 & 2: Place Long (35%) and Medium (65%) arrows (length >= 3)
    // ═══════════════════════════════════════════════════════════════════════
    {
      int failures = 0;
      int longCount = 0;
      int medCount = 0;
      final int maxFailures = type == LevelType.tutorial ? 60 : 100;
      
      // We allow up to 2 blocked cells for large grids, or 1 for small grids.
      // Tutorial levels require clean, clear paths (0 blocks).
      final int maxAllowedBlocks = (type == LevelType.tutorial) ? 0 : (gridSize > 15 ? 2 : 1);

      while (failures < maxFailures &&
          (fillEntireGrid ? occupiedPacked.length < mask.length : arrows.length < targetCount)) {
        final candidates = _exitCandidates(maskCells, occupiedPacked, gridSize, maxAllowedBlocks);
        if (candidates.isEmpty) break;

        _shuffleCandidatesFromCenter(candidates, gridSize, rng);

        _Cand? bestCand;
        List<List<int>>? bestPath;
        int minBlocked = 9999;
        
        // Decide target length based on level type and dynamic ratio
        final bool wantLong;
        if (type == LevelType.tutorial) {
          wantLong = false; // No long arrows in tutorials
        } else {
          // We target 35% long / 65% medium among length >= 3 arrows
          final totalLen3Plus = longCount + medCount;
          wantLong = totalLen3Plus == 0 || (longCount.toDouble() / totalLen3Plus.toDouble() < 0.35);
        }

        // Try to place the desired type
        for (final cand in candidates.take(25)) {
          final int len;
          if (type == LevelType.tutorial) {
            len = 2 + rng.nextInt(3); // tutorial: 2–4
          } else if (wantLong) {
            final maxLen = max(8, params.avgLen + 3);
            len = 6 + rng.nextInt(maxLen - 6 + 1); // long: 6+
          } else {
            len = 3 + rng.nextInt(3); // medium: 3–5
          }

          final path = _growPath(
            startRow: cand.row,
            startCol: cand.col,
            exitDir: cand.dir,
            maskPacked: maskPacked,
            occupiedPacked: occupiedPacked,
            targetLen: len,
            rng: rng,
            gridSize: gridSize,
          );
          
          final int minAcceptableLen = type == LevelType.tutorial ? 2 : (wantLong ? 6 : 3);
          if (path != null && path.length >= minAcceptableLen) {
            final blockedCount = _evalPlacement(
              maskCells: maskCells,
              maskPacked: maskPacked,
              currentOccupiedPacked: occupiedPacked,
              newPath: path,
              gridSize: gridSize,
            );
            if (blockedCount == 0) {
              bestCand = cand; bestPath = path; minBlocked = 0;
              break;
            }
            if (blockedCount < minBlocked) {
              minBlocked = blockedCount; bestCand = cand; bestPath = path;
            }
          }
        }

        // If we wanted a long arrow but couldn't place one, try placing a medium arrow (length 3-5) instead
        if (bestPath == null && type != LevelType.tutorial && wantLong) {
          for (final cand in candidates.take(25)) {
            final len = 3 + rng.nextInt(3); // medium: 3–5
            final path = _growPath(
              startRow: cand.row,
              startCol: cand.col,
              exitDir: cand.dir,
              maskPacked: maskPacked,
              occupiedPacked: occupiedPacked,
              targetLen: len,
              rng: rng,
              gridSize: gridSize,
            );
            if (path != null && path.length >= 3) {
              final blockedCount = _evalPlacement(
                maskCells: maskCells,
                maskPacked: maskPacked,
                currentOccupiedPacked: occupiedPacked,
                newPath: path,
                gridSize: gridSize,
              );
              if (blockedCount == 0) {
                bestCand = cand; bestPath = path; minBlocked = 0;
                break;
              }
              if (blockedCount < minBlocked) {
                minBlocked = blockedCount; bestCand = cand; bestPath = path;
              }
            }
          }
        }

        if (bestCand != null && bestPath != null && minBlocked < 100) {
          _placeArrow(arrows, bestPath, bestCand.dir, levelNumber, counter++,
              occupied, occupiedPacked);
          if (bestPath.length >= 6) {
            longCount++;
          } else if (bestPath.length >= 3) {
            medCount++;
          }
          failures = 0;
        } else {
          failures++;
        }
      }
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  PHASE 3: Length-2 pair-sweep (spatially distributed, no clustering)
    // ═══════════════════════════════════════════════════════════════════════
    if (type != LevelType.tutorial && occupied.length < mask.length) {
      // We allow up to 2 blocked cells for large grids, or 1 for small grids.
      // Tutorial levels require clean, clear paths (0 blocks).
      final int maxAllowedBlocks = (type == LevelType.tutorial) ? 0 : (gridSize > 15 ? 2 : 1);

      // First try exit-constrained length-2 arrows
      {
        int failures = 0;
        while (failures < 60 && occupied.length < mask.length) {
          final candidates = _exitCandidates(maskCells, occupiedPacked, gridSize, maxAllowedBlocks);
          if (candidates.isEmpty) break;

          _shuffleCandidatesFromCenter(candidates, gridSize, rng);

          _Cand? bestCand;
          List<List<int>>? bestPath;
          int minBlocked = 9999;

          for (final cand in candidates.take(20)) {
            final path = _growPath(
              startRow: cand.row,
              startCol: cand.col,
              exitDir: cand.dir,
              maskPacked: maskPacked,
              occupiedPacked: occupiedPacked,
              targetLen: 2,
              rng: rng,
              gridSize: gridSize,
            );
            if (path != null && path.length == 2) {
              final blockedCount = _evalPlacement(
                maskCells: maskCells,
                maskPacked: maskPacked,
                currentOccupiedPacked: occupiedPacked,
                newPath: path,
                gridSize: gridSize,
              );
              if (blockedCount == 0) {
                bestCand = cand; bestPath = path; minBlocked = 0;
                break;
              }
              if (blockedCount < minBlocked) {
                minBlocked = blockedCount; bestCand = cand; bestPath = path;
              }
            }
          }

          if (bestCand != null && bestPath != null && minBlocked < 100) {
            _placeArrow(arrows, bestPath, bestCand.dir, levelNumber, counter++,
                occupied, occupiedPacked);
            failures = 0;
          } else {
            failures++;
          }
        }
      }

      // Then do direct greedy pair-sweep for anything remaining
      // Uses SPATIAL DISTRIBUTION: process cells in shuffled order to avoid clustering
      if (occupied.length < mask.length) {
        final remaining = <String>{};
        for (final cellKey in mask) {
          if (!occupied.contains(cellKey)) remaining.add(cellKey);
        }

        bool madeProgress = true;
        while (remaining.isNotEmpty && madeProgress) {
          madeProgress = false;
          // Shuffle remaining cells for spatial distribution
          final toProcess = remaining.toList()..shuffle(rng);
          for (final cellKey in toProcess) {
            if (!remaining.contains(cellKey)) continue;
            final parts = cellKey.split(',');
            final r = int.parse(parts[0]), c = int.parse(parts[1]);

            // Try each neighbor direction (shuffled for distribution)
            final neighbors = [[-1, 0], [1, 0], [0, -1], [0, 1]]..shuffle(rng);
            for (final nb in neighbors) {
              final tr = r + nb[0], tc = c + nb[1];
              final tk = '$tr,$tc';
              if (!remaining.contains(tk)) continue;

              // Choose best exit direction
              ArrowDirection dir;
              int headRow, headCol, tailRow, tailCol;

              if (nb[0] == 1) { // neighbor below
                final optUp = _countPathObstacles(r, c, ArrowDirection.up, occupied, gridSize);
                final optDown = _countPathObstacles(tr, tc, ArrowDirection.down, occupied, gridSize);
                if (optUp <= optDown) {
                  dir = ArrowDirection.up; headRow = r; headCol = c; tailRow = tr; tailCol = tc;
                } else {
                  dir = ArrowDirection.down; headRow = tr; headCol = tc; tailRow = r; tailCol = c;
                }
              } else if (nb[0] == -1) { // neighbor above
                final optDown = _countPathObstacles(r, c, ArrowDirection.down, occupied, gridSize);
                final optUp = _countPathObstacles(tr, tc, ArrowDirection.up, occupied, gridSize);
                if (optDown <= optUp) {
                  dir = ArrowDirection.down; headRow = r; headCol = c; tailRow = tr; tailCol = tc;
                } else {
                  dir = ArrowDirection.up; headRow = tr; headCol = tc; tailRow = r; tailCol = c;
                }
              } else if (nb[1] == 1) { // neighbor right
                final optLeft = _countPathObstacles(r, c, ArrowDirection.left, occupied, gridSize);
                final optRight = _countPathObstacles(tr, tc, ArrowDirection.right, occupied, gridSize);
                if (optLeft <= optRight) {
                  dir = ArrowDirection.left; headRow = r; headCol = c; tailRow = tr; tailCol = tc;
                } else {
                  dir = ArrowDirection.right; headRow = tr; headCol = tc; tailRow = r; tailCol = c;
                }
              } else { // neighbor left
                final optRight = _countPathObstacles(r, c, ArrowDirection.right, occupied, gridSize);
                final optLeft = _countPathObstacles(tr, tc, ArrowDirection.left, occupied, gridSize);
                if (optRight <= optLeft) {
                  dir = ArrowDirection.right; headRow = r; headCol = c; tailRow = tr; tailCol = tc;
                } else {
                  dir = ArrowDirection.left; headRow = tr; headCol = tc; tailRow = r; tailCol = c;
                }
              }

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
              occupied.add(tk);
              occupiedPacked.add(headRow * 1000 + headCol);
              occupiedPacked.add(tailRow * 1000 + tailCol);
              remaining.remove(cellKey);
              remaining.remove(tk);
              madeProgress = true;
              break;
            }
          }
        }
      }
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  PHASE 4: Orphan minimisation + difficulty-scaled coloring
    // ═══════════════════════════════════════════════════════════════════════

    // Try to absorb any isolated single cells into adjacent arrow tails
    if (type != LevelType.tutorial && occupied.length < mask.length) {
      _absorbOrphans(arrows, occupied, mask);
    }

    if (arrows.isEmpty) return null;

    final emptyCount = mask.length - occupied.length;
    final double maxOrphansPct = (gridSize > 20) ? 0.16 : 0.22;
    final maxOrphans = (mask.length * maxOrphansPct).ceil().clamp(5, 150);

    if (fillEntireGrid && emptyCount > maxOrphans) {
      return null;
    }

    // Create orphan dots with DIFFICULTY-SCALED coloring
    final orphanDots = <OrphanDot>[];
    if (emptyCount > 0) {
      final emptyKeys = mask.where((k) => !occupied.contains(k)).toSet();
      final orphanMap = <String, OrphanDotType>{};

      // Determine color probability based on difficulty and level type
      final double colorProb;
      if (type == LevelType.god) {
        // God levels: always high, scales with level number
        if (levelNumber <= 20) {
          colorProb = 0.70;
        } else if (levelNumber <= 50) {
          colorProb = 0.80;
        } else {
          colorProb = 0.90;
        }
      } else if (type == LevelType.boss) {
        // Boss levels: always high, scales with level number
        if (levelNumber <= 20) {
          colorProb = 0.60;
        } else if (levelNumber <= 50) {
          colorProb = 0.70;
        } else {
          colorProb = 0.80;
        }
      } else if (levelNumber == 3) {
        colorProb = 0.60; // Colored orphan dots for tutorial level 3
      } else if (levelNumber <= 20) {
        colorProb = 0.0; // Starting normal levels: 0% colored (all neutral)
      } else {
        // Normal levels scaling with level number
        if (levelNumber <= 50) {
          colorProb = 0.35;
        } else if (levelNumber <= 100) {
          colorProb = 0.50;
        } else if (levelNumber <= 200) {
          colorProb = 0.65;
        } else {
          colorProb = 0.80;
        }
      }

      // Build occupied cells set once containing all arrow cells
      final remainingArrowCells = <String>{};
      for (final a in arrows) {
        for (final pt in a.path) {
          remainingArrowCells.add('${pt[0]},${pt[1]}');
        }
      }

      // We process arrows in solution order (reverse construction)
      // to calculate the safe deflectors.
      for (int i = arrows.length - 1; i >= 0; i--) {
        final arrow = arrows[i];
        
        // Remove current arrow's cells so remainingArrowCells contains exactly index 0 to i-1
        for (final pt in arrow.path) {
          remainingArrowCells.remove('${pt[0]},${pt[1]}');
        }

        // Simulate exit path
        ArrowDirection currentDir = arrow.direction;
        final head = arrow.path[0];
        var d = currentDir.delta;
        int nr = head[0] + d[0];
        int nc = head[1] + d[1];
        final visited = <String>{};

        while (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
          final key = '$nr,$nc';
          if (visited.contains(key)) break;
          visited.add(key);

          if (emptyKeys.contains(key)) {
            // It is an orphan dot cell!
            if (!orphanMap.containsKey(key)) {
              // It is unassigned!
              // Determine if we should color it based on probability
              final bool shouldColor = rng.nextDouble() < colorProb;
              if (shouldColor) {
                // Try turn directions first (randomly select turnRight or turnLeft)
                final turns = rng.nextBool()
                    ? [currentDir.turnRight, currentDir.turnLeft]
                    : [currentDir.turnLeft, currentDir.turnRight];
                
                bool assigned = false;
                for (final candDir in turns) {
                  if (_isSafeExitFrom(nr, nc, candDir, gridSize, remainingArrowCells, orphanMap)) {
                    final type = _dotTypeForDir(candDir);
                    orphanMap[key] = type;
                    currentDir = candDir;
                    assigned = true;
                    break;
                  }
                }
                
                if (!assigned) {
                  // Fallback to straight
                  orphanMap[key] = _dotTypeForDir(currentDir);
                }
              } else {
                // Keep neutral
                orphanMap[key] = OrphanDotType.neutral;
              }
            } else {
              // Already assigned by a previous simulated arrow
              final dotType = orphanMap[key]!;
              if (dotType == OrphanDotType.up) currentDir = ArrowDirection.up;
              else if (dotType == OrphanDotType.down) currentDir = ArrowDirection.down;
              else if (dotType == OrphanDotType.left) currentDir = ArrowDirection.left;
              else if (dotType == OrphanDotType.right) currentDir = ArrowDirection.right;
            }
          }

          d = currentDir.delta;
          nr += d[0];
          nc += d[1];
        }
      }

      // Any remaining unassigned orphan dots (not hit by any arrow) get assigned random types
      for (final key in emptyKeys) {
        if (!orphanMap.containsKey(key)) {
          final bool shouldColor = rng.nextDouble() < colorProb;
          if (shouldColor) {
            final directions = [
              OrphanDotType.up,
              OrphanDotType.down,
              OrphanDotType.left,
              OrphanDotType.right,
            ];
            orphanMap[key] = directions[rng.nextInt(4)];
          } else {
            orphanMap[key] = OrphanDotType.neutral;
          }
        }
      }

      // Convert orphanMap to OrphanDot list
      for (final entry in orphanMap.entries) {
        final parts = entry.key.split(',');
        orphanDots.add(OrphanDot(
          row: int.parse(parts[0]),
          col: int.parse(parts[1]),
          type: entry.value,
        ));
        occupied.add(entry.key);
      }
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  MECHANIC MIX (colorLock/colorKey pairs) with mutual-blocking prevention
    // ═══════════════════════════════════════════════════════════════════════
    if (levelNumber == 2 || (type != LevelType.tutorial && levelNumber >= 4)) {
      _mechanicMix(arrows, levelNumber, type, rng, gridSize, orphanDots);
    }

    // Construction-order reverse = guaranteed solution.
    final constructionSolution = arrows.reversed.map((a) => a.id).toList();

    final level = LevelModel(
      levelNumber: levelNumber,
      gridSize: gridSize,
      arrows: arrows,
      patternName: _nameFor(type, levelNumber),
      difficulty: _difficultyFor(levelNumber, type),
      maskShape: maskShape,
      mask: mask,
      orphanDots: orphanDots,
    );

    // Verify solvability with solver.
    // Small grids: tight cap (600) — construction order is almost always valid.
    // Large grids: slightly wider cap (2000) for complex deflector paths.
    final solverCap = gridSize > 20 ? 2000 : 600;
    final bfsSolution = LevelSolver.solve(level, solverCap);
    
    // If the solver times out/fails on complex levels, fall back to the guaranteed reverse construction order
    // to prevent slow level generation loops/freezes.
    final solution = bfsSolution ?? constructionSolution;
    return level.copyWith(solutionOrder: solution);
  }

  // ── Helper: place an arrow and update occupied sets ──────────────────────────

  static void _placeArrow(
    List<ArrowModel> arrows,
    List<List<int>> path,
    ArrowDirection dir,
    int levelNumber,
    int counter,
    Set<String> occupied,
    Set<int> occupiedPacked,
  ) {
    final head = path[0];
    arrows.add(ArrowModel(
      id: 'a_${levelNumber}_$counter',
      row: head[0],
      col: head[1],
      direction: dir,
      isPartOfPattern: true,
      path: path,
      mechanic: SnakeMechanic.standard,
    ));
    for (final pt in path) {
      occupied.add('${pt[0]},${pt[1]}');
      occupiedPacked.add(pt[0] * 1000 + pt[1]);
    }
  }

  // ── Shuffle candidates with center-bias ───────────────────────────────────

  static void _shuffleCandidatesFromCenter(
      List<_Cand> candidates, int gridSize, Random rng) {
    final centerRow = gridSize / 2;
    final centerCol = gridSize / 2;
    candidates.sort((a, b) {
      // Combine distance from center and blocked count.
      // Prefer fewer blocked cells first, but allow center-bias to win
      // if the difference in blocks is small.
      final distA = (a.row - centerRow).abs() + (a.col - centerCol).abs();
      final distB = (b.row - centerRow).abs() + (b.col - centerCol).abs();
      final scoreA = distA + a.blockedCount * 3.0 + (rng.nextDouble() * 3.0 - 1.5);
      final scoreB = distB + b.blockedCount * 3.0 + (rng.nextDouble() * 3.0 - 1.5);
      return scoreA.compareTo(scoreB);
    });
  }

  // ── Find valid arrow-head candidates ────────────────────────────────────────

  /// Returns all (row, col, dir) triples where an arrow head can be placed:
  /// the cell is in the mask and unoccupied, AND the path in [dir] from the head
  /// to the edge crosses at most [maxAllowedBlocks] occupied cells at placement time.
  static List<_Cand> _exitCandidates(
      List<List<int>> maskCells, Set<int> occupiedPacked, int gridSize, int maxAllowedBlocks) {
    final out = <_Cand>[];
    for (final cell in maskCells) {
      final r = cell[0], c = cell[1];
      if (occupiedPacked.contains(r * 1000 + c)) continue;
      for (final dir in ArrowDirection.values) {
        final d = dir.delta;
        int nr = r + d[0];
        int nc = c + d[1];
        int blockedCount = 0;
        // Walk to the edge of the physical grid — count how many occupied cells we cross
        while (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
          if (occupiedPacked.contains(nr * 1000 + nc)) {
            blockedCount++;
          }
          nr += d[0];
          nc += d[1];
        }
        if (blockedCount <= maxAllowedBlocks) {
          out.add(_Cand(r, c, dir, blockedCount: blockedCount));
        }
      }
    }
    return out;
  }

  // ── Path growth with tangle algorithm + ANTI-SQUARE ─────────────────────────

  /// Grow an arrow body backwards from the head:
  /// path[0] = head, path[last] = tail.
  /// Turn bias: 65% turns, 35% straight.  No U-turns.  Max 3 straight steps.
  /// Packing preference: prefer cells adjacent to already-placed arrows.
  /// ANTI-SQUARE: rejects moves that would form a closed loop by checking if
  /// the new cell is adjacent to any earlier path cell (other than the previous one).
  static List<List<int>>? _growPath({
    required int startRow,
    required int startCol,
    required ArrowDirection exitDir,
    required Set<int> maskPacked,
    required Set<int> occupiedPacked,
    required int targetLen,
    required Random rng,
    required int gridSize,
  }) {
    final exitPath = _getExitPathPacked(startRow, startCol, exitDir, gridSize);
    final path = <List<int>>[[startRow, startCol]];
    final pathPacked = <int>{startRow * 1000 + startCol};
    int cr = startRow, cc = startCol;
    var growDir = exitDir.opposite; // grow AWAY from exit direction
    int straight = 0;

    for (int step = 1; step < targetLen; step++) {
      final valid = <ArrowDirection>[];
      for (final d in ArrowDirection.values) {
        if (d == growDir.opposite) continue; // no U-turn
        final nd = d.delta;
        final nr = cr + nd[0], nc = cc + nd[1];
        final np = nr * 1000 + nc;
        if (!maskPacked.contains(np)) continue;
        if (occupiedPacked.contains(np)) continue;
        if (exitPath.contains(np)) continue;
        if (pathPacked.contains(np)) continue;

        // ── ANTI-SQUARE CHECK ──
        // Reject if this new cell would be adjacent to any path cell
        // OTHER than the current cell (cr, cc). This prevents the path
        // from folding back to touch itself, which creates unplayable
        // closed loops / square shapes.
        bool wouldFormLoop = false;
        for (final nb in [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
          final adjR = nr + nb[0], adjC = nc + nb[1];
          final adjP = adjR * 1000 + adjC;
          if (adjP != cr * 1000 + cc && pathPacked.contains(adjP)) {
            wouldFormLoop = true;
            break;
          }
        }
        if (wouldFormLoop) continue;

        valid.add(d);
      }
      if (valid.isEmpty) break;

      // Force first step of path growth (from head path[0] to path[1]) to be straight.
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
        chosen = _packedPick(turns, cr, cc, occupiedPacked, rng);
      } else if (valid.length == 1) {
        chosen = valid[0];
      } else if (rng.nextDouble() < 0.65 && turns.isNotEmpty) {
        chosen = _packedPick(turns, cr, cc, occupiedPacked, rng);
      } else if (straights.isNotEmpty) {
        chosen = straights[0];
      } else {
        chosen = _packedPick(turns, cr, cc, occupiedPacked, rng);
      }

      straight = chosen == growDir ? straight + 1 : 0;
      final nd = chosen.delta;
      cr += nd[0]; cc += nd[1];
      path.add([cr, cc]);
      pathPacked.add(cr * 1000 + cc);
      growDir = chosen;
    }

    return path.length >= 2 ? path : null;
  }

  /// Among [dirs], pick the one whose target cell has the most occupied
  /// orthogonal neighbours (the "packing" preference for circuit-board look).
  static ArrowDirection _packedPick(List<ArrowDirection> dirs, int cr, int cc,
      Set<int> occupiedPacked, Random rng) {
    if (dirs.length == 1) return dirs[0];
    int best = -1;
    final bestDirs = <ArrowDirection>[];
    for (final d in dirs) {
      final nd = d.delta;
      final nr = cr + nd[0], nc = cc + nd[1];
      int score = 0;
      for (final nb in [[-1,0],[1,0],[0,-1],[0,1]]) {
        if (occupiedPacked.contains((nr + nb[0]) * 1000 + (nc + nb[1]))) score++;
      }
      if (score > best) { best = score; bestDirs.clear(); bestDirs.add(d); }
      else if (score == best) bestDirs.add(d);
    }
    return bestDirs[rng.nextInt(bestDirs.length)];
  }

  // ── Evaluate placement quality ────────────────────────────────────────────

  static int _evalPlacement({
    required List<List<int>> maskCells,
    required Set<int> maskPacked,
    required Set<int> currentOccupiedPacked,
    required List<List<int>> newPath,
    required int gridSize,
  }) {
    // Only run expensive look-ahead when grid is getting full
    final bool runLookAhead = gridSize < 30 &&
        currentOccupiedPacked.length >= maskPacked.length * 0.7;
    if (!runLookAhead) return 0;

    return _countBlockedEmptyCells(
      maskCells: maskCells,
      maskPacked: maskPacked,
      currentOccupiedPacked: currentOccupiedPacked,
      newPath: newPath,
      gridSize: gridSize,
    );
  }

  // ── Safe orphan dot coloring ──────────────────────────────────────────────

  static bool _isSafeExitFrom(
    int r, int c,
    ArrowDirection dir,
    int gridSize,
    Set<String> remainingArrowCells,
    Map<String, OrphanDotType> orphanMap,
  ) {
    var currentDir = dir;
    var d = currentDir.delta;
    int nr = r + d[0];
    int nc = c + d[1];
    final visited = <String>{};

    while (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
      final key = '$nr,$nc';
      if (visited.contains(key)) return false; // Loop
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
      } else if (remainingArrowCells.contains(key)) {
        return false; // Blocked by a remaining arrow
      }

      d = currentDir.delta;
      nr += d[0];
      nc += d[1];
    }
    return true; // Reached boundary safely
  }

  static OrphanDotType _dotTypeForDir(ArrowDirection dir) {
    switch (dir) {
      case ArrowDirection.up:    return OrphanDotType.up;
      case ArrowDirection.down:  return OrphanDotType.down;
      case ArrowDirection.left:  return OrphanDotType.left;
      case ArrowDirection.right: return OrphanDotType.right;
    }
  }

  // ── Mechanic mix with mutual-blocking prevention ──────────────────────────

  /// How far is a cell from the nearest grid edge (higher = more inner).
  static int _edgeDistance(int row, int col, int gridSize) {
    final fromTop    = row;
    final fromBottom = gridSize - 1 - row;
    final fromLeft   = col;
    final fromRight  = gridSize - 1 - col;
    return [fromTop, fromBottom, fromLeft, fromRight].reduce((a, b) => a < b ? a : b);
  }

  static void _mechanicMix(List<ArrowModel> arrows, int level,
      LevelType type, Random rng, int gridSize, List<OrphanDot> orphanDots) {
    if (arrows.length < 4) return;
    int pairs = 0;
    if (type == LevelType.god) {
      if (level <= 20) {
        pairs = (arrows.length * 0.35).floor().clamp(2, 4);
      } else if (level <= 50) {
        pairs = (arrows.length * 0.45).floor().clamp(2, 6);
      } else {
        pairs = (arrows.length * 0.55).floor().clamp(3, 10);
      }
    } else if (type == LevelType.boss) {
      if (level <= 20) {
        pairs = (arrows.length * 0.25).floor().clamp(1, 3);
      } else if (level <= 50) {
        pairs = (arrows.length * 0.35).floor().clamp(1, 5);
      } else {
        pairs = (arrows.length * 0.45).floor().clamp(2, 8);
      }
    } else if (level == 2) {
      pairs = 1; // Exactly 1 pair for tutorial level 2
    } else {
      // Normal levels: scaling difficulty
      if (level < 15) {
        pairs = 0;
      } else if (level < 30) {
        pairs = (arrows.length * 0.08).floor().clamp(0, 1);
      } else if (level < 60) {
        pairs = (arrows.length * 0.12).floor().clamp(0, 2);
      } else if (level < 100) {
        pairs = (arrows.length * 0.16).floor().clamp(1, 3);
      } else {
        pairs = (arrows.length * 0.22).floor().clamp(1, 6);
      }
    }

    if (pairs == 0) return;

    // Build orphan dot map for exit simulation
    final orphanMap = <String, OrphanDotType>{};
    for (final od in orphanDots) {
      orphanMap[od.key] = od.type;
    }

    // Collect standard arrow indices that are in the inner side of the canvas (not on the border: edgeDistance > 0).
    var stdIndices = <int>[];
    for (int i = 0; i < arrows.length; i++) {
      if (arrows[i].mechanic == SnakeMechanic.standard) {
        final dist = _edgeDistance(arrows[i].row, arrows[i].col, gridSize);
        if (dist > 0) {
          stdIndices.add(i);
        }
      }
    }

    // If we have too few inner standard arrows (e.g., in small grids), fall back to all standard arrows
    if (stdIndices.length < pairs * 2) {
      stdIndices = <int>[];
      for (int i = 0; i < arrows.length; i++) {
        if (arrows[i].mechanic == SnakeMechanic.standard) {
          stdIndices.add(i);
        }
      }
    }

    // Shuffle standard arrow indices so that color pairs are scattered randomly
    // across the canvas instead of clustering together at the exact center.
    stdIndices.shuffle(rng);

    int actualPairs = 0;
    for (int i = 0; i < stdIndices.length && actualPairs < pairs; i++) {
      final li = stdIndices[i];
      if (arrows[li].mechanic != SnakeMechanic.standard) continue;

      for (int j = i + 1; j < stdIndices.length; j++) {
        final ki = stdIndices[j];
        if (arrows[ki].mechanic != SnakeMechanic.standard) continue;

        // Try assigning li as lock, ki as key
        final arrowLock = arrows[li];
        final arrowKey  = arrows[ki];

        // Key's exit path must not cross Lock's body cells.
        // We only check for mutual blocking (not blocked by unrelated arrows),
        // which allows inner arrows to be paired successfully instead of failing.
        final lockCells = arrowLock.path.map((p) => '${p[0]},${p[1]}').toSet();
        final keyClear = _simulateExitClear(arrowKey, gridSize, lockCells, orphanMap);

        // Lock's exit path must not cross Key's body cells
        final keyCells = arrowKey.path.map((p) => '${p[0]},${p[1]}').toSet();
        final lockClear = _simulateExitClear(arrowLock, gridSize, keyCells, orphanMap);

        if (keyClear && lockClear) {
          arrows[ki] = arrows[ki].copyWith(mechanic: SnakeMechanic.colorLock, colorGroup: actualPairs);
          arrows[li] = arrows[li].copyWith(mechanic: SnakeMechanic.colorLock, colorGroup: actualPairs);
          actualPairs++;
          break;
        }
      }
    }
  }

  /// Simulates whether an arrow can exit the grid (possibly through orphan dots).
  /// Returns true if the path reaches the grid edge, false if blocked.
  static bool _simulateExitClear(ArrowModel arrow, int gridSize,
      Set<String> occupied, Map<String, OrphanDotType> orphanDots) {
    final myPathSet = arrow.path.map((p) => '${p[0]},${p[1]}').toSet();
    ArrowDirection currentDir = arrow.direction;
    final head = arrow.path[0];
    var d = currentDir.delta;
    int nr = head[0] + d[0];
    int nc = head[1] + d[1];
    final visited = <String>{};

    while (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
      final key = '$nr,$nc';
      if (visited.contains(key)) return false; // infinite loop
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
      } else if (occupied.contains(key) && !myPathSet.contains(key)) {
        return false; // blocked
      }

      d = currentDir.delta;
      nr += d[0];
      nc += d[1];
    }
    return true; // reached edge
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

  static Set<int> _getExitPathPacked(int startRow, int startCol, ArrowDirection exitDir, int gridSize) {
    final path = <int>{};
    final d = exitDir.delta;
    int nr = startRow + d[0];
    int nc = startCol + d[1];
    while (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
      path.add(nr * 1000 + nc);
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
    required List<List<int>> maskCells,
    required Set<int> maskPacked,
    required Set<int> currentOccupiedPacked,
    required List<List<int>> newPath,
    required int gridSize,
  }) {
    final tempOccupied = Set<int>.from(currentOccupiedPacked);
    for (final pt in newPath) {
      tempOccupied.add(pt[0] * 1000 + pt[1]);
    }

    final rowsToCheck = newPath.map((pt) => pt[0]).toSet();
    final colsToCheck = newPath.map((pt) => pt[1]).toSet();
    final adjacentKeys = <int>{};
    for (final pt in newPath) {
      for (final offset in [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
        adjacentKeys.add((pt[0] + offset[0]) * 1000 + (pt[1] + offset[1]));
      }
    }

    int blocked = 0;
    for (final cell in maskCells) {
      final r = cell[0], c = cell[1];
      final packed = r * 1000 + c;
      if (tempOccupied.contains(packed)) continue;

      // Optimization: Only check empty cells near the new path
      final isNear = rowsToCheck.contains(r) || colsToCheck.contains(c) || adjacentKeys.contains(packed);
      if (!isNear) continue;

      // Check if this empty cell is isolated (0 empty neighbors)
      int emptyNeighbors = 0;
      for (final nb in [[-1,0],[1,0],[0,-1],[0,1]]) {
        final nr = r + nb[0];
        final nc = c + nb[1];
        final np = nr * 1000 + nc;
        if (maskPacked.contains(np) && !tempOccupied.contains(np)) {
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

        // The cell straight behind (r,c) must be inside the mask and empty
        final backRow = r - d[0];
        final backCol = c - d[1];
        final backPacked = backRow * 1000 + backCol;
        if (!maskPacked.contains(backPacked) || tempOccupied.contains(backPacked)) {
          continue;
        }

        int nr = r + d[0];
        int nc = c + d[1];
        bool pathClear = true;

        while (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
          if (tempOccupied.contains(nr * 1000 + nc)) {
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

  static void _absorbOrphans(List<ArrowModel> arrows, Set<String> occupied, Set<String> mask) {
    final orphans = mask.where((k) => !occupied.contains(k)).toList();
    for (final cellKey in orphans) {
      final parts = cellKey.split(',');
      final r = int.parse(parts[0]), c = int.parse(parts[1]);

      for (int i = 0; i < arrows.length; i++) {
        final arrow = arrows[i];
        final tail = arrow.path.last;
        final dist = (tail[0] - r).abs() + (tail[1] - c).abs();
        if (dist == 1) {
          // ── ANTI-CYCLE CHECK ──
          // Before absorbing, verify the new cell won't be adjacent to
          // any existing path cell other than the tail (which would create
          // a closed loop / square shape).
          bool wouldFormLoop = false;
          if (arrow.path.length >= 3) {
            for (final nb in [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
              final adjR = r + nb[0], adjC = c + nb[1];
              if (adjR == tail[0] && adjC == tail[1]) continue; // skip tail itself
              for (final pt in arrow.path) {
                if (pt[0] == adjR && pt[1] == adjC) {
                  wouldFormLoop = true;
                  break;
                }
              }
              if (wouldFormLoop) break;
            }
          }
          if (wouldFormLoop) continue;

          final newPath = List<List<int>>.from(arrow.path)..add([r, c]);
          arrows[i] = arrow.copyWith(path: newPath);
          occupied.add(cellKey);
          break;
        }
      }
    }
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
  final int blockedCount;
  _Cand(this.row, this.col, this.dir, {this.blockedCount = 0});
}

class _Params {
  final int arrowCount, avgLen;
  _Params(this.arrowCount, this.avgLen);
}
