"use client";

import { useI18n } from "../i18n";

export type Material = {
  matnr: string;
  oem_part_no: string;
  description_en: string;
  description_es: string;
  description_pt: string;
  base_uom: string;
};
export type StockRow = {
  matnr: string;
  werks: string;
  lgort: string;
  meins: string;
  stock_qty: number;
  avg_daily_issue: number | null;
  coverage_days: number | null;
};
export type ReservationRow = { rsnum: string; matnr: string; open_qty: number; meins: string; aufnr: string };
export type OrderRow = {
  aufnr: string;
  auart: string;
  ktext: string;
  kostl: string;
  equnr: string | null;
  status: "REL" | "CRTD";
  qmnum: string | null;
  qmart: string | null;
  qmtxt: string | null;
  priok: string | null;
  msaus: string | null;
};
export type CounterpartyRow = {
  partner: string;
  name: string;
  credit_limit: number;
  currency: string;
  xblocked: string;
  exposure: number;
  overdue: number;
  max_days_overdue: number | null;
  cnpj: string | null;
  inscricao_estadual: string | null;
};
export type SapData = {
  materials: Record<string, Material>;
  stock: StockRow[];
  reservations: ReservationRow[];
  orders: OrderRow[];
  counterparties: CounterpartyRow[];
};

const PANEL = "rounded-xl border border-slate-800 bg-slate-900/60 p-5";
const PANEL_TITLE = "text-sm font-semibold uppercase tracking-wide text-sky-400";

export function SapEvidence({ sap }: { sap?: SapData }) {
  const { language, t } = useI18n();
  const number = (value: number) => new Intl.NumberFormat(t.locale, { maximumFractionDigits: 1 }).format(value);
  const money = (value: number, currency: string) =>
    new Intl.NumberFormat(t.locale, { style: "currency", currency, maximumFractionDigits: 0 }).format(value);
  const describe = (matnr: string) => {
    const material = sap?.materials[matnr];
    if (!material) return "";
    return { en: material.description_en, es: material.description_es, pt: material.description_pt }[language];
  };

  return (
    <>
      {sap?.counterparties.length ? (
        <div className={PANEL}>
          <h2 data-testid="credit-title" className={PANEL_TITLE}>{t.credit.title}</h2>
          {sap.counterparties.map((c) => (
            <div key={c.partner} className="mt-3 text-xs">
              <div className="flex items-center justify-between gap-2">
                <span className="font-semibold">{c.name}</span>
                <span className={`rounded px-2 py-0.5 font-bold ${c.xblocked === "X" ? "bg-red-900/60 text-red-200" : "bg-emerald-900/60 text-emerald-200"}`}>
                  {c.xblocked === "X" ? t.credit.blocked : t.credit.active}
                </span>
              </div>
              <div className="text-slate-500">BP {c.partner}</div>
              <dl className="mt-2 grid grid-cols-2 gap-x-3 gap-y-1">
                <dt className="text-slate-400">{t.credit.limit}</dt>
                <dd className="text-right">{money(c.credit_limit, c.currency)}</dd>
                <dt className="text-slate-400">{t.credit.exposure}</dt>
                <dd className={`text-right font-semibold ${c.exposure > c.credit_limit ? "text-red-300" : ""}`}>
                  {money(c.exposure, c.currency)} ({number((c.exposure / c.credit_limit) * 100)}%)
                </dd>
                <dt className="text-slate-400">{t.credit.overdue}</dt>
                <dd className="text-right">
                  {money(c.overdue, c.currency)}
                  {c.max_days_overdue ? <div className="text-amber-300">{t.credit.days(c.max_days_overdue)}</div> : null}
                </dd>
                <dt className="text-slate-400">{t.credit.cnpj}</dt>
                <dd className="text-right font-mono">{c.cnpj ?? "—"}</dd>
                <dt className="text-slate-400">{t.credit.ie}</dt>
                <dd className="text-right font-mono">{c.inscricao_estadual ?? "—"}</dd>
              </dl>
            </div>
          ))}
        </div>
      ) : null}

      {sap?.orders.length ? (
        <div className={PANEL}>
          <h2 data-testid="orders-title" className={PANEL_TITLE}>{t.orders.title}</h2>
          {sap.orders.map((o) => (
            <div key={o.aufnr} className="mt-3 text-xs">
              <div className="flex items-center justify-between gap-2">
                <span className="font-semibold">{o.aufnr} · {o.auart}</span>
                <span className="rounded bg-sky-900/60 px-2 py-0.5 text-sky-200">{o.status === "REL" ? t.orders.released : t.orders.created}</span>
              </div>
              <div>{o.ktext}</div>
              <div className="text-slate-500">{t.orders.costCenter} {o.kostl} · {o.equnr}</div>
              {o.qmnum ? (
                <div className="mt-1 text-slate-400">
                  {t.orders.notification} {o.qmnum} ({o.qmart}, P{o.priok}{o.msaus === "X" ? `, ${t.orders.breakdown}` : ""}): {o.qmtxt}
                </div>
              ) : null}
              {sap.reservations
                .filter((r) => r.aufnr === o.aufnr)
                .map((r) => (
                  <div key={r.rsnum + r.matnr} className="mt-1 text-amber-300">{t.orders.reservation(number(r.open_qty), r.meins, r.matnr)}</div>
                ))}
            </div>
          ))}
        </div>
      ) : null}

      {!sap || sap.stock.length ? (
        <div className={PANEL}>
          <h2 data-testid="stock-title" className={PANEL_TITLE}>{t.stock.title}</h2>
          {sap?.stock.length ? (
            <table className="mt-3 w-full text-xs">
              <thead className="text-slate-400">
                <tr>
                  <th className="text-left">{t.stock.material}</th>
                  <th className="text-left">{t.stock.location}</th>
                  <th className="text-right">{t.stock.quantity}</th>
                </tr>
              </thead>
              <tbody>
                {sap.stock.map((row) => (
                  <tr key={`${row.matnr}-${row.werks}-${row.lgort}`} className="border-t border-slate-800 align-top">
                    <td className="py-1.5">
                      {row.matnr}
                      <div className="text-slate-500">{describe(row.matnr)}</div>
                    </td>
                    <td className="py-1.5">
                      {t.plants[row.werks] ?? row.werks}
                      <div className="text-slate-500">{t.storage[`${row.werks}/${row.lgort}`] ?? row.lgort}</div>
                    </td>
                    <td className={`py-1.5 text-right font-semibold ${row.stock_qty <= 0 ? "text-red-300" : ""}`}>
                      {number(row.stock_qty)} {row.meins}
                      {row.coverage_days !== null ? (
                        <div className="font-normal text-slate-500">{t.stock.coverage(number(row.coverage_days))}</div>
                      ) : null}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          ) : (
            <p className="mt-3 text-xs text-slate-500">{t.stock.empty}</p>
          )}
        </div>
      ) : null}
    </>
  );
}
