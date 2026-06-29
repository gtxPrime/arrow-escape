import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/constants.dart';
import '../../data/models/arrow.dart';
import '../../data/models/level.dart';
import '../game_state.dart';

/// Renders a multi-cell arrow that winds through the grid.
///
/// path[0] = HEAD (carries the arrowhead triangle, exits first)
/// path[last] = TAIL (exits last — the "rope pulled through" effect)
///
/// Tapping anywhere on the body initiates a head-first sliding exit:
/// the arrowhead pulls out in the arrow's direction, the body follows
/// segment by segment, and the tail disappears last.
class ArrowComponent extends PositionComponent with TapCallbacks, HasPaint {
  ArrowModel arrowModel;
  double cellSize;
  final GameState gameState;
  final LevelType levelType;

  bool _isAnimating = false;
  bool _isBlockedAnimating = false;
  double _blockDuration = 0.0;
  double _blockTime = 0.0;
  double _maxBlockSlide = 0.0;
  double _slideOffset = 0.0;

  // ── Exit state ──────────────────────────────────────────────────────────────────
  bool _isExiting = false;
  double _exitProgress = 0.0;
  double _exitDuration = 0.35;
  /// Pre-built deflected exit track (farthest → head), null = straight exit
  List<Offset>? _deflectedExtension;

  // ── Color palette for colorLock / colorKey groups ─────────────────────────
  static const List<Color> _groupColors = [
    Color(0xFF4FC3F7),
    Color(0xFF81C784),
    Color(0xFFFFB74D),
    Color(0xFFBA68C8),
    Color(0xFFFF8A65),
    Color(0xFF4DB6AC),
    Color(0xFFF06292),
    Color(0xFFAED581),
  ];

  ArrowComponent({
    required this.arrowModel,
    required this.cellSize,
    required this.gameState,
    this.levelType = LevelType.normal,
  }) : super(size: Vector2.all(cellSize * gameState.level.gridSize));

  void updateCellSize(double newSize) {
    cellSize = newSize;
    size = Vector2.all(newSize * gameState.level.gridSize);
  }

  // ── Hit test: tap anywhere along the arrow body ───────────────────────────

  @override
  bool containsLocalPoint(Vector2 point) {
    if (_isExiting) return false;
    final col = (point.x / cellSize).floor();
    final row = (point.y / cellSize).floor();
    return arrowModel.path.any((pt) => pt[0] == row && pt[1] == col);
  }

  @override
  void onTapDown(TapDownEvent event) {}

  @override
  void onTapUp(TapUpEvent event) {
    if (_isAnimating) return;
    _triggerMove();
  }

  @override
  void onTapCancel(TapCancelEvent event) {}

  void _triggerMove() {
    if (_isAnimating) return;
    _isAnimating = true;

    final result = gameState.tapArrow(arrowModel.id);
    switch (result) {
      case TapResult.exited:
        _startExitAnimation();
        break;
      case TapResult.blocked:
        _playBlockAnimation();
        break;
      case TapResult.locked:
        _playLockedAnimation();
        break;
      case TapResult.cracked:
        _playCrackAnimation();
        _isAnimating = false;
        break;
      case TapResult.ignored:
        _isAnimating = false;
        break;
    }
  }

  // ── Exit: head-first pull-through ────────────────────────────────────────

  void _startExitAnimation() {
    _exitDuration = 0.4 + arrowModel.path.length * 0.08;
    _exitProgress = 0.0;
    _isExiting = true;
    _deflectedExtension = _buildDeflectedExtension();
  }

  /// Pre-computes the full exit track for arrows that pass through orphan dots.
  /// Returns a list of Offsets from FARTHEST point → first-step-from-head,
  /// or null if the exit is a plain straight line.
  List<Offset>? _buildDeflectedExtension() {
    final orphanDots = gameState.orphanDots;
    if (orphanDots.isEmpty) return null;

    ArrowDirection currentDir = arrowModel.direction;
    final head = arrowModel.path[0];
    final gridSize = gameState.level.gridSize;
    final pts = <Offset>[];
    var d = currentDir.delta;
    int nr = head[0] + d[0];
    int nc = head[1] + d[1];
    final visited = <String>{};
    bool hasDeflection = false;

    while (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
      final key = '$nr,$nc';
      if (visited.contains(key)) break;
      visited.add(key);
      pts.add(Offset((nc + 0.5) * cellSize, (nr + 0.5) * cellSize));

      if (orphanDots.containsKey(key)) {
        final dotType = orphanDots[key]!;
        if (dotType == OrphanDotType.red) {
          hasDeflection = true;
          currentDir = currentDir.turnRight;
        } else if (dotType == OrphanDotType.blue) {
          hasDeflection = true;
          currentDir = currentDir.turnLeft;
        }
      }

      d = currentDir.delta;
      nr += d[0];
      nc += d[1];
    }

    if (!hasDeflection) return null;

    // Pad a few off-screen cells in the final direction so the tail fully exits
    for (int i = 0; i <= 5; i++) {
      pts.add(Offset((nc + d[1] * i + 0.5) * cellSize,
                     (nr + d[0] * i + 0.5) * cellSize));
    }

    return pts.reversed.toList(); // farthest → closest to head
  }

