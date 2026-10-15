import 'package:flutter/material.dart';
import '../models/category.dart';
import '../theme/app_colors.dart';

/// Résultat renvoyé quand l'utilisateur appuie sur "Appliquer".
class FilterResult {
  final RangeValues priceRange;
  final Set<int> categoryIds;
  final Set<String> sizes;
  final Set<String> shoeSizes;
  final Map<String, Set<String>> attributes;

  const FilterResult({
    required this.priceRange,
    required this.categoryIds,
    required this.sizes,
    required this.shoeSizes,
    this.attributes = const {},
  });
}

/// Panneau de filtre en drawer latéral (glisse depuis la droite),
/// comme validé avec Dosso.
///
/// - Sur la Boutique : `showCategoryList = true` (toutes les catégories).
/// - Sur une archive de catégorie : `showCategoryList = false` — on
///   n'affiche que les attributs propres à cette catégorie (Prix, Tailles,
///   Pointures), pas la liste des catégories (redondant).
class FilterDrawer extends StatefulWidget {
  final List<ProductCategory> categories;
  final bool showCategoryList;
  final double maxPrice;
  final List<String> availableSizes;
  final List<String> availableShoeSizes;
  final Map<String, List<String>> availableAttributes;
  final Map<String, List<String>> Function(Set<int> categoryIds)?
      onCategorySelectionChanged;
  final FilterResult initial;
  final void Function(FilterResult) onApply;

  const FilterDrawer({
    super.key,
    required this.categories,
    required this.showCategoryList,
    required this.maxPrice,
    this.availableSizes = const [],
    this.availableShoeSizes = const [],
    this.availableAttributes = const {},
    this.onCategorySelectionChanged,
    required this.initial,
    required this.onApply,
  });

  @override
  State<FilterDrawer> createState() => _FilterDrawerState();
}

class _FilterDrawerState extends State<FilterDrawer> {
  late RangeValues _priceRange;
  late Set<int> _categoryIds;
  late Set<String> _sizes;
  late Set<String> _shoeSizes;
  late Map<String, List<String>> _availableAttributes;
  late Map<String, Set<String>> _attributes;

  @override
  void initState() {
    super.initState();
    _priceRange = widget.initial.priceRange;
    _categoryIds = {...widget.initial.categoryIds};
    _sizes = {...widget.initial.sizes};
    _shoeSizes = {...widget.initial.shoeSizes};
    _availableAttributes = {
      for (final entry in widget.availableAttributes.entries)
        entry.key: [...entry.value],
    };
    _attributes = {
      for (final entry in widget.initial.attributes.entries)
        entry.key: {...entry.value},
    };
  }

  void _reset() {
    setState(() {
      _priceRange = RangeValues(0, widget.maxPrice);
      _categoryIds.clear();
      _sizes.clear();
      _shoeSizes.clear();
      _attributes.clear();
    });
  }

  @override
  void didUpdateWidget(covariant FilterDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initial != widget.initial) {
      _priceRange = widget.initial.priceRange;
      _categoryIds = {...widget.initial.categoryIds};
      _sizes = {...widget.initial.sizes};
      _shoeSizes = {...widget.initial.shoeSizes};
      _attributes = {
        for (final entry in widget.initial.attributes.entries)
          entry.key: {...entry.value},
      };
    }
  }

  void _onCategoryChanged(int categoryId, bool selected) {
    setState(() {
      if (selected) {
        _categoryIds.add(categoryId);
      } else {
        _categoryIds.remove(categoryId);
      }
      _availableAttributes = {};
      _sizes.clear();
      _shoeSizes.clear();
      _attributes.clear();
      _availableAttributes =
          widget.onCategorySelectionChanged?.call({..._categoryIds}) ?? {};
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasCategoryAttributes =
        _categoryIds.isNotEmpty || !widget.showCategoryList;
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.78,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Filtrer',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _reset,
                child: const Text('Réinitialiser'),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _sectionTitle('Prix'),
                  RangeSlider(
                    values: _priceRange,
                    min: 0,
                    max: widget.maxPrice,
                    activeColor: AppColors.primary,
                    labels: RangeLabels(
                      '${_priceRange.start.round()} FCFA',
                      '${_priceRange.end.round()} FCFA',
                    ),
                    onChanged: (values) => setState(() => _priceRange = values),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${_priceRange.start.round()} FCFA',
                          style: const TextStyle(fontSize: 12)),
                      Text('${_priceRange.end.round()} FCFA',
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (widget.showCategoryList) ...[
                    _sectionTitle('Catégories'),
                    ...widget.categories.map((cat) => CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(cat.name,
                              style: const TextStyle(fontSize: 13)),
                          value: _categoryIds.contains(cat.id),
                          onChanged: (checked) =>
                              _onCategoryChanged(cat.id, checked == true),
                        )),
                    const SizedBox(height: 8),
                  ],
                  if (!hasCategoryAttributes &&
                      widget.availableSizes.isNotEmpty) ...[
                    _sectionTitle('Tailles'),
                    _chipWrap(
                      widget.availableSizes,
                      _sizes,
                      (value, selected) => setState(() {
                        selected ? _sizes.add(value) : _sizes.remove(value);
                      }),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (!hasCategoryAttributes &&
                      widget.availableShoeSizes.isNotEmpty) ...[
                    _sectionTitle('Pointures'),
                    _chipWrap(
                      widget.availableShoeSizes,
                      _shoeSizes,
                      (value, selected) => setState(() {
                        selected
                            ? _shoeSizes.add(value)
                            : _shoeSizes.remove(value);
                      }),
                    ),
                  ],
                  if (hasCategoryAttributes)
                    ..._availableAttributes.entries.expand((entry) => [
                          _sectionTitle(entry.key),
                          _chipWrap(
                            entry.value,
                            _attributes.putIfAbsent(
                                entry.key, () => <String>{}),
                            (value, selected) => setState(() {
                              final values = _attributes.putIfAbsent(
                                  entry.key, () => <String>{});
                              selected
                                  ? values.add(value)
                                  : values.remove(value);
                            }),
                          ),
                          const SizedBox(height: 16),
                        ]),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApply(FilterResult(
                      priceRange: _priceRange,
                      categoryIds: _categoryIds,
                      sizes: _sizes,
                      shoeSizes: _shoeSizes,
                      attributes: _attributes,
                    ));
                    Navigator.of(context).pop();
                  },
                  child: const Text('Appliquer'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      );

  Widget _chipWrap(
    List<String> options,
    Set<String> selectedSet,
    void Function(String value, bool selected) onToggle,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((value) {
        final selected = selectedSet.contains(value);
        return ChoiceChip(
          label: Text(value, style: const TextStyle(fontSize: 11)),
          selected: selected,
          selectedColor: AppColors.primary,
          labelStyle: TextStyle(
            color: selected ? Colors.white : AppColors.textPrimary,
          ),
          onSelected: (val) => onToggle(value, val),
        );
      }).toList(),
    );
  }
}
