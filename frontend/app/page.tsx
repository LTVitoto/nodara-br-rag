"use client";

import { FormEvent, useEffect, useState } from "react";

import { Header, type Status } from "./components/Header";
import { useI18n } from "./i18n";

type Source = {
  doc_id: string;
  title: string;
  equipment: string;
  source_uri: string;
  section: string;
  similarity: number;
  excerpt: string;
  sap_materials: string[];
};
type StockRow = { matnr: string; werks: string; lgort: string; meins: string; stock_qty: number; last_movement: string };
type Material = { matnr: string; oem_part_no: string; description_en: string; description_pt: string; base_uom: string };
type AskResult = {
  answer: string;
  question_en: string;
  sources: Source[];
  sap: { materials: Record<string, Material>; stock: StockRow[] };
  models: Record<string, string>;
  timings_ms: Record<string, number>;
};

const PLANTS: Record<string, string> = { BR10: "Carajás (PA)", BR20: "Itabira (MG)" };
const PANEL = "rounded-xl border border-slate-800 bg-slate-900/60 p-5";
const PANEL_TITLE = "text-sm font-semibold uppercase tracking-wide text-sky-400";

export default function Home() {
  const { language, t } = useI18n();
  const [question, setQuestion] = useState("");
  const [status, setStatus] = useState<Status>();
  const [result, setResult] = useState<AskResult>();
  const [error, setError] = useState<string>();
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    const load = () =>
      fetch("/api/status", { cache: "no-store" })
        .then((r) => r.json())
        .then(setStatus)
        .catch(() => setStatus(undefined));
    load();
    const id = setInterval(load, 15000);
    return () => clearInterval(id);
  }, []);

  async function ask(event: FormEvent) {
    event.preventDefault();
    setLoading(true);
    setError(undefined);
    setResult(undefined);
    try {
      const response = await fetch("/api/ask", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ question }),
      });
      const body = await response.json();
      if (!response.ok) throw new Error(typeof body.detail === "string" ? body.detail : JSON.stringify(body.detail));
      setResult(body);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="mx-auto max-w-6xl px-4 py-8">
      <Header status={status} />

      <form onSubmit={ask} className="mt-8 rounded-xl border border-slate-800 bg-slate-900/60 p-4">
        <label htmlFor="question" className="text-sm font-medium text-slate-300">{t.form.label}</label>
        <textarea
          id="question"
          value={question}
          onChange={(e) => setQuestion(e.target.value)}
          placeholder={t.form.placeholder}
          rows={3}
          className="mt-2 w-full rounded-lg border border-slate-700 bg-slate-950 p-3 text-sm outline-none placeholder:text-slate-600 focus:border-sky-500"
        />
        <div className="mt-3 flex flex-wrap items-center gap-2">
          {t.form.examples.map((example) => (
            <button
              key={example}
              type="button"
              onClick={() => setQuestion(example)}
              className="rounded-full border border-slate-700 px-3 py-1 text-xs text-slate-300 hover:border-sky-500"
            >
              {example.slice(0, 48)}…
            </button>
          ))}
          <button
            type="submit"
            disabled={loading || question.trim().length < 3}
            className="ml-auto rounded-lg bg-sky-600 px-5 py-2 text-sm font-semibold hover:bg-sky-500 disabled:opacity-50"
          >
            {loading ? t.form.loading : t.form.submit}
          </button>
        </div>
      </form>

      {error && <div className="mt-6 rounded-lg border border-amber-700 bg-amber-950/40 p-4 text-sm text-amber-200">{error}</div>}

      <section className="mt-6 grid gap-6 lg:grid-cols-3">
        <article className={`${PANEL} lg:col-span-2`}>
          <h2 className={PANEL_TITLE}>{t.answer.title}</h2>
          {t.answer.languageNote && <p className="mt-1 text-xs text-slate-500">{t.answer.languageNote}</p>}
          {result ? (
            <>
              <div className="mt-3 whitespace-pre-wrap text-sm leading-relaxed">{result.answer}</div>
              <p className="mt-4 text-xs text-slate-500">
                {t.answer.search}: “{result.question_en}” · {result.models.chat} ·{" "}
                {Object.values(result.timings_ms).reduce((a, b) => a + b, 0)} ms
              </p>
            </>
          ) : (
            <p className="mt-3 text-sm text-slate-500">{t.answer.empty}</p>
          )}
        </article>

        <aside className="space-y-6">
          <div className={PANEL}>
            <h2 data-testid="stock-title" className={PANEL_TITLE}>{t.stock.title}</h2>
            {result?.sap.stock.length ? (
              <table className="mt-3 w-full text-xs">
                <thead className="text-slate-400">
                  <tr>
                    <th className="text-left">{t.stock.material}</th>
                    <th className="text-left">{t.stock.location}</th>
                    <th className="text-right">{t.stock.quantity}</th>
                  </tr>
                </thead>
                <tbody>
                  {result.sap.stock.map((row) => (
                    <tr key={`${row.matnr}-${row.werks}-${row.lgort}`} className="border-t border-slate-800">
                      <td className="py-1.5">
                        {row.matnr}
                        <div className="text-slate-500">
                          {language === "en"
                            ? result.sap.materials[row.matnr]?.description_en
                            : result.sap.materials[row.matnr]?.description_pt}
                        </div>
                      </td>
                      <td>
                        {PLANTS[row.werks] ?? row.werks} · {t.storage[row.lgort] ?? row.lgort}
                      </td>
                      <td className={`text-right font-semibold ${row.stock_qty <= 1 ? "text-amber-300" : ""}`}>
                        {row.stock_qty} {row.meins}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            ) : (
              <p className="mt-3 text-xs text-slate-500">{t.stock.empty}</p>
            )}
          </div>

          <div className={PANEL}>
            <h2 data-testid="sources-title" className={PANEL_TITLE}>{t.sources.title}</h2>
            {result?.sources.length ? (
              <ul className="mt-3 space-y-3 text-xs">
                {result.sources.map((source) => (
                  <li key={`${source.doc_id}-${source.section}`}>
                    <div className="font-semibold">{source.doc_id} §{source.section}</div>
                    <div className="text-slate-500">
                      {source.title} · {t.sources.similarity} {source.similarity.toFixed(2)}
                    </div>
                    <div className="font-mono text-[11px] text-slate-600">{source.source_uri}</div>
                  </li>
                ))}
              </ul>
            ) : (
              <p className="mt-3 text-xs text-slate-500">{t.sources.empty}</p>
            )}
          </div>
        </aside>
      </section>
    </main>
  );
}
