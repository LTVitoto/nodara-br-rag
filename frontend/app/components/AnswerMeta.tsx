"use client";

import { useI18n } from "../i18n";

export type AnswerMetadata = {
  language: string;
  language_check: { status: string };
  grounding_check: { declared: string[]; cited: string[] };
  engine: "nim" | "ollama";
  model_used: string;
  question_en: string;
  trace_url: string | null;
  timings_ms: Record<string, number>;
};

// Every label and formatted value comes from the language context (ES / EN / PT).
export function AnswerMeta({ result }: { result: AnswerMetadata }) {
  const { t } = useI18n();
  const seconds = Object.values(result.timings_ms).reduce((total, ms) => total + ms, 0) / 1000;
  const usedLocalContingency = result.engine === "nim" && result.model_used.startsWith("ollama/");
  return (
    <div data-testid="answer-meta" className="mt-4 space-y-1.5 border-t border-slate-800 pt-3 text-xs text-slate-500">
      {result.grounding_check.declared.length ? (
        <div className="flex flex-wrap items-center gap-2">
          <span className="text-slate-400">{t.meta.transactions}:</span>
          {result.grounding_check.declared.map((code) => {
            const cited = result.grounding_check.cited.includes(code);
            return (
              <span
                key={code}
                className={`rounded px-2 py-0.5 font-mono ${cited ? "bg-emerald-900/50 text-emerald-200" : "border border-emerald-800 text-emerald-300"}`}
              >
                {cited ? "✓ " : ""}
                {code}
              </span>
            );
          })}
        </div>
      ) : null}
      <div>
        {t.meta.language}: {t.languageNames[result.language] ?? result.language}
        {result.language_check.status === "corrected" ? ` (${t.meta.corrected})` : ""}
      </div>
      <div>
        {t.meta.engine}: {result.engine === "nim" ? t.engine.nim : t.engine.ollama} · {t.meta.model}:{" "}
        <span className="font-mono">{result.model_used.replace(/^nim\//, "")}</span>
        {usedLocalContingency ? <span className="text-amber-300"> ({t.meta.fallback})</span> : null}
      </div>
      <div>
        {t.meta.search}: “{result.question_en}”
      </div>
      <div>
        {t.meta.time}: {t.meta.seconds(new Intl.NumberFormat(t.locale, { maximumFractionDigits: 1 }).format(seconds))}
        {result.trace_url ? (
          <>
            {" · "}
            <a href={result.trace_url} target="_blank" rel="noreferrer" className="text-sky-400 hover:underline">
              {t.meta.trace} ↗
            </a>
          </>
        ) : null}
      </div>
    </div>
  );
}
