import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/level.dart';
import '../level_generator/level_generator.dart';

// Top-level function required by compute() to run in a background isolate.
LevelModel _generateLevelIsolate(int levelNumber) {
  return LevelGenerator.generateLevel(levelNumber);
}

/// Caches generated levels and provides access by level number.
/// Generates up to 500 levels on demand and persists them to disk.
class LevelRepository {
  final SharedPreferences? _prefs;
  final Map<int, LevelModel> _cache = {};
  final Set<int> _generating = {}; // track in-flight async generations

  LevelRepository([this._prefs]);

  /// Get or generate a level by number (synchronous — always returns immediately).
  /// If the level is already cached (in memory or on disk), it returns instantly.
  /// Otherwise it generates on-the-spot.
  LevelModel getLevel(int levelNumber) {
    if (_cache.containsKey(levelNumber)) {
      return _cache[levelNumber]!;
    }

    // Try loading from persistent disk cache
    if (_prefs != null) {
      final jsonStr = _prefs!.getString('cached_level_$levelNumber');
      if (jsonStr != null) {
        try {
          final level = LevelModel.fromJson(jsonDecode(jsonStr));
          _cache[levelNumber] = level;
          return level;
        } catch (e) {
          debugPrint('Error decoding cached level: $e');
        }
      }
    }

    final level = LevelGenerator.generateLevel(levelNumber);
    _cache[levelNumber] = level;
    _saveToDisk(levelNumber, level);
    return level;
  }

  /// Asynchronously pre-generate [levelNumber] in a background isolate.
  /// This is truly non-blocking — level generation runs off the UI thread.
  /// Safe to call multiple times — duplicate requests are silently ignored.
  Future<void> preGenerateAsync(int levelNumber) async {
    if (isCached(levelNumber)) return;
    if (_generating.contains(levelNumber)) return;
    _generating.add(levelNumber);

    try {
      // Check if already on disk first to avoid spinning up isolate
      if (_prefs != null && _prefs!.containsKey('cached_level_$levelNumber')) {
        final jsonStr = _prefs!.getString('cached_level_$levelNumber');
        if (jsonStr != null) {
          final level = LevelModel.fromJson(jsonDecode(jsonStr));
          _cache[levelNumber] = level;
          return;
        }
      }

      final level = await compute(_generateLevelIsolate, levelNumber);
      _cache[levelNumber] = level;
      _saveToDisk(levelNumber, level);
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

    if (_prefs != null && _prefs!.containsKey('cached_level_$levelNumber')) {
      final jsonStr = _prefs!.getString('cached_level_$levelNumber');
      if (jsonStr != null) {
        try {
          final level = LevelModel.fromJson(jsonDecode(jsonStr));
          _cache[levelNumber] = level;
          return level;
        } catch (_) {}
      }
    }

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

  /// Returns true if [levelNumber] is already cached (in memory or disk) and ready instantly.
  bool isCached(int levelNumber) {
    if (_cache.containsKey(levelNumber)) return true;
    if (_prefs != null && _prefs!.containsKey('cached_level_$levelNumber')) {
      return true;
    }
    return false;
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

  void _saveToDisk(int levelNumber, LevelModel level) {
    if (_prefs == null) return;
    try {
      final jsonStr = jsonEncode(level.toJson());
      _prefs!.setString('cached_level_$levelNumber', jsonStr);
    } catch (e) {
      debugPrint('Error saving cached level to disk: $e');
    }
  }

  /// Total levels available (capped at 500)
  static int get totalLevels => 500;
}
