import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Nodara BR-RAG · Inteligência Operacional",
  description: "Manuais técnicos (AU) × SAP S/4HANA (BR) em tempo real, com IA local air-gapped.",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="pt-BR">
      <body className="min-h-screen bg-slate-950 text-slate-100 antialiased">{children}</body>
    </html>
  );
}
