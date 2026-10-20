/**
 * Curated phrasebook used by the offline fallback translation provider.
 *
 * It exists so UniCom degrades gracefully when external AI providers are
 * unreachable: known, reviewed sentences still translate, and anything unknown
 * returns an explicit "unavailable" state rather than a fabricated result.
 * The seeded demo conversations use these exact sentences.
 */
export type PhraseEntry = {
  id: string;
  texts: Partial<Record<string, string>>;
};

export const PHRASEBOOK: PhraseEntry[] = [
  {
    id: "greet-how",
    texts: {
      es: "Hola, ¿cómo estás?",
      yo: "Báwo ni, ṣé dáadáa ni?",
      en: "Hello, how are you?",
      fr: "Salut, comment ça va ?",
      ha: "Sannu, yaya kake yi?",
      ar: "مرحبًا، كيف حالك؟",
      pt: "Olá, como você está?",
    },
  },
  {
    id: "morning-project",
    texts: {
      es: "Buenos días, ¿qué tal el proyecto?",
      en: "Good morning, how is the project going?",
      yo: "Ẹ káàrọ̀, bawo ni iṣẹ́ akanṣe naa ṣe ń lọ?",
      fr: "Bonjour, comment avance le projet ?",
      ha: "Barka da safiya, yaya aikin gida yake?",
      ar: "صباح الخير، كيف يسير المشروع؟",
      pt: "Bom dia, como vai o projeto?",
    },
  },
  {
    id: "meet-ten",
    texts: {
      es: "¿Nos vemos mañana a las diez?",
      en: "Shall we meet tomorrow at ten?",
      yo: "Ǹjẹ́ a ó ríra lọ́la ní wákàtí mẹ́ẹ̀wáà?",
      fr: "On se voit demain à dix heures ?",
      ha: "Za mu haɗu gobe da karfe goma?",
      ar: "هل نلتقي غدًا في العاشرة؟",
      pt: "Nos vemos amanhã às dez?",
    },
  },
  {
    id: "thanks-help",
    texts: {
      es: "Gracias por tu ayuda de ayer.",
      en: "Thanks for your help yesterday.",
      yo: "Ẹ ṣéú fún ìrànlọ́wọ́ yín lána.",
      fr: "Merci pour ton aide hier.",
      ha: "Na gode da taimakowanku na jiya.",
      ar: "شكرًا على مساعدتك بالأمس.",
      pt: "Obrigado pela sua ajuda ontem.",
    },
  },
  {
    id: "design-ready",
    texts: {
      en: "The design draft is ready for review.",
      es: "El borrador del diseño está listo para revisión.",
      yo: "Àwòrán àpẹẹrẹ náà ti ṣètàn fún àyẹ̀wò.",
      fr: "La maquette est prête pour relecture.",
      ha: "Tsarin zane ya shirya don sake dubawa.",
      ar: "المسودة التصميمية جاهزة للمراجعة.",
      pt: "O rascunho do design está pronto para revisão.",
    },
  },
  {
    id: "update-after-call",
    texts: {
      en: "I will send the update after the call.",
      es: "Enviaré la actualización después de la llamada.",
      yo: "Màá fi ìmúdójúìwọ̀n náà ránṣẹ́ lẹ́yìn ìpe náà.",
      fr: "J'enverrai la mise à jour après l'appel.",
      ha: "Zan aiko da sabuntawar bayan kiran.",
      ar: "سأرسل التحديث بعد المكالمة.",
      pt: "Vou enviar a atualização depois da chamada.",
    },
  },
  {
    id: "good-morning",
    texts: {
      en: "Good morning",
      es: "Buenos días",
      yo: "Ẹ káàrọ̀",
      fr: "Bonjour",
      ha: "Barka da safiya",
      ar: "صباح الخير",
      pt: "Bom dia",
    },
  },
  {
    id: "hello",
    texts: {
      en: "Hello",
      es: "Hola",
      yo: "Báwo ni",
      fr: "Bonjour",
      ha: "Sannu",
      ar: "مرحبًا",
      pt: "Olá",
    },
  },
  {
    id: "how-are-you",
    texts: {
      en: "How are you?",
      es: "¿Cómo estás?",
      yo: "Ṣé dáadáa ni?",
      fr: "Comment ça va ?",
      ha: "Yaya kake?",
      ar: "كيف حالك؟",
      pt: "Como você está?",
    },
  },
  {
    id: "see-tomorrow",
    texts: {
      en: "See you tomorrow",
      es: "Nos vemos mañana",
      yo: "A ó ríra lọ́la",
      fr: "À demain",
      ha: "Sai gobe",
      ar: "أراك غدًا",
      pt: "Até amanhã",
    },
  },
  {
    id: "thank-you",
    texts: {
      en: "Thank you very much",
      es: "Muchas gracias",
      yo: "Ẹ ṣéú gán-nì",
      fr: "Merci beaucoup",
      ha: "Na gode sosai",
      ar: "شكرًا جزيلًا",
      pt: "Muito obrigado",
    },
  },
  {
    id: "launch-monday",
    texts: {
      en: "The launch is scheduled for Monday.",
      es: "El lanzamiento está previsto para el lunes.",
      yo: "Ìfilọ́lẹ̀ náà ti pèsè fún ọjọ́ Ajé.",
      fr: "Le lancement est prévu pour lundi.",
      ha: "An shirya ƙaddamarwar a ran Litinin.",
      ar: "تم تحديد موعد الإطلاق يوم الاثنين.",
      pt: "O lançamento está marcado para segunda-feira.",
    },
  },
  {
    id: "review-message",
    texts: {
      en: "Can you review my message?",
      es: "¿Puedes revisar mi mensaje?",
      yo: "Ǹjẹ́ o lè ṣàyẹ̀wò ìfiránṣẹ́ mi?",
      fr: "Peux-tu relire mon message ?",
      ha: "Za ka iya duba saƙonni?",
      ar: "هل يمكنك مراجعة رسالتي؟",
      pt: "Você pode revisar minha mensagem?",
    },
  },
  {
    id: "voice-note-now",
    texts: {
      es: "Te envío la nota de voz ahora.",
      en: "I'm sending you the voice note now.",
      yo: "Máà fi ihùwàásí ohùn ránṣẹ́ sí ọ báyìí.",
      fr: "Je t'envoie la note vocale maintenant.",
      ha: "Zan aiko maka da saƙon murya yanzu.",
      ar: "سأرسل لك الملاحظة الصوتية الآن.",
      pt: "Estou te enviando a nota de voz agora.",
    },
  },
  {
    id: "hello-everyone",
    texts: {
      fr: "Bonjour tout le monde",
      en: "Hello everyone",
      es: "Hola a todos",
      yo: "Báwo ni gbogbo ẹni",
      ha: "Sannu dukkanku",
      ar: "مرحبًا بالجميع",
      pt: "Olá a todos",
    },
  },
  {
    id: "how-is-work",
    texts: {
      ha: "Sannu, yaya aiki?",
      en: "Hello, how is work?",
      es: "Hola, ¿cómo va el trabajo?",
      yo: "Báwo ni, bawo ni iṣẹ́ ṣe rí?",
      fr: "Bonjour, comment va le travail ?",
      ar: "مرحبًا، كيف هو العمل؟",
      pt: "Olá, como vai o trabalho?",
    },
  },
  {
    id: "great-progress",
    texts: {
      ar: "أحرزنا تقدمًا كبيرًا هذا الأسبوع.",
      en: "We made great progress this week.",
      es: "Logramos un gran avance esta semana.",
      yo: "A ní ìlọsíwájú ńlá ní èyí ọ̀ṣẹ̀.",
      fr: "Nous avons fait de gros progrès cette semaine.",
      ha: "Mun samu babban ci gaba a wannan mako.",
      pt: "Fizemos um grande progresso esta semana.",
    },
  },
];

/** Normalize for matching: case/punctuation/whitespace-insensitive. */
export function normalizeText(input: string): string {
  return input
    .toLowerCase()
    .normalize("NFC")
    .replace(/[¿¡!?.,;:"'«»“”]/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

/**
 * Look up a reviewed translation. Returns null when the sentence is unknown —
 * callers must treat that as "provider unavailable", never invent output.
 */
export function phraseLookup(
  text: string,
  sourceLanguage: string,
  targetLanguage: string,
): { translatedText: string; entryId: string } | null {
  if (sourceLanguage === targetLanguage) return null;
  const needle = normalizeText(text);
  for (const entry of PHRASEBOOK) {
    const source = entry.texts[sourceLanguage];
    if (source && normalizeText(source) === needle) {
      const target = entry.texts[targetLanguage];
      if (target) return { translatedText: target, entryId: entry.id };
    }
  }
  return null;
}

/** Best-effort source-language detection from the phrasebook. */
export function detectLanguageByPhrase(text: string): string | null {
  const needle = normalizeText(text);
  for (const entry of PHRASEBOOK) {
    for (const [code, value] of Object.entries(entry.texts)) {
      if (value && normalizeText(value) === needle) return code;
    }
  }
  return null;
}
