/// lib/screens/client/bin_scanner_screen.dart
///
/// Écran de scan QR — Poubelle Intelligente
/// Le citoyen présente son QR code à la poubelle OU scanne le QR
/// affiché sur la poubelle pour enregistrer son recyclage.
///
/// Flow :
///   1. Ouvre la caméra (mobile_scanner)
///   2. Détecte le QR code de la poubelle
///   3. Appelle POST /qr/scan-bin avec le qr_code du citoyen
///   4. Affiche le résultat animé (+X points)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';
import '../../features/scan/scan_service.dart';
import '../../features/scan/scan_history_screen.dart';

/// Types de déchets supportés par les poubelles intelligentes
const Map<String, Map<String, dynamic>> _wasteTypes = {
  'plastique': {'label': 'Plastique', 'icon': Icons.local_drink_rounded, 'color': Color(0xFF3B82F6)},
  'verre':     {'label': 'Verre',     'icon': Icons.wine_bar_rounded,     'color': Color(0xFF10B981)},
  'papier':    {'label': 'Papier',    'icon': Icons.article_rounded,       'color': Color(0xFF8B5CF6)},
  'metal':     {'label': 'Métal',     'icon': Icons.hardware_rounded,      'color': Color(0xFFF59E0B)},
  'organique': {'label': 'Organique', 'icon': Icons.eco_rounded,          'color': Color(0xFF22C55E)},
  'electronique': {'label': 'Électronique', 'icon': Icons.devices_rounded, 'color': Color(0xFFEF4444)},
  'general':   {'label': 'Général',   'icon': Icons.delete_rounded,        'color': Color(0xFF6B7280)},
};

class BinScannerScreen extends StatefulWidget {
  const BinScannerScreen({Key? key}) : super(key: key);

  @override
  State<BinScannerScreen> createState() => _BinScannerScreenState();
}

