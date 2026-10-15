import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/customer.dart';

/// Sauvegarde les informations client après sa 1ère commande, pour que
/// les commandes suivantes pré-remplissent automatiquement le formulaire
/// (décision validée avec Dosso).
class StorageService {
  static const _customerKey = 'ivorybiz_customer_info';

  Future<void> saveCustomer(Customer customer) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customerKey, jsonEncode(customer.toJson()));
  }

  Future<Customer?> getSavedCustomer() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_customerKey);
    if (raw == null) return null;
    return Customer.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}
