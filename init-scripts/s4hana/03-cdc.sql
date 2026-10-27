-- CDC contract for Debezium (pgoutput): full row images, explicit publication
-- (no autocreate → the CDC user needs no ownership), least-privilege grants.
ALTER TABLE sap.but000 REPLICA IDENTITY FULL;
ALTER TABLE sap.matdoc REPLICA IDENTITY FULL;
ALTER TABLE sap.acdoca REPLICA IDENTITY FULL;

CREATE PUBLICATION nodara_s4_pub FOR TABLE sap.but000, sap.matdoc, sap.acdoca;

GRANT USAGE ON SCHEMA sap TO debezium, trino_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA sap TO debezium, trino_ro;
