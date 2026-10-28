import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/services/pricing_config_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/splash_screen.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    PricingConfigService.instance.startListening();
    debugPrint('>>> [Firebase initialized successfully]');
  } catch (e) {
    debugPrint('>>> [Firebase init error]: $e');
  }
  
  // Set status bar icons color to dark for clean mobile look
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const GoShipApp());
}

class GoShipApp extends StatelessWidget {
  const GoShipApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GoShip Logistics',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
