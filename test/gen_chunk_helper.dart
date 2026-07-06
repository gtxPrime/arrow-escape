// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:arrow_escape/data/level_generator/level_generator.dart';

/// Minimum arrow count for a non-tutorial level to be considered valid.
/// Catches cases where the generator accepted a nearly-empty layout
/// (e.g. 4 arrows on a 27×27 grid due to a tiny shaped mask).
/// Formula: at least max(8, gridSize ÷ 2) arrows.
bool _isCachedLevelValid(int levelNumber, Map<String, dynamic> json) {
  try {
    // Tutorial levels 1-3 are intentionally tiny — always keep them.
    if (levelNumber <= 3) return true;

    final patternName = json['patternName'] as String?;
    if (patternName == 'fallback') return false; // Evict fallback levels

    final gridSize  = (json['gridSize'] as num?)?.toInt() ?? 10;
    final arrowCount = (json['arrows'] as List?)?.length ?? 0;
    final minArrows  = (gridSize ~/ 2).clamp(8, 999);
    return arrowCount >= minArrows;
  } catch (_) {
    return false; // Corrupt JSON → regenerate
  }
}

/// Generates levels [startLevel]..[endLevel] (inclusive).
/// Persists each success immediately to [cacheFile] (JSON).
///
/// Cache validation on every run:
///   ✓ Cached level passes validation  → SKIPPED (kept forever).
///   ✗ Cached level fails validation   → evicted + regenerated automatically.
///   – Missing level                   → generated fresh.
///
/// You NEVER need to delete the cache manually.
/// After an algorithm change, just re-run — only broken or missing levels
/// are regenerated; every level that is already correct is left untouched.
void runChunk({
  required int startLevel,
  required int endLevel,
  required String cacheFile,
  required String logFile,
}) {
  final cacheF = File(cacheFile);
  final logF   = File(logFile);

  // ── Load & validate existing cache ──────────────────────────────────────
  final Map<int, Map<String, dynamic>> cache = {};
  int evicted = 0;
  if (cacheF.existsSync()) {
    try {
      final raw = jsonDecode(cacheF.readAsStringSync()) as Map<String, dynamic>;
      for (final e in raw.entries) {
        final n = int.tryParse(e.key);
        if (n == null || n < startLevel || n > endLevel) continue;
        final lvlJson = e.value as Map<String, dynamic>;
        if (_isCachedLevelValid(n, lvlJson)) {
          cache[n] = lvlJson; // ✓ good → keep forever
        } else {
          evicted++; // ✗ bad (too few arrows, corrupt, etc.) → will regen
        }
      }
    } catch (_) {}
  }

  void saveCache() {
    final m = <String, dynamic>{};
    for (final e in cache.entries) m[e.key.toString()] = e.value;
    cacheF.writeAsStringSync(jsonEncode(m));
  }

  void log(String msg) {
    final ts   = DateTime.now().toIso8601String().substring(11, 19);
    final line = '[$ts] $msg';
    print(line);
    logF.writeAsStringSync('$line\n', mode: FileMode.append);
  }

  logF.writeAsStringSync(''); // clear log for this run
  log('=== Chunk $startLevel-$endLevel'
      '  (${cache.length} cached'
      '${evicted > 0 ? ", $evicted evicted & will regen" : ""}) ===');

  final sw = Stopwatch()..start();
  int gen = 0, skip = 0, failed = 0;

  for (int lvl = startLevel; lvl <= endLevel; lvl++) {
    if (cache.containsKey(lvl)) {
      skip++;
      log('Level $lvl - CACHED');
      continue;
    }

    log('Level $lvl - generating...');
    final lsw = Stopwatch()..start();
    try {
      final level = LevelGenerator.generateLevel(lvl);
      lsw.stop();
      final ms = lsw.elapsedMilliseconds;
      final t  = ms > 1000
          ? '${(ms / 1000).toStringAsFixed(1)}s'
          : '${ms}ms';
      log('Level $lvl - OK  ${level.arrows.length} arrows'
          '  ${level.gridSize}x${level.gridSize}  $t');
      cache[lvl] = level.toJson();
      gen++;
      saveCache(); // persist immediately so crashes don't lose progress
    } catch (e) {
      lsw.stop();
      log('Level $lvl - ERROR: $e');
      failed++;
    }
  }

  sw.stop();
  final total = endLevel - startLevel + 1;
  log('');
  log('=== DONE: gen=$gen  skip=$skip  evicted=$evicted  failed=$failed'
      '  total=${cache.length}/$total  time=${sw.elapsed.inSeconds}s ===');
  saveCache();
}
