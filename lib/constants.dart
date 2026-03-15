import 'dart:io';
import 'package:flutter/foundation.dart';

/// Configuration de l'API backend
class ApiConstants {
  // ⚠️ CONFIGURATION IMPORTANTE:
  // - Pour ÉMULATEUR Android  → utiliser 10.0.2.2 (adresse spéciale)
  // - Pour APPAREIL PHYSIQUE  → utiliser l'IP locale de votre PC (ex: 192.168.1.X)
  //   Trouvez votre IP avec: ipconfig (Windows) → cherchez "Adresse IPv4" (Wi-Fi)
  static const String _physicalDeviceIp = "192.168.1.13"; // ← Mettez votre IP Wi-Fi ici

  // Mettez à true si vous testez sur un APPAREIL PHYSIQUE (pas un émulateur)
  static const bool usePhysicalDevice = true;

  /// URL du serveur selon la plateforme
  static String get baseUrl {
    if (kIsWeb) {
      // Navigateur web
      return "http://localhost:8000";
    } else if (Platform.isAndroid) {
      if (usePhysicalDevice) {
        // Appareil physique Android via Wi-Fi
        return "http://$_physicalDeviceIp:8000";
      } else {
        // Émulateur Android : 10.0.2.2 = localhost de la machine hôte
        return "http://10.0.2.2:8000";
      }
    } else {
      // iOS, Windows, macOS, Linux
      return "http://localhost:8000";
    }
  }

  /// URL alternative pour appareil physique Android (Wi-Fi)
  /// Utilisé comme fallback en cas d'échec de baseUrl
  static String get physicalDeviceUrl {
    return "http://$_physicalDeviceIp:8000";
  }

  /// URL de l'émulateur (utilitaire)
  static String get emulatorUrl {
    return "http://10.0.2.2:8000";
  }
}
