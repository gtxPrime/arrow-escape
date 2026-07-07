import 'arrow.dart';

// ─── Orphan Dot ───────────────────────────────────────────────────────────────

/// A single isolated grid cell that could not be covered by any arrow.
/// Acts as a redirect deflector in the exit path.
/// Consumed (removed) on first use.
enum OrphanDotType { up, down, left, right, neutral }

class OrphanDot {
  final int row, col;
  final OrphanDotType type;
  const OrphanDot({required this.row, required this.col, required this.type});

  String get key => '$row,$col';

  Map<String, dynamic> toJson() => {
    'row': row,
    'col': col,
    'type': type.index,
  };

  factory OrphanDot.fromJson(Map<String, dynamic> json) => OrphanDot(
    row: json['row'] as int,
    col: json['col'] as int,
    type: OrphanDotType.values[json['type'] as int],
  );
}

// ─── Mask Shape Enum ──────────────────────────────────────────────────────────

/// The canvas silhouette shape for a level's grid.
/// Normal levels always use [square].
/// Boss levels use animal / object shapes.
/// God levels use dramatic geometric shapes.
enum MaskShape {
  // Standard
  square,
  circle,
  // Geometric (god levels)
  heart,
  star,
  diamond,
  hexagon,
  blob,
  // Animals (boss levels)
  cat,
  dog,
  frog,
  fox,
  tiger,
  panda,
  fish,
  bird,
  butterfly,
  // Objects (boss levels)
  guitar,
  tree,
  house,
  crown,
  saturn,
}

// ─── Difficulty Enum ──────────────────────────────────────────────────────────

enum Difficulty {
  tutorial,
  easy,
  medium,
  hard,
  expert,
  master,
  legend;

  String get label {
    switch (this) {
      case Difficulty.tutorial: return 'Tutorial';
      case Difficulty.easy:     return 'Easy';
      case Difficulty.medium:   return 'Medium';
      case Difficulty.hard:     return 'Hard';
      case Difficulty.expert:   return 'Expert';
      case Difficulty.master:   return 'Master';
      case Difficulty.legend:   return 'Legend';
    }
  }

  static Difficulty forLevel(int levelNumber) {
    if (levelNumber <= 10) return Difficulty.tutorial;
    if (levelNumber <= 30) return Difficulty.easy;
    if (levelNumber <= 70) return Difficulty.medium;
    if (levelNumber <= 150) return Difficulty.hard;
    if (levelNumber <= 300) return Difficulty.expert;
    if (levelNumber <= 500) return Difficulty.master;
    return Difficulty.legend;
  }
}

// ─── Level Model ──────────────────────────────────────────────────────────────

class LevelModel {
  final int levelNumber;
  final int gridSize;
  final List<ArrowModel> arrows;
  final String patternName;
  final Difficulty difficulty;
  final List<String> solutionOrder;
  final MaskShape maskShape;
  final Set<String> mask;
  final List<OrphanDot> orphanDots;

  LevelModel({
    required this.levelNumber,
    required this.gridSize,
    required this.arrows,
    required this.patternName,
    required this.difficulty,
    this.solutionOrder = const [],
    this.maskShape = MaskShape.square,
    this.mask = const {},
    this.orphanDots = const [],
  });

  int get totalArrows => arrows.length;

  LevelModel copy() => LevelModel(
    levelNumber: levelNumber,
    gridSize: gridSize,
    arrows: arrows.map((a) => a.copyWith()).toList(),
    patternName: patternName,
    difficulty: difficulty,
    solutionOrder: List.from(solutionOrder),
    maskShape: maskShape,
    mask: Set.from(mask),
    orphanDots: List.from(orphanDots),
  );

  LevelModel copyWith({
    int? levelNumber,
    int? gridSize,
    List<ArrowModel>? arrows,
    String? patternName,
    Difficulty? difficulty,
    List<String>? solutionOrder,
    MaskShape? maskShape,
    Set<String>? mask,
    List<OrphanDot>? orphanDots,
  }) => LevelModel(
    levelNumber: levelNumber ?? this.levelNumber,
    gridSize: gridSize ?? this.gridSize,
    arrows: arrows ?? this.arrows,
    patternName: patternName ?? this.patternName,
    difficulty: difficulty ?? this.difficulty,
    solutionOrder: solutionOrder ?? this.solutionOrder,
    maskShape: maskShape ?? this.maskShape,
    mask: mask ?? this.mask,
    orphanDots: orphanDots ?? this.orphanDots,
  );

  Map<String, dynamic> toJson() => {
    'levelNumber': levelNumber,
    'gridSize': gridSize,
    'arrows': arrows.map((a) => a.toJson()).toList(),
    'patternName': patternName,
    'difficulty': difficulty.index,
    'solutionOrder': solutionOrder,
    'maskShape': maskShape.index,
    'mask': mask.toList(),
    'orphanDots': orphanDots.map((d) => d.toJson()).toList(),
  };

  factory LevelModel.fromJson(Map<String, dynamic> json) => LevelModel(
    levelNumber: json['levelNumber'] as int,
    gridSize: json['gridSize'] as int,
    arrows: (json['arrows'] as List)
        .map((a) => ArrowModel.fromJson(a as Map<String, dynamic>))
        .toList(),
    patternName: json['patternName'] as String,
    difficulty: Difficulty.values[json['difficulty'] as int],
    solutionOrder: List<String>.from(json['solutionOrder'] as List? ?? []),
    maskShape: json['maskShape'] != null
        ? MaskShape.values[(json['maskShape'] as int)
            .clamp(0, MaskShape.values.length - 1)]
        : MaskShape.square,
    mask: json['mask'] != null
        ? Set<String>.from((json['mask'] as List).cast<String>())
        : const {},
    orphanDots: json['orphanDots'] != null
        ? (json['orphanDots'] as List)
            .map((d) => OrphanDot.fromJson(d as Map<String, dynamic>))
            .toList()
        : const [],
  );
}

// ─── Level Result Model ───────────────────────────────────────────────────────

class LevelResult {
  final int levelNumber;
  final int stars;
  final int score;
  final int movesUsed;
  final int livesLost;
  final bool completed;
  final DateTime completedAt;

  LevelResult({
    required this.levelNumber,
    required this.stars,
    required this.score,
    required this.movesUsed,
    required this.livesLost,
    required this.completed,
    required this.completedAt,
  });

  Map<String, dynamic> toJson() => {
    'levelNumber': levelNumber,
    'stars': stars,
    'score': score,
    'movesUsed': movesUsed,
    'livesLost': livesLost,
    'completed': completed,
    'completedAt': completedAt.toIso8601String(),
  };

  factory LevelResult.fromJson(Map<String, dynamic> json) => LevelResult(
    levelNumber: json['levelNumber'] as int,
    stars: json['stars'] as int,
    score: json['score'] as int,
    movesUsed: json['movesUsed'] as int,
    livesLost: json['livesLost'] as int,
    completed: json['completed'] as bool,
    completedAt: DateTime.parse(json['completedAt'] as String),
  );
}
