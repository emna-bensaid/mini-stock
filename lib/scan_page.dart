import 'package:flutter/material.dart';

/// Écran de scan / comptage d'articles par code-barres.
///
/// Principe : le terminal industriel (ou un clavier en test) "tape" le
/// code-barres dans un champ texte focalisé, puis envoie Entrée. À chaque
/// Entrée on incrémente la quantité de cet article. La quantité reste
/// modifiable à la main pour couvrir le cas "une pile de N articles".
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  // Garde le focus sur le champ de scan en permanence.
  final FocusNode _focusNode = FocusNode();
  // Contrôle le contenu du champ de scan (pour le vider après chaque scan).
  final TextEditingController _ctrl = TextEditingController();

  // Le coeur de l'écran : code-barres -> quantité comptée.
  final Map<String, int> _comptage = {};

  @override
  void initState() {
    super.initState();
    // Dès que l'écran est affiché, on met le focus sur le champ de scan.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    // Toujours libérer les ressources pour éviter les fuites mémoire.
    _focusNode.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  /// Appelé à chaque scan (= Entrée envoyée par le scanner ou le clavier).
  void _onScan(String code) {
    code = code.trim();
    if (code.isEmpty) return;
    setState(() {
      // +1 si déjà présent, sinon on démarre à 1.
      _comptage[code] = (_comptage[code] ?? 0) + 1;
    });
    _ctrl.clear();                 // on vide le champ
    _focusNode.requestFocus();     // on reste prêt pour le scan suivant
  }

  /// Boutons - / + sur chaque ligne pour corriger la quantité.
  void _modifierQuantite(String code, int delta) {
    setState(() {
      final nouveau = (_comptage[code] ?? 0) + delta;
      if (nouveau <= 0) {
        _comptage.remove(code); // 0 ou moins -> on retire la ligne
      } else {
        _comptage[code] = nouveau;
      }
    });
    _focusNode.requestFocus();
  }

  /// Appui sur une ligne -> saisir une quantité précise (cas "pile de N").
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

  /// Tout effacer (pour recommencer un comptage).
  void _viderTout() {
    setState(() => _comptage.clear());
    _focusNode.requestFocus();
  }

  /// Total de tous les articles comptés.
  int get _total => _comptage.values.fold(0, (a, b) => a + b);

  /// Pour l'instant : affiche ce qui SERAIT envoyé à l'API.
  /// Plus tard : remplacer par un POST du lot vers l'API Laminas.
  void _envoyer() {
    final lignes = _comptage.entries
        .map((e) => '${e.key}  ->  ${e.value}')
        .join('\n');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("À envoyer à l'API"),
        content: Text(lignes.isEmpty ? 'Aucun article.' : lignes),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan inventaire'),
        actions: [
          // Total visible en permanence.
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Total : $_total',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          // Tout effacer.
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Tout effacer',
            onPressed: _comptage.isEmpty ? null : _viderTout,
          ),
        ],
      ),
      body: Column(
        children: [
          // Champ de scan (visible pour bien comprendre / déboguer).
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              focusNode: _focusNode,
              controller: _ctrl,
              autofocus: true,
              onSubmitted: _onScan, // déclenché par l'Entrée du scanner
              decoration: const InputDecoration(
                labelText: 'Scanner ici',
                hintText: 'Scannez un article (ou tapez un code + Entrée)',
                prefixIcon: Icon(Icons.qr_code_scanner),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const Divider(height: 1),

          // Liste des articles comptés.
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
                        onTap: () => _saisirQuantite(code), // saisie précise
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () => _modifierQuantite(code, -1),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => _modifierQuantite(code, 1),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Bouton d'envoi.
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _comptage.isEmpty ? null : _envoyer,
                icon: const Icon(Icons.cloud_upload),
                label: const Text('Envoyer au stock'),
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

