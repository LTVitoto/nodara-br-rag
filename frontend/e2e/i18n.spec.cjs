// UI regression test: language selector (ES / EN / PT) + persistence across reloads.
// Runs in the Playwright image against the live frontend:  make ui-test
const { chromium } = require("playwright-core");

const BASE_URL = process.env.BASE_URL ?? "http://frontend:3000";
const EXPECTED = {
  pt: { lang: "pt-BR", name: "Português", h1: "Inteligência Operacional de Manutenção", label: "Pergunta do operador", stock: "Estoque SAP (tempo real)", manuals: "Manuais" },
  es: { lang: "es", name: "Español", h1: "Inteligencia Operacional de Mantenimiento", label: "Pregunta del operador", stock: "Stock SAP (tiempo real)", manuals: "Manuales" },
  en: { lang: "en", name: "English", h1: "Maintenance Operational Intelligence", label: "Operator question", stock: "SAP stock (real time)", manuals: "Manuals" },
};

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
  if (pressed !== "true") throw new Error(`[${code}] selector button not marked aria-pressed`);
  console.log(`  ✔ ${code.toUpperCase()}  <html lang="${expected.lang}">  ${expected.h1} · ${expected.label} · ${expected.stock} · ${expected.manuals}`);
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
    console.log("  ✔ selection persisted across reload (localStorage)");
  } finally {
    await browser.close();
  }
})().catch((error) => {
  console.error(`  ✘ ${error.message}`);
  process.exit(1);
});
