import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../theme/app_colors.dart';

final _priceFormat = NumberFormat.decimalPattern('fr_FR');

String formatPrice(double price) => '${_priceFormat.format(price)} CFA';

int discountPercentage(Product product) {
  final regularPrice = product.regularPrice;
  if (!product.hasDiscount || regularPrice == null) return 0;
  return ((regularPrice - product.price) / regularPrice * 100).round();
}

class ProductPrice extends StatelessWidget {
  final Product product;
  final double regularFontSize;
  final double saleFontSize;

  const ProductPrice({
    super.key,
    required this.product,
    this.regularFontSize = 10,
    this.saleFontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    final hasDiscount = product.hasDiscount;

    if (!hasDiscount) {
      return Text(
        formatPrice(product.price),
        style: TextStyle(
          fontSize: saleFontSize,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formatPrice(product.regularPrice!),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: regularFontSize,
            color: AppColors.textSecondary,
            decoration: TextDecoration.lineThrough,
            decorationThickness: 1.5,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Flexible(
              child: Text(
                formatPrice(product.price),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: saleFontSize,
                  fontWeight: FontWeight.w700,
                  color: AppColors.promo,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              color: AppColors.promo.withOpacity(0.12),
              child: Text(
                '-${discountPercentage(product)}%',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppColors.promo,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Carte produit avec image, badge Promo si en réduction, nom et prix
/// (barré + prix promo si applicable) — reprend le visuel validé.
class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const ProductCard({super.key, required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child: product.imageUrls.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: product.imageUrls.first,
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                Container(color: AppColors.surfaceLight),
                            errorWidget: (context, url, error) => Container(
                              color: AppColors.surfaceLight,
                              child: const Icon(Icons.image_not_supported,
                                  color: AppColors.textSecondary),
                            ),
                          )
                        : Container(
                            color: AppColors.surfaceLight,
                            child: const Icon(Icons.checkroom,
                                color: AppColors.textSecondary),
                          ),
                  ),
                ),
                if (discountPercentage(product) > 0)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.promo,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '-${discountPercentage(product)}%',
                        style: TextStyle(color: Colors.white, fontSize: 9),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            product.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 2),
          ProductPrice(
            product: product,
            regularFontSize: 10,
            saleFontSize: 11,
          ),
        ],
      ),
    );
  }
}