import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class AudioAlertService {
  static final AudioPlayer _alarmPlayer = AudioPlayer();
  static final AudioPlayer _chimePlayer = AudioPlayer();

  static Uint8List? _alarmWavBytes;
  static Uint8List? _chimeWavBytes;
  static bool _isAlarmPlaying = false;
  static Timer? _vibrationTimer;

  static bool get isAlarmPlaying => _isAlarmPlaying;

  /// Initialize Audio Alert Service & Pre-generate audio waveforms
  static Future<void> initialize() async {
    try {
      _alarmWavBytes ??= _generateAlarmToneBytes();
      _chimeWavBytes ??= _generateMessageBeepBytes();

      // Configure alarm player for high-priority notification usage
      await _alarmPlayer.setReleaseMode(ReleaseMode.loop);
      await _alarmPlayer.setVolume(1.0);

      // Configure chime player for single notification play
      await _chimePlayer.setReleaseMode(ReleaseMode.stop);
      await _chimePlayer.setVolume(0.85);
    } catch (_) {}
  }

  /// 🚨 LOUD ALARM ALERT (Used when mobile screen is OFF or app in BACKGROUND)
  /// Plays a persistent loud alarm beep in a loop + continuous pulse vibration
  static Future<void> playAlarmAlert() async {
    if (_isAlarmPlaying) return;
    _isAlarmPlaying = true;

    try {
      _alarmWavBytes ??= _generateAlarmToneBytes();

      await _alarmPlayer.stop();
      await _alarmPlayer.setReleaseMode(ReleaseMode.loop);
      await _alarmPlayer.setVolume(1.0);
      await _alarmPlayer.play(BytesSource(_alarmWavBytes!));

      // Continuous pulse vibration while alarm is ringing
      _vibrationTimer?.cancel();
      _triggerAlarmVibration();
      _vibrationTimer = Timer.periodic(const Duration(milliseconds: 1400), (_) {
        if (_isAlarmPlaying) {
          _triggerAlarmVibration();
        } else {
          _vibrationTimer?.cancel();
        }
      });
    } catch (_) {
      // Fallback system feedback if audio playback is blocked
      _triggerAlarmVibration();
    }
  }

  /// ⏹️ STOP ALARM ALERT
  /// Immediately silences the alarm and cancels vibration
  static Future<void> stopAlarmAlert() async {
    _isAlarmPlaying = false;
    _vibrationTimer?.cancel();
    _vibrationTimer = null;

    try {
      await _alarmPlayer.stop();
    } catch (_) {}
  }

  /// 🔔 SIMPLE NOTIFICATION BEEP (Used when worker is ACTIVELY ON THE APP)
  /// Plays a pleasant, single message ding + soft haptic feedback
  static Future<void> playMessageBeep() async {
    // If the loud alarm is running, don't overlap, just stop it
    if (_isAlarmPlaying) {
      await stopAlarmAlert();
    }

    try {
      _chimeWavBytes ??= _generateMessageBeepBytes();

      await _chimePlayer.stop();
      await _chimePlayer.setReleaseMode(ReleaseMode.stop);
      await _chimePlayer.setVolume(0.85);
      await _chimePlayer.play(BytesSource(_chimeWavBytes!));

      HapticFeedback.mediumImpact();
    } catch (_) {
      try {
        SystemSound.play(SystemSoundType.click);
        HapticFeedback.lightImpact();
      } catch (_) {}
    }
  }

  static void _triggerAlarmVibration() {
    try {
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 250), () {
        HapticFeedback.heavyImpact();
      });
      Future.delayed(const Duration(milliseconds: 500), () {
        HapticFeedback.heavyImpact();
      });
    } catch (_) {}
  }

  /// Generates a loud 2.0-second alternating dual-tone alarm siren waveform (850Hz & 1150Hz)
  static Uint8List _generateAlarmToneBytes() {
    const int sampleRate = 22050;
    const double duration = 1.8;
    const int totalSamples = (sampleRate * duration) ~/ 1;

    final Int16List samples = Int16List(totalSamples);

    for (int i = 0; i < totalSamples; i++) {
      double t = i / sampleRate;

      // Pulse pattern: 4 rapid beeps (0.45s cycle)
      double cycleTime = t % 0.45;
      bool isBeepOn = cycleTime < 0.22;

      if (isBeepOn) {
        // High urgency tone frequency (880Hz alternating to 1100Hz)
        double freq = (cycleTime < 0.11) ? 880.0 : 1100.0;
        double wave = math.sin(2.0 * math.pi * freq * t);
        // Add subtle harmonic for louder, sharper alarm cut-through
        wave += 0.3 * math.sin(2.0 * math.pi * (freq * 2) * t);
        samples[i] = (wave.clamp(-1.0, 1.0) * 28000).toInt();
      } else {
        samples[i] = 0;
      }
    }

    return _buildWavFile(samples, sampleRate);
  }

  /// Generates a gentle 0.3-second message chime waveform (1200Hz ding with decay)
  static Uint8List _generateMessageBeepBytes() {
    const int sampleRate = 22050;
    const double duration = 0.35;
    const int totalSamples = (sampleRate * duration) ~/ 1;

    final Int16List samples = Int16List(totalSamples);

    for (int i = 0; i < totalSamples; i++) {
      double t = i / sampleRate;
      // Exponential decay envelope for smooth pleasant chime
      double envelope = math.exp(-t * 9.0);
      double wave = math.sin(2.0 * math.pi * 1250.0 * t) * envelope;
      samples[i] = (wave.clamp(-1.0, 1.0) * 22000).toInt();
    }

    return _buildWavFile(samples, sampleRate);
  }

  /// Constructs a standard 44-byte RIFF/WAVE header + 16-bit PCM payload
  static Uint8List _buildWavFile(Int16List samples, int sampleRate) {
    final int byteLength = samples.length * 2;
    final ByteData byteData = ByteData(44 + byteLength);

    // RIFF chunk
    byteData.setUint8(0, 0x52); // 'R'
    byteData.setUint8(1, 0x49); // 'I'
    byteData.setUint8(2, 0x46); // 'F'
    byteData.setUint8(3, 0x46); // 'F'
    byteData.setUint32(4, 36 + byteLength, Endian.little);
    byteData.setUint8(8, 0x57);  // 'W'
    byteData.setUint8(9, 0x41);  // 'A'
    byteData.setUint8(10, 0x56); // 'V'
    byteData.setUint8(11, 0x45); // 'E'

    // fmt subchunk
    byteData.setUint8(12, 0x66); // 'f'
    byteData.setUint8(13, 0x6D); // 'm'
    byteData.setUint8(14, 0x74); // 't'
    byteData.setUint8(15, 0x20); // ' '
    byteData.setUint32(16, 16, Endian.little); // Subchunk1Size
    byteData.setUint16(20, 1, Endian.little);  // AudioFormat: PCM (1)
    byteData.setUint16(22, 1, Endian.little);  // NumChannels: Mono (1)
    byteData.setUint32(24, sampleRate, Endian.little);
    byteData.setUint32(28, sampleRate * 2, Endian.little); // ByteRate
    byteData.setUint16(32, 2, Endian.little);  // BlockAlign: 2
    byteData.setUint16(34, 16, Endian.little); // BitsPerSample: 16

    // data subchunk
    byteData.setUint8(36, 0x64); // 'd'
    byteData.setUint8(37, 0x61); // 'a'
    byteData.setUint8(38, 0x74); // 't'
    byteData.setUint8(39, 0x61); // 'a'
    byteData.setUint32(40, byteLength, Endian.little);

    // Audio samples
    int offset = 44;
    for (int i = 0; i < samples.length; i++) {
      byteData.setInt16(offset, samples[i], Endian.little);
      offset += 2;
    }

    return byteData.buffer.asUint8List();
  }
}
