import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import 'notification_service.dart';
import '../main.dart' show navigatorKey;
import '../services/auth_service.dart';
import '../screens/client/post_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Canal de notification Android partagé
// ─────────────────────────────────────────────────────────────────────────────
const AndroidNotificationChannel _kChannel = AndroidNotificationChannel(
  'ecorewind_notifications',
  'EcoRewind Notifications',
  description: 'Notifications EcoRewind : j\'aimes, commentaires, collectes.',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
);

final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// ─────────────────────────────────────────────────────────────────────────────
// Handler de fond (doit être top-level ET annoté @pragma)
// Affiche la notification système même quand l'app est FERMÉE.
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialiser les plugins nécessaires dans l'isolate de fond
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@drawable/ic_stat_notify');
  const InitializationSettings initSettings =
      InitializationSettings(android: androidSettings);
  await _flutterLocalNotificationsPlugin.initialize(initSettings);

  // Créer le canal si besoin
  final androidPlugin = _flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.createNotificationChannel(_kChannel);

  final notification = message.notification;
  final title = notification?.title ?? 'EcoRewind';
  final body = notification?.body ?? '';
  final data = message.data;
  final type = data['type'] ?? 'info';

  await _flutterLocalNotificationsPlugin.show(
    message.hashCode,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        _kChannel.id,
        _kChannel.name,
        channelDescription: _kChannel.description,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@drawable/ic_stat_notify',
        color: const Color(0xFF2E7D32),
        playSound: true,
        enableVibration: true,
        ticker: title,
        styleInformation: BigTextStyleInformation(body),
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
      ),
    ),
    payload: jsonEncode({...data, 'type': type}),
  );

  debugPrint('[FCM-BG] Notification affichée : $title');
}

// ─────────────────────────────────────────────────────────────────────────────
// FcmService — service singleton de gestion complète des push notifications
// ─────────────────────────────────────────────────────────────────────────────
class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  bool _initialized = false;

  // ── Initialiser FCM — appeler une seule fois depuis main.dart ────────────
  static Future<void> initialize({BuildContext? context}) async {
    if (kIsWeb) {
      debugPrint('[FCM] Push non supportées sur Web.');
      return;
    }
    await FcmService()._init(context: context);
  }

  // ── Appeler après chaque connexion réussie ───────────────────────────────
  // 1. Enregistre le token FCM auprès du backend
  // 2. Affiche toutes les notifications non lues dans la barre système Android
  static Future<void> onUserLoggedIn() async {
    if (kIsWeb) return;
    try {
      // Étape 1 : enregistrer le token FCM
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FcmService()._sendTokenToBackend(token);
        debugPrint('[FCM] Token envoyé après login.');
      }
      // Étape 2 : afficher les notifications manquées
      await FcmService()._showPendingNotifications();
    } catch (e) {
      debugPrint('[FCM] Erreur onUserLoggedIn: $e');
    }
  }

  // ── Rétro-compatibilité ───────────────────────────────────────────────────
  static Future<void> sendTokenToBackend() => onUserLoggedIn();

  // ── Affiche uniquement les notifications reçues APRÈS la dernière déconnexion ──
  //
  // Logique :
  //  • Lit le timestamp de déconnexion sauvegardé par clearTokens().
  //  • Ne montre que les notifications dont created_at > last_logout_time.
  //  • Mise à jour du timestamp après chaque affichage pour le prochain login.
  //  • Première connexion (pas de timestamp) : aucune notification affichée
  //    pour ne pas submerger l'utilisateur.
  Future<void> _showPendingNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('jwt_token');
      if (jwt == null) return;

      // ── Lire la borne temporelle (timestamp de la dernière déconnexion) ──
      final lastLogoutStr = prefs.getString('fcm_last_logout_time');
      if (lastLogoutStr == null) {
        // Première connexion : on initialise la borne à maintenant
        // et on n'affiche rien (pas de spam au premier lancement)
        await prefs.setString(
          'fcm_last_logout_time',
          DateTime.now().toUtc().toIso8601String(),
        );
        debugPrint('[FCM] Première connexion — borne initialisée, aucune notif à afficher.');
        return;
      }

      final lastLogout = DateTime.tryParse(lastLogoutStr);
      if (lastLogout == null) return;

      debugPrint('[FCM] Borne de déconnexion : $lastLogoutStr');

      // ── Récupérer les notifications depuis le backend ─────────────────────
      final uri = Uri.parse('${ApiConstants.baseUrl}/notifications?skip=0&limit=50');
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $jwt'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return;

      final List<dynamic> allNotifs = jsonDecode(utf8.decode(response.bodyBytes));

      // ── Filtrer : non lues ET créées APRÈS la dernière déconnexion ─────────
      final toShow = allNotifs.where((n) {
        // Doit être non lue
        final isUnread = n['is_read'] == false || n['is_read'] == null;
        if (!isUnread) return false;

        // Doit avoir un created_at valide
        final createdAtStr = n['created_at']?.toString();
        if (createdAtStr == null) return false;

        // Doit être postérieure à la dernière déconnexion
        final createdAt = DateTime.tryParse(createdAtStr);
        if (createdAt == null) return false;

        return createdAt.isAfter(lastLogout);
      }).toList();

      // Trier du plus ancien au plus récent pour un affichage chronologique
      toShow.sort((a, b) {
        final ta = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(0);
        final tb = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(0);
        return ta.compareTo(tb);
      });

      if (toShow.isEmpty) {
        debugPrint('[FCM] Aucune nouvelle notification depuis la dernière déconnexion.');
        return;
      }

      debugPrint('[FCM] ${toShow.length} notification(s) à afficher depuis la déconnexion.');

      for (int i = 0; i < toShow.length; i++) {
        final notif  = toShow[i];
        final id     = notif['id']?.toString() ?? '';
        final type   = notif['type']?.toString() ?? 'info';
        final title  = notif['title']?.toString() ?? 'EcoRewind';
        final body   = notif['body']?.toString() ?? '';
        final postId = notif['post_id']?.toString();

        if (id.isEmpty) continue;

        // Décalage progressif entre les notifications (max 5 affichées rapidement)
        if (i > 0) await Future.delayed(const Duration(milliseconds: 400));

        // Payload de navigation — interne, jamais affiché
        final navPayload = jsonEncode({
          'type': type,
          if (postId != null) 'post_id': postId,
          'notif_id': id,
        });

        // Afficher dans la barre système Android avec son + vibration
        await _flutterLocalNotificationsPlugin.show(
          int.tryParse(id) ?? id.hashCode,
          title,   // Texte lisible uniquement
          body,    // Texte lisible uniquement
          _buildNotifDetails(body: body),
          payload: navPayload,
        );

        // ── Mettre à jour la borne IMMÉDIATEMENT après chaque affichage ──────
        // Garantit que cette notification ne sera plus affichée même en cas de crash.
        final notifTime = DateTime.tryParse(notif['created_at'] ?? '');
        if (notifTime != null) {
          // La nouvelle borne = heure de la notification affichée + 1 ms
          final newBound = notifTime.add(const Duration(milliseconds: 1));
          await prefs.setString('fcm_last_logout_time', newBound.toIso8601String());
        }

        // Ajouter au cache in-app (badge + écran notifications)
        NotificationService().addNotification(
          title: title,
          body: body,
          type: _mapType(type),
        );
      }

      // Borne finale = maintenant (pour le prochain login)
      await prefs.setString(
        'fcm_last_logout_time',
        DateTime.now().toUtc().toIso8601String(),
      );

      debugPrint('[FCM] ✅ ${toShow.length} notification(s) affichée(s).');
    } catch (e) {
      debugPrint('[FCM] Erreur _showPendingNotifications: $e');
    }

  }

  // ── Construit les NotificationDetails (affichage pur—aucun JSON technique) ──
  // Le payload de navigation n'est JAMAIS inclus dans le texte visible.
  NotificationDetails _buildNotifDetails({String body = ''}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _kChannel.id,
        _kChannel.name,
        channelDescription: _kChannel.description,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@drawable/ic_stat_notify',
        color: const Color(0xFF2E7D32),
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 250, 100, 250]),
        // BigTextStyleInformation affiche le texte lisible — jamais le payload JSON
        styleInformation: body.isNotEmpty
            ? BigTextStyleInformation(body)
            : const DefaultStyleInformation(false, false),
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
        groupKey: 'ecorewind_group',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
      ),
    );
  }


  Future<void> _init({BuildContext? context}) async {
    if (_initialized) return;
    _initialized = true;

    try {
      // 1. Demander la permission
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[FCM] Permission refusée.');
        return;
      }
      debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

      // 2. Présentation foreground iOS
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 3. Initialiser flutter_local_notifications
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@drawable/ic_stat_notify');
      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _flutterLocalNotificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          try {
            if (response.payload != null) {
              final data = jsonDecode(response.payload!) as Map<String, dynamic>;
              _navigateFromPayload(data);
            }
          } catch (e) {
            debugPrint('[FCM] Erreur tap notification locale: $e');
          }
        },
        onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationTap,
      );

      // 4. Créer le canal Android haute importance
      final androidPlugin = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(_kChannel);
      debugPrint('[FCM] Canal Android créé/vérifié');

      // 5. Enregistrer le handler de fond
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 6. Récupérer & envoyer le token FCM
      await _getAndSendToken();

      // 7. Écouter le rafraîchissement du token
      _messaging.onTokenRefresh.listen(_sendTokenToBackend);

      // 8. Messages en FOREGROUND (app ouverte)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[FCM-FG] Message: ${message.notification?.title}');
        _handleForegroundMessage(message);
      });

      // 9. Tap sur notification quand app en ARRIÈRE-PLAN (minimisée)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[FCM-TAP] App en fond: ${message.notification?.title}');
        _navigateFromRemoteMessage(message);
      });

      // 10. App relancée depuis une notification (était FERMÉE)
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[FCM-LAUNCH] App lancée via notif: ${initialMessage.notification?.title}');
        // Délai pour laisser le temps à l'arbre de widgets de se construire
        await Future.delayed(const Duration(milliseconds: 1500));
        _navigateFromRemoteMessage(initialMessage);
      }

      debugPrint('[FCM] ✅ Service FCM initialisé');
    } catch (e) {
      debugPrint('[FCM] Erreur init: $e');
    }
  }

  // ── Récupère le token et l'envoie au backend ─────────────────────────────
  Future<void> _getAndSendToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        debugPrint('[FCM] Token: ${token.substring(0, 20)}...');
        await _sendTokenToBackend(token);
      }
    } catch (e) {
      debugPrint('[FCM] Erreur récupération token: $e');
    }
  }

  // ── Envoie le token au backend FastAPI ───────────────────────────────────
  Future<void> _sendTokenToBackend(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('jwt_token');
      if (jwt == null) {
        debugPrint('[FCM] Pas de JWT → token non envoyé (non connecté)');
        return;
      }
      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/notifications/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwt',
        },
        body: jsonEncode({'token': token}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint('[FCM] ✅ Token enregistré sur le backend');
      } else {
        debugPrint('[FCM] Erreur backend: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[FCM] Erreur envoi token: $e');
    }
  }

  // ── Affiche la notification en FOREGROUND (app ouverte) ──────────────────
  void _handleForegroundMessage(RemoteMessage message) {
    final title = message.notification?.title ?? 'EcoRewind';
    final body = message.notification?.body ?? '';
    final data = message.data;
    final type = data['type'] ?? 'info';

    // Ajouter au cache local in-app
    NotificationService().addNotification(
      title: title,
      body: body,
      type: _mapType(type),
    );

    // Afficher la notification système native avec son + vibration
    // La notification n'affiche QUE le titre et le corps lisibles.
    // Le payload (données de navigation) reste strictement interne.
    final navPayload = jsonEncode({...data, 'type': type});
    _flutterLocalNotificationsPlugin.show(
      message.hashCode,
      title,
      body,
      _buildNotifDetails(body: body),
      payload: navPayload,
    );

    // Toast in-app superposé
    final ctx = navigatorKey.currentContext;
    if (ctx != null && ctx.mounted) {
      NotificationService.showToast(ctx, title: title, body: body, type: _mapType(type));
    }
  }

  // ── Navigation intelligente depuis un RemoteMessage ──────────────────────
  void _navigateFromRemoteMessage(RemoteMessage message) {
    _navigateFromPayload({...message.data, 'type': message.data['type'] ?? 'info'});
  }

  // ── Navigation intelligente depuis un payload (tap local ou FCM) ─────────
  void _navigateFromPayload(Map<String, dynamic> data) {
    final postIdRaw = data['post_id'];
    final type = data['type'] ?? '';
    debugPrint('[FCM] Navigation → type=$type, post_id=$postIdRaw');

    final context = navigatorKey.currentContext;
    if (context == null) return;

    if (postIdRaw != null) {
      final postId = int.tryParse(postIdRaw.toString());
      if (postId != null) {
        _openPost(context, postId);
        return;
      }
    }

    // Fallback : ouvrir l'écran des notifications
    Navigator.of(context).pushNamed('/notifications');
  }

  // ── Ouvre directement la publication depuis l'API ────────────────────────
  Future<void> _openPost(BuildContext context, int postId) async {
    try {
      final post = await AuthService().fetchSinglePost(postId);
      if (post != null && context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
        );
      } else if (context.mounted) {
        // Si la publication a été supprimée, ouvrir les notifications
        Navigator.of(context).pushNamed('/notifications');
      }
    } catch (e) {
      debugPrint('[FCM] Erreur ouverture post $postId: $e');
    }
  }

  NotificationType _mapType(String type) {
    switch (type) {
      case 'like': return NotificationType.like;
      case 'comment': return NotificationType.comment;
      case 'save': return NotificationType.save;
      default: return NotificationType.info;
    }
  }
}

// ── Handler de tap en arrière-plan (doit être top-level) ─────────────────────
@pragma('vm:entry-point')
void _onBackgroundNotificationTap(NotificationResponse response) {
  // Le navigatorKey n'est pas encore disponible dans ce contexte.
  // L'utilisateur relancera l'app, la navigation sera gérée par getInitialMessage.
  debugPrint('[FCM-BG-TAP] Payload: ${response.payload}');
}
