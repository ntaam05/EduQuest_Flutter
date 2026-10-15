// lib/services/sound_service.dart
// Phát âm thanh ngắn (tích tắc / hết giờ) cho phòng thi.
// Mọi lỗi âm thanh đều bị nuốt để không bao giờ làm hỏng màn chơi.

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  final AudioPlayer _tick = AudioPlayer();
  final AudioPlayer _urgent = AudioPlayer();
  final AudioPlayer _timesUp = AudioPlayer();
  bool _enabled = true;

  bool get enabled => _enabled;
  set enabled(bool value) {
    _enabled = value;
    if (!value) unawaited(stopAll());
  }

  Future<void> _play(AudioPlayer player, String asset) async {
    if (!_enabled) return;
    try {
      await player.stop();
      await player.play(AssetSource('sounds/$asset'), volume: 1.0);
    } catch (error) {
      debugPrint('SoundService: không phát được $asset: $error');
    }
  }

  /// Tiếng bíp mỗi giây khi còn <= 5 giây; [urgent] = true (<= 3 giây) bíp đôi, cao hơn.
  Future<void> playTick({bool urgent = false}) =>
      urgent ? _play(_urgent, 'tick_urgent.wav') : _play(_tick, 'tick.wav');

  /// Tiếng báo hết giờ.
  Future<void> playTimeUp() => _play(_timesUp, 'timesup.wav');

  Future<void> stopAll() async {
    try {
      await _tick.stop();
      await _urgent.stop();
      await _timesUp.stop();
    } catch (_) {}
  }
}
