# IvoryBiz — App Mobile

## État actuel

Squelette du projet Flutter en place :

- ✅ `pubspec.yaml` — dépendances (Provider, Dio, SharedPreferences, Geolocator, etc.)
- ✅ Thème et couleurs de marque (`lib/theme/`)
- ✅ Modèles (`Product`, `ProductCategory`, `CartItem`, `Customer`)
- ✅ `ApiService` — WooCommerce (lecture) + backend Ivorybiz (commande/paiement)
- ✅ `StorageService` — sauvegarde infos client après 1ère commande
- ✅ `CartProvider` / `CustomerProvider` — état partagé dans toute l'app
- ✅ `SplashScreen` — ton vrai code (version 1), adapté pour attendre le
  chargement des données au lieu d'un délai fixe
- ✅ `SkeletonBox` / `ProductGridSkeleton` — état de chargement validé
- ✅ `fastRoute()` — transition rapide (180ms) entre écrans
- 🚧 `HomeScreen` — squelette minimal, à remplir avec le vrai visuel
  (bannière carrousel, bandeaux Friperie/Prêt-à-porter, catégories
  défilables, aperçus produits)

## À faire ensuite

- [ ] Écran Boutique (recherche, filtre drawer, grille)
- [ ] Écran Catégorie (archive, pagination, filtre par attributs)
- [ ] Fiche produit (bouton sticky, description "Voir plus")
- [ ] Panier
- [ ] Commande (facturation + paiement fusionnés, Mobile Money 2×2)
- [ ] Confirmation de commande
- [ ] Géolocalisation GPS (usage marketing)
- [ ] Remplacer les clés dans `lib/utils/constants.dart` par les vraies
      clés WooCommerce (LECTURE SEULE — jamais la clé Lecture/Écriture ici)

## Avant de lancer le projet

1. Installer les dépendances :
   ```
   flutter pub get
   ```
2. Remplacer les valeurs dans `lib/utils/constants.dart` :
   - `wooConsumerKey` / `wooConsumerSecret` : la clé WooCommerce **Lecture
     seule** (la première qu'on a générée, PAS celle Lecture/Écriture
     utilisée par le backend PHP)
3. Lancer :
   ```
   flutter run
   ```

## Sécurité — rappel important

- La clé WooCommerce **Lecture/Écriture** et les clés **GeniusPay**
  restent UNIQUEMENT dans `config.php` sur le serveur (déjà déployé et
  testé sur `ivorybiz.com/api-mobile/`).
- Seule une clé WooCommerce **Lecture seule** est embarquée dans l'app,
  pour afficher les produits/catégories.
