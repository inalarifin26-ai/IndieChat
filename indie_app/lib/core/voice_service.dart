import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Speech-to-text for the chat composers.
///
/// Privacy: recognition is done by the device's speech service (on some
/// devices/languages that service is online). Indie never receives audio —
/// only the text the person sends. Nothing is sent automatically unless the
/// person has explicitly turned on hands-free send.
class VoiceService extends ChangeNotifier {
  final SpeechToText _stt = SpeechToText();

  bool _ready = false;
  bool available = false;
  bool listening = false;

  /// The person has seen the voice-input explanation and agreed.
  bool consented = false;

  /// End a command with "kirim"/"send" to send without tapping. Off by default.
  bool handsFreeSend = false;
  String localeId = 'id_ID';

  /// Last problem, in words a person can act on (null when none).
  String? error;

  void Function(String words, bool isFinal)? _onResult;
  void Function()? _onDone;
  Timer? _grace;

  static const _kConsented = 'voice.consented';
  static const _kHandsFree = 'voice.handsFree';
  static const _kLocale = 'voice.locale';

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      consented = p.getBool(_kConsented) ?? false;
      handsFreeSend = p.getBool(_kHandsFree) ?? false;
      localeId = p.getString(_kLocale) ?? localeId;
      notifyListeners();
    } catch (_) {
      // Defaults are fine; settings just will not persist.
    }
  }

  Future<void> saveSettings({bool? consented, bool? handsFree, String? locale}) async {
    if (consented != null) this.consented = consented;
    if (handsFree != null) handsFreeSend = handsFree;
    if (locale != null) localeId = locale;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kConsented, this.consented);
      await p.setBool(_kHandsFree, handsFreeSend);
      await p.setString(_kLocale, localeId);
    } catch (_) {}
  }

  String _norm(String id) => id.replaceAll('-', '_').toLowerCase();

  Future<bool> _ensureReady() async {
    if (_ready) return available;
    try {
      available = await _stt.initialize(onStatus: _onStatus, onError: _onError);
    } catch (e) {
      available = false;
      error = 'Voice input could not start ($e).';
    }
    _ready = true;
    if (available) {
      try {
        final locales = await _stt.locales();
        if (!locales.any((l) => _norm(l.localeId) == _norm(localeId))) {
          final sys = await _stt.systemLocale();
          if (sys != null) localeId = sys.localeId;
        }
      } catch (_) {
        // Keep the chosen locale; the engine will report if it cannot use it.
      }
    }
    return available;
  }

  /// Starts listening. [onResult] gets partial transcripts and finally a final one;
  /// [onDone] fires once when the session ends (finished, stopped or failed).
  Future<bool> start({required void Function(String words, bool isFinal) onResult, void Function()? onDone}) async {
    if (listening) return true;
    error = null;
    if (!await _ensureReady()) {
      error ??= 'Voice input is not available — check the microphone permission in Settings.';
      notifyListeners();
      return false;
    }
    _onResult = onResult;
    _onDone = onDone;
    listening = true;
    notifyListeners();
    try {
      await _stt.listen(
        onResult: _handleResult,
        localeId: localeId,
        listenFor: const Duration(seconds: 45),
        pauseFor: const Duration(seconds: 3),
      );
    } catch (e) {
      error = 'Voice input could not start ($e).';
      _finish();
      return false;
    }
    return true;
  }

  void _handleResult(SpeechRecognitionResult r) => _onResult?.call(r.recognizedWords, r.finalResult);

  /// Ends the session; the final transcript is still delivered to [start]'s onResult.
  Future<void> stop() async {
    try {
      await _stt.stop();
    } catch (_) {}
  }

  Future<void> cancel() async {
    try {
      await _stt.cancel();
    } catch (_) {}
    _finish();
  }

  // Status order is listening → notListening → (final result) → done. The final
  // transcript can arrive AFTER 'notListening', so only 'done' closes the
  // session; if 'done' never comes, a short grace timer closes it instead.
  void _onStatus(String status) {
    if (status == 'done' || status == 'doneNoResult') {
      _finish();
    } else if (status == 'notListening' && listening) {
      _grace?.cancel();
      _grace = Timer(const Duration(milliseconds: 1500), _finish);
    }
  }

  void _onError(SpeechRecognitionError e) {
    error = _friendly(e.errorMsg);
    _finish();
  }

  String? _friendly(String code) {
    switch (code) {
      case 'error_permission':
        return 'Microphone permission was denied — enable it in Settings.';
      case 'error_no_match':
      case 'error_speech_timeout':
        return "Didn't catch that — try again.";
      case 'error_network':
      case 'error_network_timeout':
        return 'Speech recognition needs an internet connection for this language.';
      case 'error_language_not_supported':
      case 'error_language_unavailable':
        return 'This language is not available for voice input on this device.';
      case 'error_audio':
        return 'The microphone is busy or unavailable.';
      default:
        return 'Voice input failed ($code).';
    }
  }

  void _finish() {
    _grace?.cancel();
    _grace = null;
    if (!listening) return;
    listening = false;
    final done = _onDone;
    _onDone = null;
    _onResult = null;
    notifyListeners();
    done?.call();
  }

  @override
  void dispose() {
    _grace?.cancel();
    _stt.cancel();
    super.dispose();
  }
}
