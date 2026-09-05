// Node 24: node --test supabase/functions/admin-moderation/index.test.mjs
// Executes the real handler with an isolated Supabase client; no network/secrets.
import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import { test } from 'node:test';
import assert from 'node:assert/strict';

const source = stripTypeScriptTypes((await readFile(new URL('./index.ts', import.meta.url), 'utf8'))
  .replace(/^import .*createClient.*;\r?\n/, ''));

function fixture({ admin = true, banned = false, rpcError = null } = {}) {
  const calls = [];
  const client = {
    auth: {
      getUser: async () => ({ data: { user: { id: 'admin-id' } }, error: null }),
      admin: { updateUserById: async (...args) => { calls.push(['auth', ...args]); return { data: {}, error: null }; } },
    },
    from(table) {
      const query = {
        select() { return query; }, eq() { return query; },
        or(value) { calls.push(['filter', value]); return query; },
        maybeSingle: async () => ({ data: table === 'admin_users' ? (admin ? { user_id: 'admin-id' } : null) : (banned ? { user_id: 'admin-id' } : null), error: null }),
      };
      return query;
    },
    rpc: async (...args) => { calls.push(['rpc', ...args]); return { data: [], error: rpcError }; },
  };
  let handler;
  const runtime = { env: { get: () => 'test-only' }, serve: (fn) => { handler = fn; } };
  new Function('createClient', 'Deno', source)(() => client, runtime);
  const request = (body, authenticated = true) => handler(new Request('https://test.local/admin-moderation', {
    method: 'POST', headers: { 'content-type': 'application/json', ...(authenticated ? { Authorization: 'Bearer test-token' } : {}) }, body: JSON.stringify(body),
  }));
  return { calls, request };
}

test('anonymous and ordinary callers cannot reach moderation RPCs', async () => {
  const anonymous = fixture();
  assert.equal((await anonymous.request({ action: 'decision' }, false)).status, 401);
  assert.equal(anonymous.calls.length, 0);
  const normal = fixture({ admin: false });
  assert.equal((await normal.request({ action: 'decision' })).status, 403);
  assert.equal(normal.calls.filter(c => c[0] === 'rpc').length, 0);
});
test('restricted admins are denied and expiry is included in access checks', async () => {
  const f = fixture({ banned: true });
  assert.equal((await f.request({ action: 'reports' })).status, 403);
  assert.match(f.calls[0][1], /^expires_at.is.null,expires_at.gt./);
});
test('report searches send every filter to the server-side search', async () => {
  const f = fixture();
  const response = await f.request({ action: 'reports', search: 'Alex', status: 'reviewing', category: 'harassment', since: '2026-09-01', oldest: true, page: 2 });
  assert.equal(response.status, 200);
  assert.deepEqual(f.calls.find(c => c[0] === 'rpc'), ['rpc', 'admin_search_reports', {
    p_search: 'Alex', p_status: 'reviewing', p_category: 'harassment', p_since: '2026-09-01', p_oldest: true, p_page: 2,
  }]);
});
test('case suspension forwards one atomic decision without separate account writes', async () => {
  const f = fixture();
  const target = '00000000-0000-0000-0000-000000000001';
  const response = await f.request({ action: 'decision', targetId: target, decision: 'suspend', reason: 'Reviewed', reportId: 'case', days: 7 });
  assert.equal(response.status, 200);
  assert.deepEqual(f.calls.find(c => c[0] === 'rpc'), ['rpc', 'admin_apply_decision', {
    p_actor_id: 'admin-id', p_target_id: target, p_action: 'suspend', p_reason: 'Reviewed', p_report_id: 'case', p_days: 7,
  }]);
  assert.equal(f.calls.filter(c => c[0] === 'auth').length, 0);
});
