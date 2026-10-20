import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/common.dart';
import '../../widgets/indie_logo.dart';
import 'create_id_screen.dart';
import 'sign_in_screen.dart';

/// 01 · Intro / Welcome — pastel wash, logo, "Get Started" / "Sign In".
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(center: Alignment(-0.9, -1.0), radius: 1.4, colors: [Color(0xFFE4E1FF), Colors.white], stops: [0.0, 0.7]),
        ),
        child: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(center: Alignment(1.0, 1.0), radius: 1.1, colors: [Color(0xFFCFF3FF), Color(0x00FFFFFF)], stops: [0.0, 0.7]),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
              child: Column(children: [
                const Spacer(flex: 3),
                const IndieFullLogo(width: 220),
                const Spacer(flex: 2),
                const Text('Personal Chat', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                const Text(
                  'Your private space for conversations, clear connections, and intelligent collaboration.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, height: 1.55, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: GradientButton(label: 'Get Started', onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateIdScreen()))),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignInScreen())),
                  child: const Text('Sign In', style: TextStyle(color: AppColors.indigo, fontWeight: FontWeight.w700, fontSize: 14.5)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
