import 'dart:convert';
import 'dart:io';
import '../lib/data/level_generator/level_generator_v2.dart';
import '../lib/data/level_generator/solver.dart';
import '../lib/data/level_binary_codec.dart';
import '../lib/data/models/arrow.dart';
import '../lib/data/models/level.dart';

void main(List<String> args) async {
  int startLevel = 1;
  int endLevel = 500;
  bool compileOnly = false;

  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--start' && i + 1 < args.length) {
      startLevel = int.parse(args[i + 1]);
    } else if (args[i] == '--end' && i + 1 < args.length) {
      endLevel = int.parse(args[i + 1]);
    } else if (args[i] == '--compile') {
      compileOnly = true;
    }
  }

  final logFile = File('log.txt');

  void log(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    final formatted = '[$timestamp] [Range $startLevel-$endLevel] $message';
    print(formatted);
    logFile.writeAsStringSync('$formatted\n', mode: FileMode.append);
  }

  if (compileOnly) {
    log('─────────────────────────────────────────────────────────────');
    log(' Compiling all cached levels (1–500) into assets/levels.bin');
    log('─────────────────────────────────────────────────────────────');
    final levels = <LevelModel>[];
    for (int i = 1; i <= 500; i++) {
      final cacheFile = File('assets/levels_cache/level_$i.json');
      if (cacheFile.existsSync()) {
        final level = LevelModel.fromJson(jsonDecode(cacheFile.readAsStringSync()));
        levels.add(level);
      } else {
        log('WARNING: Missing cache file for Level $i');
      }
    }
    log('Encoding ${levels.length} levels into assets/levels.bin...');
    final encodeSw = Stopwatch()..start();
    final bytes = encodeLevels(levels);
    encodeSw.stop();

    final outDir = Directory('assets');
    if (!outDir.existsSync()) {
      outDir.createSync(recursive: true);
    }
    File('assets/levels.bin').writeAsBytesSync(bytes);
    final kbSize = (bytes.length / 1024).toStringAsFixed(1);
    log('SUCCESS! Written assets/levels.bin (${kbSize} KB, ${bytes.length} bytes in ${encodeSw.elapsedMilliseconds}ms)');
    return;
  }

  log('─────────────────────────────────────────────────────────────');
  log(' Arrow Puzzle — Level Generator & Verifier (Range $startLevel to $endLevel)');
  log('─────────────────────────────────────────────────────────────');

  int loadedFromCache = 0;
  int newlyGenerated = 0;
  int skippedCount = 0;

  final cacheDir = Directory('assets/levels_cache');
  if (!cacheDir.existsSync()) {
    cacheDir.createSync(recursive: true);
  }

  final sw = Stopwatch()..start();

  for (int i = startLevel; i <= endLevel; i++) {
    final cacheFile = File('assets/levels_cache/level_$i.json');
    LevelModel? validLevel;

    // 1. Check disk cache first
    if (cacheFile.existsSync()) {
      try {
        final jsonStr = cacheFile.readAsStringSync();
        final level = LevelModel.fromJson(jsonDecode(jsonStr));
        final errors = _verifyLevel(level);
        if (errors.isEmpty) {
          validLevel = level;
          loadedFromCache++;
          log('Level ${'$i'.padLeft(3)} / $endLevel: LOADED FROM CACHE — ${level.arrows.length} arrows (${level.gridSize}×${level.gridSize})');
        } else {
          log('Level ${'$i'.padLeft(3)} / $endLevel: Cached level invalid (${errors.join("; ")}), regenerating...');
          cacheFile.deleteSync();
        }
      } catch (e) {
        log('Level ${'$i'.padLeft(3)} / $endLevel: Failed to read cache, regenerating...');
      }
    }

    // 2. Generate and verify on-the-fly if not loaded from cache (max 3 attempts)
    if (validLevel == null) {
      for (int attempt = 1; attempt <= 3; attempt++) {
        final levelSw = Stopwatch()..start();
        final level = LevelGeneratorV2.generateLevel(i);
        levelSw.stop();

        final errors = _verifyLevel(level);
        if (errors.isEmpty) {
          validLevel = level;
          newlyGenerated++;
          // Save to individual level cache
          cacheFile.parent.createSync(recursive: true);
          cacheFile.writeAsStringSync(jsonEncode(level.toJson()));
          log('Level ${'$i'.padLeft(3)} / $endLevel: GENERATED & SOLVED (Attempt $attempt in ${levelSw.elapsedMilliseconds}ms) — ${level.arrows.length} arrows (${level.gridSize}×${level.gridSize})');
          break;
        } else {
          log('Level ${'$i'.padLeft(3)} / $endLevel: Attempt $attempt FAILED verification (${errors.join("; ")})');
        }
      }
    }

    if (validLevel == null) {
      skippedCount++;
      log('Level ${'$i'.padLeft(3)} / $endLevel: SKIPPED (failed 3 generation attempts)');
    }
  }

  sw.stop();

  log('Range $startLevel-$endLevel finished in ${sw.elapsed.inSeconds}s (Cache: $loadedFromCache | New: $newlyGenerated | Skipped: $skippedCount)');
}

