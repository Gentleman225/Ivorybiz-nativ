import 'package:flutter/foundation.dart';
import '../models/customer.dart';
import '../services/storage_service.dart';

class CustomerProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();

  Customer? _customer;
  Customer? get customer => _customer;

  /// Appelé au démarrage de l'app (pendant le splash) pour pré-remplir
  /// le formulaire de commande si le client a déjà commandé une fois.
  Future<void> loadSavedCustomer() async {
    _customer = await _storage.getSavedCustomer();
    notifyListeners();
  }

  Future<void> saveCustomer(Customer customer) async {
    _customer = customer;
    await _storage.saveCustomer(customer);
    notifyListeners();
  }
}
