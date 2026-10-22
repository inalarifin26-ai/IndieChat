import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/voice_service.dart';
import 'state/app_state.dart';
import 'screens/splash_screen.dart';

class IndieApp extends StatelessWidget {
  const IndieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(create: (_) => VoiceService()..load()),
      ],
      child: MaterialApp(
        title: 'Indie',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.light,
        themeMode: ThemeMode.light,
        home: const SplashScreen(),
      ),
    );
  }
}
