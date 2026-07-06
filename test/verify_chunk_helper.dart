// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:arrow_escape/data/level_generator/level_generator.dart';
import 'package:arrow_escape/data/level_generator/solver.dart';
import 'package:arrow_escape/data/models/arrow.dart';
import 'package:arrow_escape/data/models/level.dart';
import 'package:arrow_escape/core/constants.dart';

// =============================================================================
//  Verify & cache one chunk of levels.
//
//  PASSING levels are saved to the shared progress JSON WITH their full
//  LevelModel JSON so build_levels_bin.dart never needs to re-generate.
//  FAILING levels are saved with their error list only.
//
//  Re-runs SKIP levels that already have status=="pass" in the progress file.
// =============================================================================

void runVerifyChunk({
  required int startLevel,
  required int endLevel,
  required String logFile,
}) {
  Directory('assets').createSync(recursive: true);

  final match = RegExp(r'chunk_(\d+)').firstMatch(logFile);
  final chunkIndex = match != null ? int.parse(match.group(1)!) : 1;
  final progressFile = 'assets/verify_progress_chunk_$chunkIndex.json';


  // Synchronous append writes — avoids StreamSink conflict with flutter_test.
  File(logFile).writeAsStringSync(''); // clear / create
  void write(String msg) {
    final ts = DateTime.now().toIso8601String().substring(11, 19);
    final line = '[$ts] $msg';
    print(line);
    File(logFile).writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
  }

  write('=== Verify Chunk $startLevel-$endLevel ===');

  // Load shared progress — we will only re-run levels without status=="pass".
  final progress = _loadProgress(progressFile);
  final toRun = <int>[];
  for (int lvl = startLevel; lvl <= endLevel; lvl++) {
    final key = lvl.toString();
    if (!progress.containsKey(key) || progress[key]!['status'] != 'pass') {
      toRun.add(lvl);
    }
  }

  final chunkSize  = endLevel - startLevel + 1;
  final alreadyOk  = chunkSize - toRun.length;
  write('${toRun.length} to verify, $alreadyOk already cached & passing - skipping those');

  if (toRun.isEmpty) {
    write('All levels in this chunk already pass. Done.');
    return;
  }

  final sw = Stopwatch()..start();
  int pass = 0, fail = 0;

  for (final lvl in toRun) {
    final result = _verifyLevel(lvl);

    // Atomic save: load latest progress, merge our result, save back.
    final latest = _loadProgress(progressFile);
    latest[lvl.toString()] = result;
    _saveProgress(progressFile, latest);
    // Also update our local copy so the final summary is accurate.
    progress[lvl.toString()] = result;

    final status = result['status'] as String;
    final ms     = result['ms'] as int;
    final errors = result.containsKey('errors')
        ? (result['errors'] as List).cast<String>()
        : <String>[];

    if (status == 'pass') {
      pass++;
      final type = AppConstants.levelTypeFor(lvl);
      final gs   = AppConstants.gridSizeForLevel(lvl);
      // Always log boss/god/tutorial and every 10th level; skip noisy normals.
      if (type != LevelType.normal || lvl % 10 == 0 || lvl <= 10) {
        write('  OK   Level $lvl [${ms}ms] ${gs}x${gs}');
      }
    } else {
      fail++;
      write('  FAIL Level $lvl [${ms}ms]');
      for (final e in errors) write('       - $e');
    }
  }

  sw.stop();
  write('');
  write('=== Chunk $startLevel-$endLevel done: $pass pass, $fail fail [${sw.elapsed.inSeconds}s] ===');
}

// ─── Verification logic ───────────────────────────────────────────────────────

