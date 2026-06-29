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

  // Live orphan dot map (dots are removed when consumed by an exiting arrow)
  late Map<String, OrphanDotType> _orphanDots;

  // Track which colorGroups have had their key cleared
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
    _orphanDots = {for (final od in level.orphanDots) od.key: od.type};
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
  /// Live orphan dots remaining (consumed dots are absent from this map).
  Map<String, OrphanDotType> get orphanDots => Map.unmodifiable(_orphanDots);

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

        final exitInfo1 = _computeExitInfo(arrow1, arrow2.id);
        final exitInfo2 = _computeExitInfo(arrow2, arrow1.id);

        if (exitInfo1.blocked || exitInfo2.blocked) {
          return _handleGroupBlocked(grp, groupArrows);
        } else {
          for (final k in {...exitInfo1.consumed, ...exitInfo2.consumed}) {
            _orphanDots.remove(k);
          }
          return _handleGroupExited(grp, groupArrows);
        }
      }
    }

    // ── Ice mechanic: first tap cracks, second tap clears ────────────────────
    if (arrow.mechanic == SnakeMechanic.iceSegment &&
        arrow.state == ArrowState.idle) {
      if (_computeExitInfo(arrow).blocked) {
        return _handleBlocked(index, arrow, arrowId);
      }
      // First successful tap: crack
      _arrows[index] = arrow.copyWith(state: ArrowState.cracked);
      notifyListeners();
      return TapResult.cracked;
    }

    // ── Standard move check ─────────────────────────────────────────
    final exitInfo = _computeExitInfo(arrow);
    if (exitInfo.blocked) {
      return _handleBlocked(index, arrow, arrowId);
    }

    // ── Clear: arrow exits ──────────────────────────────────────────
    _arrows[index] = arrow.copyWith(state: ArrowState.sliding);
    // Consume orphan dots along the exit path
    for (final k in exitInfo.consumed) _orphanDots.remove(k);
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

  /// Checks whether the arrow's exit path is clear (possibly with deflections
  /// through orphan dots). Returns an [_ExitInfo] with:
  ///   - [blocked]: true if the path is ultimately blocked
  ///   - [consumed]: keys of orphan dots that would be traversed
  _ExitInfo _computeExitInfo(ArrowModel arrow, [String? ignoreId]) {
    ArrowDirection currentDir = arrow.direction;
    final head = arrow.path[0];
    final gridSize = _currentLevel.gridSize;
    var d = currentDir.delta;
    int nr = head[0] + d[0];
    int nc = head[1] + d[1];
    final consumed = <String>[];
    final visited = <String>{};

    while (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
      final key = '$nr,$nc';
      if (visited.contains(key)) return _ExitInfo(true, []);
      visited.add(key);

      if (_orphanDots.containsKey(key)) {
        consumed.add(key);
        final dotType = _orphanDots[key]!;
        if (dotType == OrphanDotType.red) {
          currentDir = currentDir.turnRight;
        } else if (dotType == OrphanDotType.blue) {
          currentDir = currentDir.turnLeft;
        }
      } else {
        bool hit = false;
        for (final other in _arrows) {
          if (other.id == arrow.id) continue;
          if (ignoreId != null && other.id == ignoreId) continue;
          if (other.state == ArrowState.sliding) continue;
          for (final pt in other.path) {
            if (pt[0] == nr && pt[1] == nc) { hit = true; break; }
          }
          if (hit) break;
        }
        if (hit) return _ExitInfo(true, []);
      }

      d = currentDir.delta;
      nr += d[0];
      nc += d[1];
    }
    return _ExitInfo(false, consumed);
  }

  /// Convenience bool wrapper used by block-animation code.
  bool _isHeadBlocked(ArrowModel arrow, [String? ignoreId]) =>
      _computeExitInfo(arrow, ignoreId).blocked;

  // ── Reset ─────────────────────────────────────────────────────────────────────

  void resetLevel() {
    _arrows = _currentLevel.arrows.map((a) => a.copyWith(state: ArrowState.idle)).toList();
    _orphanDots = {for (final od in _currentLevel.orphanDots) od.key: od.type};
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

/// Exit path analysis result for one arrow.
class _ExitInfo {
  final bool blocked;
  final List<String> consumed; // orphan dot keys consumed along this path
  const _ExitInfo(this.blocked, [this.consumed = const []]);
}