  // ── Block: direction-aware shake ──────────────────────────────────────────

  void _playBlockAnimation() {
    final delta = arrowModel.direction.delta;
    final head = arrowModel.path[0];
    final gridSize = gameState.level.gridSize;

    int nr = head[0] + delta[0];
    int nc = head[1] + delta[1];
    int k = 1;

    // Find the first occupied cell along the exit direction path
    while (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
      bool occupied = false;
      for (final other in gameState.arrows) {
        if (other.id == arrowModel.id) continue;
        if (other.state == ArrowState.sliding) continue;
        for (final pt in other.path) {
          if (pt[0] == nr && pt[1] == nc) {
            occupied = true;
            break;
          }
        }
        if (occupied) break;
      }
      if (occupied) break;
      k++;
      nr += delta[0];
      nc += delta[1];
    }

    _maxBlockSlide = (k - 1) * cellSize + cellSize * 0.25;
    _blockDuration = 0.12 + (k - 1) * 0.06;
    _blockTime = 0.0;
    _isBlockedAnimating = true;
  }

  // ── ColorLock: lateral rattle ─────────────────────────────────────────────

  void _playLockedAnimation() {
    final ox = position.x, oy = position.y;
    add(SequenceEffect([
      MoveEffect.to(Vector2(ox + 4, oy), EffectController(duration: 0.06)),
      MoveEffect.to(Vector2(ox - 4, oy), EffectController(duration: 0.06)),
      MoveEffect.to(Vector2(ox + 3, oy), EffectController(duration: 0.05)),
      MoveEffect.to(Vector2(ox - 3, oy), EffectController(duration: 0.05)),
      MoveEffect.to(Vector2(ox, oy), EffectController(duration: 0.04)),
    ], onComplete: () => _isAnimating = false));
  }

  // ── Ice first crack: scale pulse ──────────────────────────────────────────

  void _playCrackAnimation() {
    add(SequenceEffect([
      ScaleEffect.to(Vector2.all(1.08), EffectController(duration: 0.07)),
      ScaleEffect.to(Vector2.all(0.96), EffectController(duration: 0.07)),
      ScaleEffect.to(Vector2.all(1.00), EffectController(duration: 0.06)),
    ]));
  }

  // ── Update ────────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);

    if (_isExiting) {
      _exitProgress += dt / _exitDuration;
      if (_exitProgress >= 1.0) {
        removeFromParent();
        return;
      }
    }

    if (_isBlockedAnimating) {
      _blockTime += dt;
      final half = _blockDuration / 2;
      if (_blockTime < half) {
        final t = _blockTime / half;
        _slideOffset = Curves.easeOut.transform(t) * _maxBlockSlide;
      } else if (_blockTime < _blockDuration) {
        final t = (_blockTime - half) / half;
        _slideOffset = (1.0 - Curves.easeIn.transform(t)) * _maxBlockSlide;
      } else {
        _slideOffset = 0.0;
        _isBlockedAnimating = false;
        _isAnimating = false;
      }
    }

