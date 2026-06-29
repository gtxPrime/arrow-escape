import 'package:flutter/foundation.dart';
import '../data/models/arrow.dart';
import '../data/models/level.dart';
import '../core/constants.dart';

/// Manages the current game state: lives, moves, arrows remaining.
class GameState extends ChangeNotifier {
  // ── Level ─────────────────────────────────────────────────────────────────────
  late LevelModel _currentLevel;
  late List<ArrowModel> _arrows;
  int _lives = AppConstants.maxLives;
  int _movesUsed = 0;
  int _livesLost = 0;
  bool _isComplete = false;
  bool _isGameOver = false;

  // Track which colorGroups have had their key cleared (unlocks colorLock snakes)
  final Set<int> _clearedColorGroups = {};

  // ── Callbacks ─────────────────────────────────────────────────────────────────
  final void Function() onLevelComplete;
  final void Function() onGameOver;
  final void Function() onLifeLost;

  GameState({
    required LevelModel level,
    required this.onLevelComplete,
    required this.onGameOver,
    required this.onLifeLost,
  }) {
    _currentLevel = level;
    _arrows = level.arrows.map((a) => a.copyWith()).toList();
  }

  // ── Getters ───────────────────────────────────────────────────────────────────
  List<ArrowModel> get arrows => List.unmodifiable(_arrows);
  int get lives => _lives;
  int get movesUsed => _movesUsed;
  int get livesLost => _livesLost;
  bool get isComplete => _isComplete;
  bool get isGameOver => _isGameOver;
  int get arrowsRemaining => _arrows.length;
  LevelModel get level => _currentLevel;

  // ── Tap Handler ───────────────────────────────────────────────────────────────

  /// Returns the outcome of tapping an arrow (snake).
  TapResult tapArrow(String arrowId) {
    if (_isComplete || _isGameOver) return TapResult.ignored;

    final index = _arrows.indexWhere((a) => a.id == arrowId);
    if (index == -1) return TapResult.ignored;

    final arrow = _arrows[index];
    if (arrow.state != ArrowState.idle && arrow.state != ArrowState.cracked) {
      return TapResult.ignored;
    }

    _movesUsed++;

    // ── Color group link logic: 2 arrows of the same color group exit together ──
    final grp = arrow.colorGroup;
    if (grp != null) {
      final groupArrows = _arrows.where((a) => a.colorGroup == grp).toList();
      if (groupArrows.length == 2) {
        final arrow1 = groupArrows[0];
        final arrow2 = groupArrows[1];

        // Check if either arrow is blocked.
        // Each arrow ignores the other's segments when checking paths.
        final blocked1 = _isHeadBlocked(arrow1, arrow2.id);
        final blocked2 = _isHeadBlocked(arrow2, arrow1.id);

        if (blocked1 || blocked2) {
          // Both are blocked / fail!
          return _handleGroupBlocked(grp, groupArrows);
        } else {
          // Both exit successfully!
          return _handleGroupExited(grp, groupArrows);
        }
      }
    }

    // ── Ice mechanic: first tap cracks, second tap clears ───────────────────
    if (arrow.mechanic == SnakeMechanic.iceSegment &&
        arrow.state == ArrowState.idle) {
      // Check if the head CAN move — only crack if it's not blocked
      if (_isHeadBlocked(arrow)) {
        return _handleBlocked(index, arrow, arrowId);
      }
      // First successful tap: crack
      _arrows[index] = arrow.copyWith(state: ArrowState.cracked);
      notifyListeners();
      return TapResult.cracked;
    }

    // ── Standard move check ────────────────────────────────────────────────
    if (_isHeadBlocked(arrow)) {
      return _handleBlocked(index, arrow, arrowId);
    }

    // ── Clear: arrow exits ───────────────────────────────────────────────────
    _arrows[index] = arrow.copyWith(state: ArrowState.sliding);
    notifyListeners();

    final exitDurationMs = 400 + arrow.path.length * 80;
    Future.delayed(Duration(milliseconds: exitDurationMs), () {
      _arrows.removeWhere((a) => a.id == arrowId);

      if (_arrows.isEmpty) {
        _isComplete = true;
        onLevelComplete();
      }
      notifyListeners();
    });

    return TapResult.exited;
  }

