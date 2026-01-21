import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../models/waste_record_model.dart';
import 'waste_prediction_result_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class WasteScannerScreen extends StatefulWidget {
  const WasteScannerScreen({Key? key}) : super(key: key);

  @override
  State<WasteScannerScreen> createState() => _WasteScannerScreenState();
}

class _WasteScannerScreenState extends State<WasteScannerScreen> {
  bool _isAnalyzing = false;
  WasteType? _predictedType;
  double? _confidence;

  void _analyzeImage() async {
    setState(() {
      _isAnalyzing = true;
      _predictedType = null;
      _confidence = null;
    });
    
    // Simulate AI analysis
    await Future.delayed(3.seconds);
    
    if (mounted) {
      // Randomly predict a waste type for demo
      final types = WasteType.values;
      final randomType = types[DateTime.now().millisecond % types.length];
      final randomConfidence = 0.82 + (DateTime.now().millisecond % 15) / 100;

      setState(() {
        _isAnalyzing = false;
        _predictedType = randomType;
        _confidence = randomConfidence;
      });

      // Navigate to result screen after a short delay
      await Future.delayed(const Duration(milliseconds: 800));
      
      if (mounted && _predictedType != null && _confidence != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WastePredictionResultScreen(
              predictedType: _predictedType!,
              confidenceScore: _confidence!,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Simulated Camera Feed
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.grey[900]!,
                  Colors.black,
                ],
              ),
            ),
          ),
          
          // Scanner Overlay
          Center(
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: _isAnalyzing ? Colors.blue : AppTheme.primaryGreen, width: 2),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Stack(
                children: [
                  Animate(
                    onPlay: (c) => c.repeat(reverse: true),
                    effects: [MoveEffect(begin: const Offset(0, 0), end: const Offset(0, 280), duration: 2.seconds)],
                    child: Container(height: 2, width: double.infinity, color: _isAnalyzing ? Colors.blue : AppTheme.primaryGreen),
                  ),
                ],
              ),
            ).animate().fadeIn(),
          ),

          Positioned(
            top: 60,
            left: 24,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: Colors.white, size: 32),
            ),
          ),

          Positioned(
            bottom: 60,
            left: 32,
            right: 32,
            child: Column(
              children: [
                GestureDetector(
                  onTap: _isAnalyzing ? null : _analyzeImage,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      color: _isAnalyzing ? Colors.grey : AppTheme.primaryGreen.withOpacity(0.5),
                    ),
                    child: Center(
                      child: _isAnalyzing 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Icon(Icons.camera_rounded, color: Colors.white, size: 40),
                    ),
                  ),
                ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1)),
                const SizedBox(height: 20),
                Text(_isAnalyzing ? 'ANALYSE IA EN COURS...' : 'SCANNEZ VOTRE DÉCHET', 
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
