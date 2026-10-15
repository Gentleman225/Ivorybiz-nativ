import 'package:flutter/foundation.dart';
import '../models/cart_item.dart';
import '../models/product.dart';

/// Gère l'état du panier. Grâce à Provider, l'icône panier dans le
/// header se met à jour partout dans l'app dès qu'un produit est ajouté
/// — sans avoir à recharger l'écran (voir décision "notification toast
/// à l'ajout au panier").
class CartProvider extends ChangeNotifier {
  final Map<String, CartItem> _items = {};

  List<CartItem> get items => _items.values.toList();

  int get itemCount =>
      _items.values.fold(0, (total, item) => total + item.quantity);

  double get total =>
      _items.values.fold(0, (sum, item) => sum + item.lineTotal);

  void addProduct(
    Product product, {
    int quantity = 1,
    String? color,
    String? size,
  }) {
    final key = '${product.id}_${color ?? ''}_${size ?? ''}';
    if (_items.containsKey(key)) {
      _items[key]!.quantity += quantity;
    } else {
      _items[key] = CartItem(
        product: product,
        quantity: quantity,
        selectedColor: color,
        selectedSize: size,
      );
    }
    notifyListeners();
  }

  void updateQuantity(String cartKey, int quantity) {
    if (quantity <= 0) {
      _items.remove(cartKey);
    } else if (_items.containsKey(cartKey)) {
      _items[cartKey]!.quantity = quantity;
    }
    notifyListeners();
  }

  void removeItem(String cartKey) {
    _items.remove(cartKey);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  /// Format attendu par create-order.php : [{product_id, quantity}, ...]
  List<Map<String, dynamic>> toOrderItems() {
    return _items.values
        .map((item) => {
              'product_id': item.product.id,
              'quantity': item.quantity,
            })
        .toList();
  }
}
