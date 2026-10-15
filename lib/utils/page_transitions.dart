import 'package:flutter/material.dart';

/// Transition rapide (150ms) utilisée pour la navigation entre les
/// écrans principaux — décision validée avec Dosso : rapidité plutôt
/// qu'un effet visuel élaboré. L'état de chargement squelette (voir
/// widgets/skeleton_loader.dart) gère l'attente des données, pas la
/// transition elle-même.
Route<T> fastRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: const Duration(milliseconds: 180),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: child,
      );
    },
  );
}
