"use client";

// Lightweight global i18n state (React Context): static UI texts in ES / EN / PT.
// Every dictionary is typed against `pt`, so a missing key fails the TypeScript build.
import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from "react";

export const LANGUAGES = ["es", "en", "pt"] as const;
export type Language = (typeof LANGUAGES)[number];

const STORAGE_KEY = "nodara.language";
const DEFAULT_LANGUAGE: Language = "pt";

const pt = {
  locale: "pt-BR",
  languageName: "Português",
  documentTitle: "Nodara BR-RAG · Inteligência Operacional",
  header: {
    title: "Inteligência Operacional de Manutenção",
    subtitle: "Manuais técnicos da Austrália × SAP S/4HANA Brasil em tempo real · IA local air-gapped",
    language: "Idioma",
  },
  status: {
    s4: "SAP S/4HANA",
    cdc: "Lakehouse CDC",
    manuals: "Manuais",
    llm: "LLM local",
    checking: "verificando…",
    unavailable: "indisponível",
    pendingModels: "modelos pendentes",
    s4Detail: (rows: unknown) => `${rows} docs de material`,
    cdcDetail: (events: unknown, lagMs: unknown) => `${events} eventos · lag ${lagMs ?? "–"} ms`,
    manualsDetail: (embedded: unknown, total: unknown) => `${embedded}/${total} trechos indexados`,
  },
  form: {
    label: "Pergunta do operador",
    placeholder: "Descreva o problema ou o procedimento que precisa executar…",
    submit: "Perguntar",
    loading: "Consultando manuais e SAP…",
    examples: [
      "Como trocar o filtro hidráulico de retorno do caminhão HT-400? Temos o filtro em estoque?",
      "Quais são os critérios de descarte do cabo de elevação da escavadeira ES-4100?",
      "Qual o procedimento para trocar o selo mecânico da bomba de polpa SP-250?",
      "Qual a pressão de calibragem dos pneus do HT-400 e quantos pneus temos disponíveis?",
    ],
  },
  answer: {
    title: "Resposta",
    empty: "Faça uma pergunta para receber o procedimento traduzido e cruzado com o SAP.",
    search: "Busca (EN)",
    languageNote: "",
  },
  stock: {
    title: "Estoque SAP (tempo real)",
    empty: "O estoque dos materiais citados aparecerá aqui.",
    material: "Material",
    location: "Local",
    quantity: "Qtd.",
  },
  sources: {
    title: "Manuais técnicos (fontes AU)",
    empty: "Os trechos de manuais usados na resposta aparecerão aqui.",
    similarity: "similaridade",
  },
  storage: { "0001": "Almoxarifado central", "0002": "Oficina" } as Record<string, string>,
};

export type Dictionary = typeof pt;

const es: Dictionary = {
  locale: "es",
  languageName: "Español",
  documentTitle: "Nodara BR-RAG · Inteligencia Operacional",
  header: {
    title: "Inteligencia Operacional de Mantenimiento",
    subtitle: "Manuales técnicos de Australia × SAP S/4HANA Brasil en tiempo real · IA local air-gapped",
    language: "Idioma",
  },
  status: {
    s4: "SAP S/4HANA",
    cdc: "Lakehouse CDC",
    manuals: "Manuales",
    llm: "LLM local",
    checking: "verificando…",
    unavailable: "no disponible",
    pendingModels: "modelos pendientes",
    s4Detail: (rows) => `${rows} docs de material`,
    cdcDetail: (events, lagMs) => `${events} eventos · lag ${lagMs ?? "–"} ms`,
    manualsDetail: (embedded, total) => `${embedded}/${total} fragmentos indexados`,
  },
  form: {
    label: "Pregunta del operador",
    placeholder: "Describe el problema o el procedimiento que necesitas ejecutar…",
    submit: "Preguntar",
    loading: "Consultando manuales y SAP…",
    examples: [
      "¿Cómo cambio el filtro hidráulico de retorno del camión HT-400? ¿Tenemos el filtro en stock?",
      "¿Cuáles son los criterios de descarte del cable de izaje de la pala ES-4100?",
      "¿Cuál es el procedimiento para cambiar el sello mecánico de la bomba de pulpa SP-250?",
      "¿Cuál es la presión de inflado de los neumáticos del HT-400 y cuántos tenemos disponibles?",
    ],
  },
  answer: {
    title: "Respuesta",
    empty: "Haz una pregunta para recibir el procedimiento traducido y cruzado con SAP.",
    search: "Búsqueda (EN)",
    languageNote: "Las respuestas del asistente se generan en portugués (pt-BR).",
  },
  stock: {
    title: "Stock SAP (tiempo real)",
    empty: "Aquí aparecerá el stock de los materiales citados.",
    material: "Material",
    location: "Ubicación",
    quantity: "Cant.",
  },
  sources: {
    title: "Manuales técnicos (fuentes AU)",
    empty: "Aquí aparecerán los fragmentos de manual usados en la respuesta.",
    similarity: "similitud",
  },
  storage: { "0001": "Almacén central", "0002": "Taller" },
};

