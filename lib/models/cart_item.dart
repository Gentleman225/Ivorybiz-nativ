import 'product.dart';

/// Un article dans le panier : un produit + la quantité choisie
/// + les options sélectionnées (couleur, taille) si applicable.
class CartItem {
  final Product product;
  int quantity;
  final String? selectedColor;
  final String? selectedSize;

  CartItem({
    required this.product,
    this.quantity = 1,
    this.selectedColor,
    this.selectedSize,
  });

  double get lineTotal => product.price * quantity;

  /// Clé unique pour regrouper le même produit + mêmes options dans le panier
  /// (ex: deux fois "Robe bleue taille M" doivent s'additionner, pas dupliquer).
  String get cartKey =>
      '${product.id}_${selectedColor ?? ''}_${selectedSize ?? ''}';
}
