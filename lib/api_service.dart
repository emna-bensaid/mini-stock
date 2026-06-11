import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models/article.dart';

/// Service centralisant tous les appels à l'API Laminas.
class ApiService {
  final String baseUrl;

  ApiService({this.baseUrl = 'http://localhost:8000'});

  /// B3 : charge tout le catalogue d'articles depuis l'API.
  /// Retourne une Map code-barres -> Article pour des lookups instantanés.
  Future<Map<String, Article>> chargerCatalogue() async {
    final res = await http.get(Uri.parse('$baseUrl/articles'));
    if (res.statusCode != 200) {
      throw Exception('Catalogue indisponible : HTTP ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final liste = (data['_embedded']?['articles'] as List?) ?? [];

    final catalogue = <String, Article>{};
    for (final json in liste) {
      final art = Article.fromJson(json as Map<String, dynamic>);
      catalogue[art.codeBarre] = art;
    }
    return catalogue;
  }

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

class ResultatEnvoi {
  final int succes;
  final List<String> erreurs;

  const ResultatEnvoi({required this.succes, required this.erreurs});

  bool get touteReussi => erreurs.isEmpty;
  int get total => succes + erreurs.length;
}