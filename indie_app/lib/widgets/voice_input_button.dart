import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/voice_command.dart';
import '../core/voice_service.dart';

/// Opens the voice-input explanation / settings.
/// [firstTime] is the consent step: nothing listens until the person taps "Allow microphone".
/// Resolves to true when the person confirmed.
Future<bool?> showVoiceSettingsSheet(BuildContext context, {required bool firstTime}) {
  final voice = context.read<VoiceService>();
  var lang = voice.localeId;
  var hands = voice.handsFreeSend;
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Voice input', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text(
              "Your device's speech recognition turns your voice into text. Depending on your device and language it may use an online service — Indie itself never receives or stores audio, only the text you send.",
              style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            const Text('Language', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [
              for (final l in const [('id_ID', 'Bahasa Indonesia'), ('en_US', 'English')])
                ChoiceChip(label: Text(l.$2), selected: lang == l.$1, onSelected: (_) => setSheet(() => lang = l.$1)),
            ]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.stroke)),
              child: Row(children: [
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Hands-free send', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                    SizedBox(height: 2),
                    Text('End a command with “kirim” or “send” to send it without tapping. Off by default.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ]),
                ),
                Switch(value: hands, onChanged: (v) => setSheet(() => hands = v)),
              ]),
            ),
            const SizedBox(height: 8),
            const Text('Say “batal” or “cancel” to discard what you just dictated.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.of(ctx).pop(false), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)), child: const Text('Cancel'))),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(14)),
                  child: TextButton(
                    style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: Colors.white),
                    onPressed: () async {
                      await voice.saveSettings(consented: true, handsFree: hands, locale: lang);
                      if (ctx.mounted) Navigator.of(ctx).pop(true);
                    },
                    child: Text(firstTime ? 'Allow microphone' : 'Save', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ),
    ),
  );
}

/// The microphone button shown in a composer when the box is empty (or while listening).
/// Tap = start / stop, long-press = voice settings. Dictation is appended to what is
/// already typed; nothing is sent unless hands-free send is on and the person ends the
/// utterance with the send keyword (see [parseVoiceCommand]).
class VoiceMicButton extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  const VoiceMicButton({super.key, required this.controller, required this.onSend});

  @override
  State<VoiceMicButton> createState() => _VoiceMicButtonState();
}

class _VoiceMicButtonState extends State<VoiceMicButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  String _prefix = '';
  String _heard = '';
  bool _finalized = false;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 3)));
  }

  void _setText(String t) {
    widget.controller.value = TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }

  Future<void> _onTap() async {
    final voice = context.read<VoiceService>();
    if (voice.listening) {
      await voice.stop();
      return;
    }
    if (!voice.consented) {
      final ok = await showVoiceSettingsSheet(context, firstTime: true);
      if (ok != true || !mounted) return;
    }
    await _start();
  }

  Future<void> _start() async {
    final voice = context.read<VoiceService>();
    final typed = widget.controller.text.trim();
    _prefix = typed.isEmpty ? '' : '$typed ';
    _heard = '';
    _finalized = false;
    final ok = await voice.start(onResult: _onResult, onDone: _onDone);
    if (!ok) _snack(voice.error ?? 'Voice input is not available on this device.');
  }

  void _onResult(String words, bool isFinal) {
    if (!mounted) return;
    _heard = words.trim();
    _setText(_prefix + _heard);
    if (isFinal) _finalize();
  }

  void _onDone() {
    if (!mounted) return;
    final voice = context.read<VoiceService>();
    if (!_finalized && _heard.isNotEmpty) _finalize();
    if (voice.error != null) _snack(voice.error!);
  }

  void _finalize() {
    if (_finalized) return;
    _finalized = true;
    final voice = context.read<VoiceService>();
    final cmd = parseVoiceCommand(_heard, handsFree: voice.handsFreeSend);
    if (cmd.clear) {
      _setText(_prefix.trim());
      _snack('Dictation cancelled');
    } else {
      _setText(_prefix + cmd.text);
      if (cmd.send) widget.onSend();
    }
    voice.stop();
  }

  @override
  Widget build(BuildContext context) {
    final listening = context.watch<VoiceService>().listening;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (listening && !_pulse.isAnimating) _pulse.repeat();
      if (!listening && _pulse.isAnimating) {
        _pulse.stop();
        _pulse.value = 0;
      }
    });
    return GestureDetector(
      onTap: _onTap,
      onLongPress: () => showVoiceSettingsSheet(context, firstTime: false),
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) => SizedBox(
          width: 40,
          height: 40,
          child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
            if (listening)
              Container(
                width: 40 + 22 * _pulse.value,
                height: 40 + 22 * _pulse.value,
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.danger.withAlpha((255 * 0.28 * (1 - _pulse.value)).round())),
              ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(shape: BoxShape.circle, color: listening ? AppColors.danger : AppColors.surfaceRaised),
              child: Icon(listening ? Icons.stop_rounded : Icons.mic_none_rounded, size: 21, color: listening ? Colors.white : AppColors.indigo),
            ),
          ]),
        ),
      ),
    );
  }
}
