-- One Thing Sync Database Schema
-- Run with: wrangler d1 execute one-thing-sync --file=schema.sql

CREATE TABLE IF NOT EXISTS sync_data (
  user_id TEXT NOT NULL,
  key TEXT NOT NULL,
  value TEXT NOT NULL,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (user_id, key)
);

-- Index for efficient pulls by timestamp
CREATE INDEX IF NOT EXISTS idx_sync_data_updated ON sync_data(user_id, updated_at);
