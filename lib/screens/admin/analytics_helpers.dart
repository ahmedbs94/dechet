import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../constants.dart';

// ── Résultat enrichi d'un appel analytics ────────────────────────────────────
class AnalyticsResult {
  final dynamic data;
  final int cacheAge;        // secondes depuis le dernier calcul backend (0 = frais)
  final DateTime fetchedAt;  // moment du fetch côté client

  const AnalyticsResult({
    required this.data,
    this.cacheAge = 0,
    required this.fetchedAt,
  });
}

// ── Requête authentifiée (retourne AnalyticsResult) ──────────────────────────
Future<AnalyticsResult?> analyticsGetFull(String path) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final jwt = prefs.getString('jwt_token');
    if (jwt == null) return null;
    final res = await http.get(
      Uri.parse('${ApiConstants.baseUrl}$path'),
      headers: {'Authorization': 'Bearer $jwt'},
    );
    if (res.statusCode == 200) {
      final cacheAge = int.tryParse(res.headers['x-cache-age'] ?? '0') ?? 0;
      return AnalyticsResult(
        data: json.decode(utf8.decode(res.bodyBytes)),
        cacheAge: cacheAge,
        fetchedAt: DateTime.now(),
      );
    }
  } catch (_) {}
  return null;
}

// ── Requête simplifiée (compatibilité ancienne API) ───────────────────────────
Future<dynamic> analyticsGet(String path) async {
  final result = await analyticsGetFull(path);
  return result?.data;
}

// ── Formatage "il y a X s/min" ───────────────────────────────────────────────
String formatAge(int totalSeconds) {
  if (totalSeconds <= 0) return 'À l\'instant';
  if (totalSeconds < 60) return 'il y a ${totalSeconds}s';
  final min = totalSeconds ~/ 60;
  final sec = totalSeconds % 60;
  if (sec == 0) return 'il y a ${min}min';
  return 'il y a ${min}min ${sec}s';
}

// ── Carte de section améliorée ────────────────────────────────────────────────
class SectionCard extends StatelessWidget {
  final String titre;
  final IconData icone;
  final Color couleur;
  final List<Widget> filtres;
  final Widget contenu;
  final bool chargement;
  final VoidCallback onActualiser;
  final DateTime? lastUpdated;   // moment où les données ont été chargées
  final int? cacheAge;           // âge cache backend en secondes

  const SectionCard({
    Key? key,
    required this.titre,
    required this.icone,
    required this.couleur,
    required this.filtres,
    required this.contenu,
    this.chargement = false,
    required this.onActualiser,
    this.lastUpdated,
    this.cacheAge,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: Theme.of(context).brightness == Brightness.dark
            ? []
            : [BoxShadow(color: couleur.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // En-tête dégradé
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [couleur.withOpacity(0.08), Colors.transparent]),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: couleur,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: couleur.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Icon(icone, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(titre, style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900, fontSize: 14,
                color: Theme.of(context).textTheme.titleLarge?.color ?? AppTheme.deepSlate))),
              if (chargement)
                SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: couleur)),
              const SizedBox(width: 4),
              IconButton(
                onPressed: onActualiser, tooltip: 'Actualiser',
                icon: Icon(Icons.refresh_rounded, color: couleur, size: 18),
                padding: EdgeInsets.zero, constraints: const BoxConstraints(),
              ),
            ]),
            // Badge de fraîcheur
            if (lastUpdated != null) ...[
              const SizedBox(height: 6),
              _FreshnessTimerBadge(
                lastUpdated: lastUpdated!,
                cacheAge: cacheAge ?? 0,
                couleur: couleur,
              ),
            ],
          ]),
        ),
        // Filtres
        if (filtres.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Wrap(spacing: 8, runSpacing: 6, children: filtres),
          ),
        const Divider(height: 1, indent: 20, endIndent: 20),
        // Contenu
        Padding(padding: const EdgeInsets.all(20), child: contenu),
      ]),
    );
  }
}

// ── Badge de fraîcheur avec timer live ───────────────────────────────────────
class _FreshnessTimerBadge extends StatefulWidget {
  final DateTime lastUpdated;
  final int cacheAge;
  final Color couleur;

  const _FreshnessTimerBadge({
    required this.lastUpdated,
    required this.cacheAge,
    required this.couleur,
  });

  @override
  State<_FreshnessTimerBadge> createState() => _FreshnessTimerBadgeState();
}

class _FreshnessTimerBadgeState extends State<_FreshnessTimerBadge> {
  late int _totalAge;

