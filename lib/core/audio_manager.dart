import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Centralized audio manager for all game sounds and music.
class AudioManager {
  AudioManager._();
  static final AudioManager instance = AudioManager._();

  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _musicPlayer = AudioPlayer();

  bool _soundEnabled = true;
  bool _musicEnabled = true;

  bool get soundEnabled => _soundEnabled;
  bool get musicEnabled => _musicEnabled;

  final List<String> _exitSounds = [
    'audio/swoosh_08.mp3',
    'audio/swoosh_16.mp3',
    'audio/swoosh_18.mp3',
    'audio/sound_effect_1.wav',
    'audio/sound_effect_12.wav',
    'audio/sound_effect_8.wav',
  ];
  int _exitSoundIndex = 0;

  Future<void> initialize() async {
    await _musicPlayer.setReleaseMode(ReleaseMode.loop);
    await _musicPlayer.setVolume(0.4);
    await _sfxPlayer.setVolume(0.8);
  }

  // ── Music ─────────────────────────────────────────────────────────────────────

  Future<void> playBgMusic() async {
    if (!_musicEnabled) return;
    try {
      if (_musicPlayer.state == PlayerState.playing) return;
      await _musicPlayer.play(AssetSource('audio/underwater.mp3'));
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
    await _musicPlayer.stop();
  }

  // ── SFX ───────────────────────────────────────────────────────────────────────

  Future<void> playClick() async {
    if (!_soundEnabled) return;
    try {
      final player = AudioPlayer();
      await player.play(AssetSource('audio/click.ogg'));
      player.onPlayerComplete.listen((_) {
        player.dispose();
      });
    } catch (e) {
      debugPrint('Error playing click sound: $e');
    }
  }

  Future<void> playArrowTap() async {
    // Falls back to UI click sound
    await playClick();
  }

  Future<void> playArrowExit() async {
    if (!_soundEnabled) return;
    try {
      final soundPath = _exitSounds[_exitSoundIndex];
      _exitSoundIndex = (_exitSoundIndex + 1) % _exitSounds.length;

      final player = AudioPlayer();
      await player.play(AssetSource(soundPath));
      player.onPlayerComplete.listen((_) {
        player.dispose();
      });
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
    if (!value) _sfxPlayer.stop();
  }

  void setMusicEnabled(bool value) {
    _musicEnabled = value;
    if (!value) {
      _musicPlayer.stop();
    } else {
      playBgMusic();
    }
  }

  void dispose() {
    _sfxPlayer.dispose();
    _musicPlayer.dispose();
  }
}
