import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../utils/page_transitions.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/filter_drawer.dart';
import '../widgets/product_card.dart';
import '../widgets/skeleton_loader.dart';
import 'product_detail_screen.dart';

/// Écran Boutique : recherche, chips de catégories (scroll horizontal),
/// compteur + tri, filtre en drawer latéral (Prix/Catégories/Tailles/
/// Pointures — liste complète des catégories ici, contrairement à
/// l'archive de catégorie), grille de produits 2 colonnes.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final ApiService _api = ApiService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();

  List<ProductCategory> _categories = [];
  List<Product> _products = [];
  bool _loading = true;
  String? _error;
  int _page = 1;
  int _totalPages = 1;
  int _totalProducts = 0;
  Map<String, List<String>> _availableAttributes = const {};
  Map<int, Map<String, List<String>>> _attributesByCategory = const {};
  bool _categoryAttributesReady = false;
  double _maxPrice = 1000;

  static const int _perPage = 20;

  int? _activeCategoryId; // null = "Tout"
  String _orderby = 'date';
  String _order = 'desc';

  FilterResult _filter = const FilterResult(
    priceRange: RangeValues(0, 1000),
    categoryIds: {},
    sizes: {},
    shoeSizes: {},
  );

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final categoriesFuture = _api.fetchCategories();
      final highestPricedProductFuture = _api.fetchProductsPage(
        orderby: 'price',
        order: 'desc',
        perPage: 1,
      );
      final categories = await categoriesFuture;
      final attributesFuture = _preloadCategoryAttributes(categories);
      final highestPricedProducts = await highestPricedProductFuture;
      final maxPrice = highestPricedProducts.products.isEmpty
          ? 1000.0
          : _roundPriceUp(highestPricedProducts.products.first.price);
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _maxPrice = maxPrice;
        _filter = FilterResult(
          priceRange: RangeValues(0, maxPrice),
          categoryIds: _filter.categoryIds,
          sizes: _filter.sizes,
          shoeSizes: _filter.shoeSizes,
          attributes: _filter.attributes,
        );
      });

      final result = await _fetchFilteredProducts();
      if (!mounted) return;
      setState(() {
        _products = result.products;
        _totalPages = result.totalPages;
        _totalProducts = result.totalProducts;
        _loading = false;
      });
      final attributesByCategory = await attributesFuture;
      if (!mounted) return;
      setState(() {
        _attributesByCategory = attributesByCategory;
        _categoryAttributesReady = true;
        _availableAttributes = _attributesForCategories({
          if (_activeCategoryId != null) _activeCategoryId!,
          ..._filter.categoryIds,
        });
      });
    } catch (e) {
      setState(() {
        _error = 'Impossible de charger la boutique. Vérifie ta connexion.';
        _loading = false;
      });
    }
  }

  double _roundPriceUp(double price) {
    if (price <= 0) return 1000;
    return ((price / 1000).ceil() * 1000).toDouble();
  }

  Future<ProductPage> _fetchFilteredProducts() {
    final categoryIds = <int>{
      if (_activeCategoryId != null) _activeCategoryId!,
      ..._filter.categoryIds,
    };
    return _api.fetchProductsPage(
      search: _searchController.text,
      categoryIds: categoryIds.isEmpty ? null : categoryIds.toList(),
      minPrice: _filter.priceRange.start,
      maxPrice: _filter.priceRange.end,
      orderby: _orderby,
      order: _order,
      page: _page,
      perPage: _perPage,
    );
  }

  Future<void> _refresh() async {
    try {
      final result = await _fetchFilteredProducts();
      final products = result.products.where(_matchesAttributeFilter).toList();
      setState(() {
        _products = products;
        _totalPages = result.totalPages;
        _totalProducts = result.totalProducts == result.products.length
            ? products.length
            : result.totalProducts;
      });
    } catch (_) {
      // Le pull-to-refresh échoue silencieusement ; l'utilisateur peut
      // retenter — on garde la liste précédente affichée.
    }
  }

  bool _matchesAttributeFilter(Product product) {
    if (_filter.sizes.isEmpty &&
        _filter.shoeSizes.isEmpty &&
        _filter.attributes.isEmpty) {
      return true;
    }
    final sizes = <String>{};
    final shoeSizes = <String>{};
    product.attributes.forEach((name, options) {
      final normalized = name.toLowerCase();
      if (normalized.contains('taille') || normalized == 'size') {
        sizes.addAll(options);
      } else if (normalized.contains('pointure') ||
          normalized.contains('shoe size')) {
        shoeSizes.addAll(options);
      }
    });
    final matchesLegacyAttributes = (_filter.sizes.isEmpty ||
            sizes.intersection(_filter.sizes).isNotEmpty) &&
        (_filter.shoeSizes.isEmpty ||
            shoeSizes.intersection(_filter.shoeSizes).isNotEmpty);
    if (!matchesLegacyAttributes) return false;
    for (final entry in _filter.attributes.entries) {
      final productOptions = product.attributes.entries
          .where((attribute) =>
              attribute.key.toLowerCase() == entry.key.toLowerCase())
          .expand((attribute) => attribute.value)
          .toSet();
      if (productOptions.intersection(entry.value).isEmpty) return false;
    }
    return true;
  }

  void _selectCategory(int? categoryId) {
    setState(() {
      _activeCategoryId = categoryId;
      _page = 1;
    });
    _loadAttributes(categoryId == null ? {} : {categoryId});
    _refresh();
  }

  void _loadAttributes(Set<int> categoryIds) {
    setState(() {
      _availableAttributes = _attributesForCategories(categoryIds);
    });
  }

  Future<Map<int, Map<String, List<String>>>> _preloadCategoryAttributes(
    List<ProductCategory> categories,
  ) async {
    final entries = await Future.wait(categories.map((category) async {
      try {
        final attributes =
            await _api.fetchProductAttributeOptions({category.id});
        return MapEntry(category.id, attributes);
      } catch (_) {
        return MapEntry(category.id, <String, List<String>>{});
      }
    }));
    return Map.fromEntries(entries);
  }

  Map<String, List<String>> _attributesForCategories(Set<int> categoryIds) {
    final attributes = <String, Set<String>>{};
    for (final categoryId in categoryIds) {
      final categoryAttributes = _attributesByCategory[categoryId];
      if (categoryAttributes == null) continue;
      for (final entry in categoryAttributes.entries) {
        attributes.putIfAbsent(entry.key, () => <String>{}).addAll(entry.value);
      }
    }
    return {
      for (final entry in attributes.entries)
        entry.key: (entry.value.toList()..sort()),
    };
  }

  void _openFilter() {
    _scaffoldKey.currentState?.openEndDrawer();
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
              onTap: () => Navigator.pop(context, ('date', 'desc')),
            ),
            ListTile(
              title: const Text('Prix croissant'),
              onTap: () => Navigator.pop(context, ('price', 'asc')),
            ),
            ListTile(
              title: const Text('Prix décroissant'),
              onTap: () => Navigator.pop(context, ('price', 'desc')),
            ),
            ListTile(
              title: const Text('Popularité'),
              onTap: () => Navigator.pop(context, ('popularity', 'desc')),
            ),
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
      _refresh();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(title: const Text('Boutique')),
      endDrawer: FilterDrawer(
        categories: _categories,
        showCategoryList: true, // liste complète ici, contrairement à l'archive
        maxPrice: _maxPrice,
        initial: _filter,
        availableSizes: const ['XS', 'S', 'M', 'L', 'XL', 'XXL'],
        availableShoeSizes: const ['37', '38', '39', '40', '41'],
        availableAttributes: _availableAttributes,
        onCategorySelectionChanged: _attributesForCategories,
        onApply: (result) {
          setState(() {
            _filter = result;
            _page = 1;
          });
          _loadAttributes(result.categoryIds);
          _refresh();
        },
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchController,
                onSubmitted: (_) => _refresh(),
                decoration: InputDecoration(
                  hintText: 'Rechercher un produit',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _categoryChip('Tout', _activeCategoryId == null,
                      () => _selectCategory(null)),
                  ..._categories.map((cat) => _categoryChip(
                        cat.name,
                        _activeCategoryId == cat.id,
                        () => _selectCategory(cat.id),
                      )),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$_totalProducts produits',
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
                        onPressed:
                            _categoryAttributesReady ? _openFilter : null,
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
      bottomNavigationBar: const IvorybizBottomNav(currentIndex: 1),
    );
  }

  Widget _buildBody() {
    if (_loading) return const ProductGridSkeleton(itemCount: 6);
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(
                onPressed: _loadInitial, child: const Text('Réessayer')),
          ],
        ),
      );
    }
    if (_products.isEmpty) {
      return const Center(child: Text('Aucun produit trouvé.'));
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
    final pages = <int>{1, _totalPages, _page, _page - 1, _page + 1}
        .where((page) => page >= 1 && page <= _totalPages)
        .toList()
      ..sort();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_page > 1)
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 18),
              onPressed: () => _goToPage(_page - 1),
            ),
          for (int index = 0; index < pages.length; index++) ...[
            if (index > 0 && pages[index] - pages[index - 1] > 1)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('…', style: TextStyle(fontSize: 11)),
              ),
            _pageNumber(pages[index]),
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

  void _goToPage(int page) {
    setState(() => _page = page);
    _refresh();
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

  Widget _categoryChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.textPrimary,
        ),
        onSelected: (_) => onTap(),
      ),
    );
  }
}
