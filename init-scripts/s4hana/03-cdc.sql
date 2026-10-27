-- CDC contract for Debezium (pgoutput): full row images, explicit publication
-- (no autocreate → the CDC user needs no ownership), least-privilege grants.
-- Capturing a new table = add it here AND to cdc/connectors/s4hana-cdc.json (table.include.list).
ALTER TABLE sap.but000        REPLICA IDENTITY FULL;
ALTER TABLE sap.ukmbp_cms_sgm REPLICA IDENTITY FULL;
ALTER TABLE sap.dfkkbptaxnum  REPLICA IDENTITY FULL;
ALTER TABLE sap.matdoc        REPLICA IDENTITY FULL;
ALTER TABLE sap.acdoca        REPLICA IDENTITY FULL;
ALTER TABLE sap.qmel          REPLICA IDENTITY FULL;
ALTER TABLE sap.aufk          REPLICA IDENTITY FULL;
ALTER TABLE sap.resb          REPLICA IDENTITY FULL;

CREATE PUBLICATION nodara_s4_pub FOR TABLE
    sap.but000, sap.ukmbp_cms_sgm, sap.dfkkbptaxnum, sap.matdoc, sap.acdoca, sap.qmel, sap.aufk, sap.resb;

GRANT USAGE ON SCHEMA sap TO debezium, trino_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA sap TO debezium, trino_ro;