/// Comprehensive level verification rules.
/// Returns a list of error strings. If empty, the level is 100% valid & solvable.
List<String> _verifyLevel(LevelModel level) {
  final errors = <String>[];

  if (level.patternName == 'fallback') {
    errors.add('Fallback level generated');
    return errors;
  }

  // 1. Solvability check
  if (level.gridSize <= 20) {
    final solution = LevelSolver.solve(level, 5000);
    if (solution == null) {
      errors.add('UNSOLVABLE (solver returned null)');
    }
  } else {
    if (level.solutionOrder.isEmpty) {
      errors.add('UNSOLVABLE (greedy solution order empty)');
    }
  }

  // 2. Infinite deflection loop check
  final orphanMap = {for (final od in level.orphanDots) od.key: od.type};
  for (final arrow in level.arrows) {
    final arrowOccupied = <String>{};
    for (final a in level.arrows) {
      if (a.id == arrow.id) continue;
      for (final pt in a.path) arrowOccupied.add('${pt[0]},${pt[1]}');
    }

    ArrowDirection currentDir = arrow.direction;
    final head = arrow.path[0];
    var d = currentDir.delta;
    int nr = head[0] + d[0];
    int nc = head[1] + d[1];
    final visited = <String>{};
    bool looped = false;

    while (nr >= 0 && nr < level.gridSize && nc >= 0 && nc < level.gridSize) {
      final key = '$nr,$nc';
      if (visited.contains(key)) {
        looped = true;
        break;
      }
      visited.add(key);

      if (orphanMap.containsKey(key)) {
        final dotType = orphanMap[key]!;
        if (dotType == OrphanDotType.up) currentDir = ArrowDirection.up;
        else if (dotType == OrphanDotType.down) currentDir = ArrowDirection.down;
        else if (dotType == OrphanDotType.left) currentDir = ArrowDirection.left;
        else if (dotType == OrphanDotType.right) currentDir = ArrowDirection.right;
      } else if (arrowOccupied.contains(key)) {
        break;
      }

      d = currentDir.delta;
      nr += d[0];
      nc += d[1];
    }

    if (looped) {
      errors.add('Infinite deflection loop for arrow ${arrow.id}');
      break;
    }
  }

  // 3. ColorLock pair mutual deadlock check (neither partner's exit path passes through the other's body)
  final colorGroups = <int, List<ArrowModel>>{};
  for (final arrow in level.arrows) {
    if (arrow.colorGroup != null) {
      colorGroups.putIfAbsent(arrow.colorGroup!, () => []).add(arrow);
    }
  }
  for (final entry in colorGroups.entries) {
    if (entry.value.length != 2) {
      errors.add('Color group ${entry.key} count != 2');
      continue;
    }
    final a1 = entry.value[0];
    final a2 = entry.value[1];
    final a1Cells = a1.path.map((p) => '${p[0]},${p[1]}').toSet();
    final a2Cells = a2.path.map((p) => '${p[0]},${p[1]}').toSet();

    if (_exitPassesThroughSet(a1, level.gridSize, a2Cells, orphanMap) ||
        _exitPassesThroughSet(a2, level.gridSize, a1Cells, orphanMap)) {
      errors.add('ColorLock mutual deadlock in group ${entry.key}');
    }
  }

  // 4. Closed loop / square path check
  for (final arrow in level.arrows) {
    if (_pathFormsCycle(arrow.path)) {
      errors.add('Closed loop path in arrow ${arrow.id}');
      break;
    }
  }

  return errors;
}

bool _exitPassesThroughSet(ArrowModel arrow, int gridSize,
    Set<String> targetSet, Map<String, OrphanDotType> orphanDots) {
  ArrowDirection currentDir = arrow.direction;
  final head = arrow.path[0];
  var d = currentDir.delta;
  int nr = head[0] + d[0];
  int nc = head[1] + d[1];
  final visited = <String>{};

  while (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
    final key = '$nr,$nc';
    if (visited.contains(key)) return false;
    visited.add(key);

    if (targetSet.contains(key)) {
      return true;
    }

    if (orphanDots.containsKey(key)) {
      final dotType = orphanDots[key]!;
      if (dotType == OrphanDotType.up) currentDir = ArrowDirection.up;
      else if (dotType == OrphanDotType.down) currentDir = ArrowDirection.down;
      else if (dotType == OrphanDotType.left) currentDir = ArrowDirection.left;
      else if (dotType == OrphanDotType.right) currentDir = ArrowDirection.right;
    }

    d = currentDir.delta;
    nr += d[0];
    nc += d[1];
  }
  return false;
}

bool _pathFormsCycle(List<List<int>> path) {
  if (path.length < 4) return false;

  final pathSet = <int>{};
  for (final pt in path) {
    pathSet.add(pt[0] * 1000 + pt[1]);
  }

  for (int i = 0; i < path.length; i++) {
    final r = path[i][0], c = path[i][1];
    for (final nb in [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
      final nr = r + nb[0], nc = c + nb[1];
      final np = nr * 1000 + nc;
      if (!pathSet.contains(np)) continue;

      for (int j = 0; j < path.length; j++) {
        if (path[j][0] == nr && path[j][1] == nc) {
          if ((i - j).abs() > 1) return true;
          break;
        }
      }
    }
  }
  return false;
}
