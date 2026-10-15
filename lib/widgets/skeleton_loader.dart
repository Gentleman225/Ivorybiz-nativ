import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Un bloc gris avec un effet de balayage lumineux, utilisé pendant que
/// les données d'un écran se chargent depuis l'API — remplace un simple
/// spinner par une pré-visualisation de la mise en page finale.
class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 6,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1 + _controller.value * 3, 0),
              end: Alignment(1 + _controller.value * 3, 0),
              colors: [
                AppColors.surfaceLight,
                AppColors.border,
                AppColors.surfaceLight,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Grille de squelettes imitant une liste de cartes produit (2 colonnes),
/// utilisée sur Boutique, Catégorie, et les sections de l'Accueil.
class ProductGridSkeleton extends StatelessWidget {
  final int itemCount;

  const ProductGridSkeleton({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: itemCount,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.68,
      ),
      itemBuilder: (context, index) => const _ProductCardSkeleton(),
    );
  }
}

class _ProductCardSkeleton extends StatelessWidget {
  const _ProductCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(child: SkeletonBox(height: double.infinity, borderRadius: 10)),
        const SizedBox(height: 8),
        SkeletonBox(width: 100, height: 10),
        const SizedBox(height: 6),
        SkeletonBox(width: 60, height: 10),
      ],
    );
  }
}
