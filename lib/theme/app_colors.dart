import 'package:flutter/material.dart';

/// Palette de couleurs de la marque Ivorybiz.
/// Centralisée ici pour que tout le monde (widgets, écrans) utilise
/// exactement les mêmes teintes — jamais de couleur codée en dur ailleurs.
class AppColors {
  AppColors._();

  // Bleus de marque (dégradé du splash / bannière)
  static const Color navyDark = Color(0xFF0A0A6E);
  static const Color blue = Color(0xFF0044CC);
  static const Color blueLight = Color(0xFF0066FF);
  static const Color skyBlue = Color(0xFF87CEEB);
  static const Color primary =
      Color(0xFF0C447C); // bleu utilisé sur les headers d'écran
  static const Color accentCyan = Color(0xFF00CFFF);

  // Doré (accents boutons, badges)
  static const Color gold = Color(0xFFD4AF37);

  // États
  static const Color success = Color(0xFF2E7D46);
  static const Color error = Color(0xFFB3261E);
  static const Color promo = Color(0xFF993C1D);

  // Neutres
  static const Color surfaceLight = Color(0xFFF5F2EC);
  static const Color background = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color border = Color(0xFFE0E0E0);

  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navyDark, blue, blueLight],
    stops: [0.0, 0.6, 1.0],
  );
}
