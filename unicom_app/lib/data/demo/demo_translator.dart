/// Offline demo engine powering the simulated AI providers.
///
/// Keys are semantic. Values map language → phrase with native orthography
/// (Yorùbá tone marks, Arabic RTL, Swahili, Hausa). The phrasebook is the
/// demo stand-in for a real MT provider — unknown text deliberately lands
/// in the app's graceful "translation unavailable" state, exactly like the
/// architecture's fallback rules.
abstract final class DemoPhrases {
  static const String _punct = "!¡?¿.,;:\"“”‘’'\u2019`\u2013\u2014…-";

  static String nz(String s) {
    var out = s.toLowerCase();
    for (final ch in _punct.split('')) {
      out = out.replaceAll(ch, ' ');
    }
    return out.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static const Map<String, Map<String, String>> book = {
    // The doc's canonical example pair: Spanish ↔ Yoruba
    'hello_how_are_you': {
      'en': 'Hey, how are you?',
      'es': 'Hola, ¿cómo estás?',
      'fr': 'Salut, ça va ?',
      'de': 'Hey, wie geht es dir?',
      'yo': 'Báwo ni, ṣé dáadáa ni?',
      'ha': 'Sannu, ya kake?',
      'sw': 'Habari, hujambo?',
      'ar': 'مرحباً، كيف حالك؟',
    },
    'im_fine_thanks': {
      'en': 'I am fine, thank you!',
      'es': 'Estoy bien, ¡gracias!',
      'fr': 'Ça va, merci !',
      'de': 'Mir geht es gut, danke!',
      'yo': 'Mo wà dáadáa, o ṣé!',
      'ha': 'Lafiya lau, na gode!',
      'sw': 'Niko nzuri, asante!',
      'ar': 'أنا بخير، شكراً!',
    },
    'good_morning': {
      'en': 'Good morning',
      'es': 'Buenos días',
      'fr': 'Bonjour',
      'de': 'Guten Morgen',
      'yo': 'Ẹ kú àárọ̀',
      'ha': 'Ina kwana',
      'sw': 'Habari ya asubuhi',
      'ar': 'صباح الخير',
    },
    'good_night': {
      'en': 'Good night',
      'es': 'Buenas noches',
      'fr': 'Bonne nuit',
      'de': 'Gute Nacht',
      'yo': 'Ó dàárọ̀',
      'ha': 'Barka da dare',
      'sw': 'Usiku mwema',
      'ar': 'تصبح على خير',
    },
    'thank_you': {
      'en': 'Thank you',
      'es': 'Gracias',
      'fr': 'Merci',
      'de': 'Danke',
      'yo': 'O ṣé',
      'ha': 'Na gode',
      'sw': 'Asante',
      'ar': 'شكراً',
    },
    'you_are_welcome': {
      'en': 'You are welcome',
      'es': 'De nada',
      'fr': 'Je t’en prie',
      'de': 'Gern geschehen',
      'yo': 'Kò tí ṣe ohun kan',
      'ha': 'Ba tare da ba',
      'sw': 'Karibu tena',
      'ar': 'على الرحب والسعة',
    },
    'what_are_you_doing': {
      'en': 'What are you doing?',
      'es': '¿Qué estás haciendo?',
      'fr': 'Qu’est-ce que tu fais ?',
      'de': 'Was machst du gerade?',
      'yo': 'Kí ni o ń ṣe?',
      'ha': 'Me kake yi?',
      'sw': 'Unafanya nini?',
      'ar': 'ماذا تفعل الآن؟',
    },
    'where_are_you': {
      'en': 'Where are you?',
      'es': '¿Dónde estás?',
      'fr': 'Où es-tu ?',
      'de': 'Wo bist du?',
      'yo': 'Nibo ni o wà?',
      'ha': 'Ina kake?',
      'sw': 'Uko wapi?',
      'ar': 'أين أنت؟',
    },
    'im_on_my_way': {
      'en': 'I am on my way',
      'es': 'Voy en camino',
      'fr': 'J’arrive',
      'de': 'Ich komme schon',
      'yo': 'Mo ń bọ̀',
      'ha': 'Ina zuwa',
      'sw': 'Niko njiani',
      'ar': 'أنا في الطريق',
    },
    'wait_for_me': {
      'en': 'Wait for me',
      'es': 'Espérame',
      'fr': 'Attends-moi',
      'de': 'Warte auf mich',
      'yo': 'Dùró dé mí',
      'ha': 'Jira ni',
      'sw': 'Nisubiri',
      'ar': 'انتظرني',
    },
    'see_you_tomorrow': {
      'en': 'See you tomorrow',
      'es': 'Nos vemos mañana',
      'fr': 'À demain',
      'de': 'Bis morgen',
      'yo': 'Ká pàdé lọ́lá',
      'ha': 'Sai gobe',
      'sw': 'Tutaonana kesho',
      'ar': 'أراك غداً',
    },
    'call_me': {
      'en': 'Call me',
      'es': 'Llámame',
      'fr': 'Appelle-moi',
      'de': 'Ruf mich an',
      'yo': 'Pè mí',
      'ha': 'Kira ni',
      'sw': 'Nipigie simu',
      'ar': 'اتصل بي',
    },
    'how_much_is_this': {
      'en': 'How much is this?',
      'es': '¿Cuánto cuesta esto?',
      'fr': 'Ça coûte combien ?',
      'de': 'Wie viel kostet das?',
      'yo': 'Elo ni èyí?',
      'ha': 'Nawa ne wannan?',
      'sw': 'Hii ni bei gani?',
      'ar': 'بكم هذا؟',
    },
    'im_at_home': {
      'en': 'I am at home',
      'es': 'Estoy en casa',
      'fr': 'Je suis à la maison',
      'de': 'Ich bin zu Hause',
      'yo': 'Mo wà nílé',
      'ha': 'Ina gida',
      'sw': 'Niko nyumbani',
      'ar': 'أنا في المنزل',
    },
    'ok_yes_no': {
      'en': 'Okay',
      'es': 'Vale',
      'fr': 'D’accord',
      'de': 'In Ordnung',
      'yo': 'Ó dára',
      'ha': 'Toh',
      'sw': 'Sawa',
      'ar': 'حسناً',
    },
    'welcome': {
      'en': 'Welcome',
      'es': 'Bienvenido',
      'fr': 'Bienvenue',
      'de': 'Willkommen',
      'yo': 'Ẹ káàbọ̀',
      'ha': 'Sannu da zuwa',
      'sw': 'Karibu',
      'ar': 'أهلاً وسهلاً',
    },
    'happy_birthday': {
      'en': 'Happy birthday',
      'es': 'Feliz cumpleaños',
      'fr': 'Joyeux anniversaire',
      'de': 'Alles Gute zum Geburtstag',
      'yo': 'Ẹ kú ọjọ́ ìbí',
      'ha': 'Barka da ranar haihuwa',
      'sw': 'Hongera sikukuu yako',
      'ar': 'عيد ميلاد سعيد',
    },
    'please_sorry': {
      'en': 'Sorry, please forgive me',
      'es': 'Perdón, por favor discúlpame',
      'fr': 'Désolé, pardonne-moi',
      'de': 'Es tut mir leid, verzeih mir',
      'yo': 'Ẹ má bínú, ẹ jọ̀wọ́ faramọ́ mí',
      'ha': 'Yi hakuri, don Allah gafarta mini',
      'sw': 'Samahani, tafadhali niwie radhi',
      'ar': 'آسف، من فضلك سامحني',
    },
    'what_is_your_name': {
      'en': 'What is your name?',
      'es': '¿Cómo te llamas?',
      'fr': 'Comment tu t’appelles ?',
      'de': 'Wie heißt du?',
      'yo': 'Kí ni orúkọ rẹ?',
      'ha': 'Mene ne sunanka?',
      'sw': 'Jina lako nani?',
      'ar': 'ما اسمك؟',
    },
    'my_name_is': {
      'en': 'My name is {name}',
      'es': 'Me llamo {name}',
      'fr': 'Je m’appelle {name}',
      'de': 'Ich heiße {name}',
      'yo': 'Orúkọ mi ń {name}',
      'ha': 'Sunana {name}',
      'sw': 'Jina langu ni {name}',
      'ar': 'اسمي {name}',
    },
    'meet_tomorrow': {
      'en': 'Are we still meeting tomorrow?',
      'es': '¿Todavía nos vemos mañana?',
      'fr': 'On se voit toujours demain ?',
      'de': 'Treffen wir uns morgen noch?',
      'yo': 'Ṣé ẹ jọ pàdé lọ́lá?',
      'ha': 'Za mu haɗu gobe?',
      'sw': 'Bado tunakutana kesho?',
      'ar': 'هل ما زلنا نلتقي غداً؟',
    },
    'sending_document': {
      'en': 'I am sending the document this evening',
      'es': 'Te envío el documento esta noche',
      'fr': 'Je t’envoie le document ce soir',
      'de': 'Ich schicke dir das Dokument heute Abend',
      'yo': 'Mo fi ìwé náà ránṣẹ́ lónìí alẹ́',
      'ha': 'Zan tura takardar wannan yamma',
      'sw': 'Nitakutumia hati jioni hii',
      'ar': 'سأرسل لك المستند هذا المساء',
    },
    'landed_airport': {
      'en': 'I just landed at the airport, call me',
      'es': 'Acabo de aterrizar en el aeropuerto, llámame',
      'fr': 'Je viens d’atterrir à l’aéroport, appelle-moi',
      'de': 'Ich bin gerade gelandet, ruf mich an',
      'yo': 'Mo ṣẹ̀ṣẹ̀ wá dé pápákọ̀ òfurufú, pè mí',
      'ha': 'Na yi sauka a filin jirgi, kira ni',
      'sw': 'Nimewasili uwanja wa ndege, nipigie simu',
      'ar': 'لقد وصلت إلى المطار، اتصل بي',
    },
    'lovely_day': {
      'en': 'Have a lovely day',
      'es': 'Que tengas un buen día',
      'fr': 'Passe une bonne journée',
      'de': 'Hab einen schönen Tag',
      'yo': 'Kí ọjọ́ rẹ dára',
      'ha': 'Rana mai albarka',
      'sw': 'Siku njema',
      'ar': 'نهارك سعيد',
    },
  };

  /// Canned voice-note transcripts, keyed for the pipeline demo.
  static const List<Map<String, String>> voiceTranscripts = [
    {
      'en': 'Hey! Are we still meeting tomorrow?',
      'es': '¡Ey! ¿Todavía nos vemos mañana?',
      'fr': 'Salut ! On se voit toujours demain ?',
      'de': 'Hey! Treffen wir uns morgen noch?',
      'yo': 'Pẹ̀lẹ́ o! Ṣé ẹ jọ pàdé lọ́lá?',
      'ha': 'Sannu! Za mu haɗu gobe?',
      'sw': 'Hodi! Bado tunakutana kesho?',
      'ar': 'مرحباً! هل ما زلنا نلتقي غداً؟',
    },
    {
      'en': 'I just landed at the airport. Call me when you can.',
      'es': 'Acabo de aterrizar en el aeropuerto. Llámame cuando puedas.',
      'fr': 'Je viens d’atterrir à l’aéroport. Appelle-moi quand tu peux.',
      'de':
          'Ich bin gerade am Flughafen gelandet. Ruf mich an, wenn du kannst.',
      'yo': 'Mo ṣẹ̀ṣẹ̀ dé pápákọ̀ òfurufú. Pè mí nígbà tí o bá lè.',
      'ha': 'Na yi sauka a filin jirgi. A kira ni idan ka samu lokaci.',
      'sw': 'Nimewasili uwanja wa ndege. Nipigie simu ukiruhusu.',
      'ar': 'لقد هبطت للتو في المطار. اتصل بي عندما تستطيع.',
    },
    {
      'en':
          'I am sending the document this evening. Take a look when you are free.',
      'es':
          'Te envío el documento esta noche. Échale un vistazo cuando estés libre.',
      'fr':
          'Je t’envoie le document ce soir. Jette-y un œil quand tu es libre.',
      'de':
          'Ich schicke das Dokument heute Abend. Schau es dir an, wenn du Zeit hast.',
      'yo': 'Mo fi ìwé náà ránṣẹ́ lónìí alẹ́. Wò ó nígbà tí ó bá ní àǹfààní.',
      'ha': 'Zan tura takardar wannan yamma. Duba idan ka samu lokaci.',
      'sw': 'Nitatumia hati jioni hii. Angalia ukipata muda.',
      'ar': 'سأرسل المستند هذا المساء. ألقِ نظرة عندما تكون متفرغاً.',
    },
  ];
}

/// Deterministic, offline stand-in for the pluggable
/// [TranslationProvider] interface. Swap this class for a real adapter —
/// nothing else in the app changes.
abstract final class DemoTranslator {
  /// Returns the translated text, or `null` when the demo dictionary
  /// has no coverage (rendered as "translation unavailable").
  static String? translate(String text, String from, String to) {
    if (from == to) return text;
    final String q = DemoPhrases.nz(text);
    for (final entry in DemoPhrases.book.values) {
      final String? src = entry[from];
      if (src != null && DemoPhrases.nz(src) == q) {
        final String? out = entry[to];
        return out; // may be null → target language not covered
      }
    }
    return null;
  }

  /// Best-effort source-language guess (demo detector).
  static String? detect(String text) {
    final String q = DemoPhrases.nz(text);
    for (final entry in DemoPhrases.book.values) {
      for (final e in entry.entries) {
        if (e.value.isNotEmpty && DemoPhrases.nz(e.value) == q) return e.key;
      }
    }
    return null;
  }

  /// Any language the dictionary can serve, used to simulate replies.
  static List<String> get servedLanguages =>
      DemoPhrases.book['thank_you']!.keys.toList();
}
