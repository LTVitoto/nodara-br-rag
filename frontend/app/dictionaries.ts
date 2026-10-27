// Static UI texts in ES / EN / PT. Plain module (no "use client"): the root layout reads it on the
// server to render the operator's language from the first byte; the client context reuses it.
// Every dictionary is typed against `pt`, so a missing key fails the TypeScript build.

export const LANGUAGES = ["es", "en", "pt"] as const;
export type Language = (typeof LANGUAGES)[number];
export type Engine = "nim" | "ollama";

export const LANGUAGE_COOKIE = "nodara.language";
export const DEFAULT_LANGUAGE: Language = "pt";

export function parseLanguage(value: string | undefined): Language {
  return (LANGUAGES as readonly string[]).includes(value ?? "") ? (value as Language) : DEFAULT_LANGUAGE;
}

const pt = {
  locale: "pt-BR",
  languageName: "Português",
  documentTitle: "Nodara BR-RAG · Inteligência Operacional",
  languageNames: { es: "espanhol", en: "inglês", pt: "português" } as Record<string, string>,
  header: {
    title: "Inteligência Operacional",
    subtitle: "Padrões corporativos da Austrália × SAP S/4HANA Brasil em tempo real · IA local + NVIDIA NIM",
    language: "Idioma",
  },
  status: {
    s4: "SAP S/4HANA",
    cdc: "Lakehouse CDC",
    manuals: "Manuais",
    llm: "Motores de IA",
    checking: "verificando…",
    unavailable: "indisponível",
    s4Detail: (rows: unknown) => `${rows} docs de material`,
    cdcDetail: (events: unknown, lagMs: unknown) => `${events} eventos · lag ${lagMs ?? "–"} ms`,
    manualsDetail: (embedded: unknown, total: unknown) => `${embedded}/${total} trechos indexados`,
    enginesDetail: (nim: boolean, ollama: boolean) => `NIM ${nim ? "✓" : "✗"} · Ollama ${ollama ? "✓" : "✗"}`,
  },
  engine: {
    label: "Motor de IA",
    nim: "NVIDIA NIM (Cloud)",
    ollama: "Ollama (Local)",
    nimUnavailable: "NVIDIA NIM não configurado (NVIDIA_API_KEY)",
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
  },
  meta: {
    language: "Idioma da resposta",
    corrected: "ajustado pelo controle de idioma",
    engine: "Motor",
    model: "Modelo",
    fallback: "contingência local",
    search: "Consulta semântica (inglês)",
    time: "Tempo total",
    seconds: (value: string) => `${value} s`,
    trace: "Ver rastreamento no Langfuse",
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
    fx: "Câmbio USD/BRL ao vivo",
    fxSource: (source: unknown, date: unknown) => `fonte: ${source} · ${date}`,
    liveBrl: "Exposição ao câmbio atual",
    bookedBrl: "Contabilizado (taxas históricas)",
    revaluation: "Reavaliação cambial",
    fxUnavailable: "Câmbio ao vivo indisponível",
  },
  sources: {
    title: "Manuais corporativos (fontes AU)",
    empty: "Os trechos de manuais usados na resposta aparecerão aqui.",
    similarity: "similaridade",
  },
  errors: {
    backendUnavailable: "Backend indisponível. Tente novamente em instantes.",
    invalidRequest: "Pergunta inválida: revise o texto (de 3 a 2000 caracteres).",
  },
  plants: { BR10: "Usina de Flotação · Carajás (PA)", BR20: "Usina de Lixiviação · Carajás (PA)" } as Record<string, string>,
  storage: { "BR10/0002": "Depósito 002 · Reagentes", "BR20/0001": "Almoxarifado central" } as Record<string, string>,
};

export type Dictionary = typeof pt;

