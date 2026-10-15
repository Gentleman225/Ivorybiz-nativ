import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../utils/page_transitions.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/product_card.dart';
import '../widgets/skeleton_loader.dart';
import 'category_screen.dart';
import 'cart_screen.dart';
import 'product_detail_screen.dart';

/// Écran d'accueil — visuel validé :
///  - Bannière carrousel média (images/vidéos pilotées depuis l'admin
///    WordPress, sans texte ajouté par l'app) — TODO : brancher la vraie
///    source une fois le champ admin décidé côté WordPress.
///  - Les 2 premières catégories (dans l'ordre réglé manuellement sur
///    WordPress) en bandeaux pleine largeur (ex: Friperie, Prêt-à-porter).
///  - Les catégories suivantes en rangée défilable horizontalement.
///  - Tout est cliquable -> archive de la catégorie.
///  - Un aperçu produits par catégorie, dans le même ordre.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const List<String> _manualCategoryOrder = [
    'friperie',
    'pret-a-porter',
    'ivorybiz-creation',
  ];

  final ApiService _api = ApiService();

  List<ProductCategory> _categories = [];
  final Map<int, List<Product>> _previewsByCategory = {};
  bool _loading = true;
  String? _error;
  DateTime? _lastBackPressed;

  // La bannière est alimentée par les slides récupérées depuis WordPress.
  List<String> _bannerImageUrls = [];
  int _bannerIndex = 0;
  final PageController _bannerPageController = PageController();
  Timer? _bannerAutoScrollTimer;
  bool _isBannerPressed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _bannerAutoScrollTimer?.cancel();
    _bannerPageController.dispose();
    super.dispose();
  }

  void _startBannerAutoScroll() {
    _bannerAutoScrollTimer?.cancel();
    if (_bannerImageUrls.length < 2 || _isBannerPressed) return;

    _bannerAutoScrollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_bannerPageController.hasClients) return;
      final nextPage = (_bannerIndex + 1) % _bannerImageUrls.length;
      _bannerPageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    });
  }

  void _pauseBannerOnPress(PointerDownEvent event) {
    _isBannerPressed = true;
    _bannerAutoScrollTimer?.cancel();
    _bannerAutoScrollTimer = null;
  }

  void _resumeBannerOnRelease(PointerEvent event) {
    if (!_isBannerPressed) return;
    _isBannerPressed = false;
    _startBannerAutoScroll();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final categories = await _api.fetchCategories();
      final bannerSlides = await _api.fetchBannerSlides();

      // Précharge un aperçu de produits pour chaque catégorie, dans le
      // même ordre (menu_order réglé manuellement sur WordPress).
      final previews = <int, List<Product>>{};
      for (final category in categories) {
        try {
          previews[category.id] =
              await _api.fetchProductsByCategory(category.id, perPage: 6);
        } catch (_) {
          previews[category.id] = [];
        }
      }

      setState(() {
        _categories = categories;
        _bannerImageUrls = bannerSlides;
        _previewsByCategory.addAll(previews);
        _loading = false;
      });
      _startBannerAutoScroll();
    } catch (e) {
      setState(() {
        _error = 'Impossible de charger l\'accueil. Vérifie ta connexion.';
        _loading = false;
      });
    }
  }

  void _openCategory(ProductCategory category) {
    Navigator.of(context).push(fastRoute(CategoryScreen(category: category)));
  }

  void _handleBack(bool didPop) {
    if (didPop) return;

    final now = DateTime.now();
    final lastPress = _lastBackPressed;
    if (lastPress != null &&
        now.difference(lastPress) <= const Duration(seconds: 2)) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      SystemNavigator.pop();
      return;
    }

    _lastBackPressed = now;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Appuyez encore pour quitter'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) => _handleBack(didPop),
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: AppColors.skyBlue,
          foregroundColor: AppColors.navyDark,
          title: Image.asset(
            'assets/images/logo.png',
            height: 65,
            fit: BoxFit.contain,
            semanticLabel: 'IvoryBiz',
          ),
          actions: [
            IconButton(icon: const Icon(Icons.search), onPressed: () {}),
            IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                onPressed: () => showCartPanel(context)),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? const ProductGridSkeleton(itemCount: 6)
              : _error != null
                  ? _errorView()
                  : _content(),
        ),
        bottomNavigationBar: const IvorybizBottomNav(currentIndex: 0),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
        ],
      ),
    );
  }

  Widget _content() {
    final orderedCategories = [..._categories]
      ..sort((a, b) => _manualCategoryIndex(a) - _manualCategoryIndex(b));
    final bigBanners = orderedCategories.where(_isFeaturedCategory).toList();
    final rowCategories = orderedCategories
        .where((category) => !_isFeaturedCategory(category))
        .toList();

    return ListView(
      children: [
        _mediaBanner(),
        if (bigBanners.isNotEmpty) const SizedBox(height: 12),
        for (final category in bigBanners) _fullWidthCategoryBanner(category),
        if (rowCategories.isNotEmpty) _categoryRow(rowCategories),
        const SizedBox(height: 8),
        for (final category in orderedCategories)
          _categoryPreviewSection(category),
        const SizedBox(height: 16),
      ],
    );
  }

  int _manualCategoryIndex(ProductCategory category) {
    final value = '${category.slug} ${category.name}'.toLowerCase();
    if (value.contains('friperie')) return 0;
    if (value.contains('pret-a-porter') ||
        value.contains('prete-a-porter') ||
        (value.contains('pret') && value.contains('porter')) ||
        (value.contains('prêt') && value.contains('porter'))) {
      return 1;
    }
    if (value.contains('ivorybiz-creation') ||
        value.contains('ivorybiz creation')) {
      return 2;
    }
    return _manualCategoryOrder.length;
  }

  bool _isFeaturedCategory(ProductCategory category) {
    final slug = category.slug.toLowerCase();
    final name = category.name.toLowerCase();
    return slug == 'friperie' ||
        slug == 'pret-a-porter' ||
        slug == 'prete-a-porter' ||
        name.contains('friperie') ||
        ((name.contains('pret') || name.contains('prêt')) &&
            name.contains('porter'));
  }

  // --------------------------------------------------------------------
  // Bannière média (carrousel)
  // --------------------------------------------------------------------
  Widget _mediaBanner() {
    if (_bannerImageUrls.isEmpty) {
      // État vide neutre — pas de fausse image tant que la vraie source
      // n'est pas branchée.
      return Container(
        height: 170,
        color: AppColors.surfaceLight,
        alignment: Alignment.center,
        child: const Icon(Icons.image_outlined,
            size: 36, color: AppColors.textSecondary),
      );
    }
    return SizedBox(
      height: 170,
      child: Stack(
        children: [
          Listener(
            onPointerDown: _pauseBannerOnPress,
            onPointerUp: _resumeBannerOnRelease,
            onPointerCancel: _resumeBannerOnRelease,
            child: PageView.builder(
              controller: _bannerPageController,
              itemCount: _bannerImageUrls.length,
              onPageChanged: (i) => setState(() => _bannerIndex = i),
              itemBuilder: (context, index) => CachedNetworkImage(
                imageUrl: _bannerImageUrls[index],
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _bannerImageUrls.length,
                (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _bannerIndex ? 16 : 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: i == _bannerIndex ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------
  // Bandeau catégorie pleine largeur (ex: Friperie, Prêt-à-porter)
  // --------------------------------------------------------------------
  Widget _fullWidthCategoryBanner(ProductCategory category) {
    return GestureDetector(
      onTap: () => _openCategory(category),
      child: Container(
        height: 110,
        margin: const EdgeInsets.only(bottom: 12),
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: AppColors.surfaceLight),
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            if (category.imageUrl != null)
              CachedNetworkImage(
                  imageUrl: category.imageUrl!, fit: BoxFit.cover),
            Container(color: Colors.black.withOpacity(0.25)),
            Center(
              child: Text(
                category.name.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'serif',
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------
  // Rangée défilable pour les catégories restantes
  // --------------------------------------------------------------------
  Widget _categoryRow(List<ProductCategory> categories) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 2),
        itemBuilder: (context, index) {
          final category = categories[index];
          return GestureDetector(
            onTap: () => _openCategory(category),
            child: Container(
              width: MediaQuery.of(context).size.width / 3,
              alignment: Alignment.bottomCenter,
              child: Stack(
                fit: StackFit.expand,
                alignment: Alignment.bottomCenter,
                children: [
                  Container(color: AppColors.surfaceLight),
                  if (category.imageUrl != null)
                    CachedNetworkImage(
                        imageUrl: category.imageUrl!, fit: BoxFit.cover),
                  Container(color: Colors.black.withOpacity(0.25)),
                  Align(
                    alignment: Alignment.center,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        category.name.toUpperCase(),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'serif',
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --------------------------------------------------------------------
  // Aperçu produits par catégorie
  // --------------------------------------------------------------------
  Widget _categoryPreviewSection(ProductCategory category) {
    final products = _previewsByCategory[category.id] ?? [];
    if (products.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            color: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    category.name.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _openCategory(category),
                  child: const Text(
                    'voir tout',
                    style: TextStyle(fontSize: 12, color: AppColors.gold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              height: 175,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: products.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final product = products[index];
                  return SizedBox(
                    width: 112,
                    child: ProductCard(
                      product: product,
                      onTap: () => Navigator.of(context).push(
                          fastRoute(ProductDetailScreen(product: product))),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
