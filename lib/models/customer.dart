/// Informations client — champs validés avec Dosso pour le formulaire
/// de commande : Prénom, Nom, Ville, Commune/Quartier, Téléphone, E-mail.
/// Sauvegardé localement après la 1ère commande pour pré-remplissage.
class Customer {
  final String firstName;
  final String lastName;
  final String city;
  final String commune;
  final String phone;
  final String email;

  const Customer({
    required this.firstName,
    required this.lastName,
    required this.city,
    required this.commune,
    required this.phone,
    required this.email,
  });

  Map<String, dynamic> toJson() => {
        'first_name': firstName,
        'last_name': lastName,
        'city': city,
        'commune': commune,
        'phone': phone,
        'email': email,
      };

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        firstName: json['first_name'] as String? ?? '',
        lastName: json['last_name'] as String? ?? '',
        city: json['city'] as String? ?? '',
        commune: json['commune'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        email: json['email'] as String? ?? '',
      );
}
