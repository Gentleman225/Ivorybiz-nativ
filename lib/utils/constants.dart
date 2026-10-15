/// Constantes de configuration de l'app.
///
/// IMPORTANT SÉCURITÉ :
/// - `wooConsumerKey`/`wooConsumerSecret` ici sont des clés WooCommerce en
///   LECTURE SEULE (générées avec la permission "Lecture" uniquement,
///   comme la 1ère clé qu'on a créée). Elles ne servent qu'à afficher les
///   produits/catégories — c'est acceptable de les embarquer dans l'app.
/// - La création de commande et le paiement passent TOUJOURS par notre
///   backend (`backendBaseUrl`), jamais directement depuis l'app avec la
///   clé WooCommerce Lecture/Écriture ni les clés GeniusPay — celles-là
///   restent uniquement dans config.php sur le serveur.
class AppConstants {
  AppConstants._();

  static const String wooBaseUrl = 'https://ivorybiz.com';
  static const String wooConsumerKey = 'ck_a86f38f67e02baebd0c9bc4c5f89079146f36543';
  static const String wooConsumerSecret = 'cs_5a05db91fcfdf08e5923f423c075143ac7c9f38c';

  static const String backendBaseUrl = 'https://ivorybiz.com/api-mobile';

  // Ordre de fallback si l'appel réseau échoue au démarrage (voir splash)
  static const Duration splashMaxWait = Duration(seconds: 10);
}
