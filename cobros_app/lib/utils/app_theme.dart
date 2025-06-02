import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color.fromARGB(255, 0, 78, 122); // Azul corporativo
  static const Color neutroColor = Color.fromARGB(255, 255, 255, 255);
  static const Color secondaryColor = Color(0xFF8C54FF); // Morado corporativo
  static const Color accentColor = Color(0xFF00C6FF); // Cyan corporativo
  static const Color errorColor = Color(0xFFFF3B30); // Rojo para errores
  static const Color successColor = Color(0xFF34C759); // Verde para éxito
  static const Color textColor = Color(0xFF2E384D); // Color de texto principal
  static const Color lightTextColor = Color(0xFFB0BAC9); // Texto secundario

  // Nombres de fuentes (deben coincidir con las cargadas en pubspec.yaml)
  static const String primaryFont = 'Roboto';
  static const String secondaryFont = 'OpenSans';

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primaryColor,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        error: errorColor,
      ),
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 2,
        titleTextStyle: TextStyle(
          fontFamily: primaryFont,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: primaryFont,
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
        displayMedium: TextStyle(
          fontFamily: primaryFont,
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
        displaySmall: TextStyle(
          fontFamily: primaryFont,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
        headlineMedium: TextStyle(
          fontFamily: primaryFont,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
        headlineSmall: TextStyle(
          fontFamily: primaryFont,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
        titleLarge: TextStyle(
          fontFamily: primaryFont,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
        bodyLarge: TextStyle(fontFamily: secondaryFont, fontSize: 16, color: textColor),
        bodyMedium: TextStyle(fontFamily: secondaryFont, fontSize: 14, color: textColor),
        bodySmall: TextStyle(fontFamily: secondaryFont, fontSize: 12, color: lightTextColor),
      ),
      buttonTheme: ButtonThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        buttonColor: primaryColor,
        textTheme: ButtonTextTheme.primary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(fontFamily: primaryFont, fontWeight: FontWeight.bold),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE0E6ED)),
        ),
        enabledBorder: OutlineInputBorder(
          // Cambiado de 'enabledBorder' a 'enabledBorder'
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE0E6ED)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(color: Color(0xFFB0BAC9), fontSize: 16),
        hintStyle: const TextStyle(color: Color(0xFFB0BAC9), fontSize: 14),
      ),
    );
  }

  // Opcional: tema oscuro corporativo
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      // Definir colores para modo oscuro
    );
  }
}
