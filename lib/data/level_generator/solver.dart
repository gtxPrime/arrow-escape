import '../models/arrow.dart';
import '../models/level.dart';

/// Backtracking solver that verifies a level is solvable.
/// Uses DFS with backtracking over grid states to find at least one solution.
/// Returns the solution sequence (list of arrow IDs) or null if unsolvable.
///
/// Blocking rule per spec: ONLY the head's immediate next cell matters.
/// If that cell is empty or outside the mask → the snake can clear.
/// The body always follows because each segment inherits the vacated cell
/// of the segment ahead of it — no further raycast needed.
class LevelSolver {
  static const int maxStates = 5000; // Safety cap for DFS recursion

  /// Returns a valid solution order of arrow IDs, or null if unsolvable.
  static List<String>? solve(LevelModel level,
      [int maxStatesLimit = maxStates]) {
    final initial = _GridState.fromLevel(level);
    final visited = <String>{};
    final path = <String>[];
    if (_dfs(initial, level.gridSize, visited, path, maxStatesLimit)) {
      return path;
    }
    return null;
  }

  static bool _dfs(_GridState state, int gridSize, Set<String> visited,
      List<String> path, int maxStatesLimit) {
    if (state.isEmpty) return true;
    if (visited.length > maxStatesLimit) return false;

    final hash = state.hash;
    if (visited.contains(hash)) return false;
    visited.add(hash);

    // Build occupied cells set once per state for O(1) lookup
    final occupied = <String>{};
    for (final a in state.arrows.values) {
      for (final pt in a.path) {
        occupied.add('${pt[0]},${pt[1]}');
      }
    }

    // Try all arrows in reverse placement order (heavily guides DFS to first-cleared)
    final arrowList = state.arrows.values.toList();
    for (int i = arrowList.length - 1; i >= 0; i--) {
      final arrow = arrowList[i];
      if (arrow.state == ArrowState.locked) continue;

      final result = _tryMove(state, arrow, gridSize, occupied);
      if (result == null) continue; // Blocked

      path.add(arrow.id);
      if (_dfs(result, gridSize, visited, path, maxStatesLimit)) {
        return true;
      }
      path.removeLast(); // Backtrack
    }

    return false;
  }

  /// Returns new state if arrow can clear, null if blocked.
  /// Simulates deflection through any orphan dots in the exit path.
  static _GridState? _tryMove(
      _GridState state, ArrowModel arrow, int gridSize, Set<String> occupied) {
    final grp = arrow.colorGroup;
    if (grp != null) {
      final groupArrows =
          state.arrows.values.where((a) => a.colorGroup == grp).toList();
      if (groupArrows.length == 2) {
        final arrow1 = groupArrows[0];
        final arrow2 = groupArrows[1];

        // Create occupied set excluding both arrows' cells so they don't block each other
        final occupiedWithoutGroup = Set<String>.from(occupied);
        for (final pt in arrow1.path)
          occupiedWithoutGroup.remove('${pt[0]},${pt[1]}');
        for (final pt in arrow2.path)
          occupiedWithoutGroup.remove('${pt[0]},${pt[1]}');

        final result1 = _simulateExit(
            arrow1, gridSize, occupiedWithoutGroup, state.orphanDots);
        final result2 = _simulateExit(
            arrow2, gridSize, occupiedWithoutGroup, state.orphanDots);

        if (result1 == null || result2 == null) return null;

        final newArrows = Map<String, ArrowModel>.from(state.arrows)
          ..remove(arrow1.id)
          ..remove(arrow2.id);

        final newClearedGroups = Set<int>.from(state.clearedColorGroups)
          ..add(grp);
        final newOrphanDots = Map<String, OrphanDotType>.from(state.orphanDots);
        for (final k in [...result1.consumed, ...result2.consumed]) {
          newOrphanDots.remove(k);
        }
        return _GridState(newArrows, newClearedGroups, newOrphanDots);
      }
    }

    // Standard single arrow
    final result = _simulateExit(arrow, gridSize, occupied, state.orphanDots);
    if (result == null) return null;

    final newArrows = Map<String, ArrowModel>.from(state.arrows)
      ..remove(arrow.id);
    final newOrphanDots = Map<String, OrphanDotType>.from(state.orphanDots);
    for (final k in result.consumed) newOrphanDots.remove(k);
    return _GridState(newArrows, state.clearedColorGroups, newOrphanDots);
  }

  /// Simulates the exit path for one arrow.
  /// Returns an [_ExitResult] (with consumed dot keys) on success, or null if blocked.
  static _ExitResult? _simulateExit(ArrowModel arrow, int gridSize,
      Set<String> occupied, Map<String, OrphanDotType> orphanDots) {
    final myPathSet = arrow.path.map((p) => '${p[0]},${p[1]}').toSet();
    ArrowDirection currentDir = arrow.direction;
    final head = arrow.path[0];
    var d = currentDir.delta;
    int nr = head[0] + d[0];
    int nc = head[1] + d[1];
    final consumed = <String>[];
    final visited = <String>{};

    while (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
      final key = '$nr,$nc';
      if (visited.contains(key)) return null; // infinite loop
      visited.add(key);

      if (orphanDots.containsKey(key)) {
        consumed.add(key);
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
        return null; // blocked by real arrow
      }

      d = currentDir.delta;
      nr += d[0];
      nc += d[1];
    }
    return _ExitResult(consumed);
  }

  static bool _isPathBlocked(
      ArrowModel arrow, int gridSize, Set<String> occupied) {
    final delta = arrow.direction.delta;
    final head = arrow.path[0];
    int nr = head[0] + delta[0];
    int nc = head[1] + delta[1];

    while (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
      if (occupied.contains('$nr,$nc')) {
        return true;
      }
      nr += delta[0];
      nc += delta[1];
    }
    return false;
  }
}

// ─── Internal state for DFS ───────────────────────────────────────────────────────────────

class _ExitResult {
  final List<String> consumed; // orphan dot keys consumed along exit path
  _ExitResult(this.consumed);
}

class _GridState {
  final Map<String, ArrowModel> arrows;
  final Set<int> clearedColorGroups;
  final Map<String, OrphanDotType> orphanDots;

  _GridState(this.arrows,
      [Set<int>? clearedColorGroups, Map<String, OrphanDotType>? orphanDots])
      : clearedColorGroups = clearedColorGroups ?? {},
        orphanDots = orphanDots ?? {};

  bool get isEmpty => arrows.isEmpty;

  /// Hash includes remaining orphan dots so states with different dots are distinct
  String get hash {
    final sortedIds = arrows.keys.toList()..sort();
    final groups = clearedColorGroups.toList()..sort();
    final dots = orphanDots.keys.toList()..sort();
    return '${sortedIds.join('|')};${groups.join(',')};${dots.join('+')}';
  }

  factory _GridState.fromLevel(LevelModel level) {
    final Map<String, ArrowModel> map = {};
    for (final arrow in level.arrows) {
      map[arrow.id] = arrow.copyWith(state: ArrowState.idle);
    }
    final orphanMap = {for (final od in level.orphanDots) od.key: od.type};
    return _GridState(map, {}, orphanMap);
  }
}

class _SearchNode {
  final _GridState state;
  final List<String> moves;
  _SearchNode(this.state, this.moves);
}
