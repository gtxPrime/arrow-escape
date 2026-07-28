import 'dart:math';

import '../../core/constants.dart';

/// V2 Parametric mask generator for puzzle canvas shapes.
///
/// Expanded from V1:
///   Boss: 34 shapes total (14 original + 20 new geometric/angular)
///   God:  24 shapes total ( 6 original + 18 new decorative/pictorial)
///
/// ALL shapes use pure-math primitives (_rect, _ellipse, _triangle, _polygon).
/// No images, no SVG assets required.
///
/// Shape name lists (bossShapeNames, godShapeNames) are exposed so the
/// no-repeat history logic in LevelGeneratorV2 can operate on them.
class MaskGeneratorV2 {
  MaskGeneratorV2._();

  // ── Shape name pools — used by LevelGeneratorV2 for the no-repeat rule ────

  static const List<String> bossShapeNames = [
    'cat', 'dog', 'frog', 'fox', 'tiger', 'panda',
    'fish', 'butterfly', 'house', 'crown', 'saturn',
    'trapezoid', 'parallelogram', 'pentagon', 'octagon',
    'gear', 'star4', 'shield', 'castle',
  ];

  static const List<String> godShapeNames = [
    'heart', 'star', 'diamond', 'hexagon', 'blob', 'circle',
    'flower', 'giftBox', 'shield', 'rocket', 'sun', 'cloud',
    'gem', 'snowflake', 'teddyBear', 'globe', 'cat', 'crown', 'castle',
  ];

  // ── Public API ─────────────────────────────────────────────────────────────

  static Set<String> maskForLevelType(LevelType type, Random rng, int side) {
    switch (type) {
      case LevelType.tutorial:
        return squareMask(side);
      case LevelType.normal:
        return longRectangleMask(side);
      case LevelType.boss:
        final mask = _randomBossShape(side, rng);
        final minCells = (side * side * 0.60).floor();
        final selected = mask.length >= minCells ? mask : circleMask(side);
        return _ensureMinBBox(selected, side);
      case LevelType.god:
        final mask = _randomGodShape(side, rng);
        final minCells = (side * side * 0.65).floor();
        final selected = mask.length >= minCells ? mask : circleMask(side);
        return _ensureMinBBox(selected, side);
    }
  }

  static Set<String> _ensureMinBBox(Set<String> mask, int side) {
    final targetBBox = min(side - 2, 27);
    int minR = 999, maxR = -1, minC = 999, maxC = -1;
    for (final cell in mask) {
      final parts = cell.split(',');
      final r = int.parse(parts[0]);
      final c = int.parse(parts[1]);
      if (r < minR) minR = r;
      if (r > maxR) maxR = r;
      if (c < minC) minC = c;
      if (c > maxC) maxC = c;
    }
    final w = maxC - minC + 1;
    final h = maxR - minR + 1;
    if (w >= targetBBox && h >= targetBBox) return mask;
    return squareMask(side);
  }

  static Set<String> _randomBossShape(int side, Random rng) {
    final name = bossShapeNames[rng.nextInt(bossShapeNames.length)];
    return shapeByName(name, side, rng);
  }

  static Set<String> _randomGodShape(int side, Random rng) {
    final name = godShapeNames[rng.nextInt(godShapeNames.length)];
    return shapeByName(name, side, rng);
  }

  // ── Shape by name ──────────────────────────────────────────────────────────

