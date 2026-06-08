import 'package:flutter/material.dart';
import 'api_service.dart';

/// Écran de scan / comptage d'articles par code-barres.
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _ctrl = TextEditingController();

  // Le coeur de l'écran : code-barres -> quantité comptée.
  final Map<String, int> _comptage = {};

  // ⚠️ Adapte l'URL selon ta cible :
  final ApiService _api = ApiService(baseUrl: 'http://localhost:8000');

  bool _envoiEnCours = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _onScan(String code) {
    code = code.trim();
    if (code.isEmpty) return;
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

  /// Envoie réellement le lot à l'API.
  Future<void> _envoyer() async {
    if (_envoiEnCours || _comptage.isEmpty) return;

    setState(() => _envoiEnCours = true);
    final resultat = await _api.envoyerScans(_comptage);
    setState(() => _envoiEnCours = false);

    if (!mounted) return;

    if (resultat.touteReussi) {
      setState(() => _comptage.clear());
      _afficherDialogue(
        titre: '✅ Envoyé',
        contenu: '${resultat.succes} article(s) enregistré(s) au stock.',
      );
    } else if (resultat.succes > 0) {
      _afficherDialogue(
        titre: '⚠️ Échec partiel',
        contenu:
            'Réussi : ${resultat.succes}\n'
            'Échoué : ${resultat.erreurs.length}\n\n'
            'Détails :\n${resultat.erreurs.join("\n")}',
      );
    } else {
      _afficherDialogue(
        titre: '❌ Échec',
        contenu:
            "Aucun article n'a pu être envoyé.\n\n"
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
              decoration: const InputDecoration(
                labelText: 'Scanner ici',
                hintText: 'Scannez un article (ou tapez un code + Entrée)',
                prefixIcon: Icon(Icons.qr_code_scanner),
                border: OutlineInputBorder(),
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
                      return ListTile(
                        title: Text(code),
                        subtitle: Text('Quantité : $qte'),
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
                onPressed: boutonActif ? _envoyer : null,
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