/// Représente un article identifié par son code-barres,
/// avec sa quantité comptée. Le champ `nom` sera rempli plus tard
/// par la recherche dans l'API (étape B).
class Article {
  final String codeBarre;
  final String? nom; // null tant qu'on ne l'a pas cherché dans l'API
  final int quantite;

  const Article({
    required this.codeBarre,
    this.nom,
    required this.quantite,
  });

  /// Construit un Article à partir du JSON renvoyé par l'API.
  /// Note maquette : pour l'instant l'API stocke le code-barres
  /// dans le champ `nom`. À nettoyer quand l'ERP sera branché.
  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      codeBarre: json['nom']?.toString() ?? '',
      quantite: (json['quantite'] as num?)?.toInt() ?? 0,
    );
  }

  /// Format envoyé à l'API lors d'un POST.
  Map<String, dynamic> toJson() => {
        'nom': codeBarre, // placeholder maquette
        'quantite': quantite,
      };

  /// Retourne une copie modifiée de l'Article.
  Article copyWith({String? codeBarre, String? nom, int? quantite}) {
    return Article(
      codeBarre: codeBarre ?? this.codeBarre,
      nom: nom ?? this.nom,
      quantite: quantite ?? this.quantite,
    );
  }
}