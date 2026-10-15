import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../screens/cart_screen.dart';
import '../screens/home_screen.dart';
import '../screens/shop_screen.dart';
import '../theme/app_colors.dart';
import '../utils/page_transitions.dart';

/// Barre de navigation basse commune à Accueil/Boutique/Panier.
/// "Compte" reste volontairement inactif (décision validée) — l'icône
/// est visible mais désactivée, sans écran derrière pour l'instant.
class IvorybizBottomNav extends StatelessWidget {
  final int currentIndex; // 0 Accueil, 1 Boutique, 2 Panier

  const IvorybizBottomNav({super.key, required this.currentIndex});

  void _go(BuildContext context, int index) {
    if (index == currentIndex) return;
    switch (index) {
      case 0:
        Navigator.of(context).push(fastRoute(const HomeScreen()));
        break;
      case 1:
        Navigator.of(context).push(fastRoute(const ShopScreen()));
        break;
      case 2:
        showCartPanel(context);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<CartProvider>().itemCount;

    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) => _go(context, index),
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Accueil',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.storefront_outlined),
          activeIcon: Icon(Icons.storefront),
          label: 'Boutique',
        ),
        BottomNavigationBarItem(
          icon: Badge(
            label: Text('$cartCount'),
            isLabelVisible: cartCount > 0,
            child: const Icon(Icons.shopping_cart_outlined),
          ),
          activeIcon: const Icon(Icons.shopping_cart),
          label: 'Panier',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person_outline, color: AppColors.textSecondary),
          label: 'Compte',
        ),
      ],
      // Note : "Compte" (index 3) n'a pas de cas dans _go() ci-dessus,
      // donc taper dessus ne fait rien pour l'instant — décision validée
      // (écran Compte volontairement inactif).
    );
  }
}