const es: Dictionary = {
  locale: "es",
  languageName: "Español",
  documentTitle: "Nodara BR-RAG · Inteligencia Operacional",
  languageNames: { es: "español", en: "inglés", pt: "portugués" },
  header: {
    title: "Inteligencia Operacional",
    subtitle: "Estándares corporativos de Australia × SAP S/4HANA Brasil en tiempo real · IA local + NVIDIA NIM",
    language: "Idioma",
  },
  status: {
    s4: "SAP S/4HANA",
    cdc: "Lakehouse CDC",
    manuals: "Manuales",
    llm: "Motores de IA",
    checking: "verificando…",
    unavailable: "no disponible",
    s4Detail: (rows) => `${rows} docs de material`,
    cdcDetail: (events, lagMs) => `${events} eventos · lag ${lagMs ?? "–"} ms`,
    manualsDetail: (embedded, total) => `${embedded}/${total} fragmentos indexados`,
    enginesDetail: (nim, ollama) => `NIM ${nim ? "✓" : "✗"} · Ollama ${ollama ? "✓" : "✗"}`,
  },
  engine: {
    label: "Motor de IA",
    nim: "NVIDIA NIM (Cloud)",
    ollama: "Ollama (Local)",
    nimUnavailable: "NVIDIA NIM no configurado (NVIDIA_API_KEY)",
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
  },
  meta: {
    language: "Idioma de la respuesta",
    corrected: "ajustado por el control de idioma",
    engine: "Motor",
    model: "Modelo",
    fallback: "contingencia local",
    search: "Consulta semántica (inglés)",
    time: "Tiempo total",
    seconds: (value) => `${value} s`,
    trace: "Ver traza en Langfuse",
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
    fx: "Tipo de cambio USD/BRL en vivo",
    fxSource: (source, date) => `fuente: ${source} · ${date}`,
    liveBrl: "Exposición al cambio actual",
    bookedBrl: "Contabilizado (tasas históricas)",
    revaluation: "Revaluación cambiaria",
    fxUnavailable: "Tipo de cambio en vivo no disponible",
  },
  sources: {
    title: "Manuales corporativos (fuentes AU)",
    empty: "Aquí aparecerán los fragmentos de manual usados en la respuesta.",
    similarity: "similitud",
  },
  errors: {
    backendUnavailable: "Backend no disponible. Inténtalo de nuevo en unos instantes.",
    invalidRequest: "Pregunta no válida: revisa el texto (de 3 a 2000 caracteres).",
  },
  plants: { BR10: "Planta de Flotación · Carajás (PA)", BR20: "Planta de Lixiviación · Carajás (PA)" },
  storage: { "BR10/0002": "Depósito 002 · Reactivos", "BR20/0001": "Almacén central" },
};

const en: Dictionary = {
  locale: "en",
  languageName: "English",
  documentTitle: "Nodara BR-RAG · Operational Intelligence",
  languageNames: { es: "Spanish", en: "English", pt: "Portuguese" },
  header: {
    title: "Operational Intelligence",
    subtitle: "Australian corporate standards × SAP S/4HANA Brazil in real time · local AI + NVIDIA NIM",
    language: "Language",
  },
  status: {
    s4: "SAP S/4HANA",
    cdc: "Lakehouse CDC",
    manuals: "Manuals",
    llm: "AI engines",
    checking: "checking…",
    unavailable: "unavailable",
    s4Detail: (rows) => `${rows} material documents`,
    cdcDetail: (events, lagMs) => `${events} events · lag ${lagMs ?? "–"} ms`,
    manualsDetail: (embedded, total) => `${embedded}/${total} chunks indexed`,
    enginesDetail: (nim, ollama) => `NIM ${nim ? "✓" : "✗"} · Ollama ${ollama ? "✓" : "✗"}`,
  },
  engine: {
    label: "AI engine",
    nim: "NVIDIA NIM (Cloud)",
    ollama: "Ollama (Local)",
    nimUnavailable: "NVIDIA NIM not configured (NVIDIA_API_KEY)",
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
  },
  meta: {
    language: "Answer language",
    corrected: "adjusted by the language guard",
    engine: "Engine",
    model: "Model",
    fallback: "local contingency",
    search: "Semantic search query (English)",
    time: "Total time",
    seconds: (value) => `${value} s`,
    trace: "View trace in Langfuse",
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
    fx: "Live USD/BRL exchange rate",
    fxSource: (source, date) => `source: ${source} · ${date}`,
    liveBrl: "Exposure at today's rate",
    bookedBrl: "Booked (historical rates)",
    revaluation: "FX revaluation",
    fxUnavailable: "Live exchange rate unavailable",
  },
  sources: {
    title: "Corporate manuals (AU sources)",
    empty: "Manual excerpts used in the answer will appear here.",
    similarity: "similarity",
  },
  errors: {
    backendUnavailable: "Backend unavailable. Please try again in a moment.",
    invalidRequest: "Invalid question: check the text (3 to 2000 characters).",
  },
  plants: { BR10: "Flotation plant · Carajás (PA)", BR20: "Leaching plant · Carajás (PA)" },
  storage: { "BR10/0002": "Depot 002 · Reagents", "BR20/0001": "Central warehouse" },
};

export const DICTIONARIES: Record<Language, Dictionary> = { es, en, pt };