    // Sync model from game state (picks up mechanic/state changes)
    final updated =
        gameState.arrows.where((a) => a.id == arrowModel.id).firstOrNull;
    if (updated != null) {
      if (updated.state == ArrowState.sliding && !_isExiting && !_isAnimating) {
        _isAnimating = true;
        _startExitAnimation();
      } else if (updated.state == ArrowState.blocked && !_isAnimating) {
        _isAnimating = true;
        _playBlockAnimation();
      }
      arrowModel = updated;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  RENDER
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  void render(Canvas canvas) {
    if (arrowModel.path.isEmpty) return;

    // ── 1. Build the pixel path (head first) ──────────────────────────────
    final pathPx = arrowModel.path
        .map((pt) => Offset((pt[1] + 0.5) * cellSize, (pt[0] + 0.5) * cellSize))
        .toList();

    // ── 2. Build the extended track for exit animation ────────────────────
    final delta = arrowModel.direction.delta;
    final headPx = pathPx.first;

    final track = <Offset>[];
    final int extCount;
    if (_deflectedExtension != null) {
      // Deflected exit path: pre-built reversed list (farthest → closest to head)
      track.addAll(_deflectedExtension!);
      extCount = _deflectedExtension!.length;
    } else {
      // Default straight extension
      extCount = gameState.level.gridSize + 2;
      for (int i = extCount; i >= 1; i--) {
        track.add(
            headPx + Offset(delta[1] * i * cellSize, delta[0] * i * cellSize));
      }
    }
    track.addAll(pathPx);

    // ── 3. Cumulative distances along the track ───────────────────────────
    final dist = <double>[0.0];
    for (int i = 1; i < track.length; i++) {
      dist.add(dist[i - 1] + (track[i] - track[i - 1]).distance);
    }
    final headDist = dist[extCount];
    final tailDist = dist[extCount + arrowModel.path.length - 1];

    // ── 4. Compute animated head/tail positions ───────────────────────────
    final double animHead, animTail;
    if (_isExiting) {
      final traveled = (_exitProgress * tailDist).clamp(0.0, tailDist);
      animHead = (headDist - traveled).clamp(0.0, headDist);
      animTail = (tailDist - traveled).clamp(0.0, tailDist);
    } else if (_isBlockedAnimating) {
      final traveled = _slideOffset.clamp(0.0, tailDist);
      animHead = (headDist - traveled).clamp(0.0, headDist);
      animTail = (tailDist - traveled).clamp(0.0, tailDist);
    } else {
      animHead = headDist;
      animTail = tailDist;
    }

    final pts = _slice(track, dist, animHead, animTail);
    if (pts.isEmpty) return;

    // ── 5. Resolve color and stroke width ─────────────────────────────────
    final mainColor = _color();
    final sw = cellSize * 0.13; // Sleek but solid aesthetic

    canvas.save();

    // A) If ice segment, draw frosty blue background under the head cell
    if (arrowModel.mechanic == SnakeMechanic.iceSegment && pts.isNotEmpty) {
      canvas.drawCircle(
        pts.first,
        cellSize * 0.28,
        Paint()
          ..color = const Color(0x6690CAF9)
          ..style = PaintingStyle.fill,
      );
    }

    final bodyPath = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) bodyPath.lineTo(pts[i].dx, pts[i].dy);

    // ── 6. Draw body ──────────────────────────────────────────────────────
    final bodyPaint = Paint()
      ..color = mainColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(bodyPath, bodyPaint);

    // ── 7. Draw arrowhead at the head end (pts.first) ─────────────────────
    _drawHead(canvas, pts, mainColor, sw);

    // ── 8. Overlays ───────────────────────────────────────────────────────
    if (arrowModel.mechanic == SnakeMechanic.iceSegment &&
        arrowModel.state == ArrowState.cracked &&
        pts.isNotEmpty) {
      _drawCrackOverlay(canvas, pts.first);
    }

    canvas.restore();
  }

  // ── Arrowhead ─────────────────────────────────────────────────────────────