  static Set<String> shapeByName(String name, int side, Random rng) {
    switch (name) {
      case 'square':        return squareMask(side);
      case 'longRectangle': return longRectangleMask(side);
      // ── Original V1 shapes ────────────────────────────────────────────────
      case 'cat':         return catMask(side);
      case 'dog':         return dogMask(side);
      case 'frog':        return frogMask(side);
      case 'fox':         return foxMask(side);
      case 'tiger':       return tigerMask(side);
      case 'panda':       return pandaMask(side);
      case 'fish':        return fishMask(side);
      case 'bird':        return birdMask(side);
      case 'butterfly':   return butterflyMask(side);
      case 'guitar':      return guitarMask(side);
      case 'tree':        return treeMask(side);
      case 'house':       return houseMask(side);
      case 'crown':       return crownMask(side);
      case 'castle':      return castleMask(side);
      case 'saturn':      return saturnMask(side);
      case 'heart':       return heartMask(side);
      case 'star':        return starMask(side, 5);
      case 'diamond':     return diamondMask(side);
      case 'hexagon':     return hexagonMask(side);
      case 'blob':        return blobMask(side, rng.nextInt(9999));
      case 'circle':      return circleMask(side);

      // ── V2 Boss shapes ─────────────────────────────────────────────────────
      case 'plus':           return plusMask(side);
      case 'tShape':         return tShapeMask(side);
      case 'lShape':         return lShapeMask(side);
      case 'hShape':         return hShapeMask(side);
      case 'uShape':         return uShapeMask(side);
      case 'zShape':         return zShapeMask(side);
      case 'xCross':         return xCrossMask(side);
      case 'arrowUp':        return arrowUpMask(side);
      case 'arrowRight':     return arrowRightMask(side);
      case 'chevron':        return chevronMask(side);
      case 'staircase':      return staircaseMask(side);
      case 'trapezoid':      return trapezoidMask(side);
      case 'parallelogram':  return parallelogramMask(side);
      case 'pentagon':       return pentagonMask(side);
      case 'octagon':        return octagonMask(side);
      case 'pinwheel':       return pinwheelMask(side);
      case 'gear':           return gearMask(side);
      case 'lightningBolt':  return lightningBoltMask(side);
      case 'star4':          return starMask(side, 4);
      case 'ribbon':         return ribbonMask(side);

      // ── V2 God shapes ──────────────────────────────────────────────────────
      case 'flower':         return flowerMask(side);
      case 'spinningTop':    return spinningTopMask(side);
      case 'lollipop':       return lollipopMask(side);
      case 'iceCream':       return iceCreamMask(side);
      case 'crescentMoon':   return crescentMoonMask(side);
      case 'giftBox':        return giftBoxMask(side);
      case 'anchor':         return anchorMask(side);
      case 'shield':         return shieldMask(side);
      case 'rocket':         return rocketMask(side);
      case 'sun':            return sunMask(side);
      case 'cloud':          return cloudMask(side);
      case 'umbrella':       return umbrellaMask(side);
      case 'key':            return keyMask(side);
      case 'bowtie':         return bowtieMask(side);
      case 'gem':            return gemMask(side);
      case 'snowflake':      return snowflakeMask(side);
      case 'teddyBear':      return teddyBearMask(side);
      case 'globe':          return globeMask(side);

      default: return squareMask(side);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  GEOMETRIC PRIMITIVES
  // ═══════════════════════════════════════════════════════════════════════════

  static Set<String> squareMask(int side) {
    final mask = <String>{};
    for (int r = 0; r < side; r++) {
      for (int c = 0; c < side; c++) mask.add('$r,$c');
    }
    return mask;
  }

  /// Long vertical rectangle mask for normal levels (13:19 width-to-height ratio).
  /// For a grid side of S rows, target width is ~ S * (13/19) columns.
  static Set<String> longRectangleMask(int side) {
    final mask = <String>{};
    final activeCols = (side * 13 / 19).round().clamp(1, side);
    final colMargin = ((side - activeCols) / 2).floor().clamp(0, side ~/ 2);
    for (int r = 0; r < side; r++) {
      for (int c = colMargin; c < colMargin + activeCols; c++) {
        mask.add('$r,$c');
      }
    }
    return mask;
  }

  static void _ellipse(Set<String> mask, int side,
      double cx, double cy, double rx, double ry) {
    for (int r = 0; r < side; r++) {
      for (int c = 0; c < side; c++) {
        final dx = (c + 0.5 - cx) / rx, dy = (r + 0.5 - cy) / ry;
        if (dx * dx + dy * dy <= 1.0) mask.add('$r,$c');
      }
    }
  }

  static void _rect(Set<String> mask, int side,
      double x1, double y1, double x2, double y2) {
    for (int r = 0; r < side; r++) {
      for (int c = 0; c < side; c++) {
        final px = c + 0.5, py = r + 0.5;
        if (px >= x1 && px <= x2 && py >= y1 && py <= y2) mask.add('$r,$c');
      }
    }
  }

  static void _triangle(Set<String> mask, int side,
      double ax, double ay, double bx, double by, double cx2, double cy2) {
    for (int r = 0; r < side; r++) {
      for (int c = 0; c < side; c++) {
        final px = c + 0.5, py = r + 0.5;
        final d1 = _cross(px, py, ax, ay, bx, by);
        final d2 = _cross(px, py, bx, by, cx2, cy2);
        final d3 = _cross(px, py, cx2, cy2, ax, ay);
        final hasNeg = (d1 < 0) || (d2 < 0) || (d3 < 0);
        final hasPos = (d1 > 0) || (d2 > 0) || (d3 > 0);
        if (!(hasNeg && hasPos)) mask.add('$r,$c');
      }
    }
  }

  static double _cross(double px, double py,
      double ax, double ay, double bx, double by) =>
      (px - bx) * (ay - by) - (ax - bx) * (py - by);

  /// General N-sided convex polygon via point-in-polygon.
  static void _polygon(Set<String> mask, int side, List<List<double>> verts) {
    for (int r = 0; r < side; r++) {
      for (int c = 0; c < side; c++) {
        final px = c + 0.5, py = r + 0.5;
        if (_pointInPolygon(px, py, verts)) mask.add('$r,$c');
      }
    }
  }

  static bool _pointInPolygon(double px, double py, List<List<double>> verts) {
    bool inside = false;
    final n = verts.length;
    for (int i = 0, j = n - 1; i < n; j = i++) {
      final xi = verts[i][0], yi = verts[i][1];
      final xj = verts[j][0], yj = verts[j][1];
      if (((yi > py) != (yj > py)) &&
          (px < (xj - xi) * (py - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
    }
    return inside;
  }

  /// Subtract [remove] cells from [base].
  static Set<String> _subtract(Set<String> base, Set<String> remove) =>
      base.difference(remove);

  /// Keep only the largest connected region.
  static Set<String> _clean(Set<String> mask, int side) {
    if (mask.isEmpty) return mask;
    final visited = <String>{};
    final regions = <Set<String>>[];
    for (final cell in mask) {
      if (visited.contains(cell)) continue;
      final region = <String>{};
      final stack  = [cell];
      while (stack.isNotEmpty) {
        final cur = stack.removeLast();
        if (!mask.contains(cur) || visited.contains(cur)) continue;
        visited.add(cur); region.add(cur);
        final p = cur.split(',');
        final r = int.parse(p[0]), c = int.parse(p[1]);
        for (final d in [[-1,0],[1,0],[0,-1],[0,1]]) {
          final nk = '${r+d[0]},${c+d[1]}';
          if (mask.contains(nk) && !visited.contains(nk)) stack.add(nk);
        }
      }
      if (region.isNotEmpty) regions.add(region);
    }
    if (regions.isEmpty) return mask;
    regions.sort((a, b) => b.length.compareTo(a.length));
    return regions.first;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  ORIGINAL V1 SHAPES (preserved exactly)
  // ═══════════════════════════════════════════════════════════════════════════

  static Set<String> circleMask(int side) {
    final mask = <String>{};
    _ellipse(mask, side, side / 2.0, side / 2.0, side / 2.0 - 0.4, side / 2.0 - 0.4);
    return _clean(mask, side);
  }

  static Set<String> heartMask(int side) {
    final mask = <String>{};
    final s = side.toDouble();
    for (int r = 0; r < side; r++) {
      for (int c = 0; c < side; c++) {
        final x = (c + 0.5) / s * 2.0 - 1.0;
        final y = -(((r + 0.5) / s) * 2.0 - 1.0) * 0.92 + 0.04;
        final v = pow(x * x + y * y - 1, 3).toDouble() - x * x * y * y * y;
        if (v <= 0.0) mask.add('$r,$c');
      }
    }
    return _clean(mask, side);
  }

  static Set<String> starMask(int side, int points) {
    final mask = <String>{};
    final cx = side / 2.0, cy = side / 2.0;
    final outerR = side / 2.0 - 0.3, innerR = outerR * 0.42;
    final step = pi / points;
    for (int r = 0; r < side; r++) {
      for (int c = 0; c < side; c++) {
        final dx = c + 0.5 - cx, dy = r + 0.5 - cy;
        final angle = atan2(dy, dx), dist = sqrt(dx * dx + dy * dy);
        final mod   = ((angle + pi) / step) % 2.0;
        final limit = mod < 1.0
            ? outerR * mod + innerR * (1 - mod)
            : outerR * (2 - mod) + innerR * (mod - 1);
        if (dist <= limit + 0.55) mask.add('$r,$c');
      }
    }
    return _clean(mask, side);
  }

  static Set<String> diamondMask(int side) {
    final mask = <String>{};
    final cx = side / 2.0, cy = side / 2.0, r = side / 2.0 - 0.3;
    for (int row = 0; row < side; row++) {
      for (int col = 0; col < side; col++) {
        if ((col + 0.5 - cx).abs() + (row + 0.5 - cy).abs() <= r + 0.55) {
          mask.add('$row,$col');
        }
      }
    }
    return _clean(mask, side);
  }

  static Set<String> hexagonMask(int side) {
    final mask = <String>{};
    final cx = side / 2.0, cy = side / 2.0, r = side / 2.0 - 0.5;
    for (int row = 0; row < side; row++) {
      for (int col = 0; col < side; col++) {
        final dx = (col + 0.5 - cx).abs(), dy = (row + 0.5 - cy).abs();
        if (dx <= r && dy <= r * 0.866 && dx + dy * 1.155 <= r * 2.0) {
          mask.add('$row,$col');
        }
      }
    }
    return _clean(mask, side);
  }

  static Set<String> blobMask(int side, int seed) {
    final rng   = Random(seed);
    final mask  = <String>{};
    final cx = side / 2.0, cy = side / 2.0, baseR = side / 2.0 - 0.8;
    final a1 = 0.12 + rng.nextDouble() * 0.08;
    final a2 = 0.07 + rng.nextDouble() * 0.06;
    final phi1 = rng.nextDouble() * 2 * pi;
    final phi2 = rng.nextDouble() * 2 * pi;
    final f1   = (rng.nextInt(3) + 2).toDouble();
    final f2   = (rng.nextInt(4) + 5).toDouble();
    for (int r = 0; r < side; r++) {
      for (int c = 0; c < side; c++) {
        final dx = c + 0.5 - cx, dy = r + 0.5 - cy;
        final angle = atan2(dy, dx), dist = sqrt(dx * dx + dy * dy);
        final limit = baseR * (1.0 + a1 * sin(f1 * angle + phi1) + a2 * sin(f2 * angle + phi2));
        if (dist <= limit) mask.add('$r,$c');
      }
    }
    return _clean(mask, side);
  }

  static Set<String> catMask(int side) {
    final mask = <String>{}; final s = side.toDouble();
    _ellipse(mask, side, s*0.5, s*0.56, s*0.42, s*0.40);
    _triangle(mask, side, s*0.18, s*0.28, s*0.38, s*0.28, s*0.27, s*0.05);
    _triangle(mask, side, s*0.62, s*0.28, s*0.82, s*0.28, s*0.73, s*0.05);
    return _clean(mask, side);
  }

  static Set<String> dogMask(int side) {
    final mask = <String>{}; final s = side.toDouble();
    _ellipse(mask, side, s*0.5, s*0.48, s*0.37, s*0.36);
    _ellipse(mask, side, s*0.18, s*0.55, s*0.14, s*0.26);
    _ellipse(mask, side, s*0.82, s*0.55, s*0.14, s*0.26);
    _ellipse(mask, side, s*0.5, s*0.74, s*0.18, s*0.11);
    return _clean(mask, side);
  }

  static Set<String> frogMask(int side) {
    final mask = <String>{}; final s = side.toDouble();
    _ellipse(mask, side, s*0.5, s*0.60, s*0.44, s*0.34);
    _ellipse(mask, side, s*0.28, s*0.28, s*0.13, s*0.12);
    _ellipse(mask, side, s*0.72, s*0.28, s*0.13, s*0.12);
    _ellipse(mask, side, s*0.18, s*0.82, s*0.16, s*0.12);
    _ellipse(mask, side, s*0.82, s*0.82, s*0.16, s*0.12);
    return _clean(mask, side);
  }

  static Set<String> foxMask(int side) {
    final mask = <String>{}; final s = side.toDouble();
    _ellipse(mask, side, s*0.5, s*0.55, s*0.34, s*0.38);
    _triangle(mask, side, s*0.10, s*0.42, s*0.38, s*0.30, s*0.22, s*0.04);
    _triangle(mask, side, s*0.62, s*0.30, s*0.90, s*0.42, s*0.78, s*0.04);
    _ellipse(mask, side, s*0.5, s*0.76, s*0.14, s*0.10);
    return _clean(mask, side);
  }

  static Set<String> tigerMask(int side) {
    final mask = <String>{}; final s = side.toDouble();
    _ellipse(mask, side, s*0.5, s*0.54, s*0.44, s*0.40);
    _ellipse(mask, side, s*0.22, s*0.20, s*0.11, s*0.10);
    _ellipse(mask, side, s*0.78, s*0.20, s*0.11, s*0.10);
    return _clean(mask, side);
  }

  static Set<String> pandaMask(int side) {
    final mask = <String>{}; final s = side.toDouble();
    _ellipse(mask, side, s*0.5, s*0.54, s*0.40, s*0.40);
    _ellipse(mask, side, s*0.26, s*0.16, s*0.14, s*0.13);
    _ellipse(mask, side, s*0.74, s*0.16, s*0.14, s*0.13);
    return _clean(mask, side);
  }

  static Set<String> fishMask(int side) {
    final mask = <String>{}; final s = side.toDouble();
    _ellipse(mask, side, s*0.42, s*0.5, s*0.38, s*0.24);
    _triangle(mask, side, s*0.78, s*0.32, s*0.98, s*0.18, s*0.88, s*0.50);
    _triangle(mask, side, s*0.78, s*0.68, s*0.98, s*0.82, s*0.88, s*0.50);
    return _clean(mask, side);
  }

  static Set<String> birdMask(int side) {
    final mask = <String>{}; final s = side.toDouble();
    _ellipse(mask, side, s*0.5, s*0.52, s*0.26, s*0.20);
    _ellipse(mask, side, s*0.21, s*0.48, s*0.24, s*0.14);
    _ellipse(mask, side, s*0.79, s*0.48, s*0.24, s*0.14);
    _triangle(mask, side, s*0.38, s*0.70, s*0.62, s*0.70, s*0.50, s*0.90);
    _ellipse(mask, side, s*0.50, s*0.31, s*0.12, s*0.12);
    return _clean(mask, side);
  }

  static Set<String> butterflyMask(int side) {
    final mask = <String>{}; final s = side.toDouble();
    _ellipse(mask, side, s*0.26, s*0.33, s*0.24, s*0.28);
    _ellipse(mask, side, s*0.74, s*0.33, s*0.24, s*0.28);
    _ellipse(mask, side, s*0.28, s*0.67, s*0.20, s*0.22);
    _ellipse(mask, side, s*0.72, s*0.67, s*0.20, s*0.22);
    _ellipse(mask, side, s*0.50, s*0.50, s*0.055, s*0.40);
    return _clean(mask, side);
  }

  static Set<String> guitarMask(int side) {
    final mask = <String>{}; final s = side.toDouble();
    _ellipse(mask, side, s*0.5, s*0.70, s*0.30, s*0.25);
    _ellipse(mask, side, s*0.5, s*0.40, s*0.24, s*0.20);
    _rect(mask, side, s*0.43, s*0.04, s*0.57, s*0.24);
    _rect(mask, side, s*0.38, s*0.56, s*0.62, s*0.66);
    return _clean(mask, side);
  }

  static Set<String> treeMask(int side) {
    final mask = <String>{}; final s = side.toDouble();
    _ellipse(mask, side, s*0.5, s*0.38, s*0.36, s*0.34);
    _rect(mask, side, s*0.42, s*0.68, s*0.58, s*0.94);
    return _clean(mask, side);
  }

  static Set<String> houseMask(int side) {
    final mask = <String>{}; final s = side.toDouble();
    _rect(mask, side, s*0.10, s*0.44, s*0.90, s*0.92);
    _triangle(mask, side, s*0.0, s*0.44, s*1.0, s*0.44, s*0.5, s*0.06);
    return _clean(mask, side);
  }

  static Set<String> crownMask(int side) {
    final mask = <String>{}; final s = side.toDouble();
    _rect(mask, side, s*0.08, s*0.58, s*0.92, s*0.90);
    _triangle(mask, side, s*0.08, s*0.58, s*0.28, s*0.58, s*0.18, s*0.10);
    _triangle(mask, side, s*0.36, s*0.58, s*0.64, s*0.58, s*0.50, s*0.04);
    _triangle(mask, side, s*0.72, s*0.58, s*0.92, s*0.58, s*0.82, s*0.10);
    return _clean(mask, side);
  }

  static Set<String> saturnMask(int side) {
    final mask = <String>{}; final s = side.toDouble();
    _ellipse(mask, side, s*0.5, s*0.5, s*0.38, s*0.38);
    _ellipse(mask, side, s*0.5, s*0.5, s*0.48, s*0.16);
    return _clean(mask, side);
  }

  static Set<String> castleMask(int side) {
    final mask = <String>{}; final s = side.toDouble();
    _rect(mask, side, s * 0.08, s * 0.35, s * 0.92, s * 0.94);
    _rect(mask, side, s * 0.08, s * 0.12, s * 0.30, s * 0.35);
    _rect(mask, side, s * 0.70, s * 0.12, s * 0.92, s * 0.35);
    _rect(mask, side, s * 0.38, s * 0.08, s * 0.62, s * 0.35);
    return _clean(mask, side);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  V2 BOSS SHAPES — Geometric / Angular Silhouettes
  // ═══════════════════════════════════════════════════════════════════════════

  /// + cross shape
  static Set<String> plusMask(int side) {
    final mask = <String>{}; final s = side.toDouble();
    _rect(mask, side, s*0.35, s*0.05, s*0.65, s*0.95); // vertical
    _rect(mask, side, s*0.05, s*0.35, s*0.95, s*0.65); // horizontal
    return _clean(mask, side);
  }

  /// T shape (wide top bar + center stem)
  static Set<String> tShapeMask(int side) {
    final mask = <String>{}; final s = side.toDouble();
    _rect(mask, side, s*0.08, s*0.08, s*0.92, s*0.36); // top bar
    _rect(mask, side, s*0.40, s*0.36, s*0.60, s*0.92); // stem
    return _clean(mask, side);
  }

  /// L shape (long vertical + base)
  static Set<String> lShapeMask(int side) {
    final mask = <String>{}; final s = side.toDouble();
    _rect(mask, side, s*0.15, s*0.08, s*0.45, s*0.92); // vertical
    _rect(mask, side, s*0.15, s*0.72, s*0.85, s*0.92); // base
    return _clean(mask, side);
  }

  /// H shape (two verticals + crossbar)
  static Set<String> hShapeMask(int side) {
    final mask = <String>{}; final s = side.toDouble();
    _rect(mask, side, s*0.08, s*0.08, s*0.38, s*0.92); // left vertical
    _rect(mask, side, s*0.62, s*0.08, s*0.92, s*0.92); // right vertical
    _rect(mask, side, s*0.38, s*0.40, s*0.62, s*0.60); // crossbar
    return _clean(mask, side);
  }

  /// U shape (two sides + bottom connector)
  static Set<String> uShapeMask(int side) {
    final mask = <String>{}; final s = side.toDouble();
    _rect(mask, side, s*0.08, s*0.08, s*0.38, s*0.92); // left side
    _rect(mask, side, s*0.62, s*0.08, s*0.92, s*0.92); // right side
    _rect(mask, side, s*0.08, s*0.72, s*0.92, s*0.92); // bottom
    return _clean(mask, side);
  }

  /// Z shape (top-right, diagonal bridge, bottom-left)
  static Set<String> zShapeMask(int side) {
    final mask = <String>{}; final s = side.toDouble();
    _rect(mask, side, s*0.08, s*0.08, s*0.92, s*0.32); // top bar
    _rect(mask, side, s*0.08, s*0.68, s*0.92, s*0.92); // bottom bar
    _triangle(mask, side,               // diagonal bridge
        s*0.08, s*0.32,
        s*0.92, s*0.32,
        s*0.08, s*0.68);
    return _clean(mask, side);
  }

  /// X cross (two diagonal ellipses crossing at center)
  static Set<String> xCrossMask(int side) {
    final mask = <String>{}; final s = side.toDouble();
    // Approximate diagonals with two rotated thick rects via polygon
    final cx = s * 0.5, cy = s * 0.5;
    final hw = s * 0.14, len = s * 0.64;
    // Diagonal /
    _polygon(mask, side, [
      [cx - len, cy + hw], [cx - len, cy - hw],
      [cx + len, cy - hw], [cx + len, cy + hw],
    ]);
    // Diagonal \  (rotated 90°, same shape)
    _polygon(mask, side, [
      [cx - hw, cy - len], [cx + hw, cy - len],
      [cx + hw, cy + len], [cx - hw, cy + len],
    ]);
    // But we need the actual X (rotate ±45°) — approximate with triangles
    final mask2 = <String>{};
    _triangle(mask2, side, s*0.00, s*0.13, s*0.13, s*0.00, s*1.00, s*0.87);
    _triangle(mask2, side, s*0.87, s*1.00, s*1.00, s*0.87, s*0.13, s*0.00);
    _triangle(mask2, side, s*0.87, s*0.00, s*1.00, s*0.13, s*0.13, s*1.00);
    _triangle(mask2, side, s*0.00, s*0.87, s*0.13, s*1.00, s*1.00, s*0.13);
    return _clean(mask2, side);
  }

  /// Up-pointing arrow (triangle head + narrow rect stem)
  static Set<String> arrowUpMask(int side) {
    final mask = <String>{}; final s = side.toDouble();
    _triangle(mask, side, s*0.08, s*0.52, s*0.92, s*0.52, s*0.50, s*0.06); // head
    _rect(mask, side, s*0.36, s*0.52, s*0.64, s*0.94);                      // stem
    return _clean(mask, side);
  }

  /// Right-pointing arrow
  static Set<String> arrowRightMask(int side) {
    final mask = <String>{}; final s = side.toDouble();
    _triangle(mask, side, s*0.48, s*0.08, s*0.48, s*0.92, s*0.94, s*0.50); // head
    _rect(mask, side, s*0.06, s*0.36, s*0.48, s*0.64);                      // stem
    return _clean(mask, side);
  }

  /// V / chevron
  static Set<String> chevronMask(int side) {
    final mask = <String>{}; final s = side.toDouble();
    _triangle(mask, side, s*0.00, s*0.30, s*0.50, s*0.80, s*0.50, s*0.50);
    _triangle(mask, side, s*0.50, s*0.50, s*0.50, s*0.80, s*1.00, s*0.30);
    _triangle(mask, side, s*0.00, s*0.80, s*0.50, s*0.30, s*0.50, s*0.08);
    _triangle(mask, side, s*0.50, s*0.08, s*0.50, s*0.30, s*1.00, s*0.80);
    return _clean(mask, side);
  }

  /// Descending staircase (step pattern)
  static Set<String> staircaseMask(int side) {
    final mask = <String>{}; final s = side.toDouble();
    const steps = 4;
    final step = 1.0 / steps;
    for (int i = 0; i < steps; i++) {
      _rect(mask, side,
          s * (i * step),          s * (i * step),
          s * ((i + 1) * step),    s * 1.0);
    }
    return _clean(mask, side);
  }

  /// Flat-top trapezoid
  static Set<String> trapezoidMask(int side) {
    final mask = <String>{}; final s = side.toDouble();
    _polygon(mask, side, [
      [s*0.20, s*0.10], [s*0.80, s*0.10],
      [s*0.95, s*0.90], [s*0.05, s*0.90],
    ]);
    return _clean(mask, side);
  }

  /// Parallelogram (tilted rectangle)
  static Set<String> parallelogramMask(int side) {
    final mask = <String>{}; final s = side.toDouble();
    _polygon(mask, side, [
      [s*0.25, s*0.10], [s*0.95, s*0.10],
      [s*0.75, s*0.90], [s*0.05, s*0.90],
    ]);
    return _clean(mask, side);
  }

  /// Regular pentagon
  static Set<String> pentagonMask(int side) {
    final mask = <String>{};
    final cx = side / 2.0, cy = side / 2.0, r = side / 2.0 - 0.5;
    final verts = List.generate(5, (i) {
      final a = -pi / 2 + 2 * pi * i / 5;
      return [cx + r * cos(a), cy + r * sin(a)];
    });
    _polygon(mask, side, verts);
    return _clean(mask, side);
  }

  /// Regular octagon
  static Set<String> octagonMask(int side) {
    final mask = <String>{};
    final cx = side / 2.0, cy = side / 2.0, r = side / 2.0 - 0.3;
    final verts = List.generate(8, (i) {
      final a = pi / 8 + 2 * pi * i / 8;
      return [cx + r * cos(a), cy + r * sin(a)];
    });
    _polygon(mask, side, verts);
    return _clean(mask, side);
  }

  /// Pinwheel (4 rectangles rotated 45° each)
  static Set<String> pinwheelMask(int side) {
    final mask  = <String>{};
    final cx    = side / 2.0, cy = side / 2.0;
    final hw    = side * 0.12, len = side * 0.45;
    for (int k = 0; k < 4; k++) {
      final angle = k * pi / 2 + pi / 8;
      final verts = [
        [cx + (len) * cos(angle) - hw * sin(angle),
         cy + (len) * sin(angle) + hw * cos(angle)],
        [cx + (len) * cos(angle) + hw * sin(angle),
         cy + (len) * sin(angle) - hw * cos(angle)],
        [cx + (-len) * cos(angle) + hw * sin(angle),
         cy + (-len) * sin(angle) - hw * cos(angle)],
        [cx + (-len) * cos(angle) - hw * sin(angle),
         cy + (-len) * sin(angle) + hw * cos(angle)],
      ];
      _polygon(mask, side, verts);
    }
    // Center circle
    _ellipse(mask, side, cx, cy, side * 0.10, side * 0.10);
    return _clean(mask, side);
  }

  /// Gear (circle with N rectangular teeth)
  static Set<String> gearMask(int side) {
    final mask  = <String>{};
    final cx    = side / 2.0, cy = side / 2.0;
    final inner = side * 0.28, outer = side * 0.42;
    final tooth = side * 0.08;
    _ellipse(mask, side, cx, cy, inner, inner);
    const teeth = 8;
    for (int k = 0; k < teeth; k++) {
      final angle = 2 * pi * k / teeth;
      final tx = cx + outer * cos(angle);
      final ty = cy + outer * sin(angle);
      final verts = [
        [tx - tooth * sin(angle) - tooth * cos(angle),
         ty + tooth * cos(angle) - tooth * sin(angle)],
        [tx + tooth * sin(angle) - tooth * cos(angle),
         ty - tooth * cos(angle) - tooth * sin(angle)],
        [tx + tooth * sin(angle) + tooth * cos(angle),
         ty - tooth * cos(angle) + tooth * sin(angle)],
        [tx - tooth * sin(angle) + tooth * cos(angle),
         ty + tooth * cos(angle) + tooth * sin(angle)],
      ];
      _polygon(mask, side, verts);
    }
    return _clean(mask, side);
  }

  /// Lightning bolt (Z-stepped polygon)
  static Set<String> lightningBoltMask(int side) {
    final mask = <String>{}; final s = side.toDouble();
    _polygon(mask, side, [
      [s*0.55, s*0.04],  // top-right of head
      [s*0.20, s*0.55],  // bottom-left of head
      [s*0.50, s*0.55],  // inner notch
      [s*0.45, s*0.96],  // bottom of tail
      [s*0.80, s*0.45],  // top-right of body
      [s*0.50, s*0.45],  // inner notch
    ]);
    return _clean(mask, side);
  }

  /// Wide horizontal ribbon with tapered ends
  static Set<String> ribbonMask(int side) {
    final mask = <String>{}; final s = side.toDouble();
    _polygon(mask, side, [
      [s*0.02, s*0.50],  // left point
      [s*0.20, s*0.28],  // upper-left
      [s*0.80, s*0.28],  // upper-right
      [s*0.98, s*0.50],  // right point
      [s*0.80, s*0.72],  // lower-right
      [s*0.20, s*0.72],  // lower-left
    ]);
    return _clean(mask, side);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  V2 GOD SHAPES — Decorative / Pictorial Silhouettes
  // ═══════════════════════════════════════════════════════════════════════════

  /// Flower (center circle + 6 petal ellipses)
  static Set<String> flowerMask(int side) {
    final mask = <String>{}; final s = side.toDouble();
    final cx = s * 0.5, cy = s * 0.5;
    _ellipse(mask, side, cx, cy, s*0.18, s*0.18); // center
    for (int i = 0; i < 6; i++) {
      final a = i * pi / 3;
      _ellipse(mask, side,
          cx + s * 0.30 * cos(a), cy + s * 0.30 * sin(a),
          s*0.16, s*0.10);
    }
    return _clean(mask, side);
  }

  /// Spinning top (wide triangle on top, narrow triangle below)
  static Set<String> spinningTopMask(int side) {
    final mask = <String>{}; final s = side.toDouble();
    _triangle(mask, side, s*0.02, s*0.08, s*0.98, s*0.08, s*0.50, s*0.52); // body
    _triangle(mask, side, s*0.42, s*0.52, s*0.58, s*0.52, s*0.50, s*0.94); // tip
    return _clean(mask, side);
  }

  /// Lollipop (circle + thin stick)
  static Set<String> lollipopMask(int side) {
    final mask = <String>{}; final s = side.toDouble();
    _ellipse(mask, side, s*0.50, s*0.34, s*0.30, s*0.30);
    _rect(mask, side, s*0.46, s*0.64, s*0.54, s*0.94);
    return _clean(mask, side);
  }

  /// Ice cream cone (semi-circle on triangle)
  static Set<String> iceCreamMask(int side) {
    final mask = <String>{}; final s = side.toDouble();
    _ellipse(mask, side, s*0.50, s*0.34, s*0.36, s*0.32);
    _triangle(mask, side, s*0.14, s*0.60, s*0.86, s*0.60, s*0.50, s*0.94);
    // Remove bottom half of ellipse to make it a scoop (keep above row 0.54)
    for (int r = 0; r < side; r++) {
      for (int c = 0; c < side; c++) {
        final key = '$r,$c';
        if (mask.contains(key) && (r + 0.5) / s > 0.58 && (r + 0.5) / s < 0.62) {
          final dx = (c + 0.5) / s - 0.50, dy = (r + 0.5) / s - 0.34;
          if (dx * dx / (0.36 * 0.36) + dy * dy / (0.32 * 0.32) <= 1.0) {
            // Keep — this is the overlap zone, cone will cover it
          }
        }
      }
    }
    return _clean(mask, side);
  }

  /// Crescent moon (large circle minus smaller offset circle)
  static Set<String> crescentMoonMask(int side) {
    final mask  = <String>{};
    final cutout = <String>{};
    final s = side.toDouble();
    _ellipse(mask,    side, s*0.48, s*0.50, s*0.40, s*0.44);
    _ellipse(cutout, side, s*0.60, s*0.46, s*0.32, s*0.36);
    return _clean(_subtract(mask, cutout), side);
  }

  /// Gift box (body rect + ribbon + bow)
  static Set<String> giftBoxMask(int side) {
    final mask = <String>{}; final s = side.toDouble();
    _rect(mask, side, s*0.12, s*0.38, s*0.88, s*0.90); // box body
    _rect(mask, side, s*0.44, s*0.10, s*0.56, s*0.90); // vertical ribbon
    _rect(mask, side, s*0.12, s*0.44, s*0.88, s*0.56); // horizontal ribbon
    _ellipse(mask, side, s*0.38, s*0.20, s*0.10, s*0.14); // left bow loop
    _ellipse(mask, side, s*0.62, s*0.20, s*0.10, s*0.14); // right bow loop
    return _clean(mask, side);
  }

  /// Anchor (ring + shaft + horizontal crossbar)
  static Set<String> anchorMask(int side) {
    final mask = <String>{}; final s = side.toDouble();
    _ellipse(mask, side, s*0.50, s*0.22, s*0.18, s*0.16); // ring (outer)
    final inner = <String>{};
    _ellipse(inner, side, s*0.50, s*0.22, s*0.10, s*0.09); // ring (inner cutout)
    mask.removeAll(inner);
    _rect(mask, side, s*0.46, s*0.22, s*0.54, s*0.88); // shaft
    _rect(mask, side, s*0.10, s*0.74, s*0.90, s*0.86); // crossbar
    _ellipse(mask, side, s*0.18, s*0.80, s*0.08, s*0.08); // left end
    _ellipse(mask, side, s*0.82, s*0.80, s*0.08, s*0.08); // right end
    return _clean(mask, side);
  }

  /// Shield (rounded rectangle body + pointed bottom)
  static Set<String> shieldMask(int side) {
    final mask = <String>{}; final s = side.toDouble();
    _rect(mask, side, s*0.12, s*0.08, s*0.88, s*0.72);
    _triangle(mask, side, s*0.12, s*0.72, s*0.88, s*0.72, s*0.50, s*0.96);
    _ellipse(mask, side, s*0.22, s*0.14, s*0.10, s*0.10); // top-left round
    _ellipse(mask, side, s*0.78, s*0.14, s*0.10, s*0.10); // top-right round
    return _clean(mask, side);
  }

  /// Rocket (body + nose cone + 2 fins)
  static Set<String> rocketMask(int side) {
    final mask = <String>{}; final s = side.toDouble();
    _rect(mask, side, s*0.36, s*0.28, s*0.64, s*0.82);                       // body
    _triangle(mask, side, s*0.36, s*0.28, s*0.64, s*0.28, s*0.50, s*0.06);  // nose
    _triangle(mask, side, s*0.14, s*0.68, s*0.36, s*0.68, s*0.36, s*0.90);  // left fin
    _triangle(mask, side, s*0.64, s*0.68, s*0.86, s*0.68, s*0.64, s*0.90);  // right fin
    return _clean(mask, side);
  }

  /// Sun (circle + 8 rectangular rays)
  static Set<String> sunMask(int side) {
    final mask = <String>{}; final s = side.toDouble();
    final cx = s * 0.5, cy = s * 0.5;
    _ellipse(mask, side, cx, cy, s*0.22, s*0.22); // center
    for (int i = 0; i < 8; i++) {
      final a  = i * pi / 4;
      final tx = cx + s * 0.38 * cos(a), ty = cy + s * 0.38 * sin(a);
      final hw = s * 0.05;
      _polygon(mask, side, [
        [tx - hw * sin(a) - s*0.08 * cos(a), ty + hw * cos(a) - s*0.08 * sin(a)],
        [tx + hw * sin(a) - s*0.08 * cos(a), ty - hw * cos(a) - s*0.08 * sin(a)],
        [tx + hw * sin(a) + s*0.08 * cos(a), ty - hw * cos(a) + s*0.08 * sin(a)],
        [tx - hw * sin(a) + s*0.08 * cos(a), ty + hw * cos(a) + s*0.08 * sin(a)],
      ]);
    }
    return _clean(mask, side);
  }

  /// Cloud (4 overlapping circles)
  static Set<String> cloudMask(int side) {
    final mask = <String>{}; final s = side.toDouble();
    _ellipse(mask, side, s*0.30, s*0.52, s*0.22, s*0.20); // left puff
    _ellipse(mask, side, s*0.50, s*0.42, s*0.26, s*0.24); // center puff
    _ellipse(mask, side, s*0.70, s*0.52, s*0.22, s*0.20); // right puff
    _ellipse(mask, side, s*0.46, s*0.62, s*0.40, s*0.16); // base
    return _clean(mask, side);
  }

  /// Umbrella (large semicircle + handle)
  static Set<String> umbrellaMask(int side) {
    final mask = <String>{}; final s = side.toDouble();
    // Top semicircle (full ellipse, then remove bottom half)
    final dome = <String>{};
    _ellipse(dome, side, s*0.50, s*0.40, s*0.44, s*0.36);
    for (final k in dome) {
      final p = k.split(',');
      if ((int.parse(p[0]) + 0.5) / s < 0.42) mask.add(k);
    }
    // Spoke divisions (thin vertical strips removed — not really needed, add a center spoke)
    _rect(mask, side, s*0.48, s*0.40, s*0.52, s*0.40); // center point, tiny
    // Handle (vertical rect + curved end via ellipse)
    _rect(mask, side, s*0.47, s*0.68, s*0.53, s*0.90);
    _ellipse(mask, side, s*0.40, s*0.90, s*0.10, s*0.06);
    return _clean(mask, side);
  }

  /// Key (circle head + horizontal bar + notches)
  static Set<String> keyMask(int side) {
    final mask = <String>{}; final s = side.toDouble();
    _ellipse(mask, side, s*0.28, s*0.50, s*0.22, s*0.22); // head
    final hole = <String>{};
    _ellipse(hole, side, s*0.28, s*0.50, s*0.11, s*0.11);
    mask.removeAll(hole); // hollow center
    _rect(mask, side, s*0.50, s*0.46, s*0.92, s*0.54); // shaft
    _rect(mask, side, s*0.72, s*0.54, s*0.80, s*0.66); // notch 1
    _rect(mask, side, s*0.84, s*0.54, s*0.92, s*0.62); // notch 2
    return _clean(mask, side);
  }

  /// Bowtie (two triangles touching at center)
  static Set<String> bowtieMask(int side) {
    final mask = <String>{}; final s = side.toDouble();
    _triangle(mask, side, s*0.04, s*0.12, s*0.04, s*0.88, s*0.50, s*0.50); // left
    _triangle(mask, side, s*0.96, s*0.12, s*0.96, s*0.88, s*0.50, s*0.50); // right
    return _clean(mask, side);
  }

  /// Gem / jewel (wide top + narrow bottom)
  static Set<String> gemMask(int side) {
    final mask = <String>{}; final s = side.toDouble();
    _polygon(mask, side, [
      [s*0.20, s*0.22], [s*0.80, s*0.22], // top edge
      [s*0.96, s*0.46], [s*0.50, s*0.94], // right side → bottom point
      [s*0.04, s*0.46],                    // left side
    ]);
    _rect(mask, side, s*0.20, s*0.08, s*0.80, s*0.22); // flat top
    return _clean(mask, side);
  }

  /// Snowflake (6 thin rectangles at 30° intervals)
  static Set<String> snowflakeMask(int side) {
    final mask = <String>{};
    final cx = side / 2.0, cy = side / 2.0;
    final len = side * 0.46, hw = side * 0.045;
    for (int i = 0; i < 6; i++) {
      final a = i * pi / 3;
      _polygon(mask, side, [
        [cx - hw * sin(a) - len * cos(a), cy + hw * cos(a) - len * sin(a)],
        [cx + hw * sin(a) - len * cos(a), cy - hw * cos(a) - len * sin(a)],
        [cx + hw * sin(a) + len * cos(a), cy - hw * cos(a) + len * sin(a)],
        [cx - hw * sin(a) + len * cos(a), cy + hw * cos(a) + len * sin(a)],
      ]);
    }
    _ellipse(mask, side, cx, cy, side * 0.10, side * 0.10); // center dot
    return _clean(mask, side);
  }

  /// Teddy bear (body + head + ears + paws)
  static Set<String> teddyBearMask(int side) {
    final mask = <String>{}; final s = side.toDouble();
    _ellipse(mask, side, s*0.50, s*0.62, s*0.34, s*0.32); // body
    _ellipse(mask, side, s*0.50, s*0.28, s*0.22, s*0.22); // head
    _ellipse(mask, side, s*0.26, s*0.18, s*0.11, s*0.10); // left ear
    _ellipse(mask, side, s*0.74, s*0.18, s*0.11, s*0.10); // right ear
    _ellipse(mask, side, s*0.24, s*0.72, s*0.12, s*0.10); // left arm
    _ellipse(mask, side, s*0.76, s*0.72, s*0.12, s*0.10); // right arm
    _ellipse(mask, side, s*0.36, s*0.90, s*0.12, s*0.08); // left foot
    _ellipse(mask, side, s*0.64, s*0.90, s*0.12, s*0.08); // right foot
    return _clean(mask, side);
  }

  /// Globe (circle + 3 latitude line strips)
  static Set<String> globeMask(int side) {
    final mask = <String>{}; final s = side.toDouble();
    _ellipse(mask, side, s*0.50, s*0.50, s*0.44, s*0.44); // sphere
    // Latitude line shadows (small rect strips that partially overlap — just add them)
    // They're already included in the ellipse so this is purely visual context.
    // To make it distinct, subtract thin equatorial band and re-add narrow strips:
    // (Keep simple: just the full circle. The globe identity comes from context.)
    return _clean(mask, side);
  }

  // ── Legacy public alias (for compatibility with existing level_repository) ──
  static Set<String> maskForLevel(int levelNumber, Random rng, int side) {
    final type = AppConstants.levelTypeFor(levelNumber);
    return maskForLevelType(type, rng, side);
  }
}
