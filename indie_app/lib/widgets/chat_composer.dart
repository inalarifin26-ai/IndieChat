import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/voice_service.dart';
import 'voice_input_button.dart';

/// Message composer: [+]  (rounded field with emoji icon)  (gradient send).
class ChatComposer extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final VoidCallback onSend;
  final VoidCallback? onPlus;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;

  /// Shows a microphone (voice input) in place of Send while the box is empty.
  final bool voice;
  const ChatComposer({super.key, required this.controller, required this.onSend, this.hint = 'Type a message...', this.onPlus, this.onChanged, this.focusNode, this.voice = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + MediaQuery.of(context).padding.bottom * 0),
      child: SafeArea(
        top: false,
        child: Row(children: [
          GestureDetector(
            onTap: onPlus,
            child: Container(width: 38, height: 38, decoration: const BoxDecoration(color: AppColors.surfaceRaised, shape: BoxShape.circle), child: const Icon(Icons.add_rounded, color: AppColors.indigo, size: 22)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 42,
              padding: const EdgeInsets.only(left: 16, right: 12),
              decoration: BoxDecoration(color: AppColors.surfaceRaised, borderRadius: BorderRadius.circular(22)),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onChanged: onChanged,
                    onSubmitted: (_) => onSend(),
                    textInputAction: TextInputAction.send,
                    style: const TextStyle(fontSize: 14.5, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: const TextStyle(color: AppColors.textFaint, fontSize: 14.5),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const Icon(Icons.sentiment_satisfied_alt_rounded, size: 20, color: AppColors.textFaint),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final hasText = value.text.trim().isNotEmpty;
              // Keep the mic (as a Stop button) while listening, even though partial text is already in the box.
              final listening = voice ? context.watch<VoiceService>().listening : false;
              if (voice && (!hasText || listening)) return VoiceMicButton(controller: controller, onSend: onSend);
              return GestureDetector(
                onTap: onSend,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(gradient: AppColors.brandGradient, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]),
                  child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                ),
              );
            },
          ),
        ]),
      ),
    );
  }
}
