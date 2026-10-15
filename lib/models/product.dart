/// Représente un produit WooCommerce, avec uniquement les champs
/// dont l'app a besoin pour l'affichage (fiche produit, cartes, panier).
class Product {
  final int id;
  final String name;
  final String slug;
  final String description;
  final String shortDescription;
  final double price;
  final double? regularPrice; // null si pas de promo
  final bool onSale;
  final List<String> imageUrls;
  final List<String> categoryNames;
  final List<int> categoryIds;
  final bool inStock;

  // Attributs variables (ex: Couleur, Taille) — nom -> liste d'options
  final Map<String, List<String>> attributes;

  const Product({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.shortDescription,
    required this.price,
    this.regularPrice,
    required this.onSale,
    required this.imageUrls,
    required this.categoryNames,
    required this.categoryIds,
    required this.inStock,
    required this.attributes,
  });

  bool get hasDiscount => regularPrice != null && regularPrice! > price;

  factory Product.fromJson(Map<String, dynamic> json) {
    final images = (json['images'] as List<dynamic>? ?? [])
        .map((img) => img['src'] as String)
        .toList();

    final categories = (json['categories'] as List<dynamic>? ?? []);

    final attributesJson = (json['attributes'] as List<dynamic>? ?? []);
    final attributesMap = <String, List<String>>{};
    for (final attr in attributesJson) {
      final name = attr['name'] as String? ?? '';
      final options = (attr['options'] as List<dynamic>? ?? [])
          .map((o) => o.toString())
          .toList();
      if (name.isNotEmpty) attributesMap[name] = options;
    }

    final price = double.tryParse(json['price']?.toString() ?? '') ?? 0;
    var regularPrice = double.tryParse(json['regular_price']?.toString() ?? '');
    final salePrice = double.tryParse(json['sale_price']?.toString() ?? '');
    var currentPrice = salePrice ?? price;
    var onSale = json['on_sale'] == true ||
        (regularPrice != null && currentPrice < regularPrice);

    // Repli pour les produits VARIABLES (avec Taille/Couleur) : WooCommerce
    // laisse souvent regular_price/sale_price vides au niveau du produit
    // parent, même quand une variation est en promo — la vraie info ne
    // vit que dans chaque variation. Plutôt que de faire un appel réseau
    // supplémentaire par produit (trop coûteux sur une grille), on relit
    // le champ price_html, que WooCommerce calcule toujours correctement
    // (il contient le prix barré <del> et le prix promo <ins> déjà
    // fusionnés à partir des variations).
    if (onSale && regularPrice == null) {
      final priceHtml = json['price_html'] as String? ?? '';
      final htmlRegular = _extractPriceFromHtml(priceHtml, 'del');
      final htmlSale = _extractPriceFromHtml(priceHtml, 'ins');
      if (htmlRegular != null) {
        regularPrice = htmlRegular;
        if (htmlSale != null) currentPrice = htmlSale;
      } else {
        // Aucune info exploitable -> on préfère ne pas afficher de promo
        // plutôt que d'afficher des chiffres potentiellement faux.
        onSale = false;
      }
    }

    return Product(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String? ?? '',
      shortDescription: json['short_description'] as String? ?? '',
      price: currentPrice,
      regularPrice: onSale ? regularPrice : null,
      onSale: onSale,
      imageUrls: images,
      categoryNames:
          categories.map((c) => c['name'] as String? ?? '').toList(),
      categoryIds: categories.map((c) => c['id'] as int).toList(),
      inStock: (json['stock_status'] as String? ?? 'instock') == 'instock',
      attributes: attributesMap,
    );
  }

  /// Extrait un montant numérique depuis le champ price_html de
  /// WooCommerce, en cherchant le contenu d'une balise <del> (prix
  /// barré) ou <ins> (prix promo). Gère les espaces normaux/insécables
  /// utilisés par WooCommerce comme séparateurs de milliers.
  static double? _extractPriceFromHtml(String html, String tag) {
    final tagMatch =
        RegExp('<$tag[^>]*>(.*?)</$tag>', dotAll: true).firstMatch(html);
    if (tagMatch == null) return null;
    final inner = (tagMatch.group(1) ?? '').replaceAll('&nbsp;', ' ');
    final numberMatch = RegExp(r'[\d][\d\s.,]*').firstMatch(inner);
    if (numberMatch == null) return null;
    final raw = numberMatch
        .group(0)!
        .replaceAll(RegExp(r'\s'), '')
        .replaceAll(',', '.');
    return double.tryParse(raw);
  }
}