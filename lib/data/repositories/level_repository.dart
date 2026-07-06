import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/level.dart';
import '../level_generator/level_generator.dart';
import '../level_binary_codec.dart';

// Top-level function required by compute() to run in a background isolate.
LevelModel _generateLevelIsolate(int levelNumber) {
  return LevelGenerator.generateLevel(levelNumber);
}

/// Caches generated levels and provides access by level number.
///
/// Level loading priority:
///   1. In-memory cache  (instant)
///   2. levels.bin binary asset  (O(1) seek, microseconds)
///   3. SharedPreferences disk cache
///   4. On-the-fly generation  (only for levels beyond the binary asset)
class LevelRepository {
  final SharedPreferences? _prefs;
  final Map<int, LevelModel> _cache = {};
  final Set<int> _generating = {};

  LevelBinaryDecoder? _binaryDecoder;
  bool _binaryLoaded = false;

  LevelRepository([this._prefs]);

  /// Load the binary level asset. Reads only the 8-byte header + index table
  /// on startup — individual levels are decoded lazily on demand.
  Future<void> loadPregeneratedLevels() async {
    if (_binaryLoaded) return;
    try {
      final byteData = await rootBundle.load('assets/levels.bin');
      final bytes = byteData.buffer
          .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
      _binaryDecoder = LevelBinaryDecoder.fromBytes(bytes);
      _binaryLoaded = true;
      debugPrint(
          'Loaded levels.bin (${(bytes.length / 1024).toStringAsFixed(0)} KB, '
          '${_binaryDecoder!.levelCount} levels)');
    } catch (e) {
      debugPrint('Error loading levels.bin: $e');
    }
  }

  /// Get a level synchronously. Always returns immediately.
  LevelModel getLevel(int levelNumber) {
    // 1. In-memory cache
    if (_cache.containsKey(levelNumber)) return _cache[levelNumber]!;

    // 2. Binary decoder — O(1) seek, no parsing beyond this single level
    if (_binaryLoaded && _binaryDecoder != null) {
      try {
        final level = _binaryDecoder!.decodeLevelByNumber(levelNumber);
        if (level != null) {
          _cache[levelNumber] = level;
          return level;
        }
      } catch (e) {
        debugPrint('Error decoding binary level $levelNumber: $e');
      }
    }

    // 3. Disk cache (SharedPreferences)
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

    // 4. Generate on-the-fly (fallback for levels beyond the binary asset)
    final level = LevelGenerator.generateLevel(levelNumber);
    _cache[levelNumber] = level;
    _saveToDisk(levelNumber, level);
    return level;
  }

  /// Asynchronously warm up [levelNumber] in a background isolate.
  /// Safe to call multiple times — duplicates are ignored.
  Future<void> preGenerateAsync(int levelNumber) async {
    if (isCached(levelNumber)) return;
    if (_generating.contains(levelNumber)) return;
    _generating.add(levelNumber);

    try {
      // Binary asset covers it — decode directly (no isolate needed)
      if (_binaryLoaded && _binaryDecoder != null) {
        final level = _binaryDecoder!.decodeLevelByNumber(levelNumber);
        if (level != null) {
          _cache[levelNumber] = level;
          return;
        }
      }

      // Check disk cache before spinning up an isolate
      if (_prefs != null && _prefs!.containsKey('cached_level_$levelNumber')) {
        final jsonStr = _prefs!.getString('cached_level_$levelNumber');
        if (jsonStr != null) {
          final level = LevelModel.fromJson(jsonDecode(jsonStr));
          _cache[levelNumber] = level;
          return;
        }
      }

      // Generate in a background isolate (only for levels beyond binary asset)
      final level = await compute(_generateLevelIsolate, levelNumber);
      _cache[levelNumber] = level;
      _saveToDisk(levelNumber, level);
    } catch (_) {
      // Silently ignore — getLevel() will regenerate if needed
    } finally {
      _generating.remove(levelNumber);
    }
  }

  /// Asynchronously warm up a range of levels.
  Future<void> preGenerateRangeAsync(int from, int count) async {
    for (int i = from; i < from + count; i++) {
      unawaited(preGenerateAsync(i));
    }
  }

  /// Async get — returns immediately if cached/binary, otherwise waits for generation.
  Future<LevelModel> getLevelAsync(int levelNumber) async {
    if (_cache.containsKey(levelNumber)) return _cache[levelNumber]!;

    // Binary decode is synchronous O(1)
    if (_binaryLoaded && _binaryDecoder != null) {
      try {
        final level = _binaryDecoder!.decodeLevelByNumber(levelNumber);
        if (level != null) {
          _cache[levelNumber] = level;
          return level;
        }
      } catch (_) {}
    }

    // Disk cache
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

    // Background generation
    if (!_generating.contains(levelNumber)) {
      unawaited(preGenerateAsync(levelNumber));
    }
    while (!_cache.containsKey(levelNumber)) {
      await Future.delayed(const Duration(milliseconds: 16));
    }
    return _cache[levelNumber]!;
  }

  /// True if [levelNumber] is instantly available (no generation needed).
  bool isCached(int levelNumber) {
    if (_cache.containsKey(levelNumber)) return true;
    if (_binaryLoaded && _binaryDecoder != null) {
      final idx = levelNumber - 1;
      return idx >= 0 && idx < _binaryDecoder!.levelCount;
    }
    if (_prefs != null && _prefs!.containsKey('cached_level_$levelNumber')) {
      return true;
    }
    return false;
  }

  /// Trim in-memory cache, keeping levels around [currentLevel].
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
      _prefs!.setString('cached_level_$levelNumber', jsonEncode(level.toJson()));
    } catch (e) {
      debugPrint('Error saving level to disk: $e');
    }
  }

  static int get totalLevels => 500;
}
