// UI regression test: language selector (ES / EN / PT) with server-side persistence, engine
// selector (NVIDIA NIM / Ollama) and answer footer metadata translated dynamically.
// Runs in the Playwright image against the live frontend:  make ui-test
const { chromium } = require("playwright-core");

const BASE_URL = process.env.BASE_URL ?? "http://frontend:3000";
const EXPECTED = {
  pt: { lang: "pt-BR", name: "Português", h1: "Inteligência Operacional", label: "Pergunta do operador", stock: "Estoque SAP (tempo real)", manuals: "Manuais",
        meta: ["Transações SAP do procedimento", "Idioma da resposta", "Consulta semântica (inglês)", "Tempo total", "Motor"] },
  es: { lang: "es", name: "Español", h1: "Inteligencia Operacional", label: "Pregunta del operador", stock: "Stock SAP (tiempo real)", manuals: "Manuales",
        meta: ["Transacciones SAP del procedimiento", "Idioma de la respuesta", "Consulta semántica (inglés)", "Tiempo total", "Motor"] },
  en: { lang: "en", name: "English", h1: "Operational Intelligence", label: "Operator question", stock: "SAP stock (real time)", manuals: "Manuals",
        meta: ["SAP transactions of the procedure", "Answer language", "Semantic search query (English)", "Total time", "Engine"] },
};
const ENGINES = { nim: "NVIDIA NIM (Cloud)", ollama: "Ollama (Local)" };

function mockAnswer(body) {
  const nim = body.engine === "nim";
  return {
    answer: "mock answer", language: String(body.language).toLowerCase(),
    language_check: { requested: "es", detected: "es", status: "ok" },
    grounding_check: { declared: ["XD01"], cited: ["XD01"], removed: [] },
    engine: body.engine, model_used: nim ? "nim/openai/gpt-oss-20b" : "ollama/llama3.1:8b", attempts: [],
    trace_id: "t-1", trace_url: "http://localhost:3001/project/nodara-br-rag/traces/t-1", question_en: "mock query",
    sources: [], sap: { materials: {}, stock: [], reservations: [], movements: [], suppliers: [], orders: [], counterparties: [], fx: null },
    models: { chat: "mock", embeddings: "mock" }, timings_ms: { translate_ms: 900, generate_ms: 4100 },
  };
}

async function expectLanguage(page, code) {
  const expected = EXPECTED[code];
  await page.waitForFunction((lang) => document.documentElement.lang === lang, expected.lang, { timeout: 10000 });
  const actual = {
    h1: await page.locator("h1").innerText(),
    label: await page.locator("label[for=question]").innerText(),
    stock: await page.getByTestId("stock-title").innerText(),
    manuals: await page.getByTestId("status-manuals").innerText(),
  };
  for (const [key, value] of Object.entries(actual)) {
    if (value.trim().toLowerCase() !== expected[key].toLowerCase()) {
      throw new Error(`[${code}] ${key}: expected "${expected[key]}", got "${value}"`);
    }
  }
  const pressed = await page.getByRole("button", { name: expected.name }).getAttribute("aria-pressed");
  if (pressed !== "true") throw new Error(`[${code}] language button not marked aria-pressed`);
  console.log(`  ✔ ${code.toUpperCase()}  <html lang="${expected.lang}">  ${expected.h1} · ${expected.label} · ${expected.stock} · ${expected.manuals}`);
}

async function expectFooter(page, code) {
  const footer = await page.getByTestId("answer-meta").innerText();
  const missing = EXPECTED[code].meta.filter((label) => !footer.includes(label));
  if (missing.length) throw new Error(`[${code}] footer misses ${JSON.stringify(missing)}: ${footer}`);
  return footer;
}

(async () => {
  const browser = await chromium.launch();
  try {
    const page = await (await browser.newContext()).newPage();
    await page.goto(BASE_URL, { waitUntil: "networkidle" });
    await expectLanguage(page, "pt"); // default for operators in Brazil
    for (const code of ["es", "en", "pt", "es"]) {
      await page.getByRole("button", { name: EXPECTED[code].name }).click();
      await expectLanguage(page, code);
    }
    await page.reload({ waitUntil: "networkidle" });
    await expectLanguage(page, "es");
    const html = await (await page.request.get(BASE_URL)).text();
    if (!html.includes('<html lang="es"')) throw new Error("language is not rendered on the server (cookie ignored)");
    console.log('  ✔ selection persisted across reload and rendered server-side (<html lang="es"> in the HTML, no flash)');

    // Engine + language routing: every question carries the selected engine and language.
    const sent = [];
    await page.route("**/api/ask", async (route) => {
      const body = JSON.parse(route.request().postData() ?? "{}");
      sent.push(body);
      await route.fulfill({ json: mockAnswer(body) });
    });
    for (const [code, engine] of [["es", "nim"], ["en", "ollama"], ["pt", "nim"]]) {
      await page.getByRole("button", { name: EXPECTED[code].name }).click();
      await page.getByRole("button", { name: ENGINES[engine] }).click();
      await page.locator("#question").fill(`routing check ${code}`);
      await page.locator("form button[type=submit]").click();
      await page.getByTestId("answer").waitFor();
      const body = sent.at(-1) ?? {};
      if (body.language !== code.toUpperCase() || body.engine !== engine || body.question !== `routing check ${code}`) {
        throw new Error(`[${code}] /api/ask body ${JSON.stringify(body)} does not carry language ${code.toUpperCase()} + engine ${engine}`);
      }
      const footer = await expectFooter(page, code);
      if (!footer.includes(ENGINES[engine])) throw new Error(`[${code}] footer does not show the engine ${ENGINES[engine]}`);
      console.log(`  ✔ ${code.toUpperCase()}  POST /api/ask → ${JSON.stringify(body)} · footer: ${footer.split("\n")[1]}`);
    }

    // The footer of an answer already on screen follows the selector (no hardcoded metadata).
    for (const code of ["en", "es", "pt"]) {
      await page.getByRole("button", { name: EXPECTED[code].name }).click();
      // The stock panel is hidden when the answer has no stock, so check <html lang> and the title only.
      await page.waitForFunction((lang) => document.documentElement.lang === lang, EXPECTED[code].lang);
      const title = await page.locator("h1").innerText();
      if (title !== EXPECTED[code].h1) throw new Error(`[${code}] title "${title}" not translated`);
      await expectFooter(page, code);
      console.log(`  ✔ ${code.toUpperCase()}  footer re-translated in place: ${EXPECTED[code].meta.slice(0, 3).join(" · ")}`);
    }
  } finally {
    await browser.close();
  }
})().catch((error) => {
  console.error(`  ✘ ${error.message}`);
  process.exit(1);
});