  @override
  void initState() {
    super.initState();
    _totalAge = widget.cacheAge + DateTime.now().difference(widget.lastUpdated).inSeconds;
    // Mettre à jour chaque seconde
    _tick();
  }

  void _tick() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        _totalAge = widget.cacheAge + DateTime.now().difference(widget.lastUpdated).inSeconds;
      });
      _tick();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isRecent = _totalAge < 30;
    final color = isRecent ? Colors.green : _totalAge < 90 ? Colors.orange : Colors.red;
    return Row(children: [
      Container(
        width: 6, height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(
        'Mis à jour ${formatAge(_totalAge)}',
        style: GoogleFonts.inter(fontSize: 9, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
      ),
    ]);
  }
}

// ── Indicateur principal (grand) ─────────────────────────────────────────────
class IndicateurPrincipal extends StatelessWidget {
  final String valeur, etiquette, sousTitre;
  final IconData icone;
  final Color couleur;
  final bool alerte;

  const IndicateurPrincipal({
    Key? key,
    required this.valeur,
    required this.etiquette,
    required this.sousTitre,
    required this.icone,
    required this.couleur,
    this.alerte = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [couleur.withOpacity(alerte ? 0.12 : 0.06), couleur.withOpacity(0.02)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: couleur.withOpacity(alerte ? 0.4 : 0.15), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Icon(icone, color: couleur, size: 18),
          if (alerte)
            Container(width: 8, height: 8,
              decoration: BoxDecoration(color: couleur, shape: BoxShape.circle)),
        ]),
        const SizedBox(height: 10),
        FittedBox(
          alignment: Alignment.centerLeft,
          fit: BoxFit.scaleDown,
          child: Text(valeur, style: GoogleFonts.outfit(
            fontWeight: FontWeight.w900, fontSize: 22,
            color: alerte
                ? couleur
                : (Theme.of(context).textTheme.titleLarge?.color ?? AppTheme.deepSlate),
            height: 1)),
        ),
        const SizedBox(height: 4),
        FittedBox(
          alignment: Alignment.centerLeft,
          fit: BoxFit.scaleDown,
          child: Text(etiquette, style: GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.deepSlate)),
        ),
        const SizedBox(height: 2),
        Text(sousTitre,
          style: GoogleFonts.inter(fontSize: 9, color: AppTheme.textMuted),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

// ── KPI compact (1/3 de largeur) ─────────────────────────────────────────────
class IndicateurCompact extends StatelessWidget {
  final String valeur, etiquette;
  final IconData icone;
  final Color couleur;
  final bool alerte;

  const IndicateurCompact({
    Key? key,
    required this.valeur,
    required this.etiquette,
    required this.icone,
    required this.couleur,
    this.alerte = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [couleur.withOpacity(alerte ? 0.12 : 0.06), couleur.withOpacity(0.01)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: couleur.withOpacity(alerte ? 0.35 : 0.12), width: 1.2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icone, color: couleur, size: 14),
          if (alerte) ...[
            const SizedBox(width: 4),
            Container(width: 6, height: 6, decoration: BoxDecoration(color: couleur, shape: BoxShape.circle)),
          ],
        ]),
        const SizedBox(height: 6),
        FittedBox(
          alignment: Alignment.centerLeft,
          fit: BoxFit.scaleDown,
          child: Text(valeur, style: GoogleFonts.outfit(
            fontWeight: FontWeight.w900, fontSize: 17,
            color: alerte ? couleur : (Theme.of(context).textTheme.titleLarge?.color ?? AppTheme.deepSlate),
            height: 1)),
        ),
        const SizedBox(height: 2),
        Text(etiquette, style: GoogleFonts.inter(
          fontSize: 9, fontWeight: FontWeight.w700,
          color: AppTheme.textMuted),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

// ── Filtre déroulant ─────────────────────────────────────────────────────────
class FiltreDeroulant extends StatelessWidget {
  final String etiquette, valeur;
  final List<String> options;
  final ValueChanged<String> onChangement;
  final Color couleur;

  const FiltreDeroulant({
    Key? key, required this.etiquette, required this.valeur,
    required this.options, required this.onChangement,
    this.couleur = AppTheme.primaryGreen,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: couleur.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: couleur.withOpacity(0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$etiquette ', style: GoogleFonts.inter(
          fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w500)),
        DropdownButton<String>(
          value: valeur, isDense: true, underline: const SizedBox(),
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: couleur),
          dropdownColor: Theme.of(context).colorScheme.surface,
          items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
          onChanged: (v) { if (v != null) onChangement(v); },
        ),
      ]),
    );
  }
}

