import 'dart:math';

// ─── Direction Enum ───────────────────────────────────────────────────────────

enum ArrowDirection {
  up,
  down,
  left,
  right;

  /// Returns the [row, col] delta for movement
  List<int> get delta {
    switch (this) {
      case ArrowDirection.up:    return [-1, 0];
      case ArrowDirection.down:  return [1, 0];
      case ArrowDirection.left:  return [0, -1];
      case ArrowDirection.right: return [0, 1];
    }
  }

  /// Unicode arrow character for display / debugging
  String get symbol {
    switch (this) {
      case ArrowDirection.up:    return '↑';
      case ArrowDirection.down:  return '↓';
      case ArrowDirection.left:  return '←';
      case ArrowDirection.right: return '→';
    }
  }

  /// Rotation angle in radians (base asset points RIGHT = 0 rad)
  double get rotationRadians {
    switch (this) {
      case ArrowDirection.right: return 0;
      case ArrowDirection.down:  return pi / 2;
      case ArrowDirection.left:  return pi;
      case ArrowDirection.up:    return -pi / 2;
    }
  }

  ArrowDirection get opposite {
    switch (this) {
      case ArrowDirection.up:    return ArrowDirection.down;
      case ArrowDirection.down:  return ArrowDirection.up;
      case ArrowDirection.left:  return ArrowDirection.right;
      case ArrowDirection.right: return ArrowDirection.left;
    }
  }

  /// 90° clockwise turn — used by red orphan dots
  ArrowDirection get turnRight {
    switch (this) {
      case ArrowDirection.up:    return ArrowDirection.right;
      case ArrowDirection.right: return ArrowDirection.down;
      case ArrowDirection.down:  return ArrowDirection.left;
      case ArrowDirection.left:  return ArrowDirection.up;
    }
  }

  /// 90° counter-clockwise turn — used by blue orphan dots
  ArrowDirection get turnLeft {
    switch (this) {
      case ArrowDirection.up:    return ArrowDirection.left;
      case ArrowDirection.left:  return ArrowDirection.down;
      case ArrowDirection.down:  return ArrowDirection.right;
      case ArrowDirection.right: return ArrowDirection.up;
    }
  }

  static ArrowDirection random() {
    final rng = Random();
    return ArrowDirection.values[rng.nextInt(4)];
  }
}

// ─── Snake Mechanic Enum ──────────────────────────────────────────────────────

enum SnakeMechanic {
  /// No extra rule — base pull-through mechanic.
  standard,

  /// Color paired arrows that exit together.
  colorLock,
}

// ─── Arrow State Enum ─────────────────────────────────────────────────────────

enum ArrowState {
  idle,       // Waiting for tap
  sliding,    // Currently animating
  blocked,    // Hit a wall — showing error
  exited,     // Successfully left grid
  locked,     // colorLock snake — locked by its colorKey not yet cleared
}

// ─── Arrow Model ─────────────────────────────────────────────────────────────

class ArrowModel {
  final String id;
  int row;
  int col;
  ArrowDirection direction;
  ArrowState state;
  bool isPartOfPattern; // Whether this arrow is part of the target shape

  /// path[0] = head (has the arrowhead), path[last] = tail.
  /// Each consecutive pair is orthogonally adjacent (differs by exactly 1 row or col).
  /// headDirection (direction) must point AWAY from path[1].
  final List<List<int>> path;

  /// The mechanic applied to this snake.
  final SnakeMechanic mechanic;

  /// Shared color group ID for colorLock/colorKey pairing.
  /// Null for standard/ice snakes.
  final int? colorGroup;

  ArrowModel({
    required this.id,
    required this.row,
    required this.col,
    required this.direction,
    this.state = ArrowState.idle,
    this.isPartOfPattern = false,
    this.mechanic = SnakeMechanic.standard,
    this.colorGroup,
    List<List<int>>? path,
  }) : this.path = path ?? [[row, col]];

  ArrowModel copyWith({
    String? id,
    int? row,
    int? col,
    ArrowDirection? direction,
    ArrowState? state,
    bool? isPartOfPattern,
    SnakeMechanic? mechanic,
    int? colorGroup,
    List<List<int>>? path,
  }) {
    return ArrowModel(
      id: id ?? this.id,
      row: row ?? this.row,
      col: col ?? this.col,
      direction: direction ?? this.direction,
      state: state ?? this.state,
      isPartOfPattern: isPartOfPattern ?? this.isPartOfPattern,
      mechanic: mechanic ?? this.mechanic,
      colorGroup: colorGroup ?? this.colorGroup,
      path: path ?? this.path,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'row': row,
    'col': col,
    'direction': direction.index,
    'state': state.index,
    'isPartOfPattern': isPartOfPattern,
    'mechanic': mechanic.index,
    'colorGroup': colorGroup,
    'path': path,
  };

  factory ArrowModel.fromJson(Map<String, dynamic> json) => ArrowModel(
    id: json['id'] as String,
    row: json['row'] as int,
    col: json['col'] as int,
    direction: ArrowDirection.values[json['direction'] as int],
    state: ArrowState.values[json['state'] as int],
    isPartOfPattern: json['isPartOfPattern'] as bool? ?? false,
    mechanic: json['mechanic'] != null
        ? SnakeMechanic.values[json['mechanic'] as int]
        : SnakeMechanic.standard,
    colorGroup: json['colorGroup'] as int?,
    path: (json['path'] as List<dynamic>?)
        ?.map((e) => (e as List<dynamic>).map((x) => x as int).toList())
        .toList(),
  );

  @override
  String toString() => 'Arrow($id @ [$row,$col] ${direction.symbol} '
      '[${mechanic.name}${colorGroup != null ? ' grp$colorGroup' : ''}], '
      'path: $path)';
}
