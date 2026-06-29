import 'dart:async';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/constants.dart';
import '../../data/models/level.dart';
import 'components/grid_component.dart';
import 'game_state.dart';

class ArrowPuzzleGame extends FlameGame {
  // ── State ─────────────────────────────────────────────────────────────────────
  final LevelModel level;
  late GameState gameState;
  GridComponent? gridComponent;

  // ── Callbacks to Flutter ──────────────────────────────────────────────────────
  final void Function() onLevelComplete;
  final void Function() onGameOver;
  final void Function() onLifeLost;

  ArrowPuzzleGame({
    required this.level,
    required this.onLevelComplete,
    required this.onGameOver,
    required this.onLifeLost,
  });

  @override
  Color backgroundColor() => AppColors.gridBg;

  @override
  Future<void> onLoad() async {
    gameState = GameState(
      level: level,
      onLevelComplete: onLevelComplete,
      onGameOver: onGameOver,
      onLifeLost: onLifeLost,
    );

    final levelType = AppConstants.levelTypeFor(level.levelNumber);
    final scale = AppConstants.canvasScaleForType(levelType);

    // Use the smaller dimension to keep the grid square on all screen sizes.
    // Boss/God levels use more of the available space for a bigger canvas.
    final minDim = size.x < size.y ? size.x : size.y;
    final gridSize = minDim * scale;
    final gridX = (size.x - gridSize) / 2;
    // Vertical centering
    final gridY = (size.y - gridSize) / 2;

    gridComponent = GridComponent(
      gameState: gameState,
      gridPixelSize: gridSize,
      position: Vector2(gridX, gridY),
    );

    add(gridComponent!);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);

    final levelType = AppConstants.levelTypeFor(level.levelNumber);
    final scale = AppConstants.canvasScaleForType(levelType);
    final minDim = size.x < size.y ? size.x : size.y;
    final gridSize = minDim * scale;
    final gridX = (size.x - gridSize) / 2;
    final gridY = (size.y - gridSize) / 2;

    if (gridComponent != null) {
      gridComponent!.position = Vector2(gridX, gridY);
      gridComponent!.resize(gridSize);
    }
  }

  /// Reset board to initial state (restart level)
  void resetLevel() {
    gameState.resetLevel();
    gridComponent?.rebuild();
  }
}