  TapResult _handleBlocked(int index, ArrowModel arrow, String arrowId) {
    _arrows[index] = arrow.copyWith(state: ArrowState.blocked);
    _lives--;
    _livesLost++;
    onLifeLost();

    // Reset arrow state after animation
    Future.delayed(AppConstants.arrowShakeDuration, () {
      final idx = _arrows.indexWhere((a) => a.id == arrowId);
      if (idx != -1) {
        _arrows[idx] = _arrows[idx].copyWith(state: ArrowState.idle);
        notifyListeners();
      }
    });

    if (_lives <= 0) {
      _isGameOver = true;
      onGameOver();
      notifyListeners();
      return TapResult.blocked;
    }

    notifyListeners();
    return TapResult.blocked;
  }

  TapResult _handleGroupBlocked(int grp, List<ArrowModel> groupArrows) {
    // Both arrows enter the blocked state, a life is lost.
    for (final arrow in groupArrows) {
      final index = _arrows.indexWhere((a) => a.id == arrow.id);
      if (index != -1) {
        _arrows[index] = arrow.copyWith(state: ArrowState.blocked);
      }
    }
    _lives--;
    _livesLost++;
    onLifeLost();

    // Reset both after animation
    Future.delayed(AppConstants.arrowShakeDuration, () {
      for (final arrow in groupArrows) {
        final idx = _arrows.indexWhere((a) => a.id == arrow.id);
        if (idx != -1) {
          _arrows[idx] = _arrows[idx].copyWith(state: ArrowState.idle);
        }
      }
      notifyListeners();
    });

    if (_lives <= 0) {
      _isGameOver = true;
      onGameOver();
    }
    notifyListeners();
    return TapResult.blocked;
  }

  TapResult _handleGroupExited(int grp, List<ArrowModel> groupArrows) {
    // Both slide out!
    for (final arrow in groupArrows) {
      final index = _arrows.indexWhere((a) => a.id == arrow.id);
      if (index != -1) {
        _arrows[index] = arrow.copyWith(state: ArrowState.sliding);
      }
    }
    notifyListeners();

    // Find the max path length between the two to determine total slide duration
    final maxLen = groupArrows.map((a) => a.path.length).reduce((a, b) => a > b ? a : b);
    final exitDurationMs = 400 + maxLen * 80;

    Future.delayed(Duration(milliseconds: exitDurationMs), () {
      for (final arrow in groupArrows) {
        _arrows.removeWhere((a) => a.id == arrow.id);
      }
      if (_arrows.isEmpty) {
        _isComplete = true;
        onLevelComplete();
      }
      notifyListeners();
    });

    return TapResult.exited;
  }

  /// Checks if any cell along the exit path of the head is occupied.
  /// Walks from the head's immediate next cell in its heading direction to the edge.
  /// Allows ignoring a specific arrow ID (e.g. for linked color group partner).
  bool _isHeadBlocked(ArrowModel arrow, [String? ignoreId]) {
    final delta = arrow.direction.delta;
    // path[0] = head (has the arrowhead)
    final head = arrow.path[0];
    final gridSize = _currentLevel.gridSize;

    int nr = head[0] + delta[0];
    int nc = head[1] + delta[1];

    // Walk all the way to the grid boundaries in the exit direction
    while (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
      // Check if this cell is occupied by any other active (non-sliding) arrow
      for (final other in _arrows) {
        if (other.id == arrow.id || (ignoreId != null && other.id == ignoreId)) continue;
        if (other.state == ArrowState.sliding) continue; // Mid-exit snakes don't block
        for (final pt in other.path) {
          if (pt[0] == nr && pt[1] == nc) {
            return true; // Path is blocked
          }
        }
      }
      nr += delta[0];
      nc += delta[1];
    }

    return false;
  }

  // ── Reset ─────────────────────────────────────────────────────────────────────

  void resetLevel() {
    _arrows = _currentLevel.arrows.map((a) => a.copyWith(state: ArrowState.idle)).toList();
    _lives = AppConstants.maxLives;
    _movesUsed = 0;
    _livesLost = 0;
    _isComplete = false;
    _isGameOver = false;
    _clearedColorGroups.clear();
    notifyListeners();
  }

  void restoreLife() {
    if (_lives < AppConstants.maxLives) {
      _lives++;
      if (_isGameOver && _lives > 0) {
        _isGameOver = false;
      }
      notifyListeners();
    }
  }
}

enum TapResult { exited, blocked, locked, cracked, ignored }
