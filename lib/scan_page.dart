import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api_service.dart';
import 'models/article.dart';

/// Écran de scan / comptage d'articles par code-barres.
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _ctrl = TextEditingController();

  final Map<String, int> _comptage = {};

  Map<String, Article> _catalogue = {};
  bool _catalogueCharge = false;

  final ApiService _api = ApiService(baseUrl: 'http://localhost:8000');

  bool _envoiEnCours = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
    _chargerCatalogue();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _chargerCatalogue() async {
    try {
      final catalogue = await _api.chargerCatalogue();
      if (!mounted) return;
      setState(() {
        _catalogue = catalogue;
        _catalogueCharge = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📚 Catalogue chargé (${catalogue.length} articles)'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Impossible de charger le catalogue : $e'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  /// Traite un scan. Rejette le code s'il n'est pas dans le catalogue.
  void _onScan(String code) {
    code = code.trim();
    if (code.isEmpty) return;

    // Si le catalogue est chargé ET que le code n'y est pas : on rejette.
    if (_catalogueCharge && !_catalogue.containsKey(code)) {
      HapticFeedback.heavyImpact(); // vibration plus marquée pour l'erreur
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⚠️ Code "$code" inconnu — scan flou ou non référencé',
          ),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 2),
        ),
      );
      _ctrl.clear();
      _focusNode.requestFocus();
      return;
    }

    // Article connu (ou catalogue pas encore chargé) : on incrémente.
    HapticFeedback.lightImpact();
    setState(() {
      _comptage[code] = (_comptage[code] ?? 0) + 1;
    });
    _ctrl.clear();
    _focusNode.requestFocus();
  }

  void _modifierQuantite(String code, int delta) {
    setState(() {
      final nouveau = (_comptage[code] ?? 0) + delta;
      if (nouveau <= 0) {
        _comptage.remove(code);
      } else {
        _comptage[code] = nouveau;
      }
    });
    _focusNode.requestFocus();
  }

  Future<void> _saisirQuantite(String code) async {
    final dialogCtrl = TextEditingController(text: '${_comptage[code]}');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Quantité pour\n$code'),
        content: TextField(
          controller: dialogCtrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Quantité'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, int.tryParse(dialogCtrl.text.trim())),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (result != null && result > 0) {
      setState(() => _comptage[code] = result);
    }
    _focusNode.requestFocus();
  }

  void _viderTout() {
    setState(() => _comptage.clear());
    _focusNode.requestFocus();
  }

  int get _total => _comptage.values.fold(0, (a, b) => a + b);

  List<Article> get _articlesAEnvoyer => _comptage.entries
      .map((e) => Article(codeBarre: e.key, quantite: e.value))
      .toList();

  Future<void> _confirmerEtEnvoyer() async {
    if (_envoiEnCours || _comptage.isEmpty) return;

    final nbArticles = _comptage.length;
    final totalUnites = _total;

    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirmer l'envoi"),
        content: Text(
          'Envoyer $nbArticles article(s) différent(s) '
          'pour un total de $totalUnites unité(s) au stock ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );

    if (confirme == true) {
      await _envoyer();
    } else {
      _focusNode.requestFocus();
    }
  }

  Future<void> _envoyer() async {
    setState(() => _envoiEnCours = true);
    final resultat = await _api.envoyerArticles(_articlesAEnvoyer);
    setState(() => _envoiEnCours = false);

    if (!mounted) return;

    if (resultat.touteReussi) {
      setState(() => _comptage.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${resultat.succes} article(s) envoyé(s) au stock'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } else if (resultat.succes > 0) {
      _afficherDialogue(
        titre: '⚠️ Échec partiel',
        contenu: 'Réussi : ${resultat.succes}\n'
            'Échoué : ${resultat.erreurs.length}\n\n'
            'Détails :\n${resultat.erreurs.join("\n")}',
      );
    } else {
      _afficherDialogue(
        titre: '❌ Échec',
        contenu: "Aucun article n'a pu être envoyé.\n\n"
            'Détails :\n${resultat.erreurs.join("\n")}',
      );
    }
    _focusNode.requestFocus();
  }

  void _afficherDialogue({required String titre, required String contenu}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titre),
        content: SingleChildScrollView(child: Text(contenu)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final codes = _comptage.keys.toList();
    final boutonActif = _comptage.isNotEmpty && !_envoiEnCours;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan inventaire'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Total : $_total',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Tout effacer',
            onPressed: (_comptage.isEmpty || _envoiEnCours) ? null : _viderTout,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              focusNode: _focusNode,
              controller: _ctrl,
              autofocus: true,
              onSubmitted: _onScan,
              decoration: InputDecoration(
                labelText: 'Scanner ici',
                hintText: _catalogueCharge
                    ? 'Scannez un article (catalogue : ${_catalogue.length})'
                    : 'Scannez un article (catalogue en cours de chargement...)',
                prefixIcon: const Icon(Icons.qr_code_scanner),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: codes.isEmpty
                ? const Center(child: Text('Aucun article scanné'))
                : ListView.builder(
                    itemCount: codes.length,
                    itemBuilder: (ctx, i) {
                      final code = codes[i];
                      final qte = _comptage[code]!;
                      final article = _catalogue[code];
                      // Tous les articles dans la liste sont connus (les inconnus
                      // sont rejetés avant ajout), mais on garde un fallback.
                      final nom = article?.nom ?? code;
                      return ListTile(
                        leading: const Icon(
                          Icons.check_circle_outline,
                          color: Colors.green,
                        ),
                        title: Text(
                          nom,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          'Code : $code   ·   Quantité : $qte',
                        ),
                        onTap: _envoiEnCours
                            ? null
                            : () => _saisirQuantite(code),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: _envoiEnCours
                                  ? null
                                  : () => _modifierQuantite(code, -1),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: _envoiEnCours
                                  ? null
                                  : () => _modifierQuantite(code, 1),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: boutonActif ? _confirmerEtEnvoyer : null,
                icon: _envoiEnCours
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cloud_upload),
                label: Text(
                  _envoiEnCours ? 'Envoi en cours...' : 'Envoyer au stock',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}