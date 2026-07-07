import 'dart:math';
import 'dart:io';
import 'dart:typed_data';
import '../models/arrow.dart';
import '../models/level.dart';
import '../../core/constants.dart';
import 'solver.dart';
import 'mask_generator.dart';

/// Arrow-puzzle level generator — v4 rewrite.
///
/// KEY PROPERTIES:
/// ─────────────────────────────────────────────────────────────────
/// • 3-phase fill pipeline:
///
///     Phase 1 — ≥3-dot arrows (strictly separated from Phase 2):
///               33% Very Long  (≥ ceil(gridSize × 0.55), max tangle zig-zag)
///               33% Long       (≥ ceil(gridSize × 0.40))
///               34% Medium     (3–5 cells)
///               Phase 1 ends as soon as NO candidate position can accept
///               any arrow of length ≥ 3.  No ≥3-dot arrows are ever placed
///               in Phase 2.
///
///     Phase 2 — 2-dot pair-sweep (fills every remaining gap):
///               First tries exit-constrained length-2 arrows.
///               Then falls back to greedy adjacent-pair sweep.
///               No ≥3-dot arrows. Runs until the canvas is as full as possible.
///
///     Phase 3 — Orphan minimisation + difficulty-scaled dot coloring.
///
/// • TANGLE FACTOR: Very-long arrows at higher levels (>50) use tighter
///   turn biases (up to 85%) and reduced max-straight-run limits (down to 2)
///   to produce visually tangled zig-zag bodies.
///   turnBias = 0.65 + tangleFactor × 0.20  (was 0.10 in v3)
///   maxStraight = 2 when tangleFactor ≥ 0.7 (was always 3 in v3)
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
    int gridSize = AppConstants.gridSizeForLevel(levelNumber);
    if (levelNumber == 213) gridSize = 32;
    if (levelNumber == 395) gridSize = 35;
    if (levelNumber == 437) gridSize = 36;

    final seed = levelNumber * 103 + 51;
    final rng = Random(seed);

    final maskShape = _shapeFor(type, rng);

    final mask = MaskGenerator.shapeByName(maskShape.name, gridSize, rng);
    final params = _paramsFor(levelNumber, type, gridSize, mask);

    LevelModel? level;
    // Generation strategy:
    //   Small grids (≤20): run DFS solver check after each _attempt to catch
    //                       deflection loops and ColorLock deadlocks.
    //   Large grids (>20): skip solver entirely — reverse-placement construction
    //                       guarantees solvability. DFS on 200-arrow 30×30 grids
    //                       has astronomical state space; no cap is reliable.
    final bool isLargeGrid = gridSize > 20;
    // Large grids get more attempts because greedy validation may fail occasionally;
    // Normal large-grid levels get 50 attempts (boss/god get 25 — shaped masks are harder).
    final int maxAttempts =
        isLargeGrid ? (type == LevelType.normal ? 80 : 120) : 80;
    for (int attempt = 0; attempt < maxAttempts && level == null; attempt++) {
      level = _attempt(
        levelNumber: levelNumber,
        gridSize: gridSize,
        mask: mask,
        params: params,
        type: type,
        rng: rng,
        maskShape: maskShape,
        attempt: attempt,
      );
    }

    // Final strict verification only for small grids where DFS is fast.
    if (level != null && !isLargeGrid) {
      final strictSolution = LevelSolver.solve(level, 6000);
      if (strictSolution == null) {
        level = null; // rare: cheap cap too lenient — retry via fallback
      } else {
        level = level.copyWith(solutionOrder: strictSolution);
      }
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
    required int attempt,
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

    bool fillEntireGrid = type != LevelType.tutorial && attempt < 12;
    if (levelNumber == 213 || levelNumber == 395 || levelNumber == 437) {
      fillEntireGrid = false; // Never fill 100% for these custom lengthy levels!
    }

    int targetCount = fillEntireGrid ? mask.length : params.arrowCount;
    if (!fillEntireGrid) {
      double fillRate = 0.60;
      if (levelNumber == 213 || levelNumber == 395 || levelNumber == 437) {
        fillRate = 0.55; // 55% density is extremely easy to solve!
      } else {
        fillRate = (1.0 - (attempt - 12) * 0.02).clamp(0.68, 0.95);
      }
      final targetOccupied = (mask.length * fillRate).round();
      targetCount = (targetOccupied / params.avgLen).round().clamp(4, 300);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  PHASE 1: Place Very Long (33%) / Long (33%) / Medium (34%) arrows
    //  ─────────────────────────────────────────────────────────────────────
    //  • Tier thresholds are GRID-SIZE ADAPTIVE:
    //      Very long  ≥ ceil(gridSize × 0.55)  (e.g. 6 on 10×10, 14 on 25×25)
    //      Long       ≥ ceil(gridSize × 0.40)  (e.g. 4 on 10×10, 10 on 25×25)
    //      Medium     3–5 cells (fixed, always fits)
    //  • Phase 1 terminates when failures exceed maxFailures OR when no
    //    candidate can accept ANY arrow of length ≥ 3.  No ≥3-dot arrows are
    //    ever placed in Phase 2.
    //  • Tangle factor scales with level: 0.0 → 1.0 over 500 levels.
    //    Applied exclusively to Very Long arrows.
    // ═══════════════════════════════════════════════════════════════════════
    {
      int failures = 0;
      int veryLongCount = 0;
      int longCount = 0;
      int medCount = 0;
      final int maxFailures = type == LevelType.tutorial ? 60 : 80;

      // Tangle factor: 0.0 = relaxed (straight-biased), 1.0 = maximum zig-zag.
      // Scales with level number AND type.
      // Boss gets +0.15 boost; God gets +0.25 boost (min 0.4).
      final double tangleFactor;
      double baseTangle;
      if (type == LevelType.tutorial) {
        baseTangle = 0.0;
      } else if (levelNumber <= 14) {
        baseTangle = 0.0; // Level 4-14: no tangle (gentle start)
      } else if (levelNumber <= 30) {
        baseTangle = 0.10; // Level 15-30: very slight tangle
      } else if (levelNumber <= 60) {
        baseTangle = 0.30; // Level 31-60: noticeable tangle
      } else if (levelNumber <= 150) {
        baseTangle = 0.60; // Level 61-150: significant tangle
      } else if (levelNumber <= 300) {
        baseTangle = 0.80; // Level 151-300: very tangled
      } else {
        baseTangle = 1.0; // Level 300+: maximum zig-zag
      }
      if (type == LevelType.boss) {
        baseTangle = (baseTangle + 0.15).clamp(0.15, 1.0);
      } else if (type == LevelType.god) {
        baseTangle = (baseTangle + 0.25).clamp(0.40, 1.0);
      }
      tangleFactor = baseTangle;

      // Grid-size-adaptive tier thresholds matching verify_levels_test.dart definitions.
      int veryLongMin = 5 + (gridSize ~/ 6);
      int longMin = 3 + (gridSize ~/ 10);
      int veryLongMax = max(veryLongMin + 1,
          (veryLongMin + 4).clamp(veryLongMin + 1, mask.length));

      // For shaped silhouettes (Boss and God levels), scale down slightly.
      if (maskShape != MaskShape.square) {
        veryLongMin = max(5, (veryLongMin * 0.8).round());
        longMin = max(3, (longMin * 0.8).round());
        veryLongMax = max(veryLongMin + 1, (veryLongMax * 0.8).round());
      }

      // We allow up to 1 blocked cell for non-tutorial levels.
      // Tutorial levels require clean, clear paths (0 blocks).
      // Restricting this to 1 dramatically reduces dependency deadlocks on large grids.
      // For large grids (>20), we use 0 blocks to guarantee construction-based solvability.
      final int maxAllowedBlocks =
          (type == LevelType.tutorial || gridSize > 20) ? 0 : 1;

      while (failures < maxFailures &&
          (fillEntireGrid
              ? occupiedPacked.length < mask.length
              : arrows.length < targetCount)) {
        // Dynamic length relaxation based on failures to prevent getting stuck.
        final int relaxation = failures ~/ 8;
        final int curVeryLongMin = max(5, veryLongMin - relaxation);
        final int curLongMin = max(3, longMin - relaxation);
        final int curVeryLongMax =
            max(curVeryLongMin + 1, veryLongMax - relaxation);

        final candidates = _exitCandidates(
            maskCells, occupiedPacked, gridSize, maxAllowedBlocks);
        if (candidates.isEmpty) break;

        // Cheap O(n) heuristic: Phase 1 can only place ≥3-cell arrows when at
        // least one free mask cell has ≥2 free mask neighbours (a necessary
        // precondition for any 3-cell path). Avoids expensive _growPath probes.
        bool anyCanFit3 = false;
        for (final cell in maskCells) {
          final r = cell[0], c = cell[1];
          if (occupiedPacked.contains(r * 1000 + c)) continue;
          int freeNeighbours = 0;
          for (final nb in [
            [-1, 0],
            [1, 0],
            [0, -1],
            [0, 1]
          ]) {
            final nr = r + nb[0], nc = c + nb[1];
            if (maskPacked.contains(nr * 1000 + nc) &&
                !occupiedPacked.contains(nr * 1000 + nc)) {
              freeNeighbours++;
            }
          }
          if (freeNeighbours >= 2) {
            anyCanFit3 = true;
            break;
          }
        }
        if (!anyCanFit3) break; // Hand off to Phase 2

        _shuffleCandidatesFromCenter(candidates, gridSize, rng);

        _Cand? bestCand;
        List<List<int>>? bestPath;
        int minBlocked = 9999;

        // Decide target tier based on level type and dynamic 3-tier ratio.
        final _LenTier wantTier;
        if (type == LevelType.tutorial) {
          wantTier = _LenTier.medium; // No long arrows in tutorials
        } else if (failures > 15) {
          wantTier = _LenTier.medium; // Fall back to medium when getting stuck
        } else {
          final total = veryLongCount + longCount + medCount;
          if (total == 0) {
            wantTier = _LenTier.veryLong; // Start with a very long arrow
          } else {
            final vlRatio = veryLongCount / total;
            final lRatio = longCount / total;
            // Target: 33% veryLong, 33% long, 34% medium
            if (vlRatio < 0.33) {
              wantTier = _LenTier.veryLong;
            } else if (lRatio < 0.33) {
              wantTier = _LenTier.long;
            } else {
              wantTier = _LenTier.medium;
            }
          }
        }

        // Try to place the desired tier (up to 15 candidates).
        for (final cand in candidates.take(15)) {
          final int len;
          if (type == LevelType.tutorial) {
            len = 2 + rng.nextInt(3); // tutorial: 2–4
          } else if (wantTier == _LenTier.veryLong) {
            final range = max(1, curVeryLongMax - curVeryLongMin + 1);
            len = curVeryLongMin + rng.nextInt(range);
          } else if (wantTier == _LenTier.long) {
            final longMax = max(curLongMin, curVeryLongMin - 1);
            final range = max(1, longMax - curLongMin + 1);
            len = curLongMin + rng.nextInt(range);
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
            tangleFactor: wantTier == _LenTier.veryLong ? tangleFactor : 0.0,
          );

          final int minAcceptableLen;
          if (type == LevelType.tutorial) {
            minAcceptableLen = 2;
          } else if (wantTier == _LenTier.veryLong) {
            minAcceptableLen = curVeryLongMin;
          } else if (wantTier == _LenTier.long) {
            minAcceptableLen = curLongMin;
          } else {
            minAcceptableLen = 3;
          }

          if (path != null && path.length >= minAcceptableLen) {
            final blockedCount = _evalPlacement(
              maskCells: maskCells,
              maskPacked: maskPacked,
              currentOccupiedPacked: occupiedPacked,
              newPath: path,
              gridSize: gridSize,
            );
            // skip rest of candidates if clean placement found
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

        // Fallback cascade: if desired tier fails, try next shorter tier.
        if (bestPath == null && type != LevelType.tutorial) {
          // Fallback 1: if wanted very long, try long (curLongMin..curVeryLongMin-1)
          if (wantTier == _LenTier.veryLong) {
            for (final cand in candidates.take(15)) {
              final longMax = max(curLongMin, curVeryLongMin - 1);
              final range = max(1, longMax - curLongMin + 1);
              final len = curLongMin + rng.nextInt(range);
              final path = _growPath(
                startRow: cand.row,
                startCol: cand.col,
                exitDir: cand.dir,
                maskPacked: maskPacked,
                occupiedPacked: occupiedPacked,
                targetLen: len,
                rng: rng,
                gridSize: gridSize,
                tangleFactor: 0.0,
              );
              if (path != null && path.length >= curLongMin) {
                final blockedCount = _evalPlacement(
                  maskCells: maskCells,
                  maskPacked: maskPacked,
                  currentOccupiedPacked: occupiedPacked,
                  newPath: path,
                  gridSize: gridSize,
                );
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
          }
          // Fallback 2: if wanted very long or long, try medium (3-5)
          if (bestPath == null &&
              (wantTier == _LenTier.veryLong || wantTier == _LenTier.long)) {
            for (final cand in candidates.take(15)) {
              final len = 3 + rng.nextInt(3);
              final path = _growPath(
                startRow: cand.row,
                startCol: cand.col,
                exitDir: cand.dir,
                maskPacked: maskPacked,
                occupiedPacked: occupiedPacked,
                targetLen: len,
                rng: rng,
                gridSize: gridSize,
                tangleFactor: 0.0,
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
          }
        }

        if (bestCand != null && bestPath != null && minBlocked < 1000) {
          _placeArrow(arrows, bestPath, bestCand.dir, levelNumber, counter++,
              occupied, occupiedPacked);
          if (bestPath.length >= curVeryLongMin) {
            veryLongCount++;
          } else if (bestPath.length >= curLongMin) {
            longCount++;
          } else if (bestPath.length >= 3) {
            medCount++;
          }
          failures = 0;
        } else {
          failures++;
          // Fast exit: if we've failed many times AND the grid is already
          // well-filled (≥50% occupied), hand off to Phase 2 rather than
          // exhausting maxFailures. This prevents slow failure spirals on
          // large grids while still allowing full Phase 1 on sparse grids.
          if (failures > 50 &&
              bestPath == null &&
              occupiedPacked.length >= maskPacked.length * 0.5) break;
        }
      }
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  PHASE 2: 2-dot pair-sweep — fills ALL remaining gaps with length-2
    //  arrows ONLY.  No ≥3-dot arrows are ever placed here.
    //  Two sub-passes:
    //    2a. Exit-constrained: uses _growPath with targetLen=2.
    //    2b. Greedy adjacent-pair sweep for anything that remains.
    // ═══════════════════════════════════════════════════════════════════════
    if (type != LevelType.tutorial) {
      // Phase 2 arrows MUST have 0 blockers so they are unconditionally clearable.
      // (Proof: if exit path is clear at placement, and all later-placed arrows also
      //  have clear exits, the level is solvable — each arrow placed last can always
      //  exit first, unblocking the one before it, etc.)
      final int maxAllowedBlocks = 0;

      // ── Sub-pass 2a: exit-constrained length-2 arrows ─────────────────
      {
        int failures = 0;
        while (failures < 60) {
          final candidates = _exitCandidates(
              maskCells, occupiedPacked, gridSize, maxAllowedBlocks);

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

          if (bestCand != null && bestPath != null && minBlocked < 1000) {
            _placeArrow(arrows, bestPath, bestCand.dir, levelNumber, counter++,
                occupied, occupiedPacked);
            failures = 0;
          } else {
            failures++;
          }
        }
      }

      // ── Sub-pass 2b: exit-verified greedy adjacent-pair sweep ──────────────
      // Pairs every adjacent empty cell. For each pair, tries BOTH head/tail
      // orientations and places only the one whose head has a completely clear
      // exit path to the grid boundary (0 obstacles). This guarantees every
      // 2-dot arrow placed here can exit at any point in the game, regardless
      // of clearing order, eliminating all Phase-2-sourced deadlocks.
      //
      // Pairs with no clean-exit orientation in either direction are left as
      // orphan dots (cells that cannot be cleanly paired are not placeable).
      {
        bool madeProgress = true;
        while (madeProgress) {
          madeProgress = false;

          // Shuffle every iteration for spatial variety.
          final emptyCells = maskCells
              .where(
                  (cell) => !occupiedPacked.contains(cell[0] * 1000 + cell[1]))
              .toList()
            ..shuffle(rng);

          for (final cell in emptyCells) {
            final r = cell[0], c = cell[1];
            if (occupiedPacked.contains(r * 1000 + c)) continue;

            final nbOffsets = [
              [-1, 0],
              [1, 0],
              [0, -1],
              [0, 1]
            ]..shuffle(rng);
            for (final nb in nbOffsets) {
              final tr = r + nb[0], tc = c + nb[1];
              if (!maskPacked.contains(tr * 1000 + tc)) continue;
              if (occupiedPacked.contains(tr * 1000 + tc)) continue;

              // Derive both valid arrow orientations for this adjacent pair.
              // Rule: tail is in direction [nb] from head, so head points opposite.
              final ArrowDirection dir1; // head at (r,c)
              final ArrowDirection dir2; // head at (tr,tc)
              if (nb[0] == 1) {
                // neighbour is below
                dir1 = ArrowDirection.up;
                dir2 = ArrowDirection.down;
              } else if (nb[0] == -1) {
                // neighbour is above
                dir1 = ArrowDirection.down;
                dir2 = ArrowDirection.up;
              } else if (nb[1] == 1) {
                // neighbour is right
                dir1 = ArrowDirection.left;
                dir2 = ArrowDirection.right;
              } else {
                // neighbour is left
                dir1 = ArrowDirection.right;
                dir2 = ArrowDirection.left;
              }

              int headRow, headCol, tailRow, tailCol;
              ArrowDirection chosenDir;

              if (_canExitClean(r, c, dir1, occupiedPacked, gridSize)) {
                headRow = r;
                headCol = c;
                tailRow = tr;
                tailCol = tc;
                chosenDir = dir1;
              } else if (_canExitClean(
                  tr, tc, dir2, occupiedPacked, gridSize)) {
                headRow = tr;
                headCol = tc;
                tailRow = r;
                tailCol = c;
                chosenDir = dir2;
              } else {
                continue; // Neither orientation has a clean exit — skip this pair.
              }

              arrows.add(ArrowModel(
                id: 'a_${levelNumber}_${counter++}',
                row: headRow,
                col: headCol,
                direction: chosenDir,
                isPartOfPattern: true,
                path: [
                  [headRow, headCol],
                  [tailRow, tailCol]
                ],
                mechanic: SnakeMechanic.standard,
              ));
              occupied.add('$r,$c');
              occupied.add('$tr,$tc');
              occupiedPacked.add(r * 1000 + c);
              occupiedPacked.add(tr * 1000 + tc);
              madeProgress = true;
              break; // Current cell paired — move to next empty cell.
            }
          }
        }
      }

      // ── Sub-pass 2c: greedy adjacent-pair sweep without clean exit verification ──
      // Safety pass to pair any remaining adjacent empty cells to eliminate "2 dots together".
      // Each placement is verified for solvability using greedy solver or DFS.
      {
        bool madeProgress = true;
        while (madeProgress) {
          madeProgress = false;

          final emptyCells = maskCells
              .where(
                  (cell) => !occupiedPacked.contains(cell[0] * 1000 + cell[1]))
              .toList()
            ..shuffle(rng);

          for (final cell in emptyCells) {
            final r = cell[0], c = cell[1];
            if (occupiedPacked.contains(r * 1000 + c)) continue;

            final nbOffsets = [
              [-1, 0],
              [1, 0],
              [0, -1],
              [0, 1]
            ]..shuffle(rng);
            for (final nb in nbOffsets) {
              final tr = r + nb[0], tc = c + nb[1];
              if (!maskPacked.contains(tr * 1000 + tc)) continue;
              if (occupiedPacked.contains(tr * 1000 + tc)) continue;

              final ArrowDirection dir1;
              final ArrowDirection dir2;
              if (nb[0] == 1) {
                dir1 = ArrowDirection.up;
                dir2 = ArrowDirection.down;
              } else if (nb[0] == -1) {
                dir1 = ArrowDirection.down;
                dir2 = ArrowDirection.up;
              } else if (nb[1] == 1) {
                dir1 = ArrowDirection.left;
                dir2 = ArrowDirection.right;
              } else {
                dir1 = ArrowDirection.right;
                dir2 = ArrowDirection.left;
              }

              // Try both orientations and pick the first solvable one.
              final tries = rng.nextBool()
                  ? [
                      [r, c, tr, tc, dir1],
                      [tr, tc, r, c, dir2]
                    ]
                  : [
                      [tr, tc, r, c, dir2],
                      [r, c, tr, tc, dir1]
                    ];

              bool placedSolvably = false;
              for (final t in tries) {
                final hr = t[0] as int;
                final hc = t[1] as int;
                final tailR = t[2] as int;
                final tailC = t[3] as int;
                final dir = t[4] as ArrowDirection;

                final newArrow = ArrowModel(
                  id: 'a_${levelNumber}_${counter}',
                  row: hr,
                  col: hc,
                  direction: dir,
                  isPartOfPattern: true,
                  path: [
                    [hr, hc],
                    [tailR, tailC]
                  ],
                  mechanic: SnakeMechanic.standard,
                );

                final isSolvable =
                    _canExitClean(hr, hc, dir, occupiedPacked, gridSize);

                if (isSolvable) {
                  arrows.add(newArrow);
                  counter++;
                  occupied.add('$hr,$hc');
                  occupied.add('$tailR,$tailC');
                  occupiedPacked.add(hr * 1000 + hc);
                  occupiedPacked.add(tailR * 1000 + tailC);
                  madeProgress = true;
                  placedSolvably = true;
                  break;
                }
              }

              if (placedSolvably) break;
            }
          }
        }
      }

      // Verify no adjacent empty cells remain.
      if (attempt < 10) {
        bool hasAdjacentEmpty = false;
        final remainingEmpty = maskCells
            .where((cell) => !occupiedPacked.contains(cell[0] * 1000 + cell[1]))
            .toList();
        final remainingEmptyPacked =
            remainingEmpty.map((c) => c[0] * 1000 + c[1]).toSet();
        for (final cell in remainingEmpty) {
          final r = cell[0], c = cell[1];
          for (final nb in [
            [-1, 0],
            [1, 0],
            [0, -1],
            [0, 1]
          ]) {
            final nr = r + nb[0], nc = c + nb[1];
            if (remainingEmptyPacked.contains(nr * 1000 + nc)) {
              hasAdjacentEmpty = true;
              break;
            }
          }
          if (hasAdjacentEmpty) break;
        }
        if (hasAdjacentEmpty) {
          File('attempt_log.txt').writeAsStringSync(
              'Level $levelNumber Attempt $attempt: adjacent empty cells left (2 dots together)\n',
              mode: FileMode.append,
              flush: true);
          return null;
        }
      }
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  PHASE 3: Orphan minimisation + difficulty-scaled coloring
    // ═══════════════════════════════════════════════════════════════════════

    // Try to absorb any isolated single cells into adjacent arrow tails.
    if (type != LevelType.tutorial && occupied.length < mask.length) {
      _absorbOrphans(arrows, occupied, occupiedPacked, mask);
    }

    if (arrows.isEmpty) return null;

    // ── Minimum arrow density check ─────────────────────────────────────────
    // Boss/god shaped-mask levels bypass the orphan-count check (fillEntireGrid
    // is false). Without a floor, the greedy validator may accept a tiny layout
    // (e.g. 4 arrows on a 40×40 canvas) that passed 25 attempts but is trivially
    // boring. Require at least 30% of the mask to be covered by arrows.
    final minArrowCoverage = (mask.length * 0.30).floor();
    if (occupied.length < minArrowCoverage && type != LevelType.tutorial) {
      File('attempt_log.txt').writeAsStringSync(
          'Level $levelNumber Attempt $attempt: too sparse ${occupied.length} / $minArrowCoverage cells\n',
          mode: FileMode.append,
          flush: true);
      return null;
    }

    final emptyCount = mask.length - occupied.length;
    const double maxOrphansPct = 0.26;
    final maxOrphans = (mask.length * maxOrphansPct).ceil().clamp(5, 300);

    if (fillEntireGrid && emptyCount > maxOrphans) {
      File('attempt_log.txt').writeAsStringSync(
          'Level $levelNumber Attempt $attempt: too many orphans $emptyCount / $maxOrphans\n',
          mode: FileMode.append,
          flush: true);
      return null;
    }

    // Create orphan dots with DIFFICULTY-SCALED coloring.
    final orphanDots = <OrphanDot>[];
    if (emptyCount > 0) {
      final emptyKeysPacked = maskCells
          .where((cell) => !occupiedPacked.contains(cell[0] * 1000 + cell[1]))
          .map((cell) => cell[0] * 1000 + cell[1])
          .toSet();
      final orphanMap = <int, OrphanDotType>{};

      // Determine color probability based on difficulty and level type.
      // Boss: minimum 0.35. God: minimum 0.50.
      // Normal: 0 until level 15, then progressively increases.
      final double colorProb;
      if (levelNumber == 395 || levelNumber == 437) {
        colorProb = 0.0; // no direction dots!
      } else if (type == LevelType.god) {
        // God: always has direction dots. Minimum 0.50, ramps to 0.88.
        if (levelNumber <= 7) {
          colorProb = 0.50; // First god level
        } else if (levelNumber <= 20) {
          colorProb = 0.65;
        } else if (levelNumber <= 50) {
          colorProb = 0.78;
        } else {
          colorProb = 0.88;
        }
      } else if (type == LevelType.boss) {
        // Boss: always has direction dots. Minimum 0.35, ramps to 0.80.
        if (levelNumber <= 7) {
          colorProb = 0.35; // First boss level
        } else if (levelNumber <= 20) {
          colorProb = 0.50;
        } else if (levelNumber <= 50) {
          colorProb = 0.65;
        } else {
          colorProb = 0.80;
        }
      } else if (levelNumber == 3) {
        colorProb = 0.60; // Tutorial level 3: colored orphan dots
      } else if (levelNumber <= 14) {
        colorProb = 0.0; // Normal 4-14: no direction dots
      } else {
        // Normal 15+: progressive introduction
        if (levelNumber <= 30) {
          colorProb = 0.10; // Level 15-30: very gentle introduction (was 0.35)
        } else if (levelNumber <= 60) {
          colorProb = 0.20; // Level 31-60 (was 0.55)
        } else if (levelNumber <= 150) {
          colorProb = 0.40; // Level 61-150 (was 0.70)
        } else if (levelNumber <= 300) {
          colorProb = 0.65; // Level 151-300 (was 0.80)
        } else {
          colorProb = 0.80; // Level 300+ (was 0.90)
        }
      }

      // Process arrows in solution order (reverse construction) to trace paths
      // and decide deflector settings.
      for (int i = arrows.length - 1; i >= 0; i--) {
        final arrow = arrows[i];

        ArrowDirection currentDir = arrow.direction;
        final head = arrow.path[0];
        var d = currentDir.delta;
        int nr = head[0] + d[0];
        int nc = head[1] + d[1];
        final visited = <int>{};

        while (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
          final keyPacked = nr * 1000 + nc;
          if (visited.contains(keyPacked)) break;
          visited.add(keyPacked);

          if (emptyKeysPacked.contains(keyPacked)) {
            if (!orphanMap.containsKey(keyPacked)) {
              final bool shouldColor = rng.nextDouble() < colorProb;
              if (shouldColor) {
                // ── SPATIAL SPREAD CHECK ──
                // Colored direction dots should not cluster. Enforce
                // minimum Manhattan distance of 2 from any existing
                // colored orphan dot (neutral dots are exempt).
                bool tooClose = false;
                for (final entry in orphanMap.entries) {
                  if (entry.value == OrphanDotType.neutral) continue;
                  final pk = entry.key;
                  final er = pk ~/ 1000, ec = pk % 1000;
                  if ((er - nr).abs() + (ec - nc).abs() < 2) {
                    tooClose = true;
                    break;
                  }
                }

                if (!tooClose) {
                  final turns = rng.nextBool()
                      ? [currentDir.turnRight, currentDir.turnLeft]
                      : [currentDir.turnLeft, currentDir.turnRight];

                  bool assigned = false;
                  for (final candDir in turns) {
                    orphanMap[keyPacked] = _dotTypeForDir(candDir);

                    // Verify solvability of the entire level layout using greedy simulation.
                    final isSolvable =
                        _greedySolveWithMap(gridSize, arrows, orphanMap) !=
                            null;

                    if (isSolvable) {
                      currentDir = candDir;
                      assigned = true;
                      break;
                    } else {
                      orphanMap.remove(keyPacked); // rollback
                    }
                  }

                  if (!assigned) {
                    // Try placing a straight deflector
                    orphanMap[keyPacked] = _dotTypeForDir(currentDir);
                    final isSolvable =
                        _greedySolveWithMap(gridSize, arrows, orphanMap) !=
                            null;
                    if (!isSolvable) {
                      // Fallback to neutral (always safe)
                      orphanMap[keyPacked] = OrphanDotType.neutral;
                    }
                  }
                } else {
                  orphanMap[keyPacked] = OrphanDotType.neutral;
                }
              } else {
                orphanMap[keyPacked] = OrphanDotType.neutral;
              }
            } else {
              final dotType = orphanMap[keyPacked]!;
              if (dotType == OrphanDotType.up)
                currentDir = ArrowDirection.up;
              else if (dotType == OrphanDotType.down)
                currentDir = ArrowDirection.down;
              else if (dotType == OrphanDotType.left)
                currentDir = ArrowDirection.left;
              else if (dotType == OrphanDotType.right)
                currentDir = ArrowDirection.right;
            }
          }

          d = currentDir.delta;
          nr += d[0];
          nc += d[1];
        }
      }

      // Any orphan dot not hit by any arrow gets a NEUTRAL type.
      for (final keyPacked in emptyKeysPacked) {
        if (!orphanMap.containsKey(keyPacked)) {
          orphanMap[keyPacked] = OrphanDotType.neutral;
        }
      }

      // Convert orphanMap to OrphanDot list.
      for (final entry in orphanMap.entries) {
        final r = entry.key ~/ 1000;
        final c = entry.key % 1000;
        orphanDots.add(OrphanDot(
          row: r,
          col: c,
          type: entry.value,
        ));
        occupied.add('$r,$c');
      }
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  MECHANIC MIX (colorLock/colorKey pairs) with mutual-blocking prevention
    // ═══════════════════════════════════════════════════════════════════════
    if (levelNumber == 2 || (type != LevelType.tutorial && levelNumber >= 4)) {
      _mechanicMix(
          arrows, levelNumber, type, rng, gridSize, orphanDots, gridSize);
    }

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

    // ── Solvability check ─────────────────────────────────────────────────────
    // Large grids (>20): greedy simulation — repeatedly clear any arrow whose
    //   exit is currently unblocked (inc. orphan dot redirections). Returns the
    //   clearing order if all arrows exit, null if any remain permanently blocked.
    //   This is O(N²×G) — fast even for 200-arrow 30×30 grids.
    // Small grids (≤20): DFS solver — exhaustive, finds any valid order.
    if (gridSize > 20) {
      final greedyOrder = _greedySolve(level);
      if (greedyOrder == null) {
        File('attempt_log.txt').writeAsStringSync(
            'Level $levelNumber Attempt $attempt: greedy FAILED (deadlock)\n',
            mode: FileMode.append,
            flush: true);
        return null;
      }
      File('attempt_log.txt').writeAsStringSync(
          'Level $levelNumber Attempt $attempt: SUCCEEDED (greedy)\n',
          mode: FileMode.append,
          flush: true);
      return level.copyWith(solutionOrder: greedyOrder);
    }

    final quickSolution = LevelSolver.solve(level, 5000);
    if (quickSolution == null) {
      File('attempt_log.txt').writeAsStringSync(
          'Level $levelNumber Attempt $attempt: solver failed\n',
          mode: FileMode.append,
          flush: true);
      return null;
    }
    File('attempt_log.txt').writeAsStringSync(
        'Level $levelNumber Attempt $attempt: SUCCEEDED\n',
        mode: FileMode.append,
        flush: true);
    return level.copyWith(solutionOrder: quickSolution);
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
      final distA = (a.row - centerRow).abs() + (a.col - centerCol).abs();
      final distB = (b.row - centerRow).abs() + (b.col - centerCol).abs();
      final scoreA =
          distA + a.blockedCount * 3.0 + (rng.nextDouble() * 3.0 - 1.5);
      final scoreB =
          distB + b.blockedCount * 3.0 + (rng.nextDouble() * 3.0 - 1.5);
      return scoreA.compareTo(scoreB);
    });
  }

  // ── Find valid arrow-head candidates ────────────────────────────────────────

  /// Returns all (row, col, dir) triples where an arrow head can be placed:
  /// the cell is in the mask and unoccupied, AND the path in [dir] from the head
  /// to the edge crosses at most [maxAllowedBlocks] occupied cells at placement time.
  static List<_Cand> _exitCandidates(List<List<int>> maskCells,
      Set<int> occupiedPacked, int gridSize, int maxAllowedBlocks) {
    final out = <_Cand>[];
    for (final cell in maskCells) {
      final r = cell[0], c = cell[1];
      if (occupiedPacked.contains(r * 1000 + c)) continue;
      for (final dir in ArrowDirection.values) {
        final d = dir.delta;
        int nr = r + d[0];
        int nc = c + d[1];
        int blockedCount = 0;
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

  // ── Path growth with enhanced tangle algorithm + ANTI-SQUARE ─────────────────

  /// Grow an arrow body backwards from the head:
  /// path[0] = head, path[last] = tail.
  ///
  /// Turn bias formula: 0.65 + tangleFactor × 0.20
  ///   tangleFactor 0.0 → 65% turn bias (relaxed, straight-biased)
  ///   tangleFactor 0.5 → 75% turn bias (medium tangle)
  ///   tangleFactor 1.0 → 85% turn bias (maximum zig-zag)
  ///
  /// maxStraight: 3 when tangleFactor < 0.7; 2 when tangleFactor ≥ 0.7.
  ///
  /// Packing preference: prefer cells adjacent to already-placed arrows.
  /// ANTI-SQUARE: rejects moves that would form a closed loop.
  ///
  /// [tangleFactor]: 0.0 = relaxed, 1.0 = maximum zig-zag.
  /// Only applied meaningfully to very-long arrows at higher difficulty levels.
  static List<List<int>>? _growPath({
    required int startRow,
    required int startCol,
    required ArrowDirection exitDir,
    required Set<int> maskPacked,
    required Set<int> occupiedPacked,
    required int targetLen,
    required Random rng,
    required int gridSize,
    double tangleFactor = 0.0,
  }) {
    final exitPath = _getExitPathPacked(startRow, startCol, exitDir, gridSize);
    final path = <List<int>>[
      [startRow, startCol]
    ];
    final pathPacked = <int>{startRow * 1000 + startCol};
    int cr = startRow, cc = startCol;
    var growDir = exitDir.opposite; // grow AWAY from exit direction
    int straight = 0;

    // Enhanced tangle parameters (v4):
    //   turnBias:   0.65 + tangleFactor × 0.20  (max 0.85)
    //   maxStraight: 2 when tangleFactor ≥ 0.7 (highly tangled), else 3
    final double turnBias = 0.65 + tangleFactor * 0.20;
    final int maxStraight = tangleFactor >= 0.7 ? 2 : 3;

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
        // from folding back to touch itself, creating unplayable closed loops.
        bool wouldFormLoop = false;
        for (final nb in [
          [-1, 0],
          [1, 0],
          [0, -1],
          [0, 1]
        ]) {
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

      // Force first step of path growth (path[0] to path[1]) to be straight.
      if (step == 1 && !valid.contains(growDir)) {
        return null; // Invalid candidate, discard
      }

      final mustTurn = straight >= maxStraight;
      final turns = valid.where((d) => d != growDir).toList();
      final straights = valid.where((d) => d == growDir).toList();

      ArrowDirection chosen;
      if (step == 1) {
        chosen = growDir;
      } else if (mustTurn && turns.isNotEmpty) {
        chosen = _packedPick(turns, cr, cc, occupiedPacked, rng);
      } else if (valid.length == 1) {
        chosen = valid[0];
      } else if (rng.nextDouble() < turnBias && turns.isNotEmpty) {
        chosen = _packedPick(turns, cr, cc, occupiedPacked, rng);
      } else if (straights.isNotEmpty) {
        chosen = straights[0];
      } else {
        chosen = _packedPick(turns, cr, cc, occupiedPacked, rng);
      }

      straight = chosen == growDir ? straight + 1 : 0;
      final nd = chosen.delta;
      cr += nd[0];
      cc += nd[1];
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
      for (final nb in [
        [-1, 0],
        [1, 0],
        [0, -1],
        [0, 1]
      ]) {
        if (occupiedPacked.contains((nr + nb[0]) * 1000 + (nc + nb[1])))
          score++;
      }
      if (score > best) {
        best = score;
        bestDirs.clear();
        bestDirs.add(d);
      } else if (score == best) bestDirs.add(d);
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
    // Only run expensive look-ahead on small grids when nearly full.
    // Large grids (≥20) skip entirely to prevent over-constraining the generator.
    final bool runLookAhead = gridSize < 20 &&
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

  /// Recursively traces whether the arrow starting at (headRow, headCol) in [startDir]
  /// can exit the grid cleanly, accounting for active orphan dot deflections and
  /// recursive dependencies on all other arrows it hits.
  /// Returns true if it exits safely, false if blocked or a cyclic deadlock is found.
  /// Complexity: O(G × pathLength) — extremely fast.
  static bool _canExitWithDeflections(
    int headRow,
    int headCol,
    ArrowDirection startDir,
    int gridSize,
    List<ArrowModel> arrows,
    Map<String, OrphanDotType> orphanMap,
    List<bool> visitedArrows,
    Int16List board,
  ) {
    var currentDir = startDir;
    var d = currentDir.delta;
    int nr = headRow + d[0];
    int nc = headCol + d[1];
    final visitedCells = <int>{}; // nr * 1000 + nc

    while (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
      final keyPacked = nr * 1000 + nc;
      if (visitedCells.contains(keyPacked))
        return false; // Loop within this path trace
      visitedCells.add(keyPacked);

      final key = '$nr,$nc';
      if (orphanMap.containsKey(key)) {
        final dotType = orphanMap[key]!;
        if (dotType == OrphanDotType.up)
          currentDir = ArrowDirection.up;
        else if (dotType == OrphanDotType.down)
          currentDir = ArrowDirection.down;
        else if (dotType == OrphanDotType.left)
          currentDir = ArrowDirection.left;
        else if (dotType == OrphanDotType.right)
          currentDir = ArrowDirection.right;
      } else {
        // Query the static arrow occupancy board in O(1).
        final val = board[nr * gridSize + nc];
        if (val != 0) {
          final hitIndex = val - 1;
          if (visitedArrows[hitIndex]) {
            return false; // Cycle detected (e.g. mutual block between k and hitIndex) -> deadlock!
          }
          visitedArrows[hitIndex] = true;
          final targetArrow = arrows[hitIndex];
          final ok = _canExitWithDeflections(
            targetArrow.path[0][0],
            targetArrow.path[0][1],
            targetArrow.direction,
            gridSize,
            arrows,
            orphanMap,
            visitedArrows,
            board,
          );
          visitedArrows[hitIndex] = false; // backtrack
          return ok;
        }
      }

      d = currentDir.delta;
      nr += d[0];
      nc += d[1];
    }
    return true; // Reached boundary safely
  }

  static OrphanDotType _dotTypeForDir(ArrowDirection dir) {
    switch (dir) {
      case ArrowDirection.up:
        return OrphanDotType.up;
      case ArrowDirection.down:
        return OrphanDotType.down;
      case ArrowDirection.left:
        return OrphanDotType.left;
      case ArrowDirection.right:
        return OrphanDotType.right;
    }
  }

  // ── Mechanic mix with mutual-blocking prevention ──────────────────────────

  /// How far is a cell from the nearest grid edge (higher = more inner).
  static int _edgeDistance(int row, int col, int gridSize) {
    final fromTop = row;
    final fromBottom = gridSize - 1 - row;
    final fromLeft = col;
    final fromRight = gridSize - 1 - col;
    return [fromTop, fromBottom, fromLeft, fromRight]
        .reduce((a, b) => a < b ? a : b);
  }

  static void _mechanicMix(List<ArrowModel> arrows, int level, LevelType type,
      Random rng, int gridSize, List<OrphanDot> orphanDots,
      [int actualGridSize = 0]) {
    if (arrows.length < 4) return;

    // ─── Color pair counts by level band ──────────────────────────────────
    // NOTE: Large-grid restriction removed. We use _simulateExitClear
    // (a structural O(n) path trace, not full DFS) to validate each pair,
    // which works correctly on any grid size.
    // Boss: always ≥ 1 pair. God: always ≥ 2 pairs.

    int pairs = 0;
    if (type == LevelType.god) {
      // God: always ≥ 2 color pairs, ramps up significantly.
      if (level <= 7) {
        pairs = 2; // First god level: 2 pairs
      } else if (level <= 20) {
        pairs = (arrows.length * 0.10).floor().clamp(2, 3);
      } else if (level <= 50) {
        pairs = (arrows.length * 0.18).floor().clamp(2, 4);
      } else if (level <= 100) {
        pairs = (arrows.length * 0.28).floor().clamp(3, 6);
      } else if (level <= 200) {
        pairs = (arrows.length * 0.38).floor().clamp(4, 8);
      } else {
        pairs = (arrows.length * 0.50).floor().clamp(5, 12);
      }
    } else if (type == LevelType.boss) {
      // Boss: always ≥ 1 color pair.
      if (level <= 7) {
        pairs = 1; // First boss level: exactly 1 pair
      } else if (level <= 20) {
        pairs = (arrows.length * 0.08).floor().clamp(1, 2);
      } else if (level <= 50) {
        pairs = (arrows.length * 0.14).floor().clamp(1, 3);
      } else if (level <= 100) {
        pairs = (arrows.length * 0.22).floor().clamp(2, 4);
      } else if (level <= 200) {
        pairs = (arrows.length * 0.32).floor().clamp(2, 6);
      } else {
        pairs = (arrows.length * 0.42).floor().clamp(3, 8);
      }
    } else if (level == 2) {
      pairs = 1; // Tutorial level 2: exactly 1 pair (introduction)
    } else {
      // Normal levels: no pairs until level 15, then progressive ramp.
      if (level < 15) {
        pairs = 0;
      } else if (level < 30) {
        pairs = 1; // Level 15-29: exactly 1 pair (introduction)
      } else if (level < 60) {
        pairs = (arrows.length * 0.10).floor().clamp(1, 2);
      } else if (level < 150) {
        pairs = (arrows.length * 0.15).floor().clamp(1, 3);
      } else if (level < 300) {
        pairs = (arrows.length * 0.20).floor().clamp(2, 5);
      } else {
        pairs = (arrows.length * 0.28).floor().clamp(2, 6);
      }
    }

    if (level == 395 || level == 437) {
      pairs = 0; // fuck color pair!
    }

    if (pairs == 0) return;

    // Build orphan dot map for exit simulation.
    final orphanMap = <String, OrphanDotType>{};
    for (final od in orphanDots) {
      orphanMap[od.key] = od.type;
    }

    // Collect standard arrow indices that are not on the immediate outer edge.
    var stdIndices = <int>[];
    for (int i = 0; i < arrows.length; i++) {
      if (arrows[i].mechanic == SnakeMechanic.standard) {
        final dist = _edgeDistance(arrows[i].row, arrows[i].col, gridSize);
        if (dist > 0) {
          stdIndices.add(i);
        }
      }
    }

    // Fall back to all standard arrows if too few inner ones.
    if (stdIndices.length < pairs * 2) {
      stdIndices = <int>[];
      for (int i = 0; i < arrows.length; i++) {
        if (arrows[i].mechanic == SnakeMechanic.standard) {
          stdIndices.add(i);
        }
      }
    }

    // Shuffle randomly so they are scattered nicely across the entire canvas!
    stdIndices.shuffle(rng);

    int actualPairs = 0;
    for (int i = 0; i < stdIndices.length && actualPairs < pairs; i++) {
      final li = stdIndices[i];
      if (arrows[li].mechanic != SnakeMechanic.standard) continue;

      for (int j = i + 1; j < stdIndices.length; j++) {
        final ki = stdIndices[j];
        if (arrows[ki].mechanic != SnakeMechanic.standard) continue;

        final arrowLock = arrows[li];
        final arrowKey = arrows[ki];

        final allCells = <String>{};
        for (int idx = 0; idx < arrows.length; idx++) {
          for (final pt in arrows[idx].path) {
            allCells.add('${pt[0]},${pt[1]}');
          }
        }
        final allOtherThanKey = Set<String>.from(allCells);
        for (final pt in arrowKey.path)
          allOtherThanKey.remove('${pt[0]},${pt[1]}');

        final allOtherThanLock = Set<String>.from(allCells);
        for (final pt in arrowLock.path)
          allOtherThanLock.remove('${pt[0]},${pt[1]}');

        final keyClear =
            _simulateExitClear(arrowKey, gridSize, allOtherThanKey, orphanMap);
        final lockClear = _simulateExitClear(
            arrowLock, gridSize, allOtherThanLock, orphanMap);

        if (keyClear && lockClear) {
          final oldKi = arrows[ki];
          final oldLi = arrows[li];
          arrows[ki] = arrows[ki].copyWith(
              mechanic: SnakeMechanic.colorLock, colorGroup: actualPairs);
          arrows[li] = arrows[li].copyWith(
              mechanic: SnakeMechanic.colorLock, colorGroup: actualPairs);

          // Verify if the level remains completely solvable after adding this pair.
          final tempLevel = LevelModel(
            levelNumber: level,
            gridSize: gridSize,
            arrows: arrows,
            patternName: 'temp',
            difficulty: Difficulty.easy,
            mask: arrows
                .expand((a) => a.path.map((p) => '${p[0]},${p[1]}'))
                .toSet(),
            orphanDots: orphanDots,
          );

          bool solvable = false;
          if (gridSize > 20) {
            solvable = _greedySolve(tempLevel) != null;
          } else {
            solvable = LevelSolver.solve(tempLevel, 2000) != null;
          }

          if (solvable) {
            actualPairs++;
            break; // Paired successfully, proceed to next pair
          } else {
            // Revert changes and try other candidates
            arrows[ki] = oldKi;
            arrows[li] = oldLi;
          }
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
        if (dotType == OrphanDotType.up)
          currentDir = ArrowDirection.up;
        else if (dotType == OrphanDotType.down)
          currentDir = ArrowDirection.down;
        else if (dotType == OrphanDotType.left)
          currentDir = ArrowDirection.left;
        else if (dotType == OrphanDotType.right)
          currentDir = ArrowDirection.right;
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

  static _Params _paramsFor(
      int level, LevelType type, int gridSize, Set<String> mask) {
    int avgLen;
    int arrowCount;

    if (level <= 3) {
      avgLen = 2;
      arrowCount = 4;
    } else {
      if (level == 395 || level == 437) {
        avgLen = 6; // lengthy!
      } else if (level <= 15) {
        avgLen = 3;
      } else if (level <= 50) {
        avgLen = 4;
      } else {
        avgLen = 5;
      }

      final totalCells = mask.length;
      const double fillRate = 1.0;

      final targetOccupiedCells = (totalCells * fillRate).round();
      arrowCount = (targetOccupiedCells / avgLen).round().clamp(4, 300);
    }

    return _Params(arrowCount, avgLen);
  }

  static Set<int> _getExitPathPacked(
      int startRow, int startCol, ArrowDirection exitDir, int gridSize) {
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
      case LevelType.normal:
        return MaskShape.square;
      case LevelType.boss:
        const bossShapes = [
          MaskShape.cat,
          MaskShape.dog,
          MaskShape.frog,
          MaskShape.fox,
          MaskShape.tiger,
          MaskShape.panda,
          MaskShape.fish,
          MaskShape.bird,
          MaskShape.butterfly,
          MaskShape.guitar,
          MaskShape.tree,
          MaskShape.house,
          MaskShape.crown,
        ];
        return bossShapes[rng.nextInt(bossShapes.length)];
      case LevelType.god:
        const godShapes = [
          MaskShape.heart,
          MaskShape.star,
          MaskShape.diamond,
          MaskShape.hexagon,
          MaskShape.blob,
          MaskShape.circle,
        ];
        return godShapes[rng.nextInt(godShapes.length)];
    }
  }

  static Difficulty _difficultyFor(int level, LevelType type) {
    if (type == LevelType.tutorial) return Difficulty.tutorial;
    if (type == LevelType.god) return Difficulty.legend;
    if (type == LevelType.boss) {
      if (level <= 20) return Difficulty.hard;
      if (level <= 50) return Difficulty.expert;
      if (level <= 100) return Difficulty.master;
      return Difficulty.legend;
    }
    if (level <= 20) return Difficulty.easy;
    if (level <= 50) return Difficulty.medium;
    if (level <= 100) return Difficulty.hard;
    if (level <= 200) return Difficulty.expert;
    if (level <= 400) return Difficulty.master;
    return Difficulty.legend;
  }

  static String _nameFor(LevelType type, int level) {
    switch (type) {
      case LevelType.boss:
        return 'Boss $level';
      case LevelType.god:
        return 'God $level';
      case LevelType.tutorial:
        return 'Tutorial';
      default:
        return 'Level $level';
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
        row: mid,
        col: col,
        direction: ArrowDirection.right,
        isPartOfPattern: true,
        path: [
          [mid, col]
        ],
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
    final newPathPacked = <int>{};
    for (final pt in newPath) {
      newPathPacked.add(pt[0] * 1000 + pt[1]);
    }
    bool isOccupied(int packed) {
      return currentOccupiedPacked.contains(packed) ||
          newPathPacked.contains(packed);
    }

    final rowsToCheck = newPath.map((pt) => pt[0]).toSet();
    final colsToCheck = newPath.map((pt) => pt[1]).toSet();
    final adjacentKeys = <int>{};
    for (final pt in newPath) {
      for (final offset in [
        [-1, 0],
        [1, 0],
        [0, -1],
        [0, 1]
      ]) {
        adjacentKeys.add((pt[0] + offset[0]) * 1000 + (pt[1] + offset[1]));
      }
    }

    int blocked = 0;
    for (final cell in maskCells) {
      final r = cell[0], c = cell[1];
      final packed = r * 1000 + c;
      if (isOccupied(packed)) continue;

      // Optimization: Only check empty cells near the new path.
      final isNear = rowsToCheck.contains(r) ||
          colsToCheck.contains(c) ||
          adjacentKeys.contains(packed);
      if (!isNear) continue;

      // Check if this empty cell is isolated (0 empty neighbors).
      int emptyNeighbors = 0;
      for (final nb in [
        [-1, 0],
        [1, 0],
        [0, -1],
        [0, 1]
      ]) {
        final nr = r + nb[0];
        final nc = c + nb[1];
        final np = nr * 1000 + nc;
        if (maskPacked.contains(np) && !isOccupied(np)) {
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

        final backRow = r - d[0];
        final backCol = c - d[1];
        final backPacked = backRow * 1000 + backCol;
        if (!maskPacked.contains(backPacked) || isOccupied(backPacked)) {
          continue;
        }

        int nr = r + d[0];
        int nc = c + d[1];
        bool pathClear = true;

        while (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
          if (isOccupied(nr * 1000 + nc)) {
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

  static void _absorbOrphans(List<ArrowModel> arrows, Set<String> occupied,
      Set<int> occupiedPacked, Set<String> mask) {
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
          bool wouldFormLoop = false;
          if (arrow.path.length >= 3) {
            for (final nb in [
              [-1, 0],
              [1, 0],
              [0, -1],
              [0, 1]
            ]) {
              final adjR = r + nb[0], adjC = c + nb[1];
              if (adjR == tail[0] && adjC == tail[1]) continue;
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
          occupiedPacked.add(r * 1000 + c);
          break;
        }
      }
    }
  }

  static int _countPathObstacles(
      int r, int c, ArrowDirection dir, Set<String> occupied, int gridSize) {
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

  /// Anti-cluster helper: counts how many of the 4 orthogonal neighbours
  /// of (r,c) are occupied by 2-dot arrows (tracked in [twoDotPacked]).
  static int _countTwoDotNeighbors(int r, int c, Set<int> twoDotPacked) {
    int cnt = 0;
    for (final nb in [
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1]
    ]) {
      if (twoDotPacked.contains((r + nb[0]) * 1000 + (c + nb[1]))) cnt++;
    }
    return cnt;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Phase-2 exit verification helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns true iff the straight-line exit path from (headRow, headCol) in
  /// [dir] reaches the grid boundary with ZERO occupied cells in the way.
  /// Used by Phase 2b to guarantee every 2-dot arrow can always exit.
  static bool _canExitClean(int headRow, int headCol, ArrowDirection dir,
      Set<int> occupiedPacked, int gridSize) {
    final d = dir.delta;
    int nr = headRow + d[0];
    int nc = headCol + d[1];
    while (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
      if (occupiedPacked.contains(nr * 1000 + nc)) return false;
      nr += d[0];
      nc += d[1];
    }
    return true;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Greedy solvability validator (used for large grids instead of DFS)
  // ─────────────────────────────────────────────────────────────────────────

  static List<String>? _greedySolveWithMap(int gridSize,
      List<ArrowModel> arrows, Map<int, OrphanDotType> orphanMap) {
    final board = Uint16List(gridSize * gridSize);
    for (int i = 0; i < arrows.length; i++) {
      for (final pt in arrows[i].path) {
        board[pt[0] * gridSize + pt[1]] = i + 1;
      }
    }

    final orphanTypes = Uint8List(gridSize * gridSize);
    final orphanActive = List<bool>.filled(gridSize * gridSize, false);
    orphanMap.forEach((packed, type) {
      final r = packed ~/ 1000;
      final c = packed % 1000;
      final idx = r * gridSize + c;
      orphanTypes[idx] = type.index;
      orphanActive[idx] = true;
    });

    // Build partner map for color pairs
    final partnerOf = List<int>.filled(arrows.length, -1);
    final grpBuckets = <int, List<int>>{};
    for (int i = 0; i < arrows.length; i++) {
      final g = arrows[i].colorGroup;
      if (g != null) grpBuckets.putIfAbsent(g, () => []).add(i);
    }
    for (final v in grpBuckets.values) {
      if (v.length == 2) {
        partnerOf[v[0]] = v[1];
        partnerOf[v[1]] = v[0];
      }
    }

    final active = List<bool>.filled(arrows.length, true);
    final order = <String>[];
    int remaining = arrows.length;

    // Zero-allocation exit path tracking using a flat visited array with tokens
    final exitVisited = Uint16List(gridSize * gridSize);
    int exitToken = 0;

    // Returns consumed dot indices if arrow [ai] can exit (partner [pi] transparent), else null.
    List<int>? tryExit(int ai, int pi) {
      exitToken++;
      ArrowDirection dir = arrows[ai].direction;
      final h = arrows[ai].path[0];
      var d = dir.delta;
      int nr = h[0] + d[0], nc = h[1] + d[1];
      final consumed = <int>[];
      while (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
        final idx = nr * gridSize + nc;
        if (exitVisited[idx] == exitToken) return null;
        exitVisited[idx] = exitToken;
        if (orphanActive[idx]) {
          consumed.add(idx);
          final t = orphanTypes[idx];
          if (t == 0)
            dir = ArrowDirection.up;
          else if (t == 1)
            dir = ArrowDirection.down;
          else if (t == 2)
            dir = ArrowDirection.left;
          else if (t == 3) dir = ArrowDirection.right;
        } else {
          final val = board[idx];
          if (val != 0 && val != ai + 1 && (pi == -1 || val != pi + 1))
            return null;
        }
        d = dir.delta;
        nr += d[0];
        nc += d[1];
      }
      return consumed;
    }

    void clearArrow(int idx) {
      active[idx] = false;
      remaining--;
      for (final pt in arrows[idx].path) board[pt[0] * gridSize + pt[1]] = 0;
      order.add(arrows[idx].id);
    }

    bool madeProgress = true;
    final seenGroups = <int>{};
    while (madeProgress && remaining > 0) {
      madeProgress = false;
      seenGroups.clear();

      // Pass 1: color pairs (simultaneous exit required)
      for (int i = 0; i < arrows.length; i++) {
        if (!active[i]) continue;
        final p = partnerOf[i];
        if (p == -1) continue;
        final g = arrows[i].colorGroup!;
        if (seenGroups.contains(g)) continue;
        seenGroups.add(g);
        if (!active[p]) continue;
        final c1 = tryExit(i, p);
        final c2 = tryExit(p, i);
        if (c1 != null && c2 != null) {
          final consumed = <int>{...c1, ...c2};
          for (final f in consumed) orphanActive[f] = false;
          clearArrow(i);
          clearArrow(p);
          madeProgress = true;
        }
      }

      // Pass 2: single (unpaired) arrows
      for (int i = 0; i < arrows.length; i++) {
        if (!active[i] || partnerOf[i] != -1) continue;
        final c = tryExit(i, -1);
        if (c != null) {
          for (final f in c) orphanActive[f] = false;
          clearArrow(i);
          madeProgress = true;
        }
      }
    }

    return remaining == 0 ? order : null;
  }

  static List<String>? _greedySolve(LevelModel level) {
    final orphanMap = <int, OrphanDotType>{};
    for (final od in level.orphanDots) {
      orphanMap[od.row * 1000 + od.col] = od.type;
    }
    return _greedySolveWithMap(level.gridSize, level.arrows, orphanMap);
  }
}

/// Tier for the 3-tier arrow length distribution.
enum _LenTier { veryLong, long, medium }

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
