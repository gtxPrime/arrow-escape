import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

/// Centralized audio manager for all game sounds and music.
class AudioManager {
  AudioManager._();
  static final AudioManager instance = AudioManager._();

  bool _soundEnabled = true;
  bool _musicEnabled = true;

  bool get soundEnabled => _soundEnabled;
  bool get musicEnabled => _musicEnabled;

  final List<String> _exitSounds = [
    'swoosh_08.mp3',
    'swoosh_16.mp3',
    'swoosh_18.mp3',
    'sound_effect_1.wav',
    'sound_effect_12.wav',
    'sound_effect_8.wav',
  ];
  int _exitSoundIndex = 0;

  late AudioPool _clickPool;
  bool _clickPoolInitialized = false;

  Future<void> initialize() async {
    try {
      FlameAudio.bgm.initialize();
      // Precache the audio files during splash screen load
      await FlameAudio.audioCache.loadAll([
        'click.ogg',
        'underwater.mp3',
        ..._exitSounds,
      ]);
      // Pre-warm a pool of players for the click sound to ensure zero latency
      _clickPool = await FlameAudio.createPool(
        'click.ogg',
        minPlayers: 3,
        maxPlayers: 5,
      );
      _clickPoolInitialized = true;
    } catch (e) {
      debugPrint('Error initializing FlameAudio: $e');
    }
  }

  // ── Music ─────────────────────────────────────────────────────────────────────

  Future<void> playBgMusic() async {
    if (!_musicEnabled) return;
    try {
      if (FlameAudio.bgm.isPlaying) return;
      await FlameAudio.bgm.play('underwater.mp3', volume: 0.4);
    } catch (e) {
      debugPrint('Error playing background music: $e');
    }
  }

  Future<void> playMenuMusic() async {
    await playBgMusic();
  }

  Future<void> playGameMusic() async {
    await playBgMusic();
  }

  Future<void> stopMusic() async {
    try {
      await FlameAudio.bgm.stop();
    } catch (e) {
      debugPrint('Error stopping background music: $e');
    }
  }

  // ── SFX ───────────────────────────────────────────────────────────────────────

  Future<void> playClick() async {
    if (!_soundEnabled) return;
    try {
      if (_clickPoolInitialized) {
        await _clickPool.start(volume: 0.8);
      } else {
        await FlameAudio.play('click.ogg', volume: 0.8);
      }
    } catch (e) {
      debugPrint('Error playing click sound: $e');
    }
  }

  Future<void> playArrowTap() async {
    await playClick();
  }

  Future<void> playArrowExit() async {
    if (!_soundEnabled) return;
    try {
      final soundPath = _exitSounds[_exitSoundIndex];
      _exitSoundIndex = (_exitSoundIndex + 1) % _exitSounds.length;
      await FlameAudio.play(soundPath, volume: 0.8);
    } catch (e) {
      debugPrint('Error playing arrow exit sound: $e');
    }
  }

  Future<void> playArrowBlock() async {}

  Future<void> playLevelComplete() async {}

  Future<void> playLifeLost() async {}

  Future<void> playGameOver() async {}

  Future<void> playStreakExtended() async {}

  // ── Settings ──────────────────────────────────────────────────────────────────

  void setSoundEnabled(bool value) {
    _soundEnabled = value;
  }

  void setMusicEnabled(bool value) {
    _musicEnabled = value;
    if (!value) {
      stopMusic();
    } else {
      playBgMusic();
    }
  }

  void dispose() {
    try {
      FlameAudio.bgm.dispose();
    } catch (e) {
      debugPrint('Error disposing FlameAudio bgm: $e');
    }
  }
}
