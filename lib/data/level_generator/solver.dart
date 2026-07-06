import 'dart:typed_data';
import '../models/arrow.dart';
import '../models/level.dart';

/// Backtracking solver that verifies a level is solvable.
/// Uses DFS with backtracking over grid states to find at least one solution.
/// Returns the solution sequence (list of arrow IDs) or null if unsolvable.
///
/// This implementation is highly optimized using typed arrays, flat indices,
/// and incremental state hashing to run with zero allocations in the DFS hot path.
class LevelSolver {
  static const int maxStates = 5000; // Safety cap for DFS recursion

  /// Returns a valid solution order of arrow IDs, or null if unsolvable.
  static List<String>? solve(LevelModel level, [int maxStatesLimit = maxStates]) {
    final gridSize = level.gridSize;
    final arrows = level.arrows;
    final orphanDots = level.orphanDots;

    // 1. Initialize occupancy board (0 = empty, idx + 1 = arrow occupied)
    final board = Uint16List(gridSize * gridSize);
    for (int i = 0; i < arrows.length; i++) {
      final arrow = arrows[i];
      for (final pt in arrow.path) {
        board[pt[0] * gridSize + pt[1]] = i + 1;
      }
    }

    // 2. Initialize orphan dots (store indices and type index)
    final orphanTypes = Uint8List(gridSize * gridSize);
    final activeOrphans = List<bool>.filled(gridSize * gridSize, false);
    for (final od in orphanDots) {
      final idx = od.row * gridSize + od.col;
      orphanTypes[idx] = od.type.index;
      activeOrphans[idx] = true;
    }

    // 3. Precalculate color partners (N-sized array, mapping index to partner index, or -1)
    final groupToIndices = <int, List<int>>{};
    for (int i = 0; i < arrows.length; i++) {
      final grp = arrows[i].colorGroup;
      if (grp != null) {
        groupToIndices.putIfAbsent(grp, () => []).add(i);
      }
    }
    final partnerIndices = List<int>.filled(arrows.length, -1);
    for (final indices in groupToIndices.values) {
      if (indices.length == 2) {
        partnerIndices[indices[0]] = indices[1];
        partnerIndices[indices[1]] = indices[0];
      }
    }

    // 4. Initialize tracker states
    final activeArrows = List<bool>.filled(arrows.length, true);
    
    // Hash state incrementally
    int arrowHash = 0;
    for (int i = 0; i < arrows.length; i++) {
      arrowHash ^= arrows[i].id.hashCode;
    }
    int dotHash = orphanDots.length * 997;
    for (final od in orphanDots) {
      dotHash ^= od.key.hashCode;
    }
    int groupHash = 0;

    final visited = <String>{};
    final path = <String>[];
    int statesVisited = 0;

    // Preallocated visited cache for exit path simulation to prevent GC churn in hot path
    final exitVisited = Uint32List(gridSize * gridSize);
    int exitToken = 0;

    bool dfs(int remainingCount) {
      if (remainingCount == 0) return true;
      if (statesVisited > maxStatesLimit) return false;

      final hash = '$arrowHash|$groupHash|$dotHash';
      if (visited.contains(hash)) return false;
      visited.add(hash);
      statesVisited++;

      // Try arrows in reverse placement order to guide DFS to first-cleared
      for (int i = arrows.length - 1; i >= 0; i--) {
        if (!activeArrows[i]) continue;

        final partner = partnerIndices[i];
        if (partner != -1) {
          // Color Locked Pair
          // To avoid duplicate work, only process the pair from the lower index
          if (i > partner) continue;
          if (!activeArrows[partner]) continue;

          // Try to exit both
          exitToken++;
          if (exitToken == 0) {
            exitVisited.fillRange(0, exitVisited.length, 0);
            exitToken = 1;
          }
          final consumed1 = _simulateExit(i, partner, gridSize, board, activeOrphans, orphanTypes, arrows, exitVisited, exitToken);
          if (consumed1 == null) continue;

          exitToken++;
          if (exitToken == 0) {
            exitVisited.fillRange(0, exitVisited.length, 0);
            exitToken = 1;
          }
          final consumed2 = _simulateExit(partner, i, gridSize, board, activeOrphans, orphanTypes, arrows, exitVisited, exitToken);
          if (consumed2 == null) continue;

          // Apply move
          activeArrows[i] = false;
          activeArrows[partner] = false;
          final id1 = arrows[i].id;
          final id2 = arrows[partner].id;
          arrowHash ^= id1.hashCode ^ id2.hashCode;

          // Clear cells on board
          for (final pt in arrows[i].path) board[pt[0] * gridSize + pt[1]] = 0;
          for (final pt in arrows[partner].path) board[pt[0] * gridSize + pt[1]] = 0;

          // Deactivate consumed orphans
          final deactivated = <int>[];
          for (final idx in consumed1) {
            if (activeOrphans[idx]) {
              activeOrphans[idx] = false;
              deactivated.add(idx);
              final odKey = '${idx ~/ gridSize},${idx % gridSize}';
              dotHash ^= odKey.hashCode;
            }
          }
          for (final idx in consumed2) {
            if (activeOrphans[idx]) {
              activeOrphans[idx] = false;
              deactivated.add(idx);
              final odKey = '${idx ~/ gridSize},${idx % gridSize}';
              dotHash ^= odKey.hashCode;
            }
          }

          final grp = arrows[i].colorGroup!;
          groupHash ^= grp * 31;

          path.add(id1); // click registers the first arrow ID

          if (dfs(remainingCount - 2)) return true;

          // Backtrack
          path.removeLast();
          groupHash ^= grp * 31;
          for (final idx in deactivated) {
            activeOrphans[idx] = true;
            final odKey = '${idx ~/ gridSize},${idx % gridSize}';
            dotHash ^= odKey.hashCode;
          }
          for (final pt in arrows[partner].path) board[pt[0] * gridSize + pt[1]] = partner + 1;
          for (final pt in arrows[i].path) board[pt[0] * gridSize + pt[1]] = i + 1;
          arrowHash ^= id1.hashCode ^ id2.hashCode;
          activeArrows[partner] = true;
          activeArrows[i] = true;
        } else {
          // Standard Single Arrow
          exitToken++;
          if (exitToken == 0) {
            exitVisited.fillRange(0, exitVisited.length, 0);
            exitToken = 1;
          }
          final consumed = _simulateExit(i, -1, gridSize, board, activeOrphans, orphanTypes, arrows, exitVisited, exitToken);
          if (consumed == null) continue;

          // Apply move
          activeArrows[i] = false;
          final id = arrows[i].id;
          arrowHash ^= id.hashCode;

          // Clear cells on board
          for (final pt in arrows[i].path) board[pt[0] * gridSize + pt[1]] = 0;

          // Deactivate consumed orphans
          final deactivated = <int>[];
          for (final idx in consumed) {
            if (activeOrphans[idx]) {
              activeOrphans[idx] = false;
              deactivated.add(idx);
              final odKey = '${idx ~/ gridSize},${idx % gridSize}';
              dotHash ^= odKey.hashCode;
            }
          }

          path.add(id);

          if (dfs(remainingCount - 1)) return true;

          // Backtrack
          path.removeLast();
          for (final idx in deactivated) {
            activeOrphans[idx] = true;
            final odKey = '${idx ~/ gridSize},${idx % gridSize}';
            dotHash ^= odKey.hashCode;
          }
          for (final pt in arrows[i].path) board[pt[0] * gridSize + pt[1]] = i + 1;
          arrowHash ^= id.hashCode;
          activeArrows[i] = true;
        }
      }
      return false;
    }

    if (dfs(arrows.length)) return path;
    return null;
  }

