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
    title: "Inteligência Operacional",
    subtitle: "Padrões corporativos da Austrália × SAP S/4HANA Brasil em tempo real · IA local air-gapped",
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
    placeholder: "Descreva a situação ou o procedimento que precisa executar…",
    submit: "Perguntar",
    loading: "Consultando manuais e SAP…",
    examples: [
      {
        label: "Compliance · cliente bloqueado",
        question: "O cliente refinador está bloqueado por limite de crédito. O que preciso para regularizá-lo segundo o padrão KYC?",
      },
      {
        label: "Lixiviação · bomba de ácido",
        question: "A bomba de ácido da lixiviação falhou após a tempestade tropical. Já existe ordem aberta e temos a peça SKU-BR-ACID-9902 em estoque?",
      },
      {
        label: "Flotação · dosagem de xantato",
        question: "O teor do minério caiu. Como ajustar a dosagem de xantato para 15 g/t e o estoque do Depósito 002 é suficiente?",
      },
    ],
  },
  answer: {
    title: "Resposta",
    empty: "Faça uma pergunta para receber o procedimento corporativo cruzado com os dados do SAP.",
    search: "Busca (EN)",
    language: "Idioma da resposta",
    corrected: "ajustado pelo controle de idioma",
    transactions: "Transações SAP do procedimento",
  },
  stock: {
    title: "Estoque SAP (tempo real)",
    empty: "O estoque dos materiais citados aparecerá aqui.",
    material: "Material",
    location: "Local",
    quantity: "Qtd.",
    coverage: (days: unknown) => `cobertura ${days} dias`,
  },
  orders: {
    title: "Ordens de manutenção (SAP PM)",
    released: "Liberada",
    created: "Criada",
    costCenter: "Centro de custo",
    notification: "Nota",
    breakdown: "parada",
    reservation: (qty: unknown, uom: unknown, matnr: unknown) => `Reserva aberta: ${qty} ${uom} de ${matnr}`,
  },
  credit: {
    title: "Crédito de contrapartes (SAP)",
    blocked: "BLOQUEADO",
    active: "Ativo",
    limit: "Limite",
    exposure: "Exposição",
    overdue: "Vencido",
    days: (days: unknown) => `${days} dias de atraso`,
    cnpj: "CNPJ",
    ie: "Inscrição Estadual",
  },
  sources: {
    title: "Manuais corporativos (fontes AU)",
    empty: "Os trechos de manuais usados na resposta aparecerão aqui.",
    similarity: "similaridade",
  },
  plants: { BR10: "Usina de Flotação · Carajás (PA)", BR20: "Usina de Lixiviação · Carajás (PA)" } as Record<string, string>,
  storage: { "BR10/0002": "Depósito 002 · Reagentes", "BR20/0001": "Almoxarifado central" } as Record<string, string>,
};

export type Dictionary = typeof pt;

