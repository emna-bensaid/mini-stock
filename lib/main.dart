import 'dart:convert'; //les outils permettant de travailler avec le JSON.
import 'package:flutter/material.dart';  //Importe tous les composants graphiques Flutter
import 'package:http/http.dart' as http; //Importe la bibliothèque HTTP

// ⚠️ Adapte cette URL selon ta cible 
const String baseUrl = 'http://localhost:8000';

void main() => runApp(const MyApp());  //affiche l'application à l'écran.

class MyApp extends StatelessWidget {   //classe Flutter qui représente l'application entière.
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) { //méthode construit l'interface.
    return MaterialApp(
      title: 'Mini Stock',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: const StockPage(), //première page affichée
    );
  }
}

class StockPage extends StatefulWidget {
  const StockPage({super.key});
  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> { //Ici sont stockées les variables.
  List<dynamic> _items = [];
  bool _loading = false;
  //Contrôleurs des champs
  final _nomCtrl = TextEditingController();
  final _qteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _charger();
  }

  // GET /stock — récupère la liste
  Future<void> _charger() async { 
    setState(() => _loading = true);
    try {
      final res = await http.get(Uri.parse('$baseUrl/stock'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        // La liste est dans _embedded.stock (format HAL)
        setState(() => _items = data['_embedded']['stock'] ?? []);
      }
    } catch (e) {
      _message('Erreur de connexion : $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  // POST /stock — ajoute un article
  Future<void> _ajouter() async {
    final nom = _nomCtrl.text.trim();
    final qte = int.tryParse(_qteCtrl.text.trim()) ?? 0;
    if (nom.isEmpty) return;

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/stock'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'nom': nom, 'quantite': qte}),
      );
      if (res.statusCode == 201) {
        _nomCtrl.clear();
        _qteCtrl.clear();
        _message('Article ajouté');
        _charger(); // on recharge la liste
      } else {
        _message('Échec (${res.statusCode}) : ${res.body}');
      }
    } catch (e) {
      _message('Erreur : $e');
    }
  }

  void _message(String txt) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(txt)));  //récupère le gestionnaire des notifications.
  }

  @override
  //Construction de l'écran
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mini Stock')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nomCtrl,
                    decoration: const InputDecoration(labelText: 'Nom'),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: _qteCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Qté'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _ajouter,
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _charger,
                    child: ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (ctx, i) {
                        final item = _items[i];
                        return ListTile(
                          title: Text(item['nom'].toString()),
                          trailing: Text('Qté : ${item['quantite']}'),
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