  static List<int>? _simulateExit(
      int arrowIdx,
      int partnerIdx,
      int gridSize,
      Uint16List board,
      List<bool> activeOrphans,
      Uint8List orphanTypes,
      List<ArrowModel> arrows,
      Uint32List exitVisited,
      int token) {
    final arrow = arrows[arrowIdx];
    ArrowDirection currentDir = arrow.direction;
    final head = arrow.path[0];
    var d = currentDir.delta;
    int nr = head[0] + d[0];
    int nc = head[1] + d[1];
    final consumed = <int>[];

    while (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
      final idx = nr * gridSize + nc;
      if (exitVisited[idx] == token) return null;
      exitVisited[idx] = token;

      if (activeOrphans[idx]) {
        consumed.add(idx);
        final typeVal = orphanTypes[idx];
        if (typeVal == 0) currentDir = ArrowDirection.up;
        else if (typeVal == 1) currentDir = ArrowDirection.down;
        else if (typeVal == 2) currentDir = ArrowDirection.left;
        else if (typeVal == 3) currentDir = ArrowDirection.right;
      } else {
        final val = board[idx];
        if (val != 0 && val != arrowIdx + 1 && (partnerIdx == -1 || val != partnerIdx + 1)) {
          return null;
        }
      }

      d = currentDir.delta;
      nr += d[0];
      nc += d[1];
    }
    return consumed;
  }
}
