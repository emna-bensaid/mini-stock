import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models/article.dart';

/// Service centralisant tous les appels à l'API Laminas.
///
/// Si l'URL de base change (déménagement, intégration ERP...),
/// on ne modifie que cette classe.
class ApiService {
  final String baseUrl;

  ApiService({this.baseUrl = 'http://localhost:8000'});

  /// Envoie une liste d'articles à l'API. Un POST /stock par article.
  Future<ResultatEnvoi> envoyerArticles(List<Article> articles) async {
    int succes = 0;
    final List<String> erreurs = [];

    for (final article in articles) {
      try {
        final res = await http.post(
          Uri.parse('$baseUrl/stock'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(article.toJson()),
        );
        if (res.statusCode == 201) {
          succes++;
        } else {
          erreurs.add('${article.codeBarre} : HTTP ${res.statusCode}');
        }
      } catch (e) {
        erreurs.add('${article.codeBarre} : $e');
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