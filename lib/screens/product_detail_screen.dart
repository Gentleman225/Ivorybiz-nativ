import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../utils/page_transitions.dart';
import '../widgets/product_card.dart';

/// Fiche produit — visuel validé :
/// galerie photo, fil d'Ariane, titre/prix/description courte,
/// options Couleur/Taille, quantité, bouton "Ajouter au panier" STICKY
/// en bas pendant que le reste défile, description longue tronquée à
/// 5 lignes avec "Voir plus", et produits similaires en bas.
class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final ApiService _api = ApiService();

  int _galleryIndex = 0;
  String? _selectedColor;
  String? _selectedSize;
  int _quantity = 1;
  bool _descriptionExpanded = false;

  List<Product> _similarProducts = [];
  bool _loadingSimilar = true;

  @override
  void initState() {
    super.initState();
    final colors = widget.product.attributes['Couleur'];
    if (colors != null && colors.isNotEmpty) _selectedColor = colors.first;
    final sizes = widget.product.attributes['Taille'];
    if (sizes != null && sizes.isNotEmpty) _selectedSize = sizes.first;
    _loadSimilar();
  }

  Future<void> _loadSimilar() async {
    if (widget.product.categoryIds.isEmpty) {
      setState(() => _loadingSimilar = false);
      return;
    }
    try {
      final products = await _api.fetchProductsByCategory(
        widget.product.categoryIds.first,
        perPage: 6,
      );
      setState(() {
        _similarProducts =
            products.where((p) => p.id != widget.product.id).toList();
        _loadingSimilar = false;
      });
    } catch (_) {
      setState(() => _loadingSimilar = false);
    }
  }

  void _addToCart() {
    context.read<CartProvider>().addProduct(
          widget.product,
          quantity: _quantity,
          color: _selectedColor,
          size: _selectedSize,
        );
    // Toast "produit ajouté au panier" (décision validée)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${widget.product.name} ajouté au panier')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final colors = product.attributes['Couleur'] ?? [];
    final sizes = product.attributes['Taille'] ?? [];

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: false,
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                expandedHeight: 320,
                automaticallyImplyLeading: false,
                flexibleSpace: FlexibleSpaceBar(
                  background: _gallery(product),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Text(
                      'Accueil / ${product.categoryNames.isNotEmpty ? product.categoryNames.first : ''}',
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    if (product.categoryNames.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          product.categoryNames.first,
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.primary),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Text(product.name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    ProductPrice(
                      product: product,
                      regularFontSize: 13,
                      saleFontSize: 16,
                    ),
                    const SizedBox(height: 12),
                    if (colors.isNotEmpty) ...[
                      const Text('Couleur',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Wrap(
                          spacing: 10,
                          children: colors.map((c) => _colorDot(c)).toList()),
                      const SizedBox(height: 14),
                    ],
                    if (sizes.isNotEmpty) ...[
                      const Text('Taille',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Wrap(
                          spacing: 8,
                          children: sizes.map((s) => _sizeChip(s)).toList()),
                      const SizedBox(height: 16),
                    ],
                    const Divider(color: AppColors.border),
                    const SizedBox(height: 8),
                    const Text('Description',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    _description(product),
                    const SizedBox(height: 24),
                    if (!_loadingSimilar && _similarProducts.isNotEmpty) ...[
                      const Text('Produits similaires',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 170,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _similarProducts.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final similar = _similarProducts[index];
                            return SizedBox(
                              width: 110,
                              child: ProductCard(
                                product: similar,
                                onTap: () =>
                                    Navigator.of(context).pushReplacement(
                                  fastRoute(
                                      ProductDetailScreen(product: similar)),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ]),
                ),
              ),
            ],
          ),

          // Bandeau STICKY — décision validée : reste fixe en bas pendant
          // que le reste (photos, description, produits similaires) défile.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  16, 10, 16, 10 + MediaQuery.of(context).padding.bottom),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  _qtyButton(Icons.remove, () {
                    if (_quantity > 1) setState(() => _quantity--);
                  }),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('$_quantity',
                        style: const TextStyle(fontSize: 13)),
                  ),
                  _qtyButton(Icons.add, () => setState(() => _quantity++)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: product.inStock ? _addToCart : null,
                      child: Text(product.inStock
                          ? 'Ajouter au panier'
                          : 'Indisponible'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 12,
            child: _circleIconButton(
                Icons.arrow_back, () => Navigator.of(context).pop()),
          ),
        ],
      ),
    );
  }

  Widget _gallery(Product product) {
    if (product.imageUrls.isEmpty) {
      return Container(
        color: AppColors.surfaceLight,
        child: const Icon(Icons.checkroom,
            size: 48, color: AppColors.textSecondary),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: product.imageUrls.length,
          onPageChanged: (index) => setState(() => _galleryIndex = index),
          itemBuilder: (context, index) => CachedNetworkImage(
            imageUrl: product.imageUrls[index],
            fit: BoxFit.cover,
            placeholder: (context, url) =>
                Container(color: AppColors.surfaceLight),
          ),
        ),
        if (product.imageUrls.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                product.imageUrls.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: index == _galleryIndex ? 7 : 5,
                  height: index == _galleryIndex ? 7 : 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index == _galleryIndex
                        ? AppColors.primary
                        : Colors.white,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _description(Product product) {
    final text = product.description.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    final isLong = text.length > 220; // approximation pour ~5 lignes

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          maxLines: _descriptionExpanded ? null : 5,
          overflow: _descriptionExpanded
              ? TextOverflow.visible
              : TextOverflow.ellipsis,
          style: const TextStyle(
              fontSize: 12, color: AppColors.textSecondary, height: 1.5),
        ),
        if (isLong)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: GestureDetector(
              onTap: () =>
                  setState(() => _descriptionExpanded = !_descriptionExpanded),
              child: Text(
                _descriptionExpanded ? 'Voir moins' : 'Voir plus',
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ),
      ],
    );
  }

  Widget _colorDot(String colorName) {
    final selected = _selectedColor == colorName;
    return GestureDetector(
      onTap: () => setState(() => _selectedColor = colorName),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _colorFromName(colorName),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
      ),
    );
  }

  Color _colorFromName(String name) {
    switch (name.toLowerCase()) {
      case 'bleu':
      case 'bleu royal':
        return const Color(0xFF1E3A8A);
      case 'rouge':
        return const Color(0xFFB3261E);
      case 'marron':
        return const Color(0xFF7C4A2D);
      case 'noir':
        return const Color(0xFF2C2C2A);
      case 'blanc':
        return Colors.white;
      default:
        return AppColors.textSecondary;
    }
  }

  Widget _sizeChip(String size) {
    final selected = _selectedSize == size;
    return ChoiceChip(
      label: Text(size, style: const TextStyle(fontSize: 11)),
      selected: selected,
      selectedColor: AppColors.primary,
      labelStyle:
          TextStyle(color: selected ? Colors.white : AppColors.textPrimary),
      onSelected: (_) => setState(() => _selectedSize = size),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 15),
      ),
    );
  }

  Widget _circleIconButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.9),
        ),
        child: Icon(icon, size: 18, color: AppColors.primary),
      ),
    );
  }
}
