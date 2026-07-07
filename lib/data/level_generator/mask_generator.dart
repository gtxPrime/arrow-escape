import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../../core/constants.dart';

/// Parametric mask generator for puzzle canvas shapes.
///
/// Normal levels  → squareMask   (plain N×N grid)
/// Boss levels    → animal / object shapes (cat, dog, frog, fox, tiger, panda,
///                  fish, bird, butterfly, guitar, tree, house, crown)
/// God levels     → dramatic geometric shapes (heart, star, diamond, hexagon, blob)
///
/// All shapes are generated from pure math — no images, no assets.
/// Every function takes [side] (bounding-box cell count) and returns a
/// Set<String> of 'row,col' keys representing valid playable cells.
class MaskGenerator {
  MaskGenerator._();

  // ── Public API ────────────────────────────────────────────────────────────────

  /// Pick and generate the right mask shape for a level type.
  static Set<String> maskForLevelType(LevelType type, Random rng, int side) {
    switch (type) {
      case LevelType.tutorial:
      case LevelType.normal:
        return squareMask(side);

      case LevelType.boss:
        return _randomBossShape(side, rng);

      case LevelType.god:
        return _randomGodShape(side, rng);
    }
  }

  // ── Boss shapes: animals + objects ────────────────────────────────────────────

  static const List<String> _bossShapeNames = [
    'cat', 'dog', 'frog', 'fox', 'tiger', 'panda',
    'fish', 'bird', 'butterfly',
    'guitar', 'tree', 'house', 'crown', 'saturn',
  ];

  static Set<String> _randomBossShape(int side, Random rng) {
    final name = _bossShapeNames[rng.nextInt(_bossShapeNames.length)];
    return shapeByName(name, side, rng);
  }

  // ── God shapes: dramatic geometric ───────────────────────────────────────────

  static const List<String> _godShapeNames = [
    'heart', 'star', 'diamond', 'hexagon', 'blob', 'circle',
  ];

  static Set<String> _randomGodShape(int side, Random rng) {
    final name = _godShapeNames[rng.nextInt(_godShapeNames.length)];
    return shapeByName(name, side, rng);
  }

  // ── Shape by name ─────────────────────────────────────────────────────────────

