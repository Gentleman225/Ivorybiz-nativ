import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/cart_item.dart';
import '../providers/cart_provider.dart';
import '../theme/app_colors.dart';
import '../utils/page_transitions.dart';
import '../widgets/product_card.dart' show formatPrice;
import 'checkout_screen.dart';

Future<void> showCartPanel(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fermer le panier',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, animation, secondaryAnimation) => const Align(
      alignment: Alignment.centerRight,
      child: FractionallySizedBox(
        widthFactor: 0.8,
        heightFactor: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.horizontal(
            left: Radius.circular(16),
          ),
          child: CartScreen(),
        ),
      ),
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final slideAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(slideAnimation),
        child: child,
      );
    },
  );
}

/// Écran Panier — articles avec image/quantité/prix, récapitulatif,
/// bouton "Passer la commande". Le code promo n'est pas encore
/// branché à une vraie logique de réduction (TODO côté WooCommerce).
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Mon panier (${cart.itemCount})'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Fermer le panier',
        ),
      ),
      body: cart.items.isEmpty
          ? const Center(child: Text('Ton panier est vide.'))
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: cart.items.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return _CartItemRow(item: item);
                    },
                  ),
                ),
                _CartSummary(cart: cart),
              ],
            ),
    );
  }
}

class _CartItemRow extends StatelessWidget {
  final CartItem item;

  const _CartItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 56,
              height: 56,
              child: item.product.imageUrls.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: item.product.imageUrls.first,
                      fit: BoxFit.cover,
                    )
                  : Container(color: AppColors.surfaceLight),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.product.name,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500)),
                if (item.selectedSize != null)
                  Text('Taille ${item.selectedSize}',
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _QtyButton(
                      icon: Icons.remove,
                      onTap: () =>
                          cart.updateQuantity(item.cartKey, item.quantity - 1),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text('${item.quantity}',
                          style: const TextStyle(fontSize: 12)),
                    ),
                    _QtyButton(
                      icon: Icons.add,
                      onTap: () =>
                          cart.updateQuantity(item.cartKey, item.quantity + 1),
                    ),
                    const Spacer(),
                    Text(formatPrice(item.lineTotal),
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 18, color: AppColors.textSecondary),
            onPressed: () => cart.removeItem(item.cartKey),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 14),
      ),
    );
  }
}

class _CartSummary extends StatelessWidget {
  final CartProvider cart;

  const _CartSummary({required this.cart});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Sous-total', style: TextStyle(fontSize: 13)),
                Text(formatPrice(cart.total),
                    style: const TextStyle(fontSize: 13)),
              ],
            ),
            const SizedBox(height: 6),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Expédition', style: TextStyle(fontSize: 13)),
                Text('Gratuite', style: TextStyle(fontSize: 13)),
              ],
            ),
            const Divider(height: 20, color: AppColors.border),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Text(formatPrice(cart.total),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context)
                    .push(fastRoute(const CheckoutScreen())),
                child: const Text('Passer la commande'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
