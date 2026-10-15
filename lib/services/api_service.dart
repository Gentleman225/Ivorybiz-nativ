import 'package:dio/dio.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../utils/constants.dart';

class ProductPage {
  final List<Product> products;
  final int totalPages;
  final int totalProducts;

  const ProductPage({
    required this.products,
    required this.totalPages,
    required this.totalProducts,
  });
}

/// Centralise tous les appels réseau de l'app.
class ApiService {
  final Dio _dio;

  ApiService()
      : _dio = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
          ),
        );

  Map<String, String> get _wooAuthParams => {
        'consumer_key': AppConstants.wooConsumerKey,
        'consumer_secret': AppConstants.wooConsumerSecret,
      };

  // --------------------------------------------------------------------
  // WooCommerce — Catégories
  // --------------------------------------------------------------------

  Future<List<ProductCategory>> fetchCategories() async {
    final response = await _dio.get(
      '${AppConstants.wooBaseUrl}/wp-json/wc/v3/products/categories',
      queryParameters: {
        ..._wooAuthParams,
        'hide_empty': true,
        'per_page': 30,
      },
    );

    final data = response.data as List<dynamic>;

    final categories = data
        .map(
          (json) => ProductCategory.fromJson(json as Map<String, dynamic>),
        )
        .toList();

    categories.sort(
      (a, b) => a.menuOrder.compareTo(b.menuOrder),
    );

    return categories;
  }

  // --------------------------------------------------------------------
  // WooCommerce — Produits
  // --------------------------------------------------------------------

  Future<List<Product>> fetchProductsByCategory(
    int categoryId, {
    int page = 1,
    int perPage = 10,
  }) async {
    final response = await _dio.get(
      '${AppConstants.wooBaseUrl}/wp-json/wc/v3/products',
      queryParameters: {
        ..._wooAuthParams,
        'category': categoryId,
        'page': page,
        'per_page': perPage,
      },
    );

    final data = response.data as List<dynamic>;

    return data
        .map(
          (json) => Product.fromJson(json as Map<String, dynamic>),
        )
        .toList();
  }

  Future<List<Product>> fetchProducts({
    String? search,
    List<int>? categoryIds,
    double? minPrice,
    double? maxPrice,
    String orderby = 'date',
    String order = 'desc',
    int page = 1,
    int perPage = 10,
  }) async {
    final response = await _dio.get(
      '${AppConstants.wooBaseUrl}/wp-json/wc/v3/products',
      queryParameters: {
        ..._wooAuthParams,
        if (search != null && search.isNotEmpty) 'search': search,
        if (categoryIds != null && categoryIds.isNotEmpty)
          'category': categoryIds.join(','),
        if (minPrice != null) 'min_price': minPrice,
        if (maxPrice != null) 'max_price': maxPrice,
        'orderby': orderby,
        'order': order,
        'page': page,
        'per_page': perPage,
      },
    );

    final data = response.data as List<dynamic>;

    return data
        .map(
          (json) => Product.fromJson(json as Map<String, dynamic>),
        )
        .toList();
  }

  Future<ProductPage> fetchProductsPage({
    String? search,
    List<int>? categoryIds,
    double? minPrice,
    double? maxPrice,
    String orderby = 'date',
    String order = 'desc',
    int page = 1,
    int perPage = 20,
  }) async {
    final response = await _dio.get(
      '${AppConstants.wooBaseUrl}/wp-json/wc/v3/products',
      queryParameters: {
        ..._wooAuthParams,
        if (search != null && search.isNotEmpty) 'search': search,
        if (categoryIds != null && categoryIds.isNotEmpty)
          'category': categoryIds.join(','),
        if (minPrice != null) 'min_price': minPrice,
        if (maxPrice != null) 'max_price': maxPrice,
        'orderby': orderby,
        'order': order,
        'page': page,
        'per_page': perPage,
      },
    );

    final data = response.data as List<dynamic>;

    final products = data
        .map(
          (json) => Product.fromJson(json as Map<String, dynamic>),
        )
        .toList();

    final totalPages = int.tryParse(
          response.headers.value('X-WP-TotalPages') ?? '',
        ) ??
        1;

    final totalProducts = int.tryParse(
          response.headers.value('X-WP-Total') ?? '',
        ) ??
        products.length;

    return ProductPage(
      products: products,
      totalPages: totalPages,
      totalProducts: totalProducts,
    );
  }

  Future<Map<String, List<String>>> fetchProductAttributeOptions(
    Set<int> categoryIds,
  ) async {
    if (categoryIds.isEmpty) return {};

    final result = await fetchProductsPage(
      categoryIds: categoryIds.toList(),
      perPage: 100,
    );

    final attributes = <String, Set<String>>{};

    for (final product in result.products) {
      product.attributes.forEach((name, options) {
        attributes.putIfAbsent(name, () => <String>{}).addAll(options);
      });
    }

    return {
      for (final entry in attributes.entries)
        entry.key: (List<String>.from(entry.value)..sort()),
    };
  }

  Future<Product> fetchProduct(int productId) async {
    final response = await _dio.get(
      '${AppConstants.wooBaseUrl}/wp-json/wc/v3/products/$productId',
      queryParameters: _wooAuthParams,
    );

    return Product.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  // --------------------------------------------------------------------
  // Backend IvoryBiz — Création de commande
  // --------------------------------------------------------------------

  Future<int> createOrder({
    required Map<String, dynamic> customer,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final response = await _dio.post(
        '${AppConstants.backendBaseUrl}/create-order.php',
        data: {
          'customer': customer,
          'items': items,
        },
        options: Options(
          // Permet de récupérer le JSON même lorsque PHP
          // renvoie HTTP 4xx ou 5xx.
          validateStatus: (status) => status != null && status < 600,
        ),
      );

      final payload = response.data is Map
          ? Map<String, dynamic>.from(
              response.data as Map,
            )
          : <String, dynamic>{};

      if (response.statusCode != 200) {
        throw Exception(
          payload['error'] ??
              payload['message'] ??
              'Erreur serveur HTTP ${response.statusCode}',
        );
      }

      if (payload['success'] != true) {
        throw Exception(
          payload['error'] ??
              payload['message'] ??
              'Échec de la création de la commande WooCommerce',
        );
      }

      final orderId = payload['order_id'];

      if (orderId is int) {
        return orderId;
      }

      if (orderId is String) {
        final parsedId = int.tryParse(orderId);

        if (parsedId != null) {
          return parsedId;
        }
      }

      throw Exception(
        'WooCommerce a créé la commande mais aucun order_id valide n’a été renvoyé.',
      );
    } on DioException catch (e) {
      throw Exception(
        'Erreur réseau : ${e.message}',
      );
    }
  }

  // --------------------------------------------------------------------
  // WooCommerce — Total de commande
  // --------------------------------------------------------------------

  Future<double> fetchOrderTotal(int orderId) async {
    final response = await _dio.get(
      '${AppConstants.wooBaseUrl}/wp-json/wc/v3/orders/$orderId',
      queryParameters: _wooAuthParams,
    );

    final total = response.data['total'];

    if (total is num) {
      return total.toDouble();
    }

    if (total is String) {
      final parsedTotal = double.tryParse(total);

      if (parsedTotal != null) {
        return parsedTotal;
      }
    }

    throw Exception(
      'WooCommerce n’a pas renvoyé le total de la commande',
    );
  }

  // --------------------------------------------------------------------
  // Vérification du paiement
  // --------------------------------------------------------------------

  Future<bool> isOrderPaid(int orderId) async {
    final response = await _dio.get(
      '${AppConstants.wooBaseUrl}/wp-json/wc/v3/orders/$orderId',
      queryParameters: _wooAuthParams,
    );

    return isWooOrderPaid(
      response.data as Map<String, dynamic>,
    );
  }

  static bool isWooOrderPaid(
    Map<String, dynamic> order,
  ) {
    const paidStatuses = {
      'processing',
      'completed',
    };

    final status = order['status']?.toString().toLowerCase();

    final datePaid = order['date_paid']?.toString().trim();

    return paidStatuses.contains(status) &&
        datePaid != null &&
        datePaid.isNotEmpty &&
        datePaid != 'null';
  }

  // --------------------------------------------------------------------
  // INITIALISATION DU PAIEMENT
  // --------------------------------------------------------------------

  Future<Map<String, dynamic>> initPayment({
    required int orderId,
    required String paymentMethod,
    required double amount,
    required Map<String, dynamic> customer,
  }) async {
    try {
      final response = await _dio.post(
        '${AppConstants.backendBaseUrl}/init-payment.php',
        data: {
          'order_id': orderId,
          'payment_method': paymentMethod,
          'amount': amount,
          'customer': customer,
        },
        options: Options(
          // Permet de lire la réponse JSON du PHP même en cas de 502.
          validateStatus: (status) => status != null && status < 600,
        ),
      );

      final payload = response.data is Map
          ? Map<String, dynamic>.from(
              response.data as Map,
            )
          : <String, dynamic>{};

      if (response.statusCode != 200) {
        throw Exception(
          payload['message'] ??
              payload['error'] ??
              'Erreur serveur HTTP ${response.statusCode}',
        );
      }

      if (!isPaymentInitSuccess(payload)) {
        throw Exception(
          payload['message'] ?? payload['error'] ?? 'Échec du paiement',
        );
      }

      return payload;
    } on DioException catch (e) {
      throw Exception(
        'Erreur réseau : ${e.message}',
      );
    }
  }

  // --------------------------------------------------------------------
  // Vérification initialisation paiement
  // --------------------------------------------------------------------

  static bool isPaymentInitSuccess(
    Map<String, dynamic> result,
  ) {
    final directSuccess = result['success'] == true;

    final directStatus = result['status']?.toString().toLowerCase();

    final directPaymentStatus =
        result['payment_status']?.toString().toLowerCase();

    final nested = result['data'];

    final nestedMap =
        nested is Map ? Map<String, dynamic>.from(nested as Map) : null;

    final nestedSuccess = nestedMap?['success'] == true;

    final nestedStatus = nestedMap?['status']?.toString().toLowerCase();

    final nestedPaymentStatus =
        nestedMap?['payment_status']?.toString().toLowerCase();

    return directSuccess ||
        nestedSuccess ||
        directStatus == 'success' ||
        directStatus == 'paid' ||
        directStatus == 'completed' ||
        directStatus == 'succeeded' ||
        directPaymentStatus == 'success' ||
        directPaymentStatus == 'paid' ||
        directPaymentStatus == 'completed' ||
        directPaymentStatus == 'succeeded' ||
        nestedStatus == 'success' ||
        nestedStatus == 'paid' ||
        nestedStatus == 'completed' ||
        nestedStatus == 'succeeded' ||
        nestedPaymentStatus == 'success' ||
        nestedPaymentStatus == 'paid' ||
        nestedPaymentStatus == 'completed' ||
        nestedPaymentStatus == 'succeeded';
  }

  // --------------------------------------------------------------------
  // Paiement confirmé
  // --------------------------------------------------------------------

  static bool isPaymentConfirmed(
    Map<String, dynamic> result,
  ) {
    const confirmedStatuses = {
      'paid',
      'completed',
      'succeeded',
    };

    const paymentStatuses = {
      'paid',
      'completed',
      'succeeded',
      'success',
    };

    final paymentStatus = result['payment_status']?.toString().toLowerCase();

    final status = result['status']?.toString().toLowerCase();

    return paymentStatuses.contains(paymentStatus) ||
        confirmedStatuses.contains(status);
  }

  // --------------------------------------------------------------------
  // URL de paiement
  // --------------------------------------------------------------------

  static Uri? paymentUri(
    Map<String, dynamic> result,
  ) =>
      _findPaymentUri(
        result,
        const [
          'deep_link',
          'mobile_url',
          'app_url',
          'payment_url',
          'checkout_url',
          'redirect_url',
          'url',
          'link',
        ],
      );

  static Uri? paymentFallbackUri(
    Map<String, dynamic> result, {
    required Uri primaryUri,
  }) {
    final fallbackUri = _findPaymentUri(
      result,
      const [
        'fallback_url',
        'browser_url',
        'web_url',
        'checkout_url',
        'payment_url',
        'redirect_url',
        'url',
        'link',
      ],
      webOnly: true,
    );

    return fallbackUri == primaryUri ? null : fallbackUri;
  }

  static Uri? _findPaymentUri(
    Map<String, dynamic> result,
    List<String> keys, {
    bool webOnly = false,
  }) {
    final containers = <Map<String, dynamic>>[result];

    for (final key in [
      'data',
      'payment',
      'result',
    ]) {
      final nested = result[key];

      if (nested is Map) {
        containers.add(
          Map<String, dynamic>.from(nested),
        );
      }
    }

    for (final container in containers) {
      for (final key in keys) {
        final value = container[key];

        if (value is! String || value.trim().isEmpty) {
          continue;
        }

        final uri = Uri.tryParse(value.trim());

        if (uri == null || !uri.hasScheme) {
          continue;
        }

        if (uri.scheme == 'http' || uri.scheme == 'https') {
          if (uri.host.isNotEmpty) {
            return uri;
          }
        } else if (!webOnly &&
            !{
              'javascript',
              'data',
              'file',
              'content',
            }.contains(
              uri.scheme.toLowerCase(),
            )) {
          return uri;
        }
      }
    }

    return null;
  }

  // --------------------------------------------------------------------
  // Bannière
  // --------------------------------------------------------------------

  Future<List<String>> fetchBannerSlides() async {
    final response = await _dio.get(
      '${AppConstants.wooBaseUrl}/wp-json/wp/v2/banniere-slide',
      queryParameters: {
        'per_page': 20,
      },
    );

    final data = response.data as List<dynamic>;

    return data
        .map(
          (json) => json['banner_image_url'] as String?,
        )
        .whereType<String>()
        .toList();
  }
}
