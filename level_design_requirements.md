# Arrow Escape - Level Design & Generation Requirements

This document outlines the level design specifications, constraints, and generator algorithms used to generate and verify the 500 levels in Arrow Escape.

---

## 1. Core Level Types & Characteristics

Arrow Escape features three distinct level categories:

*   **Normal Levels**: Progressive difficulty scaling. Introduces mechanics gently (straight paths first, then tangling, then direction changes, and finally color key/lock pairs).
*   **Boss Levels (cycle-based)**: High density, larger grid sizes, and complex tangling. Always contain direction-change dots and color lock pairs.
*   **God Levels (cycle-based)**: Maximum difficulty, largest canvas size, high arrow density, complex zig-zag paths. Always contain direction-change dots and color lock pairs.
*   **Tutorial Levels (Levels 1-3)**: Small grid sizes (10x10) with fixed guided tasks to teach players the game mechanics.

---

## 2. Grid Size Scaling Specification

To ensure a smooth transition from beginner to advanced play, grid sizes scale dynamically as a function of the level number and cycle count, capped at a target playability limit of **35x35** (with a hard engine cap of 40x40):

| Category | Starting Size | Target Cap | Scaling Progression |
| :--- | :---: | :---: | :--- |
| **Tutorial** | 10x10 | 10x10 | Fixed at 10x10 |
| **Normal** | 15x15 (L4) | 35x35 (L500) | 15x15 to 24x24 (L4-19), 25x25 (L20) to 35x35 (L500). |
| **Boss** | 27x27 | 40x40 | Scales from 27x27 up to 40x40 over 20 boss cycles. |
| **God** | 27x27 | 40x40 | Scales from 27x27 up to 40x40 over 20 god cycles. |


*Implemented in: `AppConstants.gridSizeForLevel(level)`.*

---

## 3. Path Tangling Progression (Phase 1)

The **Tangle Factor** ranges from `0.0` (relaxed, straight-biased paths) to `1.0` (maximum zig-zag, complex turning paths). It scales progressively to prevent early game frustration:

*   **Level 1–14**: `0.0` (no turns or zig-zags; straight paths only)
*   **Level 15–30**: `0.1` (slight turning allowed)
*   **Level 31–60**: `0.3` (noticeable path tangling)
*   **Level 61–150**: `0.6` (significant zig-zag paths)
*   **Level 151–300**: `0.8` (highly tangled path structures)
*   **Level 300+**: `1.0` (maximum turn complexity)

### Special Adjustments
*   **Boss Levels**: Base Tangle + `0.15` (clamped to max `1.0`)
*   **God Levels**: Base Tangle + `0.25` (minimum of `0.40`, clamped to max `1.0`)

---

## 4. Direction-Changing (Orphan) Dots (Phase 3)

Orphan dots are empty grid spots not occupied by arrow bodies. 
As level complexity increases, a fraction of these dots act as **direction deflectors** (color-coded, forcing arrows to turn), while the remaining dots remain **neutral** (purely cosmetic, arrows slide straight through).

### Deflector Color Probability (`colorProb`)
*   **Level 1-3 (Tutorials)**: Special cases (Level 3 has 60% probability for tutorial instruction).
*   **Level 4-14**: `0.0` (no direction-change dots; all neutral).
*   **Level 15-30**: `0.15` (gentle introduction of direction changes).
*   **Level 31-60**: `0.30`.
*   **Level 61-150**: `0.50`.
*   **Level 151-300**: `0.65`.
*   **Level 300+**: `0.80`.
*   **Boss Levels**: Ramps from `0.25` (first cycle) to `0.80` (high cycles).
*   **God Levels**: Ramps from `0.40` (first cycle) to `0.90` (high cycles).

### Spatial Spacing Requirement
To prevent visual clustering and guarantee solving clarity, **colored deflectors must maintain a Manhattan distance of at least 2** from one another. Deflectors that are too close are automatically degraded to neutral dots.

---

## 5. Color Key & Lock Pairs (Mechanics Mix)

Mechanic pairs consist of a Color Key arrow and a Color Lock arrow. The locked arrow cannot move until the key arrow is cleared from the board.

### Pair Count Scaling
*   **Tutorial 1**: 0 pairs.
*   **Tutorial 2**: Exactly 1 pair.
*   **Tutorial 3**: 0 pairs.
*   **Normal Levels < 15**: 0 pairs.
*   **Normal Levels 15-29**: Exactly 1 pair.
*   **Normal Levels 30-59**: 1 to 2 pairs (up to 10% of arrows).
*   **Normal Levels 60-149**: 1 to 3 pairs (up to 15% of arrows).
*   **Normal Levels 150-299**: 2 to 5 pairs (up to 20% of arrows).
*   **Normal Levels 300+**: 2 to 6 pairs (up to 28% of arrows).
*   **Boss Levels**: Always at least 1 pair, scales up to 8 pairs.
*   **God Levels**: Always at least 2 pairs, scales up to 12 pairs.

### O(N) Exit Simulation Check (Replacing DFS for Large Grids)
On larger grids (size > 20), full depth-first search (DFS) verification is too slow. Instead, the generator uses a fast, structural path-tracing exit simulation (`_simulateExitClear`) to ensure that:
1.  Neither the key arrow nor the lock arrow creates a cyclic block.
2.  Both arrows have a valid clearance path to exit the grid once their corresponding pair is resolved.
This enables verification of color pairs on any grid size without exponential execution time.

---

## 6. Level Verification Pipeline

Levels are verified and cached in a chunked manner using a automated PowerShell & Flutter test pipeline:

1.  **Parallel Execution**: Running `.\run_verify.ps1` spawns 5 separate `flutter test` runners for chunks `1-100`, `101-200`, `201-300`, `301-400`, and `401-500`.
2.  **State Caching**: Verified passing levels are written along with their full `LevelModel` JSON representation to chunk-specific files `verify_progress_chunk_N.json`.
3.  **Selective Re-generation**: Re-running verification skips all already-passing levels, focusing compute resources only on fixing/verifying failed levels.
4.  **Binary Compilation**: Run `flutter test test/build_levels_bin_test.dart` to merge all 5 chunk caches and encode them into the production asset `assets/levels.bin`.
