import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../utils/page_transitions.dart';
import '../widgets/filter_drawer.dart';
import '../widgets/product_card.dart';
import '../widgets/skeleton_loader.dart';
import 'product_detail_screen.dart';

/// Archive de catégorie (ex: "Friperie") — visuel validé :
/// titre, compteur, tri, grille avec badge Promo, pagination numérotée
/// (contrairement à la Boutique qui scrolle en continu), et un filtre
/// SANS la liste des catégories (on y est déjà) — seulement Prix et les
/// attributs propres à cette catégorie.
class CategoryScreen extends StatefulWidget {
  final ProductCategory category;

  const CategoryScreen({super.key, required this.category});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final ApiService _api = ApiService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const int _perPage = 20;

  List<Product> _products = [];
  bool _loading = true;
  String? _error;
  int _page = 1;
  int _totalPages = 1;
  Map<String, List<String>> _availableAttributes = const {};

  String _orderby = 'date';
  String _order = 'desc';

  FilterResult _filter = const FilterResult(
    priceRange: RangeValues(0, 20000),
    categoryIds: {},
    sizes: {},
    shoeSizes: {},
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final products = await _api.fetchProducts(
        categoryIds: [widget.category.id],
        minPrice: _filter.priceRange.start,
        maxPrice: _filter.priceRange.end,
        orderby: _orderby,
        order: _order,
        page: _page,
        perPage: _perPage,
      );
      final attributes =
          await _api.fetchProductAttributeOptions({widget.category.id});
      setState(() {
        _products = products;
        _availableAttributes = attributes;
        _totalPages =
            (widget.category.productCount / _perPage).ceil().clamp(1, 999);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Impossible de charger cette catégorie.';
        _loading = false;
      });
    }
  }

  void _goToPage(int page) {
    setState(() => _page = page);
    _load();
  }

  void _showSortMenu() async {
    final selected = await showModalBottomSheet<(String, String)>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
                title: const Text('Plus récents'),
                onTap: () => Navigator.pop(context, ('date', 'desc'))),
            ListTile(
                title: const Text('Prix croissant'),
                onTap: () => Navigator.pop(context, ('price', 'asc'))),
            ListTile(
                title: const Text('Prix décroissant'),
                onTap: () => Navigator.pop(context, ('price', 'desc'))),
          ],
        ),
      ),
    );
    if (selected != null) {
      setState(() {
        _orderby = selected.$1;
        _order = selected.$2;
        _page = 1;
      });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(title: Text(widget.category.name)),
      endDrawer: FilterDrawer(
        categories: const [],
        showCategoryList:
            false, // pas de liste de catégories ici (décision validée)
        maxPrice: 20000,
        availableAttributes: _availableAttributes,
        initial: _filter,
        onApply: (result) {
          setState(() {
            _filter = result;
            _page = 1;
          });
          _load();
        },
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${widget.category.productCount} produits',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: _showSortMenu,
                        icon: const Icon(Icons.swap_vert, size: 16),
                        label:
                            const Text('Trier', style: TextStyle(fontSize: 11)),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            _scaffoldKey.currentState?.openEndDrawer(),
                        icon: const Icon(Icons.tune, size: 16),
                        label: const Text('Filtrer',
                            style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
            if (!_loading && _error == null && _totalPages > 1) _pagination(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const ProductGridSkeleton(itemCount: 6);
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
          ],
        ),
      );
    }
    if (_products.isEmpty) {
      return const Center(child: Text('Aucun produit dans cette catégorie.'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _products.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.68,
      ),
      itemBuilder: (context, index) {
        final product = _products[index];
        return ProductCard(
          product: product,
          onTap: () => Navigator.of(context)
              .push(fastRoute(ProductDetailScreen(product: product))),
        );
      },
    );
  }

  Widget _pagination() {
    // Affiche jusqu'à 5 numéros de page autour de la page active,
    // comme sur le site.
    final pages = <int>{1, _totalPages, _page, _page - 1, _page + 1}
        .where((p) => p >= 1 && p <= _totalPages)
        .toList()
      ..sort();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < pages.length; i++) ...[
            if (i > 0 && pages[i] - pages[i - 1] > 1)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('…',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ),
            _pageNumber(pages[i]),
          ],
          if (_page < _totalPages)
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 18),
              onPressed: () => _goToPage(_page + 1),
            ),
        ],
      ),
    );
  }

  Widget _pageNumber(int page) {
    final active = page == _page;
    return InkWell(
      onTap: () => _goToPage(page),
      child: Container(
        width: 26,
        height: 26,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '$page',
          style: TextStyle(
            fontSize: 11,
            color: active ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
