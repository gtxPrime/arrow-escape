import 'dart:async';
import '../models/level.dart';
import '../level_generator/level_generator.dart';

/// Caches generated levels and provides access by level number.
/// Generates up to 1000+ levels on demand.
class LevelRepository {
  final Map<int, LevelModel> _cache = {};
  final Set<int> _generating = {}; // track in-flight async generations

  /// Get or generate a level by number (synchronous — always returns immediately).
  /// If the level is already cached (e.g. from a background pre-warm), it returns
  /// instantly. Otherwise it generates on-the-spot.
  LevelModel getLevel(int levelNumber) {
    return _cache.putIfAbsent(levelNumber, () {
      return LevelGenerator.generateLevel(levelNumber);
    });
  }

  /// Asynchronously pre-generate [levelNumber] on the main isolate.
  /// Yields to the event loop first to prevent blocking any UI transitions or animations.
  /// Safe to call multiple times — duplicate requests are silently ignored.
  Future<void> preGenerateAsync(int levelNumber) async {
    if (_cache.containsKey(levelNumber)) return;
    if (_generating.contains(levelNumber)) return;
    _generating.add(levelNumber);
    
    // Yield to event loop to allow UI transition/animations to run smoothly first
    await Future.delayed(Duration.zero);
    
    try {
      final level = LevelGenerator.generateLevel(levelNumber);
      _cache[levelNumber] = level;
    } catch (_) {
      // Silently ignore errors — getLevel() will regenerate if needed
    } finally {
      _generating.remove(levelNumber);
    }
  }

  /// Pre-generate a range of levels synchronously (used post-game for next levels).
  void preGenerate(int from, int count) {
    for (int i = from; i < from + count; i++) {
      getLevel(i);
    }
  }

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