  static Set<String> shapeByName(String name, int side, Random rng) {
    switch (name) {
      // Animals
      case 'cat':       return catMask(side);
      case 'dog':       return dogMask(side);
      case 'frog':      return frogMask(side);
      case 'fox':       return foxMask(side);
      case 'tiger':     return tigerMask(side);
      case 'panda':     return pandaMask(side);
      case 'fish':      return fishMask(side);
      case 'bird':      return birdMask(side);
      case 'butterfly': return butterflyMask(side);
      // Objects
      case 'guitar':    return guitarMask(side);
      case 'tree':      return treeMask(side);
      case 'house':     return houseMask(side);
      case 'crown':     return crownMask(side);
      case 'saturn':    return saturnMask(side);
      // Geometric
      case 'heart':     return heartMask(side);
      case 'star':      return starMask(side, 5);
      case 'diamond':   return diamondMask(side);
      case 'hexagon':   return hexagonMask(side);
      case 'blob':      return blobMask(side, rng.nextInt(9999));
      case 'circle':    return circleMask(side);
      default:          return squareMask(side);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  GEOMETRIC PRIMITIVES (helpers)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Add cells whose center lies inside the ellipse cx,cy,rx,ry (in cell units).
  static void _ellipse(Set<String> mask, int side,
      double cx, double cy, double rx, double ry) {
    for (int r = 0; r < side; r++) {
      for (int c = 0; c < side; c++) {
        final dx = (c + 0.5 - cx) / rx;
        final dy = (r + 0.5 - cy) / ry;
        if (dx * dx + dy * dy <= 1.0) mask.add('$r,$c');
      }
    }
  }

  /// Add cells whose center lies inside the rectangle [x1,x2] × [y1,y2].
  static void _rect(Set<String> mask, int side,
      double x1, double y1, double x2, double y2) {
    for (int r = 0; r < side; r++) {
      for (int c = 0; c < side; c++) {
        final px = c + 0.5, py = r + 0.5;
        if (px >= x1 && px <= x2 && py >= y1 && py <= y2) mask.add('$r,$c');
      }
    }
  }

  /// Add cells whose center lies inside a triangle (ax,ay)–(bx,by)–(cx2,cy2).
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

  // ═══════════════════════════════════════════════════════════════════════════
  //  GEOMETRIC SHAPES (classic)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Full N×N square — normal level default.
  static Set<String> squareMask(int side) {
    final mask = <String>{};
    for (int r = 0; r < side; r++) {
      for (int c = 0; c < side; c++) mask.add('$r,$c');
    }
    return mask;
  }

  /// Circle / ellipse.
  static Set<String> circleMask(int side) {
    final mask = <String>{};
    final cx = side / 2.0, cy = side / 2.0;
    final r = side / 2.0 - 0.4;
    _ellipse(mask, side, cx, cy, r, r);
    return _clean(mask, side);
  }

  /// Heart silhouette (parametric equation).
  static Set<String> heartMask(int side) {
    final mask = <String>{};
    final s = side.toDouble();
    for (int r = 0; r < side; r++) {
      for (int c = 0; c < side; c++) {
        final x = (c + 0.5) / s * 2.0 - 1.0;
        final y = -(((r + 0.5) / s) * 2.0 - 1.0) * 0.92 + 0.04;
        // Heart: (x²+y²-1)³ - x²·y³ ≤ 0
        final v = pow(x * x + y * y - 1, 3).toDouble() - x * x * y * y * y;
        if (v <= 0.0) mask.add('$r,$c');
      }
    }
    return _clean(mask, side);
  }

  /// N-point star.
  static Set<String> starMask(int side, int points) {
    final mask = <String>{};
    final cx = side / 2.0, cy = side / 2.0;
    final outerR = side / 2.0 - 0.3;
    final innerR = outerR * 0.42;
    final step = pi / points;
    for (int r = 0; r < side; r++) {
      for (int c = 0; c < side; c++) {
        final dx = c + 0.5 - cx, dy = r + 0.5 - cy;
        final angle = atan2(dy, dx);
        final dist = sqrt(dx * dx + dy * dy);
        final mod = ((angle + pi) / step) % 2.0;
        final limit = mod < 1.0
            ? outerR * mod + innerR * (1 - mod)
            : outerR * (2 - mod) + innerR * (mod - 1);
        if (dist <= limit + 0.55) mask.add('$r,$c');
      }
    }
    return _clean(mask, side);
  }

  /// Diamond / rhombus.
  static Set<String> diamondMask(int side) {
    final mask = <String>{};
    final cx = side / 2.0, cy = side / 2.0;
    final r = side / 2.0 - 0.3;
    for (int row = 0; row < side; row++) {
      for (int col = 0; col < side; col++) {
        if ((col + 0.5 - cx).abs() + (row + 0.5 - cy).abs() <= r + 0.55) {
          mask.add('$row,$col');
        }
      }
    }
    return _clean(mask, side);
  }

  /// Flat-top hexagon.
  static Set<String> hexagonMask(int side) {
    final mask = <String>{};
    final cx = side / 2.0, cy = side / 2.0;
    final r = side / 2.0 - 0.5;
    for (int row = 0; row < side; row++) {
      for (int col = 0; col < side; col++) {
        final dx = (col + 0.5 - cx).abs();
        final dy = (row + 0.5 - cy).abs();
        if (dx <= r && dy <= r * 0.866 && dx + dy * 1.155 <= r * 2.0) {
          mask.add('$row,$col');
        }
      }
    }
    return _clean(mask, side);
  }

  /// Organic blob via superformula.
  static Set<String> blobMask(int side, int seed) {
    final rng = Random(seed);
    final mask = <String>{};
    final cx = side / 2.0, cy = side / 2.0;
    final baseR = side / 2.0 - 0.8;
    final a1 = 0.12 + rng.nextDouble() * 0.08;
    final a2 = 0.07 + rng.nextDouble() * 0.06;
    final phi1 = rng.nextDouble() * 2 * pi;
    final phi2 = rng.nextDouble() * 2 * pi;
    final f1 = (rng.nextInt(3) + 2).toDouble();
    final f2 = (rng.nextInt(4) + 5).toDouble();
    for (int r = 0; r < side; r++) {
      for (int c = 0; c < side; c++) {
        final dx = c + 0.5 - cx, dy = r + 0.5 - cy;
        final angle = atan2(dy, dx);
        final dist  = sqrt(dx * dx + dy * dy);
        final limit = baseR * (1.0 + a1 * sin(f1 * angle + phi1) + a2 * sin(f2 * angle + phi2));
        if (dist <= limit) mask.add('$r,$c');
      }
    }
    return _clean(mask, side);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  ANIMAL SHAPES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Cat face: round head + two pointed ears.
  static Set<String> catMask(int side) {
    final mask = <String>{};
    final s = side.toDouble();
    // Head circle — centre slightly below mid, radius 42%
    _ellipse(mask, side, s * 0.5, s * 0.56, s * 0.42, s * 0.40);
    // Left ear (triangle)
    _triangle(mask, side,
        s * 0.18, s * 0.28,   // base-left
        s * 0.38, s * 0.28,   // base-right
        s * 0.27, s * 0.05);  // tip
    // Right ear
    _triangle(mask, side,
        s * 0.62, s * 0.28,
        s * 0.82, s * 0.28,
        s * 0.73, s * 0.05);
    return _clean(mask, side);
  }

  /// Dog face: round head + two droopy ears.
  static Set<String> dogMask(int side) {
    final mask = <String>{};
    final s = side.toDouble();
    // Head
    _ellipse(mask, side, s * 0.5, s * 0.48, s * 0.37, s * 0.36);
    // Left droopy ear
    _ellipse(mask, side, s * 0.18, s * 0.55, s * 0.14, s * 0.26);
    // Right droopy ear
    _ellipse(mask, side, s * 0.82, s * 0.55, s * 0.14, s * 0.26);
    // Snout bump
    _ellipse(mask, side, s * 0.5, s * 0.74, s * 0.18, s * 0.11);
    return _clean(mask, side);
  }

  /// Frog: wide flat oval + big bulge eyes at top.
  static Set<String> frogMask(int side) {
    final mask = <String>{};
    final s = side.toDouble();
    // Body (wide oval)
    _ellipse(mask, side, s * 0.5, s * 0.60, s * 0.44, s * 0.34);
    // Left eye
    _ellipse(mask, side, s * 0.28, s * 0.28, s * 0.13, s * 0.12);
    // Right eye
    _ellipse(mask, side, s * 0.72, s * 0.28, s * 0.13, s * 0.12);
    // Back legs bumps (bottom corners)
    _ellipse(mask, side, s * 0.18, s * 0.82, s * 0.16, s * 0.12);
    _ellipse(mask, side, s * 0.82, s * 0.82, s * 0.16, s * 0.12);
    return _clean(mask, side);
  }

  /// Fox: pointed ears + round-ish face + narrow chin.
  static Set<String> foxMask(int side) {
    final mask = <String>{};
    final s = side.toDouble();
    // Face — slightly tall ellipse
    _ellipse(mask, side, s * 0.5, s * 0.55, s * 0.34, s * 0.38);
    // Large pointed left ear
    _triangle(mask, side,
        s * 0.10, s * 0.42,
        s * 0.38, s * 0.30,
        s * 0.22, s * 0.04);
    // Large pointed right ear
    _triangle(mask, side,
        s * 0.62, s * 0.30,
        s * 0.90, s * 0.42,
        s * 0.78, s * 0.04);
    // Narrow snout bridge
    _ellipse(mask, side, s * 0.5, s * 0.76, s * 0.14, s * 0.10);
    return _clean(mask, side);
  }

  /// Tiger: wide face + small rounded ears.
  static Set<String> tigerMask(int side) {
    final mask = <String>{};
    final s = side.toDouble();
    // Wide round face
    _ellipse(mask, side, s * 0.5, s * 0.54, s * 0.44, s * 0.40);
    // Small left ear
    _ellipse(mask, side, s * 0.22, s * 0.20, s * 0.11, s * 0.10);
    // Small right ear
    _ellipse(mask, side, s * 0.78, s * 0.20, s * 0.11, s * 0.10);
    return _clean(mask, side);
  }

  /// Panda: round face + two round ears.
  static Set<String> pandaMask(int side) {
    final mask = <String>{};
    final s = side.toDouble();
    // Big round face
    _ellipse(mask, side, s * 0.5, s * 0.54, s * 0.40, s * 0.40);
    // Left round ear
    _ellipse(mask, side, s * 0.26, s * 0.16, s * 0.14, s * 0.13);
    // Right round ear
    _ellipse(mask, side, s * 0.74, s * 0.16, s * 0.14, s * 0.13);
    return _clean(mask, side);
  }

  /// Fish: oval body + forked triangle tail.
  static Set<String> fishMask(int side) {
    final mask = <String>{};
    final s = side.toDouble();
    // Body (oval)
    _ellipse(mask, side, s * 0.42, s * 0.5, s * 0.38, s * 0.24);
    // Tail — upper triangle
    _triangle(mask, side,
        s * 0.78, s * 0.32,
        s * 0.98, s * 0.18,
        s * 0.88, s * 0.50);
    // Tail — lower triangle
    _triangle(mask, side,
        s * 0.78, s * 0.68,
        s * 0.98, s * 0.82,
        s * 0.88, s * 0.50);
    return _clean(mask, side);
  }

  /// Bird: oval body + two rounded wings + tail.
  static Set<String> birdMask(int side) {
    final mask = <String>{};
    final s = side.toDouble();
    // Body
    _ellipse(mask, side, s * 0.5, s * 0.52, s * 0.26, s * 0.20);
    // Left wing
    _ellipse(mask, side, s * 0.21, s * 0.48, s * 0.24, s * 0.14);
    // Right wing
    _ellipse(mask, side, s * 0.79, s * 0.48, s * 0.24, s * 0.14);
    // Tail (small downward triangle)
    _triangle(mask, side,
        s * 0.38, s * 0.70,
        s * 0.62, s * 0.70,
        s * 0.50, s * 0.90);
    // Small round head
    _ellipse(mask, side, s * 0.50, s * 0.31, s * 0.12, s * 0.12);
    return _clean(mask, side);
  }

  /// Butterfly: 4 oval wings + slender body.
  static Set<String> butterflyMask(int side) {
    final mask = <String>{};
    final s = side.toDouble();
    // Upper-left wing
    _ellipse(mask, side, s * 0.26, s * 0.33, s * 0.24, s * 0.28);
    // Upper-right wing
    _ellipse(mask, side, s * 0.74, s * 0.33, s * 0.24, s * 0.28);
    // Lower-left wing (slightly smaller)
    _ellipse(mask, side, s * 0.28, s * 0.67, s * 0.20, s * 0.22);
    // Lower-right wing
    _ellipse(mask, side, s * 0.72, s * 0.67, s * 0.20, s * 0.22);
    // Slender body
    _ellipse(mask, side, s * 0.50, s * 0.50, s * 0.055, s * 0.40);
    return _clean(mask, side);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  OBJECT SHAPES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Guitar: figure-8 hourglass body + neck rectangle.
  static Set<String> guitarMask(int side) {
    final mask = <String>{};
    final s = side.toDouble();
    // Lower bout (larger)
    _ellipse(mask, side, s * 0.5, s * 0.70, s * 0.30, s * 0.25);
    // Upper bout (slightly smaller)
    _ellipse(mask, side, s * 0.5, s * 0.40, s * 0.24, s * 0.20);
    // Neck (rectangle going up from upper bout)
    _rect(mask, side, s * 0.43, s * 0.04, s * 0.57, s * 0.24);
    // Waist connector (thin horizontal rectangle between bouts)
    _rect(mask, side, s * 0.38, s * 0.56, s * 0.62, s * 0.66);
    return _clean(mask, side);
  }

  /// Tree: rounded triangle crown + rectangle trunk.
  static Set<String> treeMask(int side) {
    final mask = <String>{};
    final s = side.toDouble();
    // Crown (large circle-ish top)
    _ellipse(mask, side, s * 0.5, s * 0.38, s * 0.36, s * 0.34);
    // Trunk
    _rect(mask, side, s * 0.42, s * 0.68, s * 0.58, s * 0.94);
    return _clean(mask, side);
  }

  /// House: rectangle walls + triangle roof.
  static Set<String> houseMask(int side) {
    final mask = <String>{};
    final s = side.toDouble();
    // Walls
    _rect(mask, side, s * 0.10, s * 0.44, s * 0.90, s * 0.92);
    // Roof (isoceles triangle)
    _triangle(mask, side,
        s * 0.0,  s * 0.44,
        s * 1.0,  s * 0.44,
        s * 0.5,  s * 0.06);
    return _clean(mask, side);
  }

  /// Crown: base rectangle + three pointed spikes.
  static Set<String> crownMask(int side) {
    final mask = <String>{};
    final s = side.toDouble();
    // Base band
    _rect(mask, side, s * 0.08, s * 0.58, s * 0.92, s * 0.90);
    // Left spike
    _triangle(mask, side,
        s * 0.08, s * 0.58,
        s * 0.28, s * 0.58,
        s * 0.18, s * 0.10);
    // Center spike (tallest)
    _triangle(mask, side,
        s * 0.36, s * 0.58,
        s * 0.64, s * 0.58,
        s * 0.50, s * 0.04);
    // Right spike
    _triangle(mask, side,
        s * 0.72, s * 0.58,
        s * 0.92, s * 0.58,
        s * 0.82, s * 0.10);
    return _clean(mask, side);
  }

  /// Saturn: sphere + flat wide ring ellipse.
  static Set<String> saturnMask(int side) {
    final mask = <String>{};
    final s = side.toDouble();
    // Sphere
    _ellipse(mask, side, s * 0.5, s * 0.5, s * 0.26, s * 0.26);
    // Flat wide ring
    _ellipse(mask, side, s * 0.5, s * 0.5, s * 0.46, s * 0.085);
    return _clean(mask, side);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SVG PATH MASK (Lucide icon d-path → cell grid)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Built-in Lucide icon SVG path data (24×24 viewBox).
  static const Map<String, String> lucidePaths = {
    'heart':
        'M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z',
    'star':
        'M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z',
    'shield':
        'M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z',
    'zap':
        'M13 2 3 14h9l-1 8 10-12h-9l1-8z',
    'cloud':
        'M17.5 19H9a7 7 0 1 1 6.71-9h1.79a4.5 4.5 0 1 1 0 9z',
    'droplet':
        'M12 22a7 7 0 0 0 7-7c0-2-1-3.9-3-5.5s-3.5-4-4-6.5c-.5 2.5-2 4.9-4 6.5C6 11.1 5 13 5 15a7 7 0 0 0 7 7z',
  };

  /// Rasterize an SVG path d-string into a cell mask.
  /// Accepts any Lucide icon path (24×24 viewBox by default).
  static Set<String> svgPathMask(int side, String svgPathData,
      {double viewBoxSize = 24.0}) {
    final mask = <String>{};
    const margin = 0.5;
    final scale = (side - 2 * margin) / viewBoxSize;
    final flutterPath = _parseSvgPath(svgPathData);
    final tx = margin, ty = margin;
    final matrix = Float64List(16)
      ..[0]  = scale
      ..[5]  = scale
      ..[10] = 1.0
      ..[12] = tx
      ..[13] = ty
      ..[15] = 1.0;
    final scaledPath = flutterPath.transform(matrix);
    for (int r = 0; r < side; r++) {
      for (int c = 0; c < side; c++) {
        if (scaledPath.contains(Offset(c + 0.5, r + 0.5))) {
          mask.add('$r,$c');
        }
      }
    }
    return _clean(mask, side);
  }

  // ── Minimal SVG path parser ────────────────────────────────────────────────

  static Path _parseSvgPath(String d) {
    final path = Path();
    final tokens = _tokenize(d);
    int i = 0;
    double cx = 0, cy = 0, sx = 0, sy = 0;

    while (i < tokens.length) {
      final cmd = tokens[i++];
      switch (cmd) {
        case 'M': case 'm':
          while (i < tokens.length && _num(tokens[i])) {
            final x = double.parse(tokens[i++]), y = double.parse(tokens[i++]);
            cmd == 'm' ? (cx += x, cy += y) : (cx = x, cy = y);
            path.moveTo(cx, cy); sx = cx; sy = cy;
          }
        case 'L': case 'l':
          while (i < tokens.length && _num(tokens[i])) {
            final x = double.parse(tokens[i++]), y = double.parse(tokens[i++]);
            cmd == 'l' ? (cx += x, cy += y) : (cx = x, cy = y);
            path.lineTo(cx, cy);
          }
        case 'H': case 'h':
          while (i < tokens.length && _num(tokens[i])) {
            final v = double.parse(tokens[i++]);
            cx = cmd == 'h' ? cx + v : v; path.lineTo(cx, cy);
          }
        case 'V': case 'v':
          while (i < tokens.length && _num(tokens[i])) {
            final v = double.parse(tokens[i++]);
            cy = cmd == 'v' ? cy + v : v; path.lineTo(cx, cy);
          }
        case 'C': case 'c':
          while (i < tokens.length && _num(tokens[i])) {
            final x1 = double.parse(tokens[i++]), y1 = double.parse(tokens[i++]);
            final x2 = double.parse(tokens[i++]), y2 = double.parse(tokens[i++]);
            final x  = double.parse(tokens[i++]), y  = double.parse(tokens[i++]);
            cmd == 'c'
                ? path.cubicTo(cx+x1, cy+y1, cx+x2, cy+y2, cx+x, cy+y)
                : path.cubicTo(x1, y1, x2, y2, x, y);
            cmd == 'c' ? (cx += x, cy += y) : (cx = x, cy = y);
          }
        case 'Q': case 'q':
          while (i < tokens.length && _num(tokens[i])) {
            final x1 = double.parse(tokens[i++]), y1 = double.parse(tokens[i++]);
            final x  = double.parse(tokens[i++]), y  = double.parse(tokens[i++]);
            cmd == 'q'
                ? path.quadraticBezierTo(cx+x1, cy+y1, cx+x, cy+y)
                : path.quadraticBezierTo(x1, y1, x, y);
            cmd == 'q' ? (cx += x, cy += y) : (cx = x, cy = y);
          }
        case 'A': case 'a':
          while (i < tokens.length && _num(tokens[i])) {
            i++; i++; i++; i++; i++; // skip rx,ry,rot,large-arc,sweep
            final x = double.parse(tokens[i++]), y = double.parse(tokens[i++]);
            cmd == 'a' ? (cx += x, cy += y) : (cx = x, cy = y);
            path.lineTo(cx, cy);
          }
        case 'Z': case 'z':
          path.close(); cx = sx; cy = sy;
      }
    }
    path.fillType = PathFillType.nonZero;
    return path;
  }

  static bool _num(String s) {
    if (s.isEmpty) return false;
    final c = s.codeUnitAt(0);
    return c == 45 || c == 46 || (c >= 48 && c <= 57); // '-', '.', '0'-'9'
  }

  static List<String> _tokenize(String d) {
    final out = <String>[];
    final sb = StringBuffer();
    for (int i = 0; i < d.length; i++) {
      final ch = d[i];
      if (RegExp(r'[MmLlHhVvCcQqAaZz]').hasMatch(ch)) {
        if (sb.isNotEmpty) { out.add(sb.toString()); sb.clear(); }
        out.add(ch);
      } else if (ch == ',' || ch == ' ' || ch == '\t' || ch == '\n') {
        if (sb.isNotEmpty) { out.add(sb.toString()); sb.clear(); }
      } else if (ch == '-' && sb.isNotEmpty) {
        out.add(sb.toString()); sb.clear(); sb.write(ch);
      } else {
        sb.write(ch);
      }
    }
    if (sb.isNotEmpty) out.add(sb.toString());
    return out.where((s) => s.isNotEmpty).toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  FLOOD-FILL ISLAND CLEANUP
  // ═══════════════════════════════════════════════════════════════════════════

  /// Keep only the largest connected region — strips isolated cells that can't
  /// hold a valid arrow with a legal exit.
  static Set<String> _clean(Set<String> mask, int side) {
    if (mask.isEmpty) return mask;
    final visited = <String>{};
    final regions = <Set<String>>[];
    for (final cell in mask) {
      if (visited.contains(cell)) continue;
      final region = <String>{};
      final stack = [cell];
      while (stack.isNotEmpty) {
        final cur = stack.removeLast();
        if (!mask.contains(cur) || visited.contains(cur)) continue;
        visited.add(cur);
        region.add(cur);
        final parts = cur.split(',');
        final r = int.parse(parts[0]), c = int.parse(parts[1]);
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

  // Legacy public alias used by grid_component
  static Set<String> maskForLevel(int levelNumber, Random rng, int side) {
    final type = AppConstants.levelTypeFor(levelNumber);
    if (type == LevelType.boss) {
      if (levelNumber == 7) return shapeByName('guitar', side, rng);
      if (levelNumber == 14) return shapeByName('saturn', side, rng);
      if (levelNumber == 21) return shapeByName('butterfly', side, rng);
    }
    return maskForLevelType(type, rng, side);
  }
}