// ── Filtre période ────────────────────────────────────────────────────────────
class FiltrePeriode extends StatelessWidget {
  final int valeur;
  final ValueChanged<int> onChangement;
  final Color couleur;

  const FiltrePeriode({Key? key, required this.valeur,
    required this.onChangement, required this.couleur}) : super(key: key);

  static const _options = [7, 30, 90, 365];
  static const _labels = ['7 jours', '30 jours', '3 mois', '1 an'];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: [
        Text('Période : ', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
        ...List.generate(_options.length, (i) => GestureDetector(
          onTap: () => onChangement(_options[i]),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: valeur == _options[i]
                  ? couleur
                  : (Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1E293B)
                      : Colors.grey.shade100),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_labels[i], style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700,
              color: valeur == _options[i] ? Colors.white : AppTheme.textMuted)),
          ),
        )),
      ],
    );
  }
}

// ── Barre de progression ──────────────────────────────────────────────────────
class BarreProgression extends StatelessWidget {
  final String etiquette, valeurTexte;
  final double valeur, max;
  final Color couleur;

  const BarreProgression({Key? key, required this.etiquette, required this.valeurTexte,
    required this.valeur, required this.max, required this.couleur}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final pct = max > 0 ? (valeur / max).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(etiquette, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600,
           color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.deepSlate)),
          Text(valeurTexte, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800,
            color: couleur)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct, minHeight: 8,
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E293B)
                : Colors.grey.shade100,
            valueColor: AlwaysStoppedAnimation(couleur),
          ),
        ),
      ]),
    );
  }
}

// ── Graphique en anneau ───────────────────────────────────────────────────────
class GraphiqueAnneau extends StatelessWidget {
  final List<MapEntry<String, double>> tranches;
  final List<Color> couleurs;
  final List<String> etiquettes;

  const GraphiqueAnneau({Key? key, required this.tranches,
    required this.couleurs, required this.etiquettes}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final total = tranches.fold<double>(0, (s, e) => s + e.value);
    return Row(children: [
      SizedBox(width: 110, height: 110,
        child: CustomPaint(painter: _PeintreAnneau(
          tranches: tranches, couleurs: couleurs, total: total, context: context))),
      const SizedBox(width: 20),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(tranches.length, (i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Container(width: 10, height: 10,
              decoration: BoxDecoration(
                color: couleurs[i % couleurs.length], shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text(i < etiquettes.length ? etiquettes[i] : tranches[i].key,
               style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.deepSlate))),
            Text('${tranches[i].value.toInt()}',
              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800,
                color: AppTheme.textMuted)),
            const SizedBox(width: 4),
            Text(total > 0 ? '(${(tranches[i].value / total * 100).toStringAsFixed(0)}%)' : '',
              style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted)),
          ]),
        )))),
    ]);
  }
}

class _PeintreAnneau extends CustomPainter {
  final List<MapEntry<String, double>> tranches;
  final List<Color> couleurs;
  final double total;
  final BuildContext context;
  _PeintreAnneau({required this.tranches, required this.couleurs, required this.total, required this.context});

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) return;
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2 - 4;
    var a = -math.pi / 2;
    final p = Paint()..style = PaintingStyle.stroke..strokeWidth = 18;
    for (var i = 0; i < tranches.length; i++) {
      final balayage = (tranches[i].value / total) * 2 * math.pi;
      if (balayage > 0.04) {
        canvas.drawArc(Rect.fromCircle(center: c, radius: r),
          a, balayage - 0.04, false, p..color = couleurs[i % couleurs.length]);
      }
      a += balayage;
    }
    final tp = TextPainter(
      text: TextSpan(text: '${total.toInt()}',
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15,
          color: Theme.of(context).textTheme.titleLarge?.color ?? AppTheme.deepSlate)),
      textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));
  }

  @override bool shouldRepaint(_PeintreAnneau o) => true;
}

// ── Graphique en ligne (courbe temporelle) ────────────────────────────────────
class GraphiqueLigne extends StatelessWidget {
  final List<Map<String, dynamic>> donnees; // [{day, count, points}]
  final Color couleur;
  final String labelY;

