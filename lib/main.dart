import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'Screens/SplashScreen.dart';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  
  // Préserver le splash screen natif pendant l'initialisation
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  
  await Firebase.initializeApp();
  await SharedPreferences.getInstance();
  await initializeDateFormatting('fr_FR', null);
  
  runApp(const MaghaliApp());
  
  // Retirer le splash screen natif après un court délai
  // Le SplashScreen Flutter prendra le relais
  Future.delayed(const Duration(milliseconds: 100), () {
    FlutterNativeSplash.remove();
  });
}

class MaghaliApp extends StatelessWidget {
  const MaghaliApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Maghali',
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.black,
        scaffoldBackgroundColor: Colors.white,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
