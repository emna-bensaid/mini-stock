import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service centralisant tous les appels à l'API Laminas.
///
/// Si l'URL de base change (déménagement, intégration ERP...),
/// on ne modifie que cette classe.
class ApiService {
  final String baseUrl;

  ApiService({this.baseUrl = 'http://localhost:8000'});

  /// Envoie un lot de scans à l'API.
  /// Pour chaque entrée (code-barres -> quantité) on fait un POST /stock.
  ///
  /// Note maquette : on envoie le code-barres dans le champ `nom`
  /// (placeholder ; à remplacer par un vrai champ `code_barre` plus tard).
  Future<ResultatEnvoi> envoyerScans(Map<String, int> comptage) async {
    int succes = 0;
    final List<String> erreurs = [];

    for (final entry in comptage.entries) {
      final code = entry.key;
      final qte = entry.value;
      try {
        final res = await http.post(
          Uri.parse('$baseUrl/stock'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'nom': code,       // placeholder pour le code-barres
            'quantite': qte,
          }),
        );
        if (res.statusCode == 201) {
          succes++;
        } else {
          erreurs.add('$code : HTTP ${res.statusCode}');
        }
      } catch (e) {
        erreurs.add('$code : $e');
      }
    }

    return ResultatEnvoi(succes: succes, erreurs: erreurs);
  }
}

/// Résultat d'un envoi de lot : combien ont réussi, lesquels ont échoué.
class ResultatEnvoi {
  final int succes;
  final List<String> erreurs;

  const ResultatEnvoi({required this.succes, required this.erreurs});

  bool get touteReussi => erreurs.isEmpty;
  int get total => succes + erreurs.length;
}