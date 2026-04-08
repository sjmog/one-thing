/**
 * One Thing Sync API
 * Cloudflare Worker with D1 database for cross-device sync
 */

interface Env {
  DB: D1Database;
}

interface SyncItem {
  key: string;
  value: string;
  updatedAt: number;
}

interface PushRequest {
  passphrase: string;
  data: SyncItem[];
}

interface PullRequest {
  passphrase: string;
  since: number;
}

interface FullRequest {
  passphrase: string;
}

// Hash passphrase to create user ID (using Web Crypto API)
async function hashPassphrase(passphrase: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(passphrase + 'one-thing-salt-v1');
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
}

// CORS headers for browser access
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      ...corsHeaders,
    },
  });
}

function errorResponse(message: string, status = 400): Response {
  return jsonResponse({ error: message }, status);
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    const url = new URL(request.url);
    const path = url.pathname;

    try {
      // POST /sync/push - Push changes to server
      if (path === '/sync/push' && request.method === 'POST') {
        const body = await request.json() as PushRequest;

        if (!body.passphrase || !body.data) {
          return errorResponse('Missing passphrase or data');
        }

        const userId = await hashPassphrase(body.passphrase);
        let updated = 0;

        for (const item of body.data) {
          // Upsert: only update if client timestamp is newer
          const existing = await env.DB.prepare(
            'SELECT updated_at FROM sync_data WHERE user_id = ? AND key = ?'
          ).bind(userId, item.key).first<{ updated_at: number }>();

          if (!existing || existing.updated_at < item.updatedAt) {
            await env.DB.prepare(
              `INSERT INTO sync_data (user_id, key, value, updated_at)
               VALUES (?, ?, ?, ?)
               ON CONFLICT(user_id, key) DO UPDATE SET
                 value = excluded.value,
                 updated_at = excluded.updated_at
               WHERE excluded.updated_at > sync_data.updated_at`
            ).bind(userId, item.key, item.value, item.updatedAt).run();
            updated++;
          }
        }

        return jsonResponse({ success: true, updated });
      }

      // POST /sync/pull - Pull changes since timestamp
      if (path === '/sync/pull' && request.method === 'POST') {
        const body = await request.json() as PullRequest;

        if (!body.passphrase) {
          return errorResponse('Missing passphrase');
        }

        const userId = await hashPassphrase(body.passphrase);
        const since = body.since || 0;

        const results = await env.DB.prepare(
          'SELECT key, value, updated_at FROM sync_data WHERE user_id = ? AND updated_at > ? ORDER BY updated_at ASC'
        ).bind(userId, since).all<{ key: string; value: string; updated_at: number }>();

        const data = results.results.map(row => ({
          key: row.key,
          value: row.value,
          updatedAt: row.updated_at,
        }));

        return jsonResponse({
          success: true,
          data,
          serverTime: Date.now()
        });
      }

      // POST /sync/full - Get all user data (initial sync)
      if (path === '/sync/full' && request.method === 'POST') {
        const body = await request.json() as FullRequest;

        if (!body.passphrase) {
          return errorResponse('Missing passphrase');
        }

        const userId = await hashPassphrase(body.passphrase);

        const results = await env.DB.prepare(
          'SELECT key, value, updated_at FROM sync_data WHERE user_id = ? ORDER BY updated_at ASC'
        ).bind(userId).all<{ key: string; value: string; updated_at: number }>();

        const data = results.results.map(row => ({
          key: row.key,
          value: row.value,
          updatedAt: row.updated_at,
        }));

        return jsonResponse({
          success: true,
          data,
          serverTime: Date.now()
        });
      }

      // Health check
      if (path === '/health' || path === '/') {
        return jsonResponse({ status: 'ok', service: 'one-thing-sync' });
      }

      return errorResponse('Not found', 404);
    } catch (error) {
      console.error('Error:', error);
      return errorResponse('Internal server error', 500);
    }
  },
};
