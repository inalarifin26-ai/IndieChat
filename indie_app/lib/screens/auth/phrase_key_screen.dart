import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/common.dart';
import '../root_shell.dart';

/// 03 · Create Phrase Key — the 12-word recovery phrase, shown exactly once.
/// The account already exists at this point (created on the previous screen),
/// so there is deliberately no way back: leaving would lose the phrase.
class PhraseKeyScreen extends StatefulWidget {
  final String phrase;
  const PhraseKeyScreen({super.key, required this.phrase});

  @override
  State<PhraseKeyScreen> createState() => _PhraseKeyScreenState();
}

class _PhraseKeyScreenState extends State<PhraseKeyScreen> {
  bool _saved = false;
  bool _shake = false;

  List<String> get _words => widget.phrase.split(RegExp(r'\s+'));

  void _continue() {
    if (!_saved) {
      setState(() => _shake = true);
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _shake = false);
      });
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const RootShell()), (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    final words = _words;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
            children: [
              Center(
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(color: const Color(0xFFE5EEFF), borderRadius: BorderRadius.circular(20)),
                  child: const Icon(Icons.verified_user_outlined, color: AppColors.accent, size: 34),
                ),
              ),
              const SizedBox(height: 14),
              const Center(child: Text('Create Phrase Key', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800))),
              const SizedBox(height: 6),
              const Text(
                'Your phrase key is the only way to recover your account. Keep it safe and private.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.stroke)),
                child: GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 2.6,
                  children: [
                    for (var i = 0; i < words.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text.rich(TextSpan(children: [
                          TextSpan(text: '${i + 1}. ', style: const TextStyle(color: AppColors.textFaint, fontSize: 12.5)),
                          TextSpan(text: words[i], style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5)),
                        ])),
                      ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: widget.phrase));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phrase copied — paste it somewhere safe, then clear your clipboard')));
                  },
                  icon: const Icon(Icons.content_copy_rounded, size: 16),
                  label: const Text('Copy'),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _saved = !_saved),
                child: Row(children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(color: _saved ? AppColors.accent : Colors.white, borderRadius: BorderRadius.circular(7), border: Border.all(color: _saved ? AppColors.accent : const Color(0xFFC4CCE2), width: 1.8)),
                    child: _saved ? const Icon(Icons.check_rounded, color: Colors.white, size: 15) : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('I have saved my phrase key in a safe place', style: TextStyle(fontSize: 13, color: _shake ? AppColors.danger : AppColors.textSecondary)),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              GradientButton(label: 'Continue', onPressed: _continue),
              const SizedBox(height: 10),
              const Text(
                'We never store this phrase. If you lose it and your device, the account cannot be recovered.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: AppColors.textFaint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