  const GraphiqueLigne({
    Key? key,
    required this.donnees,
    this.couleur = AppTheme.primaryGreen,
    this.labelY = 'scans',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (donnees.isEmpty) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1E293B)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(child: Text('Aucune donnée', style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12))),
      );
    }
    final max = donnees.map((d) => (d['count'] as num).toDouble()).reduce((a, b) => a > b ? a : b);
    return SizedBox(
      height: 120,
      child: CustomPaint(
        painter: _PeintreLigne(donnees: donnees, couleur: couleur, max: max),
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: donnees.map((d) {
              final label = (d['day'] as String).substring(5); // MM-DD
              return Text(label, style: GoogleFonts.inter(fontSize: 8, color: AppTheme.textMuted));
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _PeintreLigne extends CustomPainter {
  final List<Map<String, dynamic>> donnees;
  final Color couleur;
  final double max;
  _PeintreLigne({required this.donnees, required this.couleur, required this.max});

  @override
  void paint(Canvas canvas, Size size) {
    if (donnees.isEmpty || max == 0) return;
    final h = size.height - 20;
    final w = size.width;
    final step = w / (donnees.length - 1).clamp(1, 999);

    final fillPath = Path();
    fillPath.moveTo(0, h);
    for (var i = 0; i < donnees.length; i++) {
      final x = i * step;
      final y = h - (donnees[i]['count'] as num).toDouble() / max * h * 0.85;
      fillPath.lineTo(x, y);
    }
    fillPath.lineTo((donnees.length - 1) * step, h);
    fillPath.close();
    canvas.drawPath(fillPath, Paint()
      ..shader = LinearGradient(
        colors: [couleur.withOpacity(0.25), couleur.withOpacity(0.0)],
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill);

    final linePaint = Paint()
      ..color = couleur
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final linePath = Path();
    for (var i = 0; i < donnees.length; i++) {
      final x = i * step;
      final y = h - (donnees[i]['count'] as num).toDouble() / max * h * 0.85;
      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
    }
    canvas.drawPath(linePath, linePaint);

    for (var i = 0; i < donnees.length; i++) {
      final x = i * step;
      final y = h - (donnees[i]['count'] as num).toDouble() / max * h * 0.85;
      canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = Colors.white..style = PaintingStyle.fill);
      canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = couleur..style = PaintingStyle.stroke..strokeWidth = 2);
    }
  }

  @override bool shouldRepaint(_PeintreLigne o) => true;
}

// ── Filtre période (string) ───────────────────────────────────────────────────
class FiltrePeriodeString extends StatelessWidget {
  final String valeur;
  final ValueChanged<String> onChangement;
  final Color couleur;

  static const _options = ['today', 'yesterday', 'last_7_days', 'last_30_days', 'current_month', 'all_time'];
  static const _labels  = ["Auj.", "Hier", "7 jours", "30 jours", "Ce mois", "Tout"];

  const FiltrePeriodeString({
    Key? key,
    required this.valeur,
    required this.onChangement,
    this.couleur = AppTheme.primaryGreen,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: [
        Text('Période : ', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
        ...List.generate(_options.length, (i) => GestureDetector(
          onTap: () => onChangement(_options[i]),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: valeur == _options[i]
                  ? couleur
                  : (Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1E293B)
                      : Colors.grey.shade100),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_labels[i], style: GoogleFonts.inter(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: valeur == _options[i] ? Colors.white : AppTheme.textMuted)),
          ),
        )),
      ],
    );
  }
}

// ── Badge statut ──────────────────────────────────────────────────────────────
class BadgeStatut extends StatelessWidget {
  final String label;
  final Color couleur;
  final IconData? icone;

  const BadgeStatut({
    Key? key,
    required this.label,
    required this.couleur,
    this.icone,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: couleur.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: couleur.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icone != null) ...[
          Icon(icone, size: 12, color: couleur),
          const SizedBox(width: 4),
        ],
        Text(label, style: GoogleFonts.inter(
          fontSize: 10, fontWeight: FontWeight.w800, color: couleur)),
      ]),
    );
  }
}

// ── Séparateur de section avec titre ─────────────────────────────────────────
class SectionDivider extends StatelessWidget {
  final String label;
  const SectionDivider({Key? key, required this.label}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 4),
      child: Row(children: [
        Text(label, style: GoogleFonts.outfit(
          fontSize: 10, fontWeight: FontWeight.w900,
          letterSpacing: 1.5, color: AppTheme.textMuted)),
        const SizedBox(width: 12),
        Expanded(child: Container(height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppTheme.textMuted.withOpacity(0.3),
              Colors.transparent,
            ]),
          ),
        )),
      ]),
    );
  }
}
