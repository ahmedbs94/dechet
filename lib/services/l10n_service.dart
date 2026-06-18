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

    // Admin App
    'admin_app_bar_title': {'fr': 'EcoRewind Admin', 'ar': 'EcoRewind مشرف ♻️'},
    'admin_header_title': {'fr': 'Dashboard', 'ar': 'لوحة القيادة'},
    'admin_system_active': {'fr': '● Système actif', 'ar': '● النظام نشط'},
    
    // Admin Dashboard Tabs
    'admin_tab_indicators': {'fr': 'INDICATEURS', 'ar': 'المؤشرات'},
    'admin_tab_moderation': {'fr': 'MODÉRATION', 'ar': 'الرقابة'},
    'admin_tab_content': {'fr': 'CONTENUS', 'ar': 'المحتوى'},
    'admin_tab_proposals': {'fr': 'PROPOSITIONS', 'ar': 'الاقتراحات'},
    'admin_tab_points': {'fr': 'POINTS DE TRI', 'ar': 'نقاط الفرز'},
    'admin_tab_users': {'fr': 'UTILISATEURS', 'ar': 'المستخدمين'},
    'admin_tab_profile': {'fr': 'MON PROFIL', 'ar': 'ملفي الشخصي'},

    // Admin Dashboard KPI & Titles
    'admin_kpi_overview': {'fr': 'Vue d\'ensemble', 'ar': 'نظرة عامة'},
    'admin_kpi_users': {'fr': 'Utilisateurs', 'ar': 'المستخدمين'},
    'admin_kpi_users_sub': {'fr': 'Comptes actifs', 'ar': 'الحسابات النشطة'},
    'admin_kpi_scans': {'fr': 'Scans QR', 'ar': 'مسح الرمز'},
    'admin_kpi_scans_sub': {'fr': 'Total historique', 'ar': 'الإجمالي التاريخي'},
    'admin_kpi_points': {'fr': 'Points', 'ar': 'النقاط'},
    'admin_kpi_points_sub': {'fr': 'Distribués', 'ar': 'الموزعة'},
    'admin_kpi_centers': {'fr': 'Centres', 'ar': 'المراكز'},
    'admin_kpi_centers_sub': {'fr': 'Actifs / Total', 'ar': 'النشط / الإجمالي'},
    'admin_kpi_avg_score': {'fr': 'Score moyen', 'ar': 'متوسط النقاط'},
    'admin_kpi_avg_score_sub': {'fr': 'Moyenne citoyens', 'ar': 'متوسط المواطنين'},
    'admin_kpi_quiz': {'fr': 'Quiz faits', 'ar': 'الاختبارات المنجزة'},
    'admin_kpi_quiz_sub': {'fr': 'Soumissions totales', 'ar': 'إجمالي المشاركات'},
    'admin_kpi_moderation': {'fr': 'Modération', 'ar': 'الرقابة'},
    'admin_kpi_moderation_sub': {'fr': 'Signalements', 'ar': 'البلاغات'},
    'admin_kpi_firebase': {'fr': 'Firebase', 'ar': 'فايربيس'},
    'admin_kpi_firebase_sub': {'fr': 'Désynchronisations', 'ar': 'غير متزامن'},

    // Client Pages Headers
    'tab_multimedia_title': {'fr': 'Formation Éco', 'ar': 'التثقيف البيئي'},
    'tab_rewards_title': {'fr': 'Récompenses', 'ar': 'المكافآت'},

    // Rewards Screen Specifics
    'Solde Actuel': {'fr': 'Solde Actuel', 'ar': 'الرصيد الحالي'},
    'pts': {'fr': 'pts', 'ar': 'نقطة'},
    'Niveau Maximum atteint ! 🎉': {'fr': 'Niveau Maximum atteint ! 🎉', 'ar': 'تم الوصول إلى المستوى الأقصى! 🎉'},
    'Niveaux & Avantages': {'fr': 'Niveaux & Avantages', 'ar': 'المستويات والمزايا'},
    'Vos Badges': {'fr': 'Vos Badges', 'ar': 'شاراتك'},
    'Récompenses Exclusives': {'fr': 'Récompenses Exclusives', 'ar': 'مكافآت حصرية'},
    'Éco-Citoyen': {'fr': 'Éco-Citoyen', 'ar': 'مواطن بيئي'},
    'Champion Vert': {'fr': 'Champion Vert', 'ar': 'بطل أخضر'},
    'Légende Éco': {'fr': 'Légende Éco', 'ar': 'أسطورة البيئة'},
    'Niveau de départ': {'fr': 'Niveau de départ', 'ar': 'مستوى البداية'},
    '2 000 pts': {'fr': '2 000 pts', 'ar': '2000 نقطة'},
    '5 000 pts': {'fr': '5 000 pts', 'ar': '5000 نقطة'},
    'Premier Tri': {'fr': 'Premier Tri', 'ar': 'الفرز الأول'},
    'Série 7J': {'fr': 'Série 7J', 'ar': 'سلسلة 7 أيام'},
    'Expert Quiz': {'fr': 'Expert Quiz', 'ar': 'خبير الاختبارات'},
    'Communauté': {'fr': 'Communauté', 'ar': 'المجتمع'},
    'Bon d\'achat 10 DT': {'fr': 'Bon d\'achat 10 DT', 'ar': 'قسيمة شراء بقيمة 10 د.ت'},
    '1000 pts': {'fr': '1000 pts', 'ar': '1000 نقطة'},
    'Sac en toile bio': {'fr': 'Sac en toile bio', 'ar': 'حقيبة قماش عضوية'},
    '1500 pts': {'fr': '1500 pts', 'ar': '1500 نقطة'},
    'Gourde écologique': {'fr': 'Gourde écologique', 'ar': 'قارورة مياه صديقة للبيئة'},
    '2500 pts': {'fr': '2500 pts', 'ar': '2500 نقطة'},
    'Plantation d\'arbre': {'fr': 'Plantation d\'arbre', 'ar': 'زراعة شجرة'},
    '3000 pts': {'fr': '3000 pts', 'ar': '3000 نقطة'},

    // Multimedia Screen Specifics
    'Tout': {'fr': 'Tout', 'ar': 'الكل'},
    'Vidéos': {'fr': 'Vidéos', 'ar': 'الفيديوهات'},
    'Quiz': {'fr': 'Quiz', 'ar': 'الاختبارات'},
    'VIDÉOS ÉDUCATIVES': {'fr': 'VIDÉOS ÉDUCATIVES', 'ar': 'فيديوهات تعليمية'},
    'AUTRES VIDÉOS': {'fr': 'AUTRES VIDÉOS', 'ar': 'فيديوهات أخرى'},
    'QUIZ IA': {'fr': 'QUIZ IA', 'ar': 'اختبارات الذكاء الاصطناعي'},
    'Aucun quiz': {'fr': 'Aucun quiz', 'ar': 'لا يوجد اختبارات'},
    'Revenez plus tard pour de nouveaux défis': {'fr': 'Revenez plus tard pour de nouveaux défis', 'ar': 'عد لاحقًا لمواجهة تحديات جديدة'},

     // Feed Screen Specifics
     'Impossible de charger le fil': {'fr': 'Impossible de charger le fil', 'ar': 'تعذر تحميل المنشورات'},
     'Nouvelle publication': {'fr': 'Nouvelle publication', 'ar': 'منشور جديد'},
     'Partagez votre geste écologique...': {'fr': 'Partagez votre geste écologique...', 'ar': 'شارك بادرتك البيئية...'},
     'Ajouter une photo': {'fr': 'Ajouter une photo', 'ar': 'إضافة صورة'},
     'Publier': {'fr': 'Publier', 'ar': 'نشر'},
     'Aucune publication': {'fr': 'Aucune publication', 'ar': 'لا توجد منشورات'},
     'Soyez le premier à partager un geste éco !': {'fr': 'Soyez le premier à partager un geste éco !', 'ar': 'كن أول من يشارك بادرة بيئية!'},
     'Créer une publication': {'fr': 'Créer une publication', 'ar': 'إنشاء منشور'},

     // Community Screen Specifics
     'Espace Communauté': {'fr': 'Espace Communauté', 'ar': 'مساحة المجتمع'},
     'Témoignages et propositions de nos éco-citoyens': {'fr': 'Témoignages et propositions de nos éco-citoyens', 'ar': 'شهادات ومقترحات مواطنينا البيئيين'},
     'Avis de nos citoyens': {'fr': 'Avis de nos citoyens', 'ar': 'آراء مواطنينا'},
     'Partager votre avis': {'fr': 'Partager votre avis', 'ar': 'مشاركة رأيك'},
     'Votre expérience compte !': {'fr': 'Votre expérience compte !', 'ar': 'تجرّبتك تهمنا!'},
     'Proposer un centre de tri': {'fr': 'Proposer un centre de tri', 'ar': 'اقتراح مركز فرز'},
     'Suggérez un nouvel emplacement': {'fr': 'Suggérez un nouvel emplacement', 'ar': 'اقترح موقعًا جديدًا'},
     'Votre avis': {'fr': 'Votre avis', 'ar': 'رأيك'},
     'Partagez votre expérience avec EcoRewind': {'fr': 'Partagez votre expérience avec EcoRewind', 'ar': 'شارك تجربتك مع EcoRewind'},
     'Note': {'fr': 'Note', 'ar': 'التقييم'},
     'Votre témoignage': {'fr': 'Votre témoignage', 'ar': 'شهادتك'},

     // Intercommunality Tab Specifics
     'Coordination Territoriale': {'fr': 'Coordination Territoriale', 'ar': 'التنسيق الإقليمي'},
     'Gerez les politiques de tri et les acteurs locaux.': {'fr': 'Gérez les politiques de tri et les acteurs locaux.', 'ar': 'إدارة سياسات الفرز والجهات الفاعلة المحلية.'},
     'Consignes de tri locales': {'fr': 'Consignes de tri locales', 'ar': 'إرشادات الفرز المحلية'},
     'Mise à jour des règles 2026': {'fr': 'Mise à jour des règles 2026', 'ar': 'تحديث قواعد 2026'},
     'Points de collecte': {'fr': 'Points de collecte', 'ar': 'نقاط الجمع'},
     'Centralisation (342 points)': {'fr': 'Centralisation (342 points)', 'ar': 'المركزية (342 نقطة)'},
     'Acteurs locaux': {'fr': 'Acteurs locaux', 'ar': 'الجهات الفاعلة المحلية'},
     'Coordination : 12 prestataires': {'fr': 'Coordination : 12 prestataires', 'ar': 'التنسيق: 12 مزود خدمة'},
     'RAPPORTS DE PERFORMANCE INTERCOMMUNALE': {'fr': 'RAPPORTS DE PERFORMANCE INTERCOMMUNALE', 'ar': 'تقارير الأداء المشترك بين البلديات'},

     // Feed Screen Additional
     'Réessayer': {'fr': 'Réessayer', 'ar': 'إعادة المحاولة'},

     // Home Dashboard
     'home_score_label': {'fr': 'SCORE ÉCO ACTUEL', 'ar': 'النقاط البيئية الحالية'},
     'home_details': {'fr': 'Détails', 'ar': 'التفاصيل'},
     'home_tip_text': {'fr': 'Rincez vos contenants en plastique avant de les jeter pour un meilleur recyclage.', 'ar': 'اشطف حاويات البلاستيك قبل رميها لتحسين عملية إعادة التدوير.'},
     'home_quick_services': {'fr': 'Services Rapides', 'ar': 'الخدمات السريعة'},
     'home_action_centers': {'fr': 'Centres de Tri', 'ar': 'مراكز الفرز'},
     'home_action_quiz': {'fr': 'Quiz & Apprendre', 'ar': 'اختبارات وتعلم'},
     'home_action_feed': {'fr': 'Fil Citoyen', 'ar': 'منشورات المجتمع'},
     'home_action_shop': {'fr': 'Boutique', 'ar': 'المتجر'},
     'home_scan_title': {'fr': 'Scanner une Poubelle', 'ar': 'مسح حاوية ذكية'},
     'home_scan_sub': {'fr': 'Gagnez des points éco instantanément', 'ar': 'اكسب نقاطًا بيئية على الفور'},
     'home_history': {'fr': 'Historique', 'ar': 'السجل'},
     'home_education_section': {'fr': 'Espace Éducation', 'ar': 'مساحة التعليم'},
     'home_see_all': {'fr': 'Voir tout', 'ar': 'عرض الكل'},
     'home_see_all_arrow': {'fr': 'Tout voir →', 'ar': 'الكل →'},
     'home_global_impact': {'fr': 'IMPACT GLOBAL ECOREWIND', 'ar': 'الأثر العالمي لـ ECOREWIND'},
     'home_stat_co2': {'fr': 'CO₂ ÉVITÉ', 'ar': 'ثاني أكسيد الكربون الموفر'},
     'home_stat_sorted': {'fr': 'TRIÉ', 'ar': 'تم فرزه'},
     'home_stat_trees': {'fr': 'ARBRES', 'ar': 'الأشجار'},
     'home_news_section': {'fr': 'Actualités', 'ar': 'الأخبار'},
     'home_no_posts': {'fr': 'Aucune publication pour le moment', 'ar': 'لا توجد منشورات حالياً'},
  };

  static String tr(String key) {
    return _keys[key]?[_locale] ?? key;
  }
}