Map<String, dynamic> _verifyLevel(int levelNum) {
  final sw     = Stopwatch()..start();
  final errors = <String>[];
  LevelModel? level;

  try {
    final type = AppConstants.levelTypeFor(levelNum);
    level = LevelGenerator.generateLevel(levelNum);

    // 1. Fallback check
    if (level.patternName == 'fallback') errors.add('FALLBACK generated');

    // 2. Solvability: DFS only for small grids (≤20); large grids are
    //    guaranteed solvable by reverse-placement construction.
    if (level.patternName != 'fallback' && level.gridSize <= 20) {
      final sol = LevelSolver.solve(level, 6000);
      if (sol == null) errors.add('UNSOLVABLE');
    }

    final orphanMap = {for (final od in level.orphanDots) od.key: od.type};

    // 3. No infinite deflection loops
    for (final arrow in level.arrows) {
      final other = <String>{};
      for (final a in level.arrows) {
        if (a.id == arrow.id) continue;
        for (final pt in a.path) other.add('${pt[0]},${pt[1]}');
      }
      ArrowDirection dir = arrow.direction;
      final h = arrow.path[0];
      var dd = dir.delta;
      int nr = h[0] + dd[0], nc = h[1] + dd[1];
      final vis = <String>{};
      bool looped = false;
      while (nr >= 0 && nr < level.gridSize && nc >= 0 && nc < level.gridSize) {
        final k = '$nr,$nc';
        if (vis.contains(k)) { looped = true; break; }
        vis.add(k);
        if (orphanMap.containsKey(k)) {
          final dt = orphanMap[k]!;
          if      (dt == OrphanDotType.up)    dir = ArrowDirection.up;
          else if (dt == OrphanDotType.down)  dir = ArrowDirection.down;
          else if (dt == OrphanDotType.left)  dir = ArrowDirection.left;
          else if (dt == OrphanDotType.right) dir = ArrowDirection.right;
        } else if (other.contains(k)) break;
        dd = dir.delta;
        nr += dd[0]; nc += dd[1];
      }
      if (looped) errors.add('Arrow ${arrow.id} deflection loop');
    }

    // 4. No path cycles/squares
    for (final arrow in level.arrows) {
      if (_pathFormsCycle(arrow.path)) errors.add('Arrow ${arrow.id} path cycle');
    }

    // 5. ColorLock pair validation
    final grps = <int, List<ArrowModel>>{};
    for (final a in level.arrows) {
      if (a.colorGroup != null) grps.putIfAbsent(a.colorGroup!, () => []).add(a);
    }
    for (final entry in grps.entries) {
      if (entry.value.length != 2) {
        errors.add('Color group ${entry.key}: ${entry.value.length} arrows (expected 2)');
        continue;
      }
      final a1 = entry.value[0], a2 = entry.value[1];
      final a1Cells = a1.path.map((p) => '${p[0]},${p[1]}').toSet();
      final a2Cells = a2.path.map((p) => '${p[0]},${p[1]}').toSet();

      if (_isExitBlocked(a1, level.gridSize, a2Cells, orphanMap) &&
          _isExitBlocked(a2, level.gridSize, a1Cells, orphanMap)) {
        errors.add('ColorLock group ${entry.key}: mutual deadlock');
      }


    }

    // 6. Boss/God MUST have direction-change dots AND color pairs
    if (type == LevelType.boss || type == LevelType.god) {
      if (!level.orphanDots.any((d) => d.type != OrphanDotType.neutral)) {
        errors.add('${type.name.toUpperCase()} missing direction-change dots');
      }
      if (!level.arrows.any((a) => a.colorGroup != null)) {
        errors.add('${type.name.toUpperCase()} missing color pairs');
      }
    }
  } catch (e, st) {
    errors.add('EXCEPTION: $e\n$st');
  }

  sw.stop();

  if (errors.isEmpty && level != null) {
    // PASS: cache full level JSON so build_levels_bin.dart never re-generates.
    return {
      'status': 'pass',
      'ms': sw.elapsedMilliseconds,
      'level': level.toJson(),
    };
  }
  return {
    'status': 'fail',
    'errors': errors,
    'ms': sw.elapsedMilliseconds,
  };
}

// ─── Progress helpers ─────────────────────────────────────────────────────────

Map<String, Map<String, dynamic>> _loadProgress(String progressFile) {
  final f = File(progressFile);
  if (!f.existsSync()) return {};
  try {
    final raw = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    return raw.map((k, v) => MapEntry(k, v as Map<String, dynamic>));
  } catch (_) {
    return {};
  }
}

void _saveProgress(String progressFile, Map<String, Map<String, dynamic>> progress) {
  File(progressFile).writeAsStringSync(jsonEncode(progress), flush: true);
}


// ─── Helpers ──────────────────────────────────────────────────────────────────

bool _isExitBlocked(ArrowModel arrow, int gridSize,
    Set<String> occupied, Map<String, OrphanDotType> orphanDots) {
  ArrowDirection dir = arrow.direction;
  final h = arrow.path[0];
  var d = dir.delta;
  int nr = h[0] + d[0], nc = h[1] + d[1];
  final vis = <String>{};
  while (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
    final k = '$nr,$nc';
    if (vis.contains(k)) return true;
    vis.add(k);
    if (orphanDots.containsKey(k)) {
      final dt = orphanDots[k]!;
      if      (dt == OrphanDotType.up)    dir = ArrowDirection.up;
      else if (dt == OrphanDotType.down)  dir = ArrowDirection.down;
      else if (dt == OrphanDotType.left)  dir = ArrowDirection.left;
      else if (dt == OrphanDotType.right) dir = ArrowDirection.right;
    } else if (occupied.contains(k)) return true;
    d = dir.delta;
    nr += d[0]; nc += d[1];
  }
  return false;
}

bool _pathFormsCycle(List<List<int>> path) {
  if (path.length < 4) return false;
  final s = <int>{};
  for (final p in path) s.add(p[0] * 1000 + p[1]);
  for (int i = 0; i < path.length; i++) {
    final r = path[i][0], c = path[i][1];
    for (final nb in [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
      final np = (r + nb[0]) * 1000 + (c + nb[1]);
      if (!s.contains(np)) continue;
      for (int j = 0; j < path.length; j++) {
        if (path[j][0] == r + nb[0] && path[j][1] == c + nb[1]) {
          if ((i - j).abs() > 1) return true;
          break;
        }
      }
    }
  }
  return false;
}
