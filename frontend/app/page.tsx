"use client";

import { FormEvent, useEffect, useState } from "react";

type Probe = { ok: boolean; error?: string } & Record<string, unknown>;
type Status = { knowledge_base: Probe; s4hana_live: Probe; lakehouse_cdc: Probe; llm: Probe };
type Source = {
  doc_id: string;
  title: string;
  equipment: string;
  section: string;
  similarity: number;
  excerpt: string;
  sap_materials: string[];
};
type StockRow = { matnr: string; werks: string; lgort: string; meins: string; stock_qty: number; last_movement: string };
type Material = { matnr: string; oem_part_no: string; description_pt: string; base_uom: string };
type AskResult = {
  answer: string;
  question_en: string;
  sources: Source[];
  sap: { materials: Record<string, Material>; stock: StockRow[] };
  models: Record<string, string>;
  timings_ms: Record<string, number>;
};

const EXAMPLES = [
  "Como trocar o filtro hidráulico de retorno do caminhão HT-400? Temos o filtro em estoque?",
  "Quais são os critérios de descarte do cabo de elevação da escavadeira ES-4100?",
  "Qual o procedimento para trocar o selo mecânico da bomba de polpa SP-250?",
  "Qual a pressão de calibragem dos pneus do HT-400 e quantos pneus temos disponíveis?",
];
const PLANTS: Record<string, string> = { BR10: "Carajás (PA)", BR20: "Itabira (MG)" };
const STORAGE: Record<string, string> = { "0001": "Almoxarifado central", "0002": "Oficina" };

function Pill({ label, probe, detail }: { label: string; probe?: Probe; detail: (p: Probe) => string }) {
  const tone = !probe ? "border-slate-700 text-slate-400" : probe.ok ? "border-emerald-700 text-emerald-300" : "border-amber-700 text-amber-300";
  return (
    <div className={`rounded-lg border px-3 py-2 text-xs ${tone}`}>
      <div className="font-semibold uppercase tracking-wide">{label}</div>
      <div className="mt-0.5 text-slate-300">{!probe ? "verificando…" : probe.ok ? detail(probe) : "indisponível"}</div>
    </div>
  );
}

export default function Home() {
  const [question, setQuestion] = useState(EXAMPLES[0]);
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
      <header className="flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
        <div>
          <p className="text-xs font-semibold uppercase tracking-[0.2em] text-sky-400">Nodara BR-RAG</p>
          <h1 className="text-2xl font-bold">Inteligência Operacional de Manutenção</h1>
          <p className="text-sm text-slate-400">Manuais técnicos da Austrália × SAP S/4HANA Brasil em tempo real · IA local air-gapped</p>
        </div>
        <div className="grid grid-cols-2 gap-2 md:grid-cols-4">
          <Pill label="S/4HANA" probe={status?.s4hana_live} detail={(p) => `${p.matdoc_rows} docs de material`} />
          <Pill label="Lakehouse CDC" probe={status?.lakehouse_cdc} detail={(p) => `${p.events} eventos · lag ${p.last_lag_ms ?? "–"} ms`} />
          <Pill label="Manuais" probe={status?.knowledge_base} detail={(p) => `${p.embedded}/${p.chunks} trechos indexados`} />
          <Pill
            label="LLM local"
            probe={status?.llm}
            detail={(p) => (p.chat_ready && p.embed_ready ? String(p.chat_model) : "modelos pendentes")}
          />
        </div>
      </header>

      <form onSubmit={ask} className="mt-8 rounded-xl border border-slate-800 bg-slate-900/60 p-4">
        <label htmlFor="question" className="text-sm font-medium text-slate-300">Pergunta do operador</label>
        <textarea
          id="question"
          value={question}
          onChange={(e) => setQuestion(e.target.value)}
          rows={3}
          className="mt-2 w-full rounded-lg border border-slate-700 bg-slate-950 p-3 text-sm outline-none focus:border-sky-500"
        />
        <div className="mt-3 flex flex-wrap items-center gap-2">
          {EXAMPLES.map((example) => (
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
            {loading ? "Consultando manuais e SAP…" : "Perguntar"}
          </button>
        </div>
      </form>

      {error && <div className="mt-6 rounded-lg border border-amber-700 bg-amber-950/40 p-4 text-sm text-amber-200">{error}</div>}

      {result && (
        <section className="mt-6 grid gap-6 lg:grid-cols-3">
          <article className="rounded-xl border border-slate-800 bg-slate-900/60 p-5 lg:col-span-2">
            <h2 className="text-sm font-semibold uppercase tracking-wide text-sky-400">Resposta</h2>
            <div className="mt-3 whitespace-pre-wrap text-sm leading-relaxed">{result.answer}</div>
            <p className="mt-4 text-xs text-slate-500">
              Busca (EN): “{result.question_en}” · {result.models.chat} · {Object.values(result.timings_ms).reduce((a, b) => a + b, 0)} ms
            </p>
          </article>

          <aside className="space-y-6">
            <div className="rounded-xl border border-slate-800 bg-slate-900/60 p-5">
              <h2 className="text-sm font-semibold uppercase tracking-wide text-sky-400">Estoque SAP (tempo real)</h2>
              <table className="mt-3 w-full text-xs">
                <thead className="text-slate-400">
                  <tr><th className="text-left">Material</th><th className="text-left">Local</th><th className="text-right">Qtd.</th></tr>
                </thead>
                <tbody>
                  {result.sap.stock.map((row) => (
                    <tr key={`${row.matnr}-${row.werks}-${row.lgort}`} className="border-t border-slate-800">
                      <td className="py-1.5">
                        {row.matnr}
                        <div className="text-slate-500">{result.sap.materials[row.matnr]?.description_pt}</div>
                      </td>
                      <td>{PLANTS[row.werks] ?? row.werks} · {STORAGE[row.lgort] ?? row.lgort}</td>
                      <td className={`text-right font-semibold ${row.stock_qty <= 1 ? "text-amber-300" : ""}`}>
                        {row.stock_qty} {row.meins}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            <div className="rounded-xl border border-slate-800 bg-slate-900/60 p-5">
              <h2 className="text-sm font-semibold uppercase tracking-wide text-sky-400">Fontes (manuais AU)</h2>
              <ul className="mt-3 space-y-3 text-xs">
                {result.sources.map((source) => (
                  <li key={`${source.doc_id}-${source.section}`}>
                    <div className="font-semibold">{source.doc_id} §{source.section}</div>
                    <div className="text-slate-500">{source.title} · similaridade {source.similarity.toFixed(2)}</div>
                  </li>
                ))}
              </ul>
            </div>
          </aside>
        </section>
      )}
    </main>
  );
}
