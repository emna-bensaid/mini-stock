import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'scan_page.dart';
import 'models/article.dart';

// ⚠️ Adapte selon ta cible :
//   - Web / iOS         : http://localhost:8000
//   - Émulateur Android : http://10.0.2.2:8000
const String baseUrl = 'http://localhost:8000';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mini Stock',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: const StockPage(),
    );
  }
}

class StockPage extends StatefulWidget {
  const StockPage({super.key});
  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  Map<String, int> _stockAgrege = {};        // code-barres -> quantité totale
  Map<String, Article> _catalogue = {};      // code-barres -> Article (nom)
  bool _loading = false;
  String _recherche = '';

  final _rechercheCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _chargerTout();
  }

  @override
  void dispose() {
    _rechercheCtrl.dispose();
    super.dispose();
  }

  /// Charge en parallèle le stock agrégé et le catalogue.
  Future<void> _chargerTout() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([_fetchStock(), _fetchCatalogue()]);
      setState(() {
        _stockAgrege = results[0] as Map<String, int>;
        _catalogue = results[1] as Map<String, Article>;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<Map<String, int>> _fetchStock() async {
    final res = await http.get(Uri.parse('$baseUrl/stock'));
    if (res.statusCode != 200) {
      throw Exception('Stock indisponible (HTTP ${res.statusCode})');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final liste = (data['_embedded']?['stock'] as List?) ?? [];
    final agrege = <String, int>{};
    for (final entry in liste) {
      final code = entry['nom']?.toString() ?? '';
      final qte = (entry['quantite'] as num?)?.toInt() ?? 0;
      if (code.isEmpty) continue;
      agrege[code] = (agrege[code] ?? 0) + qte;
    }
    return agrege;
  }

  Future<Map<String, Article>> _fetchCatalogue() async {
    final res = await http.get(Uri.parse('$baseUrl/articles'));
    if (res.statusCode != 200) {
      throw Exception('Catalogue indisponible (HTTP ${res.statusCode})');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final liste = (data['_embedded']?['articles'] as List?) ?? [];
    final cat = <String, Article>{};
    for (final json in liste) {
      final art = Article.fromJson(json as Map<String, dynamic>);
      cat[art.codeBarre] = art;
    }
    return cat;
  }

  /// Construit la liste affichable (tri alphabétique par nom).
  List<_LigneStock> get _lignesAffichables {
    final lignes = <_LigneStock>[];
    for (final entry in _stockAgrege.entries) {
      final code = entry.key;
      final qte = entry.value;
      final article = _catalogue[code];
      lignes.add(_LigneStock(
        codeBarre: code,
        nom: article?.nom,
        quantite: qte,
      ));
    }
    lignes.sort((a, b) {
      final na = (a.nom ?? a.codeBarre).toLowerCase();
      final nb = (b.nom ?? b.codeBarre).toLowerCase();
      return na.compareTo(nb);
    });
    return lignes;
  }

  List<_LigneStock> get _lignesFiltrees {
    if (_recherche.trim().isEmpty) return _lignesAffichables;
    final r = _recherche.toLowerCase();
    return _lignesAffichables.where((l) {
      final nom = (l.nom ?? '').toLowerCase();
      return nom.contains(r) || l.codeBarre.toLowerCase().contains(r);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final liste = _lignesFiltrees;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mini Stock'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text(
                'SCANNER',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ScanPage()),
                );
                _chargerTout(); // recharge après le scan
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _rechercheCtrl,
              onChanged: (v) => setState(() => _recherche = v),
              decoration: InputDecoration(
                labelText: 'Rechercher un article',
                hintText: 'Tape un nom ou un code-barres',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _recherche.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _rechercheCtrl.clear();
                          setState(() => _recherche = '');
                        },
                      )
                    : null,
              ),
            ),
          ),

          // En-tête de liste
          Container(
            color: Colors.indigo.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Articles en stock',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade900,
                    ),
                  ),
                ),
                Text(
                  '${liste.length} résultat(s)',
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),

          // Liste
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : liste.isEmpty
                    ? Center(
                        child: Text(
                          _recherche.isEmpty
                              ? 'Aucun article en stock'
                              : 'Aucun résultat pour "$_recherche"',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _chargerTout,
                        child: ListView.separated(
                          itemCount: liste.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final l = liste[i];
                            final connu = l.nom != null;
                            return ListTile(
                              leading: Icon(
                                connu
                                    ? Icons.inventory_2_outlined
                                    : Icons.help_outline,
                                color: connu ? Colors.indigo : Colors.orange,
                              ),
                              title: Text(
                                l.nom ?? '(Article inconnu)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: connu ? null : Colors.orange.shade900,
                                ),
                              ),
                              subtitle: Text('Code : ${l.codeBarre}'),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.indigo.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Qté : ${l.quantite}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.indigo,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

/// Petit modèle interne combinant stock + nom du catalogue.
class _LigneStock {
  final String codeBarre;
  final String? nom;
  final int quantite;

  const _LigneStock({
    required this.codeBarre,
    this.nom,
    required this.quantite,
  });
}