import 'package:shared_preferences/shared_preferences.dart';

class L10n {
  static String _locale = 'fr';
  static final List<Function()> _listeners = [];

  static String get locale => _locale;
  static bool get isArabic => _locale == 'ar';

  static void addListener(Function() listener) {
    _listeners.add(listener);
  }

  static void removeListener(Function() listener) {
    _listeners.remove(listener);
  }

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _locale = prefs.getString('app_locale') ?? 'fr';
    } catch (_) {}
  }

  static Future<void> setLocale(String lang) async {
    _locale = lang;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_locale', lang);
    } catch (_) {}
    for (final listener in _listeners) {
      listener();
    }
  }

  // Dictionnaire de traduction Français / Arabe
  static final Map<String, Map<String, String>> _keys = {
    // Brand
    'app_name': {'fr': 'EcoRewind', 'ar': 'EcoRewind ♻️'},
    
    // Onboarding
    'onboarding_title_1': {'fr': 'Tri Intelligent', 'ar': 'الفرز الذكي'},
    'onboarding_desc_1': {
      'fr': 'Simplifiez votre gestion des déchets grâce à notre IA de reconnaissance visuelle.',
      'ar': 'سهّل إدارة نفاياتك بفضل الذكاء الاصطناعي الخاص بنا للتعرف البصري.'
    },
    'onboarding_title_2': {'fr': 'Impact Réel', 'ar': 'أثر حقيقي'},
    'onboarding_desc_2': {
      'fr': 'Visualisez vos économies de CO2 et gagnez des points éco-citoyens à chaque geste.',
      'ar': 'شاهد توفيرك لـ CO2 واكسب نقاط مواطنة بيئية مع كل بادرة.'
    },
    'onboarding_title_3': {'fr': 'Communauté Active', 'ar': 'مجتمع نشط'},
    'onboarding_desc_3': {
      'fr': 'Rejoignez des milliers de Tunisiens engagés pour un environnement plus propre.',
      'ar': 'انضم إلى آلاف التونسيين الملتزمين من أجل بيئة أنظف.'
    },
    'onboarding_title_4': {'fr': 'Guide du Tri', 'ar': 'دليل الفرز'},
    'onboarding_desc_4': {
      'fr': 'Apprenez les gestes simples pour trier vos déchets comme un expert.',
      'ar': 'تعلم الحركات البسيطة لفرز نفاياتك مثل الخبراء.'
    },
    'btn_start': {'fr': 'COMMENCER', 'ar': 'البدء'},
    'btn_next': {'fr': 'SUIVANT', 'ar': 'التالي'},
    
    // Navigation Tabs (Mobile & Web)
    'tab_feed': {'fr': 'Fil', 'ar': 'المنشورات'},
    'tab_multimedia': {'fr': 'Formation', 'ar': 'التثقيف البيئي'},
    'tab_rewards': {'fr': 'Impact', 'ar': 'المكافآت'},
    'tab_map': {'fr': 'Carte', 'ar': 'الخريطة'},
    'tab_community': {'fr': 'Communauté', 'ar': 'المجتمع'},
    'tab_profile': {'fr': 'Profil', 'ar': 'الملف الشخصي'},
    
    // Role-specific tab labels
    'tab_educator': {'fr': 'Éducateur', 'ar': 'المربّي'},
    'tab_collector': {'fr': 'Collecte', 'ar': 'الجمع'},
    'tab_intercommunality': {'fr': 'Gestion', 'ar': 'التسيير'},
    'tab_pointManager': {'fr': 'Points', 'ar': 'نقاط الفرز'},
    
    // Profile Menu
    'menu_sec_security': {'fr': 'SÉCURITÉ ET DONNÉES', 'ar': 'الأمان والبيانات'},
    'menu_sec_preferences': {'fr': 'PRÉFÉRENCES', 'ar': 'التفضيلات'},
    
    'menu_mfa': {'fr': 'Authentification forte', 'ar': 'التحقق بخطوتين'},
    'menu_mfa_enabled': {'fr': 'Activée', 'ar': 'مفعّلة'},
    'menu_mfa_disabled': {'fr': 'Désactivée', 'ar': 'غير مفعّلة'},
    
    'menu_change_pass': {'fr': 'Changer le mot de passe', 'ar': 'تغيير كلمة المرور'},
    'menu_change_pass_sub': {'fr': 'Mis à jour il y a 3 mois', 'ar': 'تم التحديث منذ 3 أشهر'},
    
    'menu_saved_posts': {'fr': 'Publications enregistrées', 'ar': 'المنشورات المحفوظة'},
    'menu_saved_posts_sub': {'fr': 'Accédez à votre bibliothèque éco', 'ar': 'الوصول إلى مكتبتك البيئية'},
    
    'menu_notifications': {'fr': 'Notifications', 'ar': 'الإشعارات'},
    'menu_notif_unread': {'fr': 'non lue', 'ar': 'غير مقروءة'},
    'menu_notif_unreads': {'fr': 'non lues', 'ar': 'غير مقروءة'},
    'menu_notif_none': {'fr': 'Aucune nouvelle', 'ar': 'لا توجد إشعارات جديدة'},
    
    'menu_push_notif': {'fr': 'Notifications push', 'ar': 'إشعارات الدفع'},
    'menu_dark_mode': {'fr': 'Mode Sombre', 'ar': 'المظهر الداكن'},
    'menu_dark_mode_sub': {'fr': 'Système par défaut', 'ar': 'تلقائي حسب النظام'},
    
    'menu_logout': {'fr': 'Déconnexion', 'ar': 'تسجيل الخروج'},
    
    // Profile Cards & Buttons
    'prof_badge_title': {'fr': 'Espace Professionnel', 'ar': 'المساحة المهنية'},
    'prof_badge_desc': {
      'fr': 'Vous avez accès aux outils d\'administration avancés.',
      'ar': 'لديك صلاحية الوصول إلى أدوات الإدارة المتقدمة.'
    },
    'prof_role_admin': {'fr': 'DIRECTEUR TECHNIQUE', 'ar': 'المدير الفني'},
    'prof_role_user': {'fr': 'USER ENGAGÉ', 'ar': 'مواطن ملتزم'},
    
    'prof_stats_score': {'fr': 'SCORE GLOBAL', 'ar': 'النقاط الإجمالية'},
    'prof_stats_posts': {'fr': 'POSTS', 'ar': 'المنشورات'},
    'prof_stats_likes': {'fr': 'LIKES', 'ar': 'الإعجابات'},
    'prof_stats_comments': {'fr': 'COMMENTAIRES', 'ar': 'التعليقات'},
    
    'prof_btn_eco_badge': {'fr': 'Mon Eco-Badge', 'ar': 'شاراتي البيئية'},
    'prof_btn_eco_badge_sub': {'fr': 'Scannez pour ouvrir une borne de tri', 'ar': 'امسح الرمز لفتح حاوية الفرز'},
    
    'prof_btn_scan_bin': {'fr': 'Scanner une Poubelle', 'ar': 'مسح حاوية ذكية'},
    'prof_btn_scan_bin_sub': {'fr': 'Gagnez des points en recyclant', 'ar': 'اكسب نقاطًا عند إعادة التدوير'},
    
    'menu_lang': {'fr': 'Langue / اللغة', 'ar': 'اللغة / Langue'},
    'menu_lang_sub': {'fr': 'Français / Arabe', 'ar': 'العربية / الفرنسية'},
  };

  static String tr(String key) {
    return _keys[key]?[_locale] ?? key;
  }
}