  void _drawHead(Canvas canvas, List<Offset> pts, Color mainColor, double sw) {
    final prev = pts.length > 1 ? pts[1] : pts.first;
    final dv = pts.first - prev;
    final len = dv.distance;

    final d = arrowModel.direction.delta;
    final dx = len > 0.01 ? dv.dx / len : d[1].toDouble();
    final dy = len > 0.01 ? dv.dy / len : d[0].toDouble();

    // The head tip position
    final tip = pts.first + Offset(dx * cellSize * 0.3, dy * cellSize * 0.3);

    final hd = cellSize * 0.25; // depth
    final hw = cellSize * 0.18; // half-width

    final base = tip - Offset(dx * hd, dy * hd);
    final px = -dy, py = dx; // perpendicular

    final caretPath = Path()
      ..moveTo(base.dx + px * hw, base.dy + py * hw)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(base.dx - px * hw, base.dy - py * hw);

    canvas.drawPath(
      caretPath,
      Paint()
        ..color = mainColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  // ── Overlays ──────────────────────────────────────────────────────────────

  void _drawKeyIndicator(Canvas canvas, Offset center) {
    final r = cellSize * 0.11;
    final strokeWidth = cellSize * 0.04;
    // Draw head of the key
    canvas.drawCircle(
      center - Offset(cellSize * 0.08, 0),
      r,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
    // Draw shaft of the key
    canvas.drawRect(
      Rect.fromLTWH(center.dx - cellSize * 0.02, center.dy - strokeWidth / 2,
          cellSize * 0.18, strokeWidth),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.fill,
    );
    // Draw teeth of the key
    canvas.drawRect(
      Rect.fromLTWH(
          center.dx + cellSize * 0.10, center.dy, strokeWidth, cellSize * 0.08),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.fill,
    );
  }

  void _drawCrackOverlay(Canvas canvas, Offset center) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = cellSize * 0.04
      ..strokeCap = StrokeCap.round;
    final z = cellSize * 0.16;
    canvas.drawPath(
        Path()
          ..moveTo(center.dx - z, center.dy - z * 0.8)
          ..lineTo(center.dx + z * 0.4, center.dy + z * 0.2)
          ..lineTo(center.dx - z * 0.4, center.dy + z * 1.1),
        p);
  }

  void _drawLockIcon(Canvas canvas, Offset center) {
    final r = cellSize * 0.16;
    final strokeWidth = cellSize * 0.04;

    // Draw lock shackle
    canvas.drawCircle(
        center - Offset(0, r * 0.3),
        r,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth);

    // Draw lock body
    final bodyRect = Rect.fromCenter(
        center: center + Offset(0, r * 0.5), width: r * 1.8, height: r * 1.3);
    canvas.drawRRect(
        RRect.fromRectAndRadius(bodyRect, Radius.circular(r * 0.25)),
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill);

    // Draw keyhole inside lock body (small dark dot + small line under it)
    final keyholePaint = Paint()
      ..color = const Color(0xFF6E503F)
      ..style = PaintingStyle.fill;
    final khCenter = center + Offset(0, r * 0.45);
    canvas.drawCircle(khCenter, r * 0.24, keyholePaint);
    final teethPath = Path()
      ..moveTo(khCenter.dx - r * 0.09, khCenter.dy)
      ..lineTo(khCenter.dx + r * 0.09, khCenter.dy)
      ..lineTo(khCenter.dx + r * 0.16, khCenter.dy + r * 0.4)
      ..lineTo(khCenter.dx - r * 0.16, khCenter.dy + r * 0.4)
      ..close();
    canvas.drawPath(teethPath, keyholePaint);
  }

  // ── Color resolution ──────────────────────────────────────────────────────

  Color _color() {
    if (arrowModel.state == ArrowState.blocked) {
      return AppColors.accent; // Shake red on block
    }
    if (arrowModel.colorGroup != null) {
      return _groupColors[arrowModel.colorGroup! % _groupColors.length];
    }
    return const Color(0xFF6E503F); // Clean brown color
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  PATH INTERPOLATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Extract the visible portion of the track between [from] and [to] distance.
  /// Returns Offsets in "head→tail" order (from = head end, to = tail end).
  List<Offset> _slice(
      List<Offset> track, List<double> dist, double from, double to) {
    if (from >= to) {
      if (from == to && track.isNotEmpty) {
        return [_lerp(track, dist, from)];
      }
      return [];
    }
    final pts = <Offset>[_lerp(track, dist, from)];
    for (int i = 0; i < dist.length; i++) {
      if (dist[i] > from && dist[i] < to) pts.add(track[i]);
    }
    pts.add(_lerp(track, dist, to));
    return pts;
  }

  Offset _lerp(List<Offset> track, List<double> dist, double s) {
    if (s <= dist.first) return track.first;
    if (s >= dist.last) return track.last;
    for (int i = 0; i < dist.length - 1; i++) {
      if (s >= dist[i] && s <= dist[i + 1]) {
        final t = (s - dist[i]) / (dist[i + 1] - dist[i]);
        return Offset.lerp(track[i], track[i + 1], t)!;
      }
    }
    return track.last;
  }
}

// ── Small helper to convert a shake offset to Vector2 ────────────────────────
extension _OffsetToVec on Offset {
  Vector2 toVector(double ox, double oy) => Vector2(ox + dx, oy + dy);
}
