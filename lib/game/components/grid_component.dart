import 'dart:async';
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/constants.dart';
import '../../data/level_generator/mask_generator.dart';
import '../../data/models/level.dart';
import '../game_state.dart';
import 'arrow_component.dart';

/// Renders the puzzle grid, mask boundary dots, and all arrow components.
///
/// IMPORTANT: the mask used for RENDERING must match the mask used when the
/// level was generated.  We regenerate it from the stored [MaskShape] so we
/// never drift between generator and renderer.
class GridComponent extends PositionComponent {
  final GameState gameState;
  double gridPixelSize;

  final Map<String, ArrowComponent> _arrowComponents = {};
  late Set<String> _mask;
  late LevelType _levelType;

  GridComponent({
    required this.gameState,
    required this.gridPixelSize,
    required Vector2 position,
  }) : super(position: position);

  double get cellSize => gridPixelSize / gameState.level.gridSize;

  @override
  Future<void> onLoad() async {
    size = Vector2.all(gridPixelSize);
    _levelType = AppConstants.levelTypeFor(gameState.level.levelNumber);
    _refreshMask();
    _buildArrows();
  }

  // ── Mask ──────────────────────────────────────────────────────────────────

  /// Rebuilds the mask from the stored MaskShape on the level model.
  /// Uses a deterministic seed derived from level + shape so the shape
  /// is always the same instance for this level (blob needs a seed).
  void _refreshMask() {
    _mask = gameState.level.mask;
  }

  // ── Arrow components ──────────────────────────────────────────────────────

  void _buildArrows() {
    removeAll(children.whereType<ArrowComponent>());
    _arrowComponents.clear();

    for (final arrow in gameState.arrows) {
      final comp = ArrowComponent(
        arrowModel: arrow,
        cellSize: cellSize,
        gameState: gameState,
        levelType: _levelType,
      )..position = Vector2(0, 0);
      _arrowComponents[arrow.id] = comp;
      add(comp);
    }
  }

  void rebuild() {
    _refreshMask();
    _buildArrows();
  }

  void resize(double newGridPixelSize) {
    gridPixelSize = newGridPixelSize;
    size = Vector2.all(gridPixelSize);
    for (final child in children) {
      if (child is ArrowComponent) child.updateCellSize(cellSize);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  RENDER
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  void render(Canvas canvas) {
    final gridSize = gameState.level.gridSize;
    final cs = cellSize;

    // ── Boss / God outer glow ─────────────────────────────────────────────
    if (_levelType == LevelType.god) {
      _glow(canvas, gridPixelSize, _godColor, 26.0, 4.0);
      _glow(canvas, gridPixelSize, _godColor.withValues(alpha: 0.35), 52.0, 2.0);
    } else if (_levelType == LevelType.boss) {
      _glow(canvas, gridPixelSize, _bossColor, 20.0, 2.8);
    }

    // ── Dot layer (drawn behind all arrows) ──────────────────────────────
    final baseDot = (cs * 0.045).clamp(0.6, 1.6);
    final inR   = baseDot;
    final outR  = inR * 0.55;

    final inPaint  = Paint()..color = const Color(0xFFC8BFB0)..style = PaintingStyle.fill;
    final outPaint = Paint()..color = const Color(0x1EBBBBBB)..style = PaintingStyle.fill;

    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        final inMask = _mask.contains('$r,$c');
        canvas.drawCircle(
          Offset((c + 0.5) * cs, (r + 0.5) * cs),
          inMask ? inR : outR,
          inMask ? inPaint : outPaint,
        );
      }
    }

    super.render(canvas);
  }

  void _drawPerimeter(Canvas canvas, int gridSize, double cs) {
    final p = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (cs * 0.045).clamp(0.8, 2.0);

    for (final key in _mask) {
      final parts = key.split(',');
      final r = int.parse(parts[0]);
      final c = int.parse(parts[1]);
      final x = c * cs, y = r * cs;

      // Draw edge on each side that faces outside the mask
      final edges = [
        [-1, 0, x, y, x + cs, y],
        [ 1, 0, x, y + cs, x + cs, y + cs],
        [ 0,-1, x, y, x, y + cs],
        [ 0, 1, x + cs, y, x + cs, y + cs],
      ];
      for (final e in edges) {
        if (!_mask.contains('${r+e[0]},${c+e[1]}')) {
          canvas.drawLine(
            Offset(e[2].toDouble(), e[3].toDouble()),
            Offset(e[4].toDouble(), e[5].toDouble()),
            p,
          );
        }
      }
    }
  }

  void _glow(Canvas canvas, double size, Color color, double blur, double width) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(-4, -4, size + 8, size + 8), const Radius.circular(16)),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
    );
  }

  static const Color _bossColor = Color(0xFFFF7A00);
  static const Color _godColor  = Color(0xFFAA55FF);

  // ── Update ────────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);
    final current = gameState.arrows.map((a) => a.id).toSet();
    final gone = _arrowComponents.keys.where((id) => !current.contains(id)).toList();
    for (final id in gone) {
      _arrowComponents[id]?.removeFromParent();
      _arrowComponents.remove(id);
    }
  }
}
