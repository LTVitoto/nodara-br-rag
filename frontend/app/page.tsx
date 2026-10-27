"use client";

import { FormEvent, useEffect, useState } from "react";

import { Header, type Status } from "./components/Header";
import { SapEvidence, type SapData } from "./components/SapEvidence";
import { useI18n } from "./i18n";

type Source = {
  doc_id: string;
  title: string;
  applies_to: string;
  source_uri: string;
  section: string;
  similarity: number;
  excerpt: string;
};
type AskResult = {
  answer: string;
  language: string;
  language_check: { requested: string; detected: string | null; status: string };
  grounding_check: { declared: string[]; cited: string[]; removed: string[] };
  question_en: string;
  sources: Source[];
  sap: SapData;
  models: Record<string, string>;
  timings_ms: Record<string, number>;
};

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
      // Language routing: the backend answers exactly in the language selected in the UI.
      const response = await fetch("/api/ask", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ question, language: language.toUpperCase() }),
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
              key={example.label}
              type="button"
              title={example.question}
              onClick={() => setQuestion(example.question)}
              className="rounded-full border border-slate-700 px-3 py-1 text-xs text-slate-300 hover:border-sky-500"
            >
              {example.label}
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
          {result ? (
            <>
              <div data-testid="answer" className="mt-3 whitespace-pre-wrap text-sm leading-relaxed">{result.answer}</div>
              {result.grounding_check?.declared.length ? (
                <div className="mt-4 flex flex-wrap items-center gap-2 text-xs">
                  <span className="text-slate-400">{t.answer.transactions}:</span>
                  {result.grounding_check.declared.map((code) => (
                    <span
                      key={code}
                      className={`rounded px-2 py-0.5 font-mono ${result.grounding_check.cited.includes(code) ? "bg-emerald-900/50 text-emerald-200" : "border border-emerald-800 text-emerald-300"}`}
                    >
                      {result.grounding_check.cited.includes(code) ? "✓ " : ""}
                      {code}
                    </span>
                  ))}
                </div>
              ) : null}
              <p className="mt-4 text-xs text-slate-500">
                {t.answer.language}: {result.language.toUpperCase()}
                {result.language_check.status === "corrected" ? ` (${t.answer.corrected})` : ""} · {t.answer.search}: “
                {result.question_en}” · {result.models.chat} · {Object.values(result.timings_ms).reduce((a, b) => a + b, 0)} ms
              </p>
            </>
          ) : (
            <p className="mt-3 text-sm text-slate-500">{t.answer.empty}</p>
          )}
        </article>

        <aside className="space-y-6">
          <SapEvidence sap={result?.sap} />

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