class _BinScannerScreenState extends State<BinScannerScreen>
    with TickerProviderStateMixin {
  final MobileScannerController _cameraController = MobileScannerController();
  bool _scanning = true;
  bool _loading = false;
  String _selectedWaste = 'general';
  _ScanResult? _lastResult;

  late AnimationController _pulseController;
  late AnimationController _resultController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _resultController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _pulseController.dispose();
    _resultController.dispose();
    super.dispose();
  }

  // ── Appel API scan-bin via ScanService ─────────────────────────────────────

  Future<void> _processScan(String scannedQr) async {
    if (!_scanning || _loading) return;
    setState(() { _scanning = false; _loading = true; });
    HapticFeedback.heavyImpact();

    // scannedQr = bin_code de la poubelle (ex: "BIN-PLASTIQUE-001")
    // Le backend identifie le citoyen via son qr_code personnel
    final userQr = AuthState.currentUser?.qrCode ?? '';
    if (userQr.isEmpty) {
      _showError('QR code citoyen introuvable. Reconnectez-vous.');
      return;
    }

    final result = await ScanService().scanBin(
      binCode: scannedQr,
      qrCode: userQr,
    );

    if (result.success) {
      setState(() {
        _loading = false;
        _lastResult = _ScanResult(
          success: true,
          pointsEarned: result.pointsEarned,
          scoreAfter: result.scoreAfter,
          scoreBefore: result.scoreBefore,
          wasteType: result.binType ?? _selectedWaste,
          userName: result.userName ?? '',
        );
      });
      _resultController.forward(from: 0);
      // Mettre à jour le score en cache local
      if (AuthState.currentUser != null) {
        AuthState.currentUser = AuthState.currentUser!.copyWithScore(
          _lastResult!.scoreAfter,
        );
      }
    } else {
      _showError(result.error ?? result.message);
    }
  }

  void _showError(String msg) {
    setState(() { _loading = false; _scanning = true; });
    HapticFeedback.vibrate();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _resetScan() {
    setState(() {
      _scanning = true;
      _loading = false;
      _lastResult = null;
    });
    _resultController.reset();
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Scanner la Poubelle',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _cameraController,
              builder: (_, state, __) {
                final isTorchOn = state.torchState == TorchState.on;
                return Icon(
                  isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                  color: isTorchOn ? Colors.amber : Colors.white54,
                );
              },
            ),
            onPressed: () => _cameraController.toggleTorch(),
          ),
        ],
      ),
      body: _lastResult != null
          ? _buildResultView()
          : _buildScannerView(),
    );
  }

  // ── Vue Scanner ─────────────────────────────────────────────────────────────

  Widget _buildScannerView() {
    return Stack(
      children: [
        // Caméra
        MobileScanner(
          controller: _cameraController,
          onDetect: (capture) {
            final code = capture.barcodes.firstOrNull?.rawValue;
            if (code != null && code.isNotEmpty) {
              _processScan(code);
            }
          },
        ),

        // Overlay sombre + cadre de scan
        _buildScanOverlay(),

        // Sélecteur de type de déchet
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildWasteSelector(),
        ),

        // Loader
        if (_loading)
          Container(
            color: Colors.black54,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppTheme.primaryGreen),
                  const SizedBox(height: 16),
                  Text(
                    'Attribution des points...',
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildScanOverlay() {
    return CustomPaint(
      painter: _ScanOverlayPainter(_pulseController),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            AnimatedBuilder(
              animation: _pulseController,
              builder: (_, __) => Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppTheme.primaryGreen.withOpacity(
                      0.5 + _pulseController.value * 0.5,
                    ),
                    width: 2.5,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                'Pointez vers le QR code de la poubelle',
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWasteSelector() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Type de déchet',
            style: GoogleFonts.outfit(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 78,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _wasteTypes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final key = _wasteTypes.keys.elementAt(i);
                final info = _wasteTypes[key]!;
                final isSelected = _selectedWaste == key;
                return GestureDetector(
                  onTap: () => setState(() => _selectedWaste = key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 64,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (info['color'] as Color).withOpacity(0.25)
                          : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? (info['color'] as Color)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          info['icon'] as IconData,
                          color: isSelected
                              ? (info['color'] as Color)
                              : Colors.white38,
                          size: 22,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          info['label'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: isSelected ? Colors.white : Colors.white38,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Vue Résultat ────────────────────────────────────────────────────────────

  Widget _buildResultView() {
    final r = _lastResult!;
    final wasteInfo = _wasteTypes[r.wasteType] ?? _wasteTypes['general']!;
    final color = wasteInfo['color'] as Color;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFF0F172A), color.withOpacity(0.15)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Spacer(),

              // Icône succès
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.15),
                  border: Border.all(color: color.withOpacity(0.4), width: 2),
                ),
                child: Icon(Icons.check_circle_rounded, color: color, size: 64),
              )
                  .animate(controller: _resultController)
                  .scale(begin: const Offset(0.3, 0.3), duration: 500.ms, curve: Curves.elasticOut)
                  .fadeIn(duration: 300.ms),

              const SizedBox(height: 32),

              // Points gagnés
              Text(
                '+${r.pointsEarned.toStringAsFixed(0)} pts',
                style: GoogleFonts.outfit(
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1,
                ),
              )
                  .animate(controller: _resultController, delay: 200.ms)
                  .fadeIn()
                  .slideY(begin: 0.3, curve: Curves.easeOutCubic),

              const SizedBox(height: 8),

              Text(
                'pour ${wasteInfo['label']}',
                style: GoogleFonts.inter(color: Colors.white60, fontSize: 18),
              ).animate(controller: _resultController, delay: 300.ms).fadeIn(),

              const SizedBox(height: 32),

              // Score total
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Score avant', style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
                        Text(
                          '${r.scoreBefore.toStringAsFixed(0)} pts',
                          style: GoogleFonts.outfit(color: Colors.white54, fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    Icon(Icons.arrow_forward_rounded, color: color),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Score total', style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
                        Text(
                          '${r.scoreAfter.toStringAsFixed(0)} pts',
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate(controller: _resultController, delay: 400.ms).fadeIn().slideY(begin: 0.2),

              const SizedBox(height: 16),

              // Nom du citoyen
              Text(
                'Bravo, ${r.userName} !',
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 16),
              ).animate(controller: _resultController, delay: 500.ms).fadeIn(),

              const Spacer(),

              // Boutons
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _resetScan,
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: Text('Scanner à nouveau', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ScanHistoryScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.history_rounded, size: 18),
                      label: Text(
                        'Voir mon historique',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(color: Colors.white.withOpacity(0.2)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Retour au profil',
                        style: GoogleFonts.inter(color: Colors.white38, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ).animate(controller: _resultController, delay: 600.ms).fadeIn(),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Résultat d'un scan ──────────────────────────────────────────────────────

class _ScanResult {
  final bool success;
  final double pointsEarned;
  final double scoreAfter;
  final double scoreBefore;
  final String wasteType;
  final String userName;

  const _ScanResult({
    required this.success,
    required this.pointsEarned,
    required this.scoreAfter,
    required this.scoreBefore,
    required this.wasteType,
    required this.userName,
  });
}

// ── Painter pour l'overlay de scan ─────────────────────────────────────────

class _ScanOverlayPainter extends CustomPainter {
  final Animation<double> animation;
  _ScanOverlayPainter(this.animation) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black54;
    final cx = size.width / 2;
    final cy = size.height / 2 - 60;
    const half = 130.0;
    const r = 24.0;

    // Zone sombre autour du cadre de scan
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: half * 2, height: half * 2),
        const Radius.circular(r),
      ))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);

    // Ligne de scan animée
    final linePaint = Paint()
      ..color = AppTheme.primaryGreen.withOpacity(0.8)
      ..strokeWidth = 2;
    final scanY = (cy - half) + animation.value * (half * 2);
    canvas.drawLine(
      Offset(cx - half + r, scanY),
      Offset(cx + half - r, scanY),
      linePaint,
    );

    // Coins du cadre
    final cornerPaint = Paint()
      ..color = AppTheme.primaryGreen
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const cLen = 24.0;

    // Coin TL
    canvas.drawLine(Offset(cx - half + r, cy - half), Offset(cx - half + r + cLen, cy - half), cornerPaint);
    canvas.drawLine(Offset(cx - half, cy - half + r), Offset(cx - half, cy - half + r + cLen), cornerPaint);
    // Coin TR
    canvas.drawLine(Offset(cx + half - r - cLen, cy - half), Offset(cx + half - r, cy - half), cornerPaint);
    canvas.drawLine(Offset(cx + half, cy - half + r), Offset(cx + half, cy - half + r + cLen), cornerPaint);
    // Coin BL
    canvas.drawLine(Offset(cx - half + r, cy + half), Offset(cx - half + r + cLen, cy + half), cornerPaint);
    canvas.drawLine(Offset(cx - half, cy + half - r - cLen), Offset(cx - half, cy + half - r), cornerPaint);
    // Coin BR
    canvas.drawLine(Offset(cx + half - r - cLen, cy + half), Offset(cx + half - r, cy + half), cornerPaint);
    canvas.drawLine(Offset(cx + half, cy + half - r - cLen), Offset(cx + half, cy + half - r), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
