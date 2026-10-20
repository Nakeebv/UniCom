/**
 * Server-side language capability registry.
 *
 * UniCom does not assume every advertised language direction works equally well:
 * each entry records which capabilities were actually validated for the launch
 * languages (es, yo, fr, ha, ar) plus English and Portuguese.
 *
 * `stt:false` means the sender should rely on a typed transcript because
 * on-device/browser speech recognition coverage is too unreliable at launch.
 */
export type Capability = {
  translation: boolean;
  stt: boolean;
  tts: boolean;
  detection: boolean;
};

export type LanguageDef = {
  code: string;
  name: string;
  nativeName: string;
  dir: "ltr" | "rtl";
  speechLocale: string;
  accent: string;
  status: "tested" | "beta";
  capabilities: Capability;
};

export const SUPPORTED_LANGUAGES: LanguageDef[] = [
  {
    code: "en",
    name: "English",
    nativeName: "English",
    dir: "ltr",
    speechLocale: "en-US",
    accent: "#60A5FA",
    status: "tested",
    capabilities: { translation: true, stt: true, tts: true, detection: true },
  },
  {
    code: "es",
    name: "Spanish",
    nativeName: "Español",
    dir: "ltr",
    speechLocale: "es-ES",
    accent: "#F59E0B",
    status: "tested",
    capabilities: { translation: true, stt: true, tts: true, detection: true },
  },
  {
    code: "yo",
    name: "Yoruba",
    nativeName: "Yorùbá",
    dir: "ltr",
    speechLocale: "yo-NG",
    accent: "#34D399",
    status: "beta",
    capabilities: { translation: true, stt: false, tts: true, detection: true },
  },
  {
    code: "fr",
    name: "French",
    nativeName: "Français",
    dir: "ltr",
    speechLocale: "fr-FR",
    accent: "#A78BFA",
    status: "tested",
    capabilities: { translation: true, stt: true, tts: true, detection: true },
  },
  {
    code: "ha",
    name: "Hausa",
    nativeName: "Hausa",
    dir: "ltr",
    speechLocale: "ha-NG",
    accent: "#F472B6",
    status: "beta",
    capabilities: { translation: true, stt: false, tts: true, detection: true },
  },
  {
    code: "ar",
    name: "Arabic",
    nativeName: "العربية",
    dir: "rtl",
    speechLocale: "ar-SA",
    accent: "#22D3EE",
    status: "tested",
    capabilities: { translation: true, stt: true, tts: true, detection: true },
  },
  {
    code: "pt",
    name: "Portuguese",
    nativeName: "Português",
    dir: "ltr",
    speechLocale: "pt-BR",
    accent: "#FB923C",
    status: "tested",
    capabilities: { translation: true, stt: true, tts: true, detection: true },
  },
];

export const DEFAULT_LANGUAGE = "en";

export function languageByCode(code?: string | null): LanguageDef | undefined {
  if (!code) return undefined;
  return SUPPORTED_LANGUAGES.find((l) => l.code === code);
}

export function languageName(code?: string | null): string {
  return languageByCode(code)?.name ?? code ?? "Unknown";
}

export function isSupported(code: string): boolean {
  return SUPPORTED_LANGUAGES.some((l) => l.code === code);
}