const en: Dictionary = {
  locale: "en",
  languageName: "English",
  documentTitle: "Nodara BR-RAG · Operational Intelligence",
  header: {
    title: "Maintenance Operational Intelligence",
    subtitle: "Australian technical manuals × SAP S/4HANA Brazil in real time · air-gapped local AI",
    language: "Language",
  },
  status: {
    s4: "SAP S/4HANA",
    cdc: "Lakehouse CDC",
    manuals: "Manuals",
    llm: "Local LLM",
    checking: "checking…",
    unavailable: "unavailable",
    pendingModels: "models pending",
    s4Detail: (rows) => `${rows} material documents`,
    cdcDetail: (events, lagMs) => `${events} events · lag ${lagMs ?? "–"} ms`,
    manualsDetail: (embedded, total) => `${embedded}/${total} chunks indexed`,
  },
  form: {
    label: "Operator question",
    placeholder: "Describe the problem or the procedure you need to perform…",
    submit: "Ask",
    loading: "Searching manuals and SAP…",
    examples: [
      "How do I replace the hydraulic return filter on the HT-400 truck? Do we have the filter in stock?",
      "What are the discard criteria for the ES-4100 shovel hoist rope?",
      "What is the procedure to replace the mechanical seal of the SP-250 slurry pump?",
      "What is the HT-400 tyre inflation pressure and how many tyres do we have available?",
    ],
  },
  answer: {
    title: "Answer",
    empty: "Ask a question to get the procedure translated and cross-checked against SAP.",
    search: "Search (EN)",
    languageNote: "Assistant answers are generated in Portuguese (pt-BR).",
  },
  stock: {
    title: "SAP stock (real time)",
    empty: "Stock for the referenced materials will appear here.",
    material: "Material",
    location: "Location",
    quantity: "Qty",
  },
  sources: {
    title: "Technical manuals (AU sources)",
    empty: "Manual excerpts used in the answer will appear here.",
    similarity: "similarity",
  },
  storage: { "0001": "Central warehouse", "0002": "Workshop" },
};

export const DICTIONARIES: Record<Language, Dictionary> = { es, en, pt };

type I18n = { language: Language; setLanguage: (language: Language) => void; t: Dictionary };

const I18nContext = createContext<I18n | null>(null);

export function LanguageProvider({ children }: { children: ReactNode }) {
  const [language, setLanguageState] = useState<Language>(DEFAULT_LANGUAGE);

  // The server renders the default language; the operator's choice is restored after hydration.
  useEffect(() => {
    try {
      const saved = window.localStorage.getItem(STORAGE_KEY);
      if (saved && (LANGUAGES as readonly string[]).includes(saved)) setLanguageState(saved as Language);
    } catch {
      // storage unavailable (private mode / blocked): keep the default
    }
  }, []);

  useEffect(() => {
    document.documentElement.lang = DICTIONARIES[language].locale;
    document.title = DICTIONARIES[language].documentTitle;
  }, [language]);

  const setLanguage = useCallback((next: Language) => {
    setLanguageState(next);
    try {
      window.localStorage.setItem(STORAGE_KEY, next);
    } catch {
      // not persisted, still applied for this session
    }
  }, []);

  const value = useMemo(() => ({ language, setLanguage, t: DICTIONARIES[language] }), [language, setLanguage]);
  return <I18nContext.Provider value={value}>{children}</I18nContext.Provider>;
}

export function useI18n(): I18n {
  const context = useContext(I18nContext);
  if (!context) throw new Error("useI18n must be used inside <LanguageProvider>");
  return context;
}
