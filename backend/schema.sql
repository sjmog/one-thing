-- One Thing Sync v2 Schema
-- Record-level sync with HLC timestamps, tombstones, server-assigned monotonic seq.
-- Run with: wrangler d1 execute one-thing-sync --file=schema.sql

DROP TABLE IF EXISTS sync_data;
DROP TABLE IF EXISTS records;
DROP TABLE IF EXISTS user_seq;

-- Per-user monotonic sequence counter, used for pull pagination.
CREATE TABLE user_seq (
  user_id TEXT PRIMARY KEY,
  next_seq INTEGER NOT NULL DEFAULT 1
);

-- One row per logical record. Conflict resolution is by (hlc_physical, hlc_logical, hlc_device)
-- lexicographic comparison. Deletes are tombstones (deleted = 1), not row removals, so stale
-- devices cannot resurrect them.
CREATE TABLE records (
  user_id TEXT NOT NULL,
  record_type TEXT NOT NULL,
  record_id TEXT NOT NULL,
  fields TEXT NOT NULL,         -- JSON blob of this record's fields
  deleted INTEGER NOT NULL DEFAULT 0,
  hlc_physical INTEGER NOT NULL,
  hlc_logical INTEGER NOT NULL,
  hlc_device TEXT NOT NULL,
  server_seq INTEGER NOT NULL,
  server_received_at INTEGER NOT NULL,
  PRIMARY KEY (user_id, record_type, record_id)
);

-- Pull pagination: fetch all records for a user with server_seq > cursor, in order.
CREATE INDEX idx_records_user_seq ON records(user_id, server_seq);
