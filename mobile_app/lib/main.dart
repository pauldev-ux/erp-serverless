import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const ErpApp());
}

class ErpApp extends StatelessWidget {
  const ErpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ERP Serverless',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0B2447),
          brightness: Brightness.dark,
          primary: const Color(0xFF0B2447),
          secondary: const Color(0xFF2AB7CA),
          surface: const Color(0xFF0F2336),
          background: const Color(0xFF071028),
        ),
        scaffoldBackgroundColor: const Color(0xFF071028),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF1E1E2E),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF0F2336),
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2A2A3E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 2),
          ),
          labelStyle: const TextStyle(color: Color(0xFF8A8AA0)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0B2447),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            textStyle: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF6C63FF),
          foregroundColor: Colors.white,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF2A2A3E),
          contentTextStyle: GoogleFonts.inter(color: Colors.white),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
