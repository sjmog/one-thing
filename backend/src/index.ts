/**
 * One Thing Sync API — v2
 *
 * Record-level sync with HLC (Hybrid Logical Clock) conflict resolution. Each record is
 * identified by (user_id, record_type, record_id). Writes are accepted iff the incoming
 * HLC tuple (physical, logical, device) is strictly greater than the stored one. Deletes
 * are tombstones so stale devices cannot resurrect. The server assigns a monotonic
 * per-user `server_seq` on every accepted write; clients paginate pulls by that cursor
 * so clock skew cannot hide updates.
 */

interface Env {
  DB: D1Database;
}

interface Hlc {
  physical: number;
  logical: number;
  device: string;
}

interface PushOp {
  opId: string;
  recordType: string;
  recordId: string;
  fields: unknown;          // stored as JSON string server-side
  deleted?: boolean;
  hlc: Hlc;
}

interface PushRequest {
  passphrase: string;
  deviceId: string;
  ops: PushOp[];
}

interface PullRequest {
  passphrase: string;
  deviceId: string;
  sinceSeq: number;
}

interface StoredRecord {
  record_type: string;
  record_id: string;
  fields: string;
  deleted: number;
  hlc_physical: number;
  hlc_logical: number;
  hlc_device: string;
  server_seq: number;
}

async function hashPassphrase(passphrase: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(passphrase + 'one-thing-salt-v1');
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  return Array.from(new Uint8Array(hashBuffer))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders },
  });
}

function err(message: string, status = 400): Response {
  return json({ error: message }, status);
}

function serializeRecord(row: StoredRecord) {
  return {
    recordType: row.record_type,
    recordId: row.record_id,
    fields: JSON.parse(row.fields),
    deleted: row.deleted === 1,
    hlc: {
      physical: row.hlc_physical,
      logical: row.hlc_logical,
      device: row.hlc_device,
    },
    serverSeq: row.server_seq,
  };
}

async function handlePush(body: PushRequest, env: Env): Promise<Response> {
  if (!body.passphrase || !body.deviceId || !Array.isArray(body.ops)) {
    return err('Missing passphrase, deviceId, or ops');
  }

  const userId = await hashPassphrase(body.passphrase);

  // Ensure the user's seq row exists before we try to increment it.
  await env.DB.prepare(
    'INSERT OR IGNORE INTO user_seq (user_id, next_seq) VALUES (?1, 1)'
  ).bind(userId).run();

  const accepted: Array<{ opId: string; serverSeq: number }> = [];
  const rejected: Array<{ opId: string; current: ReturnType<typeof serializeRecord> | null }> = [];

  for (const op of body.ops) {
    if (!op.opId || !op.recordType || !op.recordId || !op.hlc) {
      rejected.push({ opId: op.opId ?? '', current: null });
      continue;
    }

    // Allocate the next server_seq atomically. If the upsert is rejected, the seq is
    // skipped — pull cursors don't care about gaps.
    const seqRow = await env.DB.prepare(
      'UPDATE user_seq SET next_seq = next_seq + 1 WHERE user_id = ?1 RETURNING next_seq - 1 AS seq'
    ).bind(userId).first<{ seq: number }>();
    if (!seqRow) {
      rejected.push({ opId: op.opId, current: null });
      continue;
    }
    const newSeq = seqRow.seq;

    const fieldsJson = JSON.stringify(op.fields ?? {});
    const deletedInt = op.deleted ? 1 : 0;
    const receivedAt = Date.now();

    // Upsert only if the incoming HLC tuple is strictly greater than the stored one.
    // RETURNING returns the row iff the write actually applied.
    const applied = await env.DB.prepare(`
      INSERT INTO records (
        user_id, record_type, record_id, fields, deleted,
        hlc_physical, hlc_logical, hlc_device, server_seq, server_received_at
      ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)
      ON CONFLICT (user_id, record_type, record_id) DO UPDATE SET
        fields = excluded.fields,
        deleted = excluded.deleted,
        hlc_physical = excluded.hlc_physical,
        hlc_logical = excluded.hlc_logical,
        hlc_device = excluded.hlc_device,
        server_seq = excluded.server_seq,
        server_received_at = excluded.server_received_at
      WHERE (excluded.hlc_physical, excluded.hlc_logical, excluded.hlc_device) >
            (records.hlc_physical, records.hlc_logical, records.hlc_device)
      RETURNING server_seq
    `).bind(
      userId, op.recordType, op.recordId, fieldsJson, deletedInt,
      op.hlc.physical, op.hlc.logical, op.hlc.device, newSeq, receivedAt
    ).first<{ server_seq: number }>();

    if (applied) {
      accepted.push({ opId: op.opId, serverSeq: applied.server_seq });
    } else {
      // Fetch the winning record so the client can reconcile.
      const current = await env.DB.prepare(
        `SELECT record_type, record_id, fields, deleted,
                hlc_physical, hlc_logical, hlc_device, server_seq
         FROM records WHERE user_id = ?1 AND record_type = ?2 AND record_id = ?3`
      ).bind(userId, op.recordType, op.recordId).first<StoredRecord>();
      rejected.push({
        opId: op.opId,
        current: current ? serializeRecord(current) : null,
      });
    }
  }

  return json({ accepted, rejected });
}

async function handlePull(body: PullRequest, env: Env): Promise<Response> {
  if (!body.passphrase || !body.deviceId) {
    return err('Missing passphrase or deviceId');
  }

  const userId = await hashPassphrase(body.passphrase);
  const sinceSeq = Number.isFinite(body.sinceSeq) ? body.sinceSeq : 0;

  const result = await env.DB.prepare(
    `SELECT record_type, record_id, fields, deleted,
            hlc_physical, hlc_logical, hlc_device, server_seq
     FROM records
     WHERE user_id = ?1 AND server_seq > ?2
     ORDER BY server_seq ASC`
  ).bind(userId, sinceSeq).all<StoredRecord>();

  const records = (result.results ?? []).map(serializeRecord);
  const serverSeq = records.length > 0
    ? records[records.length - 1].serverSeq
    : sinceSeq;

  return json({ records, serverSeq });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    const url = new URL(request.url);
    const path = url.pathname;

    try {
      if (path === '/v2/push' && request.method === 'POST') {
        return await handlePush(await request.json() as PushRequest, env);
      }
      if (path === '/v2/pull' && request.method === 'POST') {
        return await handlePull(await request.json() as PullRequest, env);
      }
      if (path === '/health' || path === '/') {
        return json({ status: 'ok', service: 'one-thing-sync', version: 'v2' });
      }
      return err('Not found', 404);
    } catch (e) {
      console.error('Error:', e);
      return err('Internal server error', 500);
    }
  },
};
