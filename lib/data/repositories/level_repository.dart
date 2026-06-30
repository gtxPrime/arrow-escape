import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/level.dart';
import '../level_generator/level_generator.dart';

// Top-level function required by compute() to run in a background isolate.
LevelModel _generateLevelIsolate(int levelNumber) {
  return LevelGenerator.generateLevel(levelNumber);
}

/// Caches generated levels and provides access by level number.
/// Generates up to 1000+ levels on demand.
class LevelRepository {
  final Map<int, LevelModel> _cache = {};
  final Set<int> _generating = {}; // track in-flight async generations

  /// Get or generate a level by number (synchronous — always returns immediately).
  /// If the level is already cached (e.g. from a background pre-warm), it returns
  /// instantly. Otherwise it generates on-the-spot (may block briefly).
  LevelModel getLevel(int levelNumber) {
    return _cache.putIfAbsent(levelNumber, () {
      return LevelGenerator.generateLevel(levelNumber);
    });
  }

  /// Asynchronously pre-generate [levelNumber] in a background isolate.
  /// This is truly non-blocking — level generation runs off the UI thread.
  /// Safe to call multiple times — duplicate requests are silently ignored.
  Future<void> preGenerateAsync(int levelNumber) async {
    if (_cache.containsKey(levelNumber)) return;
    if (_generating.contains(levelNumber)) return;
    _generating.add(levelNumber);

    try {
      final level = await compute(_generateLevelIsolate, levelNumber);
      _cache[levelNumber] = level;
    } catch (_) {
      // Silently ignore errors — getLevel() will regenerate if needed
    } finally {
      _generating.remove(levelNumber);
    }
  }

  /// Asynchronously pre-generate a range of levels in background isolates.
  /// Each level is generated in its own isolate — non-blocking for the UI.
  Future<void> preGenerateRangeAsync(int from, int count) async {
    for (int i = from; i < from + count; i++) {
      unawaited(preGenerateAsync(i));
    }
  }

  /// Wait until a specific level is ready (either cached or being generated).
  /// Returns the level, generating synchronously only if not already in-flight.
  Future<LevelModel> getLevelAsync(int levelNumber) async {
    if (_cache.containsKey(levelNumber)) return _cache[levelNumber]!;

    // If not generating yet, kick off background generation
    if (!_generating.contains(levelNumber)) {
      unawaited(preGenerateAsync(levelNumber));
    }

    // Poll until it's available (it's being generated in background)
    while (!_cache.containsKey(levelNumber)) {
      await Future.delayed(const Duration(milliseconds: 16));
    }
    return _cache[levelNumber]!;
  }

  /// Returns true if [levelNumber] is already cached and ready instantly.
  bool isCached(int levelNumber) => _cache.containsKey(levelNumber);

  /// Clear cache to free memory (keep current ±5 levels)
  void trimCache(int currentLevel) {
    final keys = _cache.keys.toList();
    for (final key in keys) {
      if (key < currentLevel - 5 || key > currentLevel + 10) {
        _cache.remove(key);
      }
    }
  }

  /// Total levels available (capped at 500)
  static int get totalLevels => 500;
}
