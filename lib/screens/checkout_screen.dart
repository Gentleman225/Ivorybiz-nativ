import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/customer.dart';
import '../providers/cart_provider.dart';
import '../providers/customer_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../utils/page_transitions.dart';
import '../widgets/product_card.dart' show formatPrice;
import 'order_confirmation_screen.dart';

/// Écran Commande — facturation + paiement.
///
/// Modes de paiement disponibles :
/// - Wave
/// - Carte bancaire
/// - Paiement à la livraison
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final ApiService _api = ApiService();

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _communeCtrl = TextEditingController();

  String? _selectedPaymentMethod;

  int? _pendingOrderId;
  double? _pendingTotal;
  String? _pendingPaymentMethod;

  Uri? _pendingPaymentUri;
  Uri? _pendingPaymentFallbackUri;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();

    final saved = context.read<CustomerProvider>().customer;

    if (saved != null) {
      _firstNameCtrl.text = saved.firstName;
      _lastNameCtrl.text = saved.lastName;
      _phoneCtrl.text = saved.phone;
      _emailCtrl.text = saved.email;
      _cityCtrl.text = saved.city;
      _communeCtrl.text = saved.commune;
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _cityCtrl.dispose();
    _communeCtrl.dispose();

    super.dispose();
  }

  String get _city => _cityCtrl.text;

  String get _commune => _communeCtrl.text;

  bool get _formValid =>
      _firstNameCtrl.text.trim().isNotEmpty &&
      _lastNameCtrl.text.trim().isNotEmpty &&
      _city.trim().isNotEmpty &&
      _commune.trim().isNotEmpty &&
      _phoneCtrl.text.trim().isNotEmpty &&
      _emailCtrl.text.trim().isNotEmpty &&
      _selectedPaymentMethod != null;

  Future<void> _submit() async {
    if (_pendingOrderId == null && !_formValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Merci de remplir tous les champs.'),
        ),
      );

      return;
    }

    setState(() => _submitting = true);

    try {
      /*
      |--------------------------------------------------------------------------
      | VÉRIFICATION D'UN PAIEMENT EN ATTENTE
      |--------------------------------------------------------------------------
      */

      if (_pendingOrderId != null) {
        final isPaid = await _api.isOrderPaid(_pendingOrderId!);

        if (!mounted) return;

        if (!isPaid) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Paiement toujours en attente. Vérifie la transaction puis réessaie.',
              ),
            ),
          );

          return;
        }

        final cart = context.read<CartProvider>();

        cart.clear();

        Navigator.of(context).pushReplacement(
          fastRoute(
            OrderConfirmationScreen(
              orderId: _pendingOrderId!,
              paymentMethod: _pendingPaymentMethod!,
              total: _pendingTotal!,
            ),
          ),
        );

        return;
      }

      /*
      |--------------------------------------------------------------------------
      | CRÉATION DE LA COMMANDE
      |--------------------------------------------------------------------------
      */

      final cart = context.read<CartProvider>();
      final customerProvider = context.read<CustomerProvider>();

      final customer = Customer(
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        city: _city.trim(),
        commune: _commune.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
      );

      final orderId = await _api.createOrder(
        customer: customer.toJson(),
        items: cart.toOrderItems(),
      );

      /*
      |--------------------------------------------------------------------------
      | RÉCUPÉRATION DU TOTAL
      |--------------------------------------------------------------------------
      */

      final total = await _api.fetchOrderTotal(orderId);

      /*
      |--------------------------------------------------------------------------
      | INITIALISATION DU PAIEMENT
      |--------------------------------------------------------------------------
      */

      final paymentResult = await _api.initPayment(
        orderId: orderId,
        paymentMethod: _selectedPaymentMethod!,
        amount: total,
        customer: {
          'name': '${customer.firstName} ${customer.lastName}',
          'phone': customer.phone,
          'email': customer.email,
        },
      );

      /*
      |--------------------------------------------------------------------------
      | PAIEMENT WAVE / CARTE
      |--------------------------------------------------------------------------
      */

      if (_selectedPaymentMethod != 'livraison' &&
          !ApiService.isPaymentConfirmed(paymentResult)) {
        _pendingOrderId = orderId;
        _pendingTotal = total;
        _pendingPaymentMethod = _selectedPaymentMethod;

        _pendingPaymentUri = ApiService.paymentUri(paymentResult);

        if (_pendingPaymentUri == null) {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Le service de paiement n’a renvoyé aucun lien. '
                'Contacte le support avant de recommencer.',
              ),
              backgroundColor: AppColors.error,
            ),
          );

          return;
        }

        _pendingPaymentFallbackUri = ApiService.paymentFallbackUri(
          paymentResult,
          primaryUri: _pendingPaymentUri!,
        );

        await customerProvider.saveCustomer(customer);

        final launched = await _launchPendingPayment();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              launched
                  ? 'Page de paiement ouverte. Termine le paiement puis reviens dans l’application.'
                  : 'Impossible d’ouvrir le paiement. Vérifie que le navigateur est installé.',
            ),
            backgroundColor: launched ? null : AppColors.error,
          ),
        );

        return;
      }

      /*
      |--------------------------------------------------------------------------
      | PAIEMENT CONFIRMÉ / LIVRAISON
      |--------------------------------------------------------------------------
      */

      await customerProvider.saveCustomer(customer);

      cart.clear();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _selectedPaymentMethod == 'livraison'
                ? 'Commande confirmée. Paiement à la livraison.'
                : 'Paiement effectué avec succès !',
          ),
        ),
      );

      Navigator.of(context).pushReplacement(
        fastRoute(
          OrderConfirmationScreen(
            orderId: orderId,
            paymentMethod: _selectedPaymentMethod!,
            total: total,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      final message = e.toString().replaceFirst('Exception: ', '');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message.isNotEmpty
                ? message
                : "Le paiement n'a pas été confirmé. "
                    "Vérifie ton compte ou contacte le support avant de réessayer.",
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<bool> _launchPendingPayment() async {
    final paymentUri = _pendingPaymentUri;

    if (paymentUri == null) return false;

    final launched = await launchUrl(
      paymentUri,
      mode: LaunchMode.externalApplication,
    );

    if (launched) return true;

    final fallbackUri = _pendingPaymentFallbackUri;

    if (fallbackUri == null) return false;

    return launchUrl(
      fallbackUri,
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _reopenPendingPayment() async {
    setState(() => _submitting = true);

    try {
      final launched = await _launchPendingPayment();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            launched
                ? 'Page de paiement ouverte.'
                : 'Impossible d’ouvrir le paiement. Vérifie que le navigateur est installé.',
          ),
          backgroundColor: launched ? null : AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Commande'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Vos informations',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _textField(
            'Prénom',
            _firstNameCtrl,
          ),
          _textField(
            'Nom',
            _lastNameCtrl,
          ),
          Row(
            children: [
              Expanded(
                child: _textField(
                  'Ville',
                  _cityCtrl,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _textField(
                  'Commune',
                  _communeCtrl,
                ),
              ),
            ],
          ),
          _textField(
            'Téléphone',
            _phoneCtrl,
            keyboardType: TextInputType.phone,
          ),
          _textField(
            'E-mail',
            _emailCtrl,
            keyboardType: TextInputType.emailAddress,
          ),
          const Divider(
            height: 32,
            color: AppColors.border,
          ),
          const Text(
            'Mode de paiement',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          /*
          |--------------------------------------------------------------------------
          | PAIEMENT ÉLECTRONIQUE
          |--------------------------------------------------------------------------
          */

          _sectionHeader('PAIEMENT EN LIGNE'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _paymentTile(
                  'wave',
                  'Wave',
                  const Color(0xFF4BC5C4),
                  assetPath: 'assets/images/wave.png',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _paymentTile(
                  'card',
                  'Carte bancaire',
                  AppColors.primary,
                  icon: Icons.credit_card_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          /*
          |--------------------------------------------------------------------------
          | PAIEMENT À LA LIVRAISON
          |--------------------------------------------------------------------------
          */

          _sectionHeader('AUTRE'),
          const SizedBox(height: 8),
          _deliveryPaymentTile(),
          const Divider(
            height: 32,
            color: AppColors.border,
          ),
          _summaryRow(
            'Sous-total',
            formatPrice(cart.total),
          ),
          const SizedBox(height: 6),
          _summaryRow(
            'Expédition',
            'Gratuite',
          ),
          const Divider(
            height: 20,
            color: AppColors.border,
          ),
          _summaryRow(
            'Total',
            formatPrice(cart.total),
            bold: true,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _pendingOrderId == null
                          ? 'Continuer vers le paiement'
                          : 'Vérifier le paiement',
                    ),
            ),
          ),
          if (_pendingPaymentUri != null)
            TextButton.icon(
              onPressed: _submitting ? null : _reopenPendingPayment,
              icon: const Icon(
                Icons.open_in_new,
                size: 18,
              ),
              label: const Text(
                'Rouvrir la page de paiement',
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    bool bold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 16 : 14,
            fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _textField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          isDense: true,
        ),
      ),
    );
  }

  Widget _paymentTile(
    String value,
    String label,
    Color color, {
    IconData? icon,
    String? assetPath,
  }) {
    final selected = _selectedPaymentMethod == value;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = value;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(8),
          color: selected ? AppColors.primary.withOpacity(0.06) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: assetPath == null ? color : null,
                borderRadius: BorderRadius.circular(6),
              ),
              clipBehavior: Clip.antiAlias,
              child: assetPath != null
                  ? Image.asset(
                      assetPath,
                      fit: BoxFit.contain,
                    )
                  : icon != null
                      ? Icon(
                          icon,
                          size: 16,
                          color: Colors.white,
                        )
                      : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: selected ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deliveryPaymentTile() {
    final selected = _selectedPaymentMethod == 'livraison';

    return InkWell(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = 'livraison';
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(8),
          color: selected ? AppColors.primary.withOpacity(0.06) : null,
        ),
        child: Row(
          children: [
            Icon(
              Icons.local_shipping_outlined,
              size: 18,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              'Paiement à la livraison',
              style: TextStyle(
                fontSize: 12,
                color: selected ? AppColors.primary : AppColors.textPrimary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
