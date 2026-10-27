---
doc_id: AU-CMP-KYC-001
title: Global KYC & Counterparty Onboarding Standard
applies_to: All counterparties (customers, refiners, suppliers)
doc_type: compliance_standard
issuing_site: Group Compliance, Perth (AU)
revision: Rev 4 2026-02
language: en
classification: SYNTHETIC-SIMULATION
---

# Global KYC & Counterparty Onboarding Standard

> SYNTHETIC document for the Nodara BR-RAG simulation. Thresholds, forms and procedures are illustrative;
> do not use as legal or tax advice.

## 1. Scope and risk-based approach

This standard applies to every counterparty of the Group (customers including copper refiners and smelters, suppliers and logistics providers) in every country of operation. No credit exposure, delivery or payment may be executed before onboarding is approved. Each counterparty receives a risk rating (low, medium or high) based on jurisdiction, ownership structure, product and payment channel. Onboarding must be re-validated every 24 months and immediately after a trigger event: change of ownership, sanctions alert, request for a credit limit increase, or a credit block in SAP.

## 3. Tax documentation: Form W-8BEN

Before activation, collect the IRS withholding certificate from every non-US counterparty: Form W-8BEN for individuals and Form W-8BEN-E for legal entities. Validate the legal name, country of incorporation, foreign tax identification number (TIN), treaty claim and signature date against the incorporation documents. A form is valid until 31 December of the third year after signature; an expired, unsigned or inconsistent form blocks onboarding and re-validation, and payments subject to US withholding must then be withheld at 30 %. Store the form in the counterparty file and record its validity in the SAP business partner.

## 4. Anti-money laundering (AML) validation

Screen the counterparty, its directors and every ultimate beneficial owner holding 25 % or more against the UN, OFAC, EU and Australian (DFAT) sanctions lists, politically exposed persons (PEP) databases and adverse media. Red flags include payments from third parties, cash or cryptocurrency settlement, transit through high-risk jurisdictions and ownership that cannot be verified. Any unresolved hit stops the process; high-risk counterparties require enhanced due diligence approved by the Group Compliance Officer. Screening results are valid for 12 months.

## 6. Credit limits and blocked counterparties

Credit limits are approved by the Credit Committee according to the risk rating; limits above USD 5,000,000 require approval by the Board Credit Committee. When exposure (open receivables plus open orders) exceeds the approved limit, SAP credit management automatically blocks the counterparty for new sales orders and deliveries. To release the block, either collect the overdue receivables or obtain a temporary limit increase approved at the required level; in both cases KYC must be current (valid W-8BEN or W-8BEN-E and AML screening younger than 12 months). Document the decision in the SAP credit case and never bypass the block with manual deliveries.

## Annex BR. Brazil fiscal registration requirements

For counterparties in Brazil, the customer master record must contain the CNPJ (Cadastro Nacional da Pessoa Jurídica) of the establishment and its Inscrição Estadual (state tax registration, IE). Both fields are mandatory in SAP transaction XD01 (create customer) and the record cannot be saved without them; an IE recorded as ISENTO (exempt) requires a written justification from the tax department. Before creating or reactivating the customer, confirm that the CNPJ status is ATIVA at the Receita Federal and validate the IE in the state registry (SINTEGRA), because NF-e invoices cannot be issued against an invalid registration.
