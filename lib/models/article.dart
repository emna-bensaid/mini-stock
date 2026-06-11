/// Représente un article identifié par son code-barres.
class Article {
  final String codeBarre;
  final String? nom; // null = inconnu (pas trouvé dans le catalogue)
  final int quantite;

  const Article({
    required this.codeBarre,
    this.nom,
    this.quantite = 0,
  });

  /// Construit un Article depuis le JSON renvoyé par l'API.
  /// Gère les deux schémas :
  ///   - table articles : { code_barre, nom }
  ///   - table stock    : { nom (=code-barre placeholder), quantite }
  factory Article.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('code_barre')) {
      return Article(
        codeBarre: json['code_barre'].toString(),
        nom: json['nom']?.toString(),
        quantite: (json['quantite'] as num?)?.toInt() ?? 0,
      );
    }
    return Article(
      codeBarre: json['nom']?.toString() ?? '',
      quantite: (json['quantite'] as num?)?.toInt() ?? 0,
    );
  }

  /// Format envoyé à l'API lors d'un POST sur /stock.
  /// On envoie le code-barres dans le champ `nom` (placeholder maquette).
  Map<String, dynamic> toJson() => {
        'nom': codeBarre,
        'quantite': quantite,
      };

  Article copyWith({String? codeBarre, String? nom, int? quantite}) {
    return Article(
      codeBarre: codeBarre ?? this.codeBarre,
      nom: nom ?? this.nom,
      quantite: quantite ?? this.quantite,
    );
  }
}