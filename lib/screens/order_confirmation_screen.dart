import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/page_transitions.dart';
import '../widgets/product_card.dart' show formatPrice;
import 'home_screen.dart';

const Map<String, String> _paymentLabels = {
  'orange_money': 'Orange Money',
  'wave': 'Wave',
  'mtn_money': 'MTN Money',
  'moov_money': 'Moov Money',
  'livraison': 'Paiement à la livraison',
};

/// Écran de confirmation — visuel validé : icône succès, n° commande,
/// récap, "Suivre ma commande" / retour accueil.
class OrderConfirmationScreen extends StatelessWidget {
  final int orderId;
  final String paymentMethod;
  final double total;

  const OrderConfirmationScreen({
    super.key,
    required this.orderId,
    required this.paymentMethod,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFE6F4EA),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check,
                    size: 36, color: AppColors.success),
              ),
              const SizedBox(height: 20),
              const Text('Commande confirmée !',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                'Ta commande #IB-$orderId a bien été enregistrée. '
                'Tu recevras une notification dès qu\'elle sera expédiée.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    _summaryRow('N° commande', '#IB-$orderId'),
                    const SizedBox(height: 6),
                    _summaryRow('Paiement',
                        _paymentLabels[paymentMethod] ?? paymentMethod),
                    const SizedBox(height: 6),
                    _summaryRow('Total', formatPrice(total), bold: true),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: écran de suivi de commande (hors périmètre actuel)
                  },
                  child: const Text('Suivre ma commande'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                  fastRoute(const HomeScreen()),
                  (route) => false,
                ),
                child: const Text('Retour à l\'accueil'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        Text(value,
            style: TextStyle(
              fontSize: bold ? 13 : 11,
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
            )),
      ],
    );
  }
}
