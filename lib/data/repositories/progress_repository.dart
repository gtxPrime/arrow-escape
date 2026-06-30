import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../models/level.dart';
import '../../core/constants.dart';
import '../../core/audio_manager.dart';

class ProgressRepository extends ChangeNotifier {
  final SharedPreferences _prefs;

  // ── State fields ────────────────────────────────────────────────────────────
  int _lives = AppConstants.maxLives;
  int _currentLevel = 1;
  int _highestUnlockedLevel = 1;
  int _totalScore = 0;
  int _coins = 0;

  // Streak
  int _streakDays = 0;
  DateTime? _lastPlayedDate;

  // Level results
  final Map<int, LevelResult> _levelResults = {};

  // Settings
  bool _soundEnabled = true;
  bool _musicEnabled = true;
  bool _vibrationEnabled = true;

  // ── Getters ──────────────────────────────────────────────────────────────────
  int get lives => _lives;
  int get maxLives => AppConstants.maxLives;
  int get currentLevel => _currentLevel;
  int get highestUnlockedLevel => _highestUnlockedLevel;
  int get totalScore => _totalScore;
  int get coins => _coins;
  int get streakDays => _streakDays;
  DateTime? get lastPlayedDate => _lastPlayedDate;
  bool get hasLives => _lives > 0;
  bool get livesAreFull => _lives >= AppConstants.maxLives;

  bool get soundEnabled => _soundEnabled;
  bool get musicEnabled => _musicEnabled;
  bool get vibrationEnabled => _vibrationEnabled;

  int getStarsForLevel(int level) => _levelResults[level]?.stars ?? 0;
  bool isLevelUnlocked(int level) => level <= _highestUnlockedLevel;
  bool isLevelCompleted(int level) => _levelResults.containsKey(level);

  ProgressRepository(this._prefs) {
    _load();
  }

  // ── Load / Save ──────────────────────────────────────────────────────────────

  void _load() {
    _lives = _prefs.getInt('lives') ?? AppConstants.maxLives;
    _currentLevel = _prefs.getInt('currentLevel') ?? 1;
    _highestUnlockedLevel = _prefs.getInt('highestUnlockedLevel') ?? 1;
    _totalScore = _prefs.getInt('totalScore') ?? 0;
    _coins = _prefs.getInt('coins') ?? 0;
    _streakDays = _prefs.getInt('streakDays') ?? 0;

    _soundEnabled = _prefs.getBool('soundEnabled') ?? true;
    _musicEnabled = _prefs.getBool('musicEnabled') ?? true;
    _vibrationEnabled = _prefs.getBool('vibrationEnabled') ?? true;

    // Synchronize to AudioManager
    AudioManager.instance.setSoundEnabled(_soundEnabled);
    AudioManager.instance.setMusicEnabled(_musicEnabled);

    final lastPlayedStr = _prefs.getString('lastPlayedDate');
    if (lastPlayedStr != null) {
      _lastPlayedDate = DateTime.tryParse(lastPlayedStr);
    }

    final resultsJson = _prefs.getString('levelResults');
    if (resultsJson != null) {
      final Map<String, dynamic> map = jsonDecode(resultsJson);
      for (final entry in map.entries) {
        final level = int.tryParse(entry.key);
        if (level != null) {
          _levelResults[level] =
              LevelResult.fromJson(entry.value as Map<String, dynamic>);
        }
      }
    }

    // Check streak
    _updateStreak();
  }

  Future<void> _save() async {
    await Future.wait([
      _prefs.setInt('lives', _lives),
      _prefs.setInt('currentLevel', _currentLevel),
      _prefs.setInt('highestUnlockedLevel', _highestUnlockedLevel),
      _prefs.setInt('totalScore', _totalScore),
      _prefs.setInt('coins', _coins),
      _prefs.setInt('streakDays', _streakDays),
      if (_lastPlayedDate != null)
        _prefs.setString('lastPlayedDate', _lastPlayedDate!.toIso8601String()),
    ]);

    // Save level results
    final Map<String, dynamic> resultsMap = {};
    for (final entry in _levelResults.entries) {
      resultsMap[entry.key.toString()] = entry.value.toJson();
    }
    await _prefs.setString('levelResults', jsonEncode(resultsMap));
  }