const es: Dictionary = {
  locale: "es",
  languageName: "Español",
  documentTitle: "Nodara BR-RAG · Inteligencia Operacional",
  header: {
    title: "Inteligencia Operacional",
    subtitle: "Estándares corporativos de Australia × SAP S/4HANA Brasil en tiempo real · IA local air-gapped",
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
    placeholder: "Describe la situación o el procedimiento que necesitas ejecutar…",
    submit: "Preguntar",
    loading: "Consultando manuales y SAP…",
    examples: [
      {
        label: "Compliance · cliente bloqueado",
        question: "El cliente refinador está bloqueado por límite de crédito. ¿Qué necesito para regularizarlo según el estándar KYC?",
      },
      {
        label: "Lixiviación · bomba de ácido",
        question: "La bomba de ácido de lixiviación falló tras la tormenta tropical. ¿Ya hay una orden abierta y tenemos el repuesto SKU-BR-ACID-9902?",
      },
      {
        label: "Flotación · dosis de xantato",
        question: "Cayó la ley del mineral. ¿Cómo ajusto la dosis de xantato a 15 g/t y alcanza el stock del Depósito 002?",
      },
    ],
  },
  answer: {
    title: "Respuesta",
    empty: "Haz una pregunta para recibir el procedimiento corporativo cruzado con los datos de SAP.",
    search: "Búsqueda (EN)",
    language: "Idioma de la respuesta",
    corrected: "ajustado por el control de idioma",
    transactions: "Transacciones SAP del procedimiento",
  },
  stock: {
    title: "Stock SAP (tiempo real)",
    empty: "Aquí aparecerá el stock de los materiales citados.",
    material: "Material",
    location: "Ubicación",
    quantity: "Cant.",
    coverage: (days) => `cobertura ${days} días`,
  },
  orders: {
    title: "Órdenes de mantenimiento (SAP PM)",
    released: "Liberada",
    created: "Creada",
    costCenter: "Centro de costo",
    notification: "Aviso",
    breakdown: "avería",
    reservation: (qty, uom, matnr) => `Reserva abierta: ${qty} ${uom} de ${matnr}`,
  },
  credit: {
    title: "Crédito de contrapartes (SAP)",
    blocked: "BLOQUEADO",
    active: "Activo",
    limit: "Límite",
    exposure: "Exposición",
    overdue: "Vencido",
    days: (days) => `${days} días de atraso`,
    cnpj: "CNPJ",
    ie: "Inscripción Estatal (IE)",
  },
  sources: {
    title: "Manuales corporativos (fuentes AU)",
    empty: "Aquí aparecerán los fragmentos de manual usados en la respuesta.",
    similarity: "similitud",
  },
  plants: { BR10: "Planta de Flotación · Carajás (PA)", BR20: "Planta de Lixiviación · Carajás (PA)" },
  storage: { "BR10/0002": "Depósito 002 · Reactivos", "BR20/0001": "Almacén central" },
};

const en: Dictionary = {
  locale: "en",
  languageName: "English",
  documentTitle: "Nodara BR-RAG · Operational Intelligence",
  header: {
    title: "Operational Intelligence",
    subtitle: "Australian corporate standards × SAP S/4HANA Brazil in real time · air-gapped local AI",
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
    placeholder: "Describe the situation or the procedure you need to perform…",
    submit: "Ask",
    loading: "Searching manuals and SAP…",
    examples: [
      {
        label: "Compliance · blocked customer",
        question: "The refinery customer is blocked by its credit limit. What do I need to regularize it under the KYC standard?",
      },
      {
        label: "Leaching · acid pump",
        question: "The leaching acid pump failed after the tropical storm. Is there already an open order and do we have spare SKU-BR-ACID-9902?",
      },
      {
        label: "Flotation · xanthate dosage",
        question: "The ore grade dropped. How do I adjust the xanthate dosage to 15 g/t and is the Depot 002 stock enough?",
      },
    ],
  },
  answer: {
    title: "Answer",
    empty: "Ask a question to get the corporate procedure cross-checked against SAP data.",
    search: "Search (EN)",
    language: "Answer language",
    corrected: "adjusted by the language guard",
    transactions: "SAP transactions of the procedure",
  },
  stock: {
    title: "SAP stock (real time)",
    empty: "Stock for the referenced materials will appear here.",
    material: "Material",
    location: "Location",
    quantity: "Qty",
    coverage: (days) => `coverage ${days} days`,
  },
  orders: {
    title: "Maintenance orders (SAP PM)",
    released: "Released",
    created: "Created",
    costCenter: "Cost center",
    notification: "Notification",
    breakdown: "breakdown",
    reservation: (qty, uom, matnr) => `Open reservation: ${qty} ${uom} of ${matnr}`,
  },
  credit: {
    title: "Counterparty credit (SAP)",
    blocked: "BLOCKED",
    active: "Active",
    limit: "Limit",
    exposure: "Exposure",
    overdue: "Overdue",
    days: (days) => `${days} days past due`,
    cnpj: "CNPJ",
    ie: "State registration (IE)",
  },
  sources: {
    title: "Corporate manuals (AU sources)",
    empty: "Manual excerpts used in the answer will appear here.",
    similarity: "similarity",
  },
  plants: { BR10: "Flotation plant · Carajás (PA)", BR20: "Leaching plant · Carajás (PA)" },
  storage: { "BR10/0002": "Depot 002 · Reagents", "BR20/0001": "Central warehouse" },
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
