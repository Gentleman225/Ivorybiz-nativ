/// Représente une catégorie de produit WooCommerce (ex: Friperie).
/// L'ordre d'affichage vient de `menu_order`, réglé manuellement
/// depuis l'admin WordPress — voir décision validée avec Dosso.
class ProductCategory {
  final int id;
  final String name;
  final String slug;
  final String? imageUrl;
  final int productCount;
  final int menuOrder;

  const ProductCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.imageUrl,
    required this.productCount,
    required this.menuOrder,
  });

  factory ProductCategory.fromJson(Map<String, dynamic> json) {
    return ProductCategory(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      imageUrl: json['image'] != null
          ? json['image']['src'] as String?
          : null,
      productCount: json['count'] as int? ?? 0,
      menuOrder: json['menu_order'] as int? ?? 0,
    );
  }
}