  // ── Lives — restored only via rewarded ad or level restart ─────────────────

  /// Called by GameState when player makes a wrong move.
  /// NOTE: Lives are NOT decremented from here — GameState manages lives
  /// during gameplay. This method is for external persistence (e.g. continue).
  Future<void> restoreLives({int amount = AppConstants.maxLives}) async {
    _lives = (_lives + amount).clamp(0, AppConstants.maxLives);
    await _save();
    notifyListeners();
  }

  /// Reset lives to full — called when player restarts a level.
  Future<void> resetLivesToFull() async {
    _lives = AppConstants.maxLives;
    await _save();
    notifyListeners();
  }

  // ── Streak ───────────────────────────────────────────────────────────────────

  void _updateStreak() {
    if (_lastPlayedDate == null) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastPlayed = DateTime(
      _lastPlayedDate!.year,
      _lastPlayedDate!.month,
      _lastPlayedDate!.day,
    );
    final diff = today.difference(lastPlayed).inDays;
    if (diff > 1) {
      // Streak broken
      _streakDays = 0;
      _save();
    }
  }

  Future<void> recordDailyPlay() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_lastPlayedDate != null) {
      final lastPlayed = DateTime(
        _lastPlayedDate!.year,
        _lastPlayedDate!.month,
        _lastPlayedDate!.day,
      );
      final diff = today.difference(lastPlayed).inDays;
      if (diff == 0) return; // Already recorded today
      if (diff == 1) {
        _streakDays++; // Consecutive day
      } else {
        _streakDays = 1; // Restart streak
      }
    } else {
      _streakDays = 1;
    }

    _lastPlayedDate = now;
    await _save();
    notifyListeners();
  }

  Future<void> protectStreak() async {
    // Called after watching a rewarded ad on streak break
    _lastPlayedDate = DateTime.now();
    await _save();
    notifyListeners();
  }

  // ── Level Progress ────────────────────────────────────────────────────────────

  Future<void> recordLevelComplete(LevelResult result) async {
    final existing = _levelResults[result.levelNumber];
    if (existing == null || result.stars > existing.stars) {
      _levelResults[result.levelNumber] = result;
    }
    _totalScore += result.score;
    _coins += (result.stars * 10);
    _currentLevel = result.levelNumber + 1;
    if (_currentLevel > _highestUnlockedLevel) {
      _highestUnlockedLevel = _currentLevel;
    }
    await _save();
    notifyListeners();
  }

  Future<void> setCurrentLevel(int level) async {
    _currentLevel = level;
    await _save();
    notifyListeners();
  }

  Future<void> addCoins(int amount) async {
    _coins += amount;
    await _save();
    notifyListeners();
  }

  // ── Settings Setters ─────────────────────────────────────────────────────────

  Future<void> setSoundEnabled(bool value) async {
    _soundEnabled = value;
    AudioManager.instance.setSoundEnabled(value);
    await _prefs.setBool('soundEnabled', value);
    notifyListeners();
  }

  Future<void> setMusicEnabled(bool value) async {
    _musicEnabled = value;
    AudioManager.instance.setMusicEnabled(value);
    await _prefs.setBool('musicEnabled', value);
    notifyListeners();
  }

  Future<void> setVibrationEnabled(bool value) async {
    _vibrationEnabled = value;
    await _prefs.setBool('vibrationEnabled', value);
    notifyListeners();
  }

  // ── Star rating calculator ────────────────────────────────────────────────────
  static int calculateStars(int livesLost, int totalArrows, int movesUsed) {
    if (livesLost == 0) return 3;
    if (livesLost == 1) return 2;
    return 1;
  }
}
