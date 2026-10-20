import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ATFA brand colors
   static const Color primarySlate = Color(0xFF1E293B);
  static const Color secondarySlate = Color(0xFF94A3B8);
  static const Color primaryBlue = Color(0xFF1976D2);
  static const Color secondaryBlue = Color(0xFF94A3B8);
  static const Color accentOrange = Color(0xFFFF9800);
  
  // Status / Data Feedback Colors
  static const Color successGreen = Color(0xFF10B981);
  static const Color warningYellow = Color(0xFFFACC15);
  static const Color errorRed = Color(0xFFEF4444);
  
  // Additional radial/gradient colors
  static const Color successGreenLight = Color(0xFF34D399);
  static const Color warningYellowLight = Color(0xFFFDE047);
  static const Color errorRedLight = Color(0xFFF87171);
  
  static const Color darkGrey = Color(0xFF424242);
  static const Color lightGrey = Color(0xFFF5F5F5);
  static const Color pageBackground = Color(0xFFF1F5F9);

  // One per screen: the next best action. Navy text keeps contrast above 4.5:1.
  static ButtonStyle get primaryButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: accentOrange,
    foregroundColor: primarySlate,
    disabledBackgroundColor: accentOrange.withValues(alpha: 0.45),
    disabledForegroundColor: primarySlate.withValues(alpha: 0.6),
    minimumSize: const Size(0, 52),
    elevation: 0,
    shadowColor: Colors.transparent,
  );

  static ButtonStyle secondaryButtonStyle(Brightness brightness) {
    final color = brightness == Brightness.dark ? Colors.white70 : primarySlate;
    return OutlinedButton.styleFrom(
      foregroundColor: color,
      side: BorderSide(color: color, width: 1.5),
      minimumSize: const Size(0, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primarySlate,
        brightness: Brightness.light,
        primary: primarySlate,
        secondary: accentOrange,
        tertiary: primaryBlue,
        surface: Colors.white,
        onSurface: darkGrey,
        error: errorRed,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primarySlate,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: primarySlate,
        selectedItemColor: Colors.white,
        unselectedItemColor: secondarySlate,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      cardTheme: const CardThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        color: Colors.white,
      ),
      scaffoldBackgroundColor: pageBackground,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primarySlate,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textTheme: TextTheme(
        headlineLarge: GoogleFonts.poppins(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: darkGrey,
        ),
        headlineMedium: GoogleFonts.poppins(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: darkGrey,
        ),
        titleLarge: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: darkGrey,
        ),
        titleMedium: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: darkGrey,
        ),
        bodyLarge: GoogleFonts.poppins(
          fontSize: 16,
          color: darkGrey,
        ),
        bodyMedium: GoogleFonts.poppins(
          fontSize: 14,
          color: darkGrey,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        brightness: Brightness.dark,
        primary: accentOrange,
        secondary: primarySlate,
        tertiary: primaryBlue,
        surface: const Color(0xFF1E1E1E),
        onSurface: Colors.white,
        error: errorRed,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primarySlate,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: primarySlate,
        selectedItemColor: accentOrange,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      cardTheme: const CardThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        color: Color(0xFF2D2D2D),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primarySlate,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textTheme: TextTheme(
        headlineLarge: GoogleFonts.poppins(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        headlineMedium: GoogleFonts.poppins(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titleLarge: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titleMedium: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        bodyLarge: GoogleFonts.poppins(
          fontSize: 16,
          color: Colors.white70,
        ),
        bodyMedium: GoogleFonts.poppins(
          fontSize: 14,
          color: Colors.white70,
        ),
      ),
    );
  }
}
