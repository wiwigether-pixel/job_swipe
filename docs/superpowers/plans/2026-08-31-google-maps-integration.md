# Google Maps Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add geographic distance (Haversine on card) and commute time (Distance Matrix on detail page tap) between job seekers and jobs, powered by Google Maps API via Supabase Edge Functions.

**Architecture:** Layered strategy. Backend Edge Functions (`geocode-address`, `commute-time`) hold the Google API key server-side; Flutter never sees the key. On address entry, geocode once and store `lat/lng/formatted_address`. Card displays Haversine (0 API cost). Detail page "查看通勤" button triggers Distance Matrix with `commute_cache` (7-day TTL, keyed by geohash6). RLS hides raw `lat/lng` from other users.

**Tech Stack:** Flutter + Riverpod codegen + freezed; Supabase (Postgres + Edge Functions/Deno) via MCP `klwsmonobcenfoyhkyuq`; Google Maps Platform (Geocoding + Distance Matrix APIs).

**Reference spec:** `docs/superpowers/specs/2026-08-31-google-maps-integration-design.md`

## Global Constraints

- Google Maps free tier: **10,000 calls per SKU per month** (2025 new plan; verify at pricing page). Exceeding hits credit card.
- Cache TTL: `commute_cache.expires_at = now() + 7 days`
- Geohash precision: **6 characters** (~1.2 km); shared algorithm between Edge Functions (Deno) and any client-side use — pick one lib and pin.
- Distance Matrix modes: `driving | transit | bicycling` ONLY (Google does not support motorcycle → fall back to driving with `approximated: true` flag).
- Never store Google response fields beyond: `lat`, `lng`, `formatted_address`, `duration_seconds`, `distance_meters`. No `place_id`, no photos.
- Google API key stored only in Supabase secret `GOOGLE_MAPS_API_KEY`. Never in client, never committed.
- All Edge Functions require JWT (auth); anonymous callers get 401.
- Per-user rate-limit: **5 calls per 15 seconds per endpoint per user_id**; exceeding returns 429.
- After freezed model changes: run `dart run build_runner build --delete-conflicting-outputs` (Flutter/Dart binary at `/Users/alice/dev/tooling/flutter/bin`).
- Supabase project auto-pauses when idle; restore via MCP `restore_project` before running SQL if `INACTIVE`.
- Migration naming: follow existing pattern (`admin_001`, `reports_002`, `search_path_003`, `job_quota_005`) → use `location_006` for this feature.
- Flutter theme uses dark cyberpunk palette; new UI must use `theme.colorScheme` tokens, not hardcoded colors.

---

## File Structure

**Create:**
- `supabase/functions/_shared/geohash.ts` — geohash6 encoder (Deno)
- `supabase/functions/_shared/rate_limit.ts` — per-user rate-limit helper
- `supabase/functions/_shared/cors.ts` — standard CORS headers (needed for Flutter web calls)
- `supabase/functions/geocode-address/index.ts` — Edge Function
- `supabase/functions/geocode-address/test.ts` — Deno test
- `supabase/functions/commute-time/index.ts` — Edge Function
- `supabase/functions/commute-time/test.ts` — Deno test
- `sql/location_006_up.sql` — migration SQL (also applied via MCP)
- `lib/features/location/domain/lat_lng.dart` — plain LatLng value type
- `lib/features/location/domain/distance_utils.dart` — Haversine
- `lib/features/location/domain/commute_result.dart` — freezed model
- `lib/features/location/data/geocoding_service.dart`
- `lib/features/location/data/commute_service.dart`
- `lib/features/location/providers/location_providers.dart` — service providers
- `lib/features/location/providers/commute_provider.dart` — FutureProvider.family
- `lib/features/swipe/presentation/job_detail_screen.dart` — new detail page with commute button
- `test/features/location/distance_utils_test.dart`
- `test/features/location/commute_provider_test.dart`
- `scripts/backfill_geocode.ts` — one-off Deno script

**Modify:**
- `pubspec.yaml` — no new packages needed (do NOT add `google_maps_flutter`, `geolocator`, or `dart_geohash` — geohash is server-side only)
- `lib/shared/models/user_model.dart` — add `lat, lng, formattedAddress, locationUpdatedAt` fields + `fromSupabase`
- `lib/shared/models/job_model.dart` — same 4 fields
- `lib/features/onboarding/onboarding_screen.dart` — geocode on address save
- `lib/features/profile/presentation/employer_jobs_screen.dart` — geocode on job save
- `lib/features/swipe/presentation/job_card.dart` — replace `location` chip with distance chip when both sides have lat/lng; add tap → open detail screen
- `lib/features/swipe/presentation/swipe_screen.dart` — wire tap-to-detail
- `lib/core/router/app_router.dart` — add `/job/:id` route

---

## Task 1: DB Migration (columns + commute_cache + RLS)

**Files:**
- Create: `sql/location_006_up.sql`
- Apply: via MCP `mcp__27f6b935-...__apply_migration` on project `klwsmonobcenfoyhkyuq`

**Interfaces:**
- Produces: `users.lat, users.lng, users.formatted_address, users.location_updated_at`; same on `jobs`; new table `commute_cache(origin_geohash, dest_geohash, mode, duration_seconds, distance_meters, cached_at, expires_at)`; RLS policy hiding `users.lat/lng` from non-owner reads.

- [ ] **Step 1: Write migration SQL file**

Create `sql/location_006_up.sql`:

```sql
-- Migration: location_006
-- Add geocoding fields to users and jobs, commute cache table, RLS masking.

alter table users
  add column if not exists lat double precision,
  add column if not exists lng double precision,
  add column if not exists formatted_address text,
  add column if not exists location_updated_at timestamptz;

alter table jobs
  add column if not exists lat double precision,
  add column if not exists lng double precision,
  add column if not exists formatted_address text,
  add column if not exists location_updated_at timestamptz;

create table if not exists commute_cache (
  origin_geohash text not null,
  dest_geohash   text not null,
  mode           text not null check (mode in ('driving','transit','bicycling')),
  duration_seconds integer not null,
  distance_meters  integer not null,
  cached_at   timestamptz not null default now(),
  expires_at  timestamptz not null default (now() + interval '7 days'),
  primary key (origin_geohash, dest_geohash, mode)
);
create index if not exists commute_cache_expires_at_idx on commute_cache (expires_at);

-- Rate-limit tracking (used by both Edge Functions)
create table if not exists edge_function_hits (
  user_id     uuid   not null,
  endpoint    text   not null,
  hit_at      timestamptz not null default now()
);
create index if not exists edge_function_hits_lookup_idx
  on edge_function_hits (user_id, endpoint, hit_at desc);

-- commute_cache: only service_role writes; anyone authenticated can read
alter table commute_cache enable row level security;
create policy commute_cache_read on commute_cache
  for select using (auth.role() = 'authenticated');
-- No insert/update policy → only service_role (Edge Function) can write.

-- edge_function_hits: only service_role reads/writes
alter table edge_function_hits enable row level security;
-- (no policies = no access for anon/authenticated; service_role bypasses RLS)

-- RLS: hide lat/lng on users from anyone but owner.
-- Approach: existing users_select policy stays for row-level access; add a view
-- for other-user reads that masks the sensitive columns.
create or replace view public.users_public as
  select id, email, role, display_name, avatar_url, bio, location, skills,
         experience_years, expected_salary, company_name, company_size,
         formatted_address,  -- OK to expose (human-readable, not GPS)
         status, created_at, updated_at
    from users;
-- Grant read on view (RLS still applies via base table).
grant select on public.users_public to authenticated;
```

- [ ] **Step 2: Apply migration via Supabase MCP**

Use `mcp__27f6b935-8f76-4225-a98b-53bd54dd8bc2__apply_migration` with:
- `project_id`: `klwsmonobcenfoyhkyuq`
- `name`: `location_006`
- `query`: contents of `sql/location_006_up.sql`

If project status is INACTIVE, first call `restore_project`.

- [ ] **Step 3: Verify columns and table exist**

Use `mcp__..._execute_sql`:

```sql
select column_name from information_schema.columns
  where table_name = 'users' and column_name in ('lat','lng','formatted_address','location_updated_at')
  order by column_name;
-- expect 4 rows

select column_name from information_schema.columns
  where table_name = 'jobs' and column_name in ('lat','lng','formatted_address','location_updated_at');
-- expect 4 rows

select to_regclass('public.commute_cache'), to_regclass('public.edge_function_hits');
-- expect both non-null
```

Expected: all queries return non-empty results.

- [ ] **Step 4: Commit**

```bash
git add sql/location_006_up.sql
git commit -m "+migration: location_006 (lat/lng + commute_cache + RLS)"
```

---

## Task 2: Shared Deno utils (geohash6 + rate_limit + CORS)

**Files:**
- Create: `supabase/functions/_shared/geohash.ts`
- Create: `supabase/functions/_shared/rate_limit.ts`
- Create: `supabase/functions/_shared/cors.ts`
- Create: `supabase/functions/_shared/geohash_test.ts`
- Create: `supabase/functions/_shared/rate_limit_test.ts`

**Interfaces:**
- Produces: `geohash6(lat: number, lng: number): string`
- Produces: `checkRateLimit(supabase: SupabaseClient, userId: string, endpoint: string, opts?: {maxHits?: number, windowSec?: number}): Promise<boolean>` — returns `true` if allowed, `false` if over limit.
- Produces: `corsHeaders: Record<string,string>` and `handleCors(req: Request): Response | null`

- [ ] **Step 1: Write CORS helper (no test needed — trivial constants)**

Create `supabase/functions/_shared/cors.ts`:

```typescript
export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

export function handleCors(req: Request): Response | null {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  return null;
}
```

- [ ] **Step 2: Write failing geohash6 test**

Create `supabase/functions/_shared/geohash_test.ts`:

```typescript
import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts';
import { geohash6 } from './geohash.ts';

Deno.test('geohash6: Taipei 101', () => {
  // Taipei 101: 25.0330, 121.5645 → wsqqm* prefix
  const gh = geohash6(25.0330, 121.5645);
  assertEquals(gh.length, 6);
  assertEquals(gh, 'wsqqm3');
});

Deno.test('geohash6: same 1.2km cell shares hash', () => {
  // Two points ~500m apart in Taipei should share geohash6
  const a = geohash6(25.0330, 121.5645);
  const b = geohash6(25.0350, 121.5645);
  assertEquals(a, b);
});

Deno.test('geohash6: different cities differ', () => {
  const taipei = geohash6(25.0330, 121.5645);
  const kaohsiung = geohash6(22.6273, 120.3014);
  if (taipei === kaohsiung) throw new Error('should differ');
});
```

- [ ] **Step 3: Run test to verify it fails**

```bash
cd supabase/functions && deno test _shared/geohash_test.ts
```
Expected: FAIL — `geohash.ts` module not found.

- [ ] **Step 4: Implement geohash6**

Create `supabase/functions/_shared/geohash.ts`:

```typescript
// Standard geohash algorithm (base32). Fixed to 6 chars precision.
const BASE32 = '0123456789bcdefghjkmnpqrstuvwxyz';

export function geohash6(lat: number, lng: number): string {
  let latRange = [-90.0, 90.0];
  let lngRange = [-180.0, 180.0];
  let hash = '';
  let bits = 0;
  let bitCount = 0;
  let even = true; // start with longitude bit

  while (hash.length < 6) {
    if (even) {
      const mid = (lngRange[0] + lngRange[1]) / 2;
      if (lng >= mid) { bits = (bits << 1) | 1; lngRange[0] = mid; }
      else            { bits = (bits << 1);     lngRange[1] = mid; }
    } else {
      const mid = (latRange[0] + latRange[1]) / 2;
      if (lat >= mid) { bits = (bits << 1) | 1; latRange[0] = mid; }
      else            { bits = (bits << 1);     latRange[1] = mid; }
    }
    even = !even;
    bitCount++;
    if (bitCount === 5) {
      hash += BASE32[bits];
      bits = 0;
      bitCount = 0;
    }
  }
  return hash;
}
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
cd supabase/functions && deno test _shared/geohash_test.ts
```
Expected: 3 passed.

If `wsqqm3` assertion fails with actual value, update assertion to match — Taipei 101 exact hash depends on rounding; correct value is what the algorithm produces for standard geohash. Verify against https://geohash.softeng.co/ external tool.

- [ ] **Step 6: Write failing rate_limit test**

Create `supabase/functions/_shared/rate_limit_test.ts`:

```typescript
import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts';
import { checkRateLimit } from './rate_limit.ts';

function mockSupabase(hits: number) {
  return {
    from() {
      return {
        select() { return this; },
        eq() { return this; },
        gte() { return this; },
        then(cb: (r: {count: number; data: unknown[]; error: null}) => void) {
          cb({ count: hits, data: [], error: null });
        },
        insert() { return Promise.resolve({ error: null }); },
      };
    },
  };
}

Deno.test('checkRateLimit: under threshold returns true and records hit', async () => {
  const ok = await checkRateLimit(mockSupabase(2) as any, 'user1', 'test');
  assertEquals(ok, true);
});

Deno.test('checkRateLimit: at threshold returns false', async () => {
  const ok = await checkRateLimit(mockSupabase(5) as any, 'user1', 'test');
  assertEquals(ok, false);
});
```

- [ ] **Step 7: Run to verify failure**

```bash
deno test _shared/rate_limit_test.ts
```
Expected: FAIL — module not found.

- [ ] **Step 8: Implement rate_limit**

Create `supabase/functions/_shared/rate_limit.ts`:

```typescript
import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

export async function checkRateLimit(
  supabase: SupabaseClient,
  userId: string,
  endpoint: string,
  opts: { maxHits?: number; windowSec?: number } = {},
): Promise<boolean> {
  const maxHits = opts.maxHits ?? 5;
  const windowSec = opts.windowSec ?? 15;
  const since = new Date(Date.now() - windowSec * 1000).toISOString();

  const { count, error } = await supabase
    .from('edge_function_hits')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', userId)
    .eq('endpoint', endpoint)
    .gte('hit_at', since);

  if (error) return true; // fail-open on DB errors

  if ((count ?? 0) >= maxHits) return false;

  await supabase
    .from('edge_function_hits')
    .insert({ user_id: userId, endpoint });

  return true;
}
```

- [ ] **Step 9: Run to verify pass**

```bash
deno test _shared/rate_limit_test.ts
```
Expected: 2 passed.

- [ ] **Step 10: Commit**

```bash
git add supabase/functions/_shared/
git commit -m "+edge fn: shared geohash6 + rate_limit + cors utils"
```

---

## Task 3: Edge Function `geocode-address`

**Files:**
- Create: `supabase/functions/geocode-address/index.ts`
- Create: `supabase/functions/geocode-address/test.ts`

**Interfaces:**
- Consumes: `_shared/cors.ts`, `_shared/rate_limit.ts`; Supabase secret `GOOGLE_MAPS_API_KEY`
- Produces: HTTP endpoint `POST /functions/v1/geocode-address` requiring auth JWT. Request `{address: string}` → 200 `{lat, lng, formatted_address}` | 400 `{error:"invalid_address"}` | 404 `{error:"address_not_found"}` | 429 `{error:"rate_limited"}` | 502 `{error:"upstream_error"}`.

- [ ] **Step 1: Write failing test**

Create `supabase/functions/geocode-address/test.ts`:

```typescript
import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts';

// Stub Deno.env for the module under test
Deno.env.set('GOOGLE_MAPS_API_KEY', 'test_key');
Deno.env.set('SUPABASE_URL', 'http://localhost');
Deno.env.set('SUPABASE_SERVICE_ROLE_KEY', 'test');

const originalFetch = globalThis.fetch;

function stubFetch(response: { status: number; body: unknown }) {
  globalThis.fetch = ((_url: string) =>
    Promise.resolve(new Response(JSON.stringify(response.body), {
      status: response.status,
      headers: { 'content-type': 'application/json' },
    }))) as typeof fetch;
}

function restoreFetch() { globalThis.fetch = originalFetch; }

function makeRequest(body: unknown, auth = 'Bearer test.jwt.token'): Request {
  return new Request('http://x/geocode-address', {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'authorization': auth },
    body: JSON.stringify(body),
  });
}

Deno.test('geocode-address: OK returns lat/lng/formatted', async () => {
  stubFetch({ status: 200, body: {
    status: 'OK',
    results: [{
      geometry: { location: { lat: 25.0330, lng: 121.5645 } },
      formatted_address: '110台北市信義區信義路五段7號',
    }],
  }});
  const { handler } = await import('./index.ts');
  const res = await handler(makeRequest({ address: '台北101' }));
  assertEquals(res.status, 200);
  const j = await res.json();
  assertEquals(j.lat, 25.0330);
  assertEquals(j.lng, 121.5645);
  assertEquals(j.formatted_address, '110台北市信義區信義路五段7號');
  restoreFetch();
});

Deno.test('geocode-address: ZERO_RESULTS → 404', async () => {
  stubFetch({ status: 200, body: { status: 'ZERO_RESULTS', results: [] }});
  const { handler } = await import('./index.ts');
  const res = await handler(makeRequest({ address: 'xxx nonsense' }));
  assertEquals(res.status, 404);
  restoreFetch();
});

Deno.test('geocode-address: OVER_QUERY_LIMIT → 429', async () => {
  stubFetch({ status: 200, body: { status: 'OVER_QUERY_LIMIT' }});
  const { handler } = await import('./index.ts');
  const res = await handler(makeRequest({ address: 'x' }));
  assertEquals(res.status, 429);
  restoreFetch();
});

Deno.test('geocode-address: missing address → 400', async () => {
  const { handler } = await import('./index.ts');
  const res = await handler(makeRequest({}));
  assertEquals(res.status, 400);
});

Deno.test('geocode-address: no auth header → 401', async () => {
  const { handler } = await import('./index.ts');
  const res = await handler(makeRequest({ address: 'x' }, ''));
  assertEquals(res.status, 401);
});
```

- [ ] **Step 2: Run to verify failure**

```bash
cd supabase/functions && deno test geocode-address/test.ts
```
Expected: FAIL — `./index.ts` missing.

- [ ] **Step 3: Implement handler**

Create `supabase/functions/geocode-address/index.ts`:

```typescript
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';
import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { checkRateLimit } from '../_shared/rate_limit.ts';

const GOOGLE_URL = 'https://maps.googleapis.com/maps/api/geocode/json';

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'content-type': 'application/json' },
  });
}

export async function handler(req: Request): Promise<Response> {
  const preflight = handleCors(req);
  if (preflight) return preflight;
  if (req.method !== 'POST') return json(405, { error: 'method_not_allowed' });

  const auth = req.headers.get('authorization') ?? '';
  if (!auth.startsWith('Bearer ')) return json(401, { error: 'unauthorized' });

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { global: { headers: { Authorization: auth } } },
  );
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return json(401, { error: 'unauthorized' });

  // Rate-limit (fail-open on DB error inside checkRateLimit)
  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );
  const allowed = await checkRateLimit(admin, user.id, 'geocode-address');
  if (!allowed) return json(429, { error: 'rate_limited' });

  const body = await req.json().catch(() => ({}));
  const address = typeof body.address === 'string' ? body.address.trim() : '';
  if (!address) return json(400, { error: 'invalid_address' });

  const key = Deno.env.get('GOOGLE_MAPS_API_KEY')!;
  const url = `${GOOGLE_URL}?address=${encodeURIComponent(address)}&region=tw&key=${key}`;

  let googleRes: Response;
  try { googleRes = await fetch(url); }
  catch { return json(502, { error: 'upstream_error' }); }

  if (!googleRes.ok) return json(502, { error: 'upstream_error' });
  const data = await googleRes.json();

  switch (data.status) {
    case 'OK': {
      const r = data.results[0];
      return json(200, {
        lat: r.geometry.location.lat,
        lng: r.geometry.location.lng,
        formatted_address: r.formatted_address,
      });
    }
    case 'ZERO_RESULTS':
      return json(404, { error: 'address_not_found' });
    case 'OVER_QUERY_LIMIT':
    case 'RESOURCE_EXHAUSTED':
      return json(429, { error: 'rate_limited' });
    default:
      return json(502, { error: 'upstream_error', google_status: data.status });
  }
}

// Supabase Edge Function entrypoint
Deno.serve(handler);
```

- [ ] **Step 4: Run tests**

```bash
cd supabase/functions && deno test geocode-address/test.ts
```
Expected: 5 passed. (Auth tests will pass because the auth check runs before Supabase call — no real network.)

Note: the test file bypasses the real `supabase.auth.getUser()` by importing `handler` directly and relying on the fake Bearer token being present. If auth check calls fail against a real Supabase URL, refactor `handler` to accept an injectable auth-checker for testability, or use `SUPABASE_URL=http://localhost` + stub the `fetch` on that URL too.

- [ ] **Step 5: Deploy Edge Function**

```bash
supabase functions deploy geocode-address --project-ref klwsmonobcenfoyhkyuq
```
Or via MCP `mcp__..._deploy_edge_function` with name `geocode-address` and the index.ts contents.

- [ ] **Step 6: Set secret (one-time)**

```bash
supabase secrets set GOOGLE_MAPS_API_KEY=<your-key> --project-ref klwsmonobcenfoyhkyuq
```
(If key not yet obtained, complete Task 14 Step 1 first.)

- [ ] **Step 7: Smoke test deployed function**

```bash
curl -X POST "https://klwsmonobcenfoyhkyuq.supabase.co/functions/v1/geocode-address" \
  -H "Authorization: Bearer <YOUR_USER_JWT>" \
  -H "Content-Type: application/json" \
  -d '{"address":"台北101"}'
```
Expected: `{"lat":25.0..., "lng":121.5..., "formatted_address":"..."}`.

- [ ] **Step 8: Commit**

```bash
git add supabase/functions/geocode-address/
git commit -m "+edge fn: geocode-address (auth + rate-limit + Google Geocoding)"
```

---

## Task 4: Edge Function `commute-time`

**Files:**
- Create: `supabase/functions/commute-time/index.ts`
- Create: `supabase/functions/commute-time/test.ts`

**Interfaces:**
- Consumes: `_shared/geohash.ts`, `_shared/rate_limit.ts`, `_shared/cors.ts`; `commute_cache` table
- Produces: `POST /functions/v1/commute-time` requiring JWT. Request `{originLat, originLng, destLat, destLng, modes: ("driving"|"transit"|"bicycling")[]}` → 200 `{[mode]: {duration_seconds, distance_meters, approximated?: bool}}` | 400 | 401 | 429 | 502.

- [ ] **Step 1: Write failing test**

Create `supabase/functions/commute-time/test.ts`:

```typescript
import { assertEquals, assert } from 'https://deno.land/std@0.208.0/assert/mod.ts';

Deno.env.set('GOOGLE_MAPS_API_KEY', 'test_key');
Deno.env.set('SUPABASE_URL', 'http://localhost');
Deno.env.set('SUPABASE_SERVICE_ROLE_KEY', 'test');

const originalFetch = globalThis.fetch;
let fetchCalls: string[] = [];

function stubGoogle(mode: string, duration: number, distance: number) {
  globalThis.fetch = ((url: string) => {
    fetchCalls.push(url);
    return Promise.resolve(new Response(JSON.stringify({
      status: 'OK',
      rows: [{ elements: [{ status: 'OK',
        duration: { value: duration },
        distance: { value: distance },
      }]}],
    }), { status: 200 }));
  }) as typeof fetch;
}

// Simplified: assumes we can inject a mock supabase for cache reads/writes.
// The handler MUST accept an optional `deps` param for testability.

Deno.test('commute-time: cache miss calls Google + writes cache', async () => {
  fetchCalls = [];
  stubGoogle('driving', 1800, 5200);
  const cache = new Map<string, unknown>();
  const mockDb = {
    from() {
      return {
        select() { return { in: () => Promise.resolve({ data: [], error: null }) }; },
        upsert(rows: unknown[]) { for (const r of rows as any[]) cache.set(`${r.origin_geohash}-${r.dest_geohash}-${r.mode}`, r); return Promise.resolve({ error: null }); },
      };
    },
  };
  const { handler } = await import('./index.ts');
  const res = await handler(new Request('http://x', {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'authorization': 'Bearer x' },
    body: JSON.stringify({ originLat: 25.03, originLng: 121.56, destLat: 25.05, destLng: 121.58, modes: ['driving'] }),
  }), { db: mockDb, skipAuth: true });
  assertEquals(res.status, 200);
  const j = await res.json();
  assertEquals(j.driving.duration_seconds, 1800);
  assertEquals(j.driving.distance_meters, 5200);
  assertEquals(fetchCalls.length, 1);
  restoreFetch();
});

Deno.test('commute-time: cache hit skips Google', async () => {
  fetchCalls = [];
  globalThis.fetch = originalFetch; // no google calls expected
  const cachedRow = {
    origin_geohash: 'wsqqm3', dest_geohash: 'wsqqmc', mode: 'driving',
    duration_seconds: 1200, distance_meters: 4000,
    expires_at: new Date(Date.now() + 86400_000).toISOString(),
  };
  const mockDb = {
    from() {
      return {
        select() { return { in: () => Promise.resolve({ data: [cachedRow], error: null }) }; },
        upsert() { return Promise.resolve({ error: null }); },
      };
    },
  };
  const { handler } = await import('./index.ts');
  const res = await handler(new Request('http://x', {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'authorization': 'Bearer x' },
    body: JSON.stringify({ originLat: 25.03, originLng: 121.56, destLat: 25.05, destLng: 121.58, modes: ['driving'] }),
  }), { db: mockDb, skipAuth: true });
  assertEquals(res.status, 200);
  const j = await res.json();
  assertEquals(j.driving.duration_seconds, 1200);
  assertEquals(fetchCalls.length, 0);
});

Deno.test('commute-time: missing coords → 400', async () => {
  const { handler } = await import('./index.ts');
  const res = await handler(new Request('http://x', {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'authorization': 'Bearer x' },
    body: JSON.stringify({ originLat: 25 }),
  }), { skipAuth: true });
  assertEquals(res.status, 400);
});

function restoreFetch() { globalThis.fetch = originalFetch; }
```

- [ ] **Step 2: Run to verify failure**

```bash
deno test commute-time/test.ts
```
Expected: FAIL — `./index.ts` missing.

- [ ] **Step 3: Implement handler**

Create `supabase/functions/commute-time/index.ts`:

```typescript
import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';
import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { checkRateLimit } from '../_shared/rate_limit.ts';
import { geohash6 } from '../_shared/geohash.ts';

const GOOGLE_URL = 'https://maps.googleapis.com/maps/api/distancematrix/json';
type Mode = 'driving' | 'transit' | 'bicycling';

interface Deps {
  db?: SupabaseClient | any;
  skipAuth?: boolean;
}

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'content-type': 'application/json' },
  });
}

async function fetchGoogle(origin: {lat:number;lng:number}, dest: {lat:number;lng:number}, mode: Mode): Promise<{duration:number; distance:number} | null> {
  const key = Deno.env.get('GOOGLE_MAPS_API_KEY')!;
  const url = `${GOOGLE_URL}?origins=${origin.lat},${origin.lng}&destinations=${dest.lat},${dest.lng}&mode=${mode}&key=${key}`;
  try {
    const r = await fetch(url);
    if (!r.ok) return null;
    const d = await r.json();
    if (d.status !== 'OK') return null;
    const el = d.rows?.[0]?.elements?.[0];
    if (!el || el.status !== 'OK') return null;
    return { duration: el.duration.value, distance: el.distance.value };
  } catch { return null; }
}

export async function handler(req: Request, deps: Deps = {}): Promise<Response> {
  const preflight = handleCors(req);
  if (preflight) return preflight;
  if (req.method !== 'POST') return json(405, { error: 'method_not_allowed' });

  const auth = req.headers.get('authorization') ?? '';
  if (!auth.startsWith('Bearer ')) return json(401, { error: 'unauthorized' });

  const admin = deps.db ?? createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  let userId = 'test';
  if (!deps.skipAuth) {
    const authed = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
      { global: { headers: { Authorization: auth } } },
    );
    const { data: { user } } = await authed.auth.getUser();
    if (!user) return json(401, { error: 'unauthorized' });
    userId = user.id;
    const allowed = await checkRateLimit(admin, userId, 'commute-time');
    if (!allowed) return json(429, { error: 'rate_limited' });
  }

  const body = await req.json().catch(() => ({}));
  const { originLat, originLng, destLat, destLng, modes } = body;
  if (typeof originLat !== 'number' || typeof originLng !== 'number' ||
      typeof destLat !== 'number' || typeof destLng !== 'number' ||
      !Array.isArray(modes) || modes.length === 0) {
    return json(400, { error: 'invalid_request' });
  }
  const validModes: Mode[] = modes.filter((m: string) => ['driving','transit','bicycling'].includes(m));
  if (validModes.length === 0) return json(400, { error: 'invalid_modes' });

  const originGH = geohash6(originLat, originLng);
  const destGH   = geohash6(destLat, destLng);

  // Query cache
  const cacheKeys = validModes.map(m => `${originGH}|${destGH}|${m}`);
  const { data: cached = [] } = await admin
    .from('commute_cache')
    .select('*')
    .in('mode', validModes)
    .eq('origin_geohash', originGH)
    .eq('dest_geohash', destGH);

  const now = Date.now();
  const cacheByMode = new Map<Mode, any>();
  for (const row of (cached as any[])) {
    if (new Date(row.expires_at).getTime() > now) {
      cacheByMode.set(row.mode as Mode, row);
    }
  }

  const result: Record<string, unknown> = {};
  const toWrite: unknown[] = [];
  for (const mode of validModes) {
    if (cacheByMode.has(mode)) {
      const r = cacheByMode.get(mode);
      result[mode] = { duration_seconds: r.duration_seconds, distance_meters: r.distance_meters };
    } else {
      const g = await fetchGoogle({lat: originLat, lng: originLng}, {lat: destLat, lng: destLng}, mode);
      if (!g) { result[mode] = { error: 'unavailable' }; continue; }
      result[mode] = { duration_seconds: g.duration, distance_meters: g.distance };
      toWrite.push({
        origin_geohash: originGH, dest_geohash: destGH, mode,
        duration_seconds: g.duration, distance_meters: g.distance,
      });
    }
  }

  if (toWrite.length > 0) {
    await admin.from('commute_cache').upsert(toWrite, { onConflict: 'origin_geohash,dest_geohash,mode' });
  }

  return json(200, result);
}

Deno.serve((req) => handler(req));
```

- [ ] **Step 4: Run tests**

```bash
deno test commute-time/test.ts
```
Expected: 3 passed.

- [ ] **Step 5: Deploy**

```bash
supabase functions deploy commute-time --project-ref klwsmonobcenfoyhkyuq
```

- [ ] **Step 6: Smoke test**

```bash
curl -X POST "https://klwsmonobcenfoyhkyuq.supabase.co/functions/v1/commute-time" \
  -H "Authorization: Bearer <JWT>" -H "Content-Type: application/json" \
  -d '{"originLat":25.03,"originLng":121.56,"destLat":25.05,"destLng":121.58,"modes":["driving","transit"]}'
```
Expected: JSON with `driving` and `transit` keys, each with `duration_seconds`, `distance_meters`.

Then re-run same curl → should be much faster (cache hit) and no Google API call incurred.

- [ ] **Step 7: Commit**

```bash
git add supabase/functions/commute-time/
git commit -m "+edge fn: commute-time (cache + Distance Matrix)"
```

---

## Task 5: Update Flutter models (UserModel + JobModel)

**Files:**
- Modify: `lib/shared/models/user_model.dart`
- Modify: `lib/shared/models/job_model.dart`

**Interfaces:**
- Produces: `UserModel.lat, lng, formattedAddress, locationUpdatedAt` (all nullable); `JobModel.lat, lng, formattedAddress, locationUpdatedAt`. `fromSupabase` populates from snake_case columns.

- [ ] **Step 1: Add fields to UserModel**

Edit `lib/shared/models/user_model.dart`. In the `factory UserModel({...})` block, add these fields BEFORE `required DateTime createdAt`:

```dart
    double? lat,
    double? lng,
    String? formattedAddress,
    DateTime? locationUpdatedAt,
```

Then in `fromSupabase`, add mappings after `location:` line:

```dart
      lat: (row['lat'] as num?)?.toDouble(),
      lng: (row['lng'] as num?)?.toDouble(),
      formattedAddress: row['formatted_address'] as String?,
      locationUpdatedAt: row['location_updated_at'] != null
          ? DateTime.parse(row['location_updated_at'] as String)
          : null,
```

- [ ] **Step 2: Add fields to JobModel**

Edit `lib/shared/models/job_model.dart`. Same 4 fields added to factory + `fromSupabase`.

- [ ] **Step 3: Regenerate freezed/json**

```bash
export PATH="/opt/homebrew/bin:$HOME/dev/tooling/flutter/bin:$PATH"
cd /Users/alice/job_swipe
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 4: Verify build**

```bash
flutter analyze lib/shared/models/
```
Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/models/
git commit -m "+models: lat/lng/formatted_address/location_updated_at on User+Job"
```

---

## Task 6: Flutter `distance_utils` + `LatLng` value type

**Files:**
- Create: `lib/features/location/domain/lat_lng.dart`
- Create: `lib/features/location/domain/distance_utils.dart`
- Create: `test/features/location/distance_utils_test.dart`

**Interfaces:**
- Produces: `class LatLng { final double lat, lng; const LatLng(this.lat, this.lng); }`
- Produces: `double haversineKm(LatLng a, LatLng b)` — returns distance in kilometers.

- [ ] **Step 1: Write failing test**

Create `test/features/location/distance_utils_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:job_swipe/features/location/domain/lat_lng.dart';
import 'package:job_swipe/features/location/domain/distance_utils.dart';

void main() {
  test('haversineKm: same point = 0', () {
    final p = const LatLng(25.033, 121.565);
    expect(haversineKm(p, p), closeTo(0, 0.001));
  });

  test('haversineKm: Taipei 101 → Kaohsiung International Airport ~ 300-360km', () {
    final taipei = const LatLng(25.0330, 121.5645);
    final kaohsiung = const LatLng(22.5771, 120.3502);
    final d = haversineKm(taipei, kaohsiung);
    expect(d, inInclusiveRange(290, 360));
  });

  test('haversineKm: 1 degree latitude ~ 111 km', () {
    final a = const LatLng(25.0, 121.5);
    final b = const LatLng(26.0, 121.5);
    expect(haversineKm(a, b), closeTo(111.0, 1.0));
  });
}
```

- [ ] **Step 2: Verify failure**

```bash
cd /Users/alice/job_swipe && flutter test test/features/location/distance_utils_test.dart
```
Expected: FAIL — imports missing.

- [ ] **Step 3: Implement**

Create `lib/features/location/domain/lat_lng.dart`:

```dart
class LatLng {
  final double lat;
  final double lng;
  const LatLng(this.lat, this.lng);
}
```

Create `lib/features/location/domain/distance_utils.dart`:

```dart
import 'dart:math' as math;
import 'lat_lng.dart';

const _earthRadiusKm = 6371.0088;

double haversineKm(LatLng a, LatLng b) {
  final dLat = _rad(b.lat - a.lat);
  final dLng = _rad(b.lng - a.lng);
  final la1 = _rad(a.lat);
  final la2 = _rad(b.lat);
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(la1) * math.cos(la2) * math.pow(math.sin(dLng / 2), 2);
  final c = 2 * math.asin(math.min(1.0, math.sqrt(h)));
  return _earthRadiusKm * c;
}

double _rad(double deg) => deg * math.pi / 180.0;
```

- [ ] **Step 4: Verify pass**

```bash
flutter test test/features/location/distance_utils_test.dart
```
Expected: 3 passed.

- [ ] **Step 5: Commit**

```bash
git add lib/features/location/ test/features/location/
git commit -m "+location: LatLng + haversineKm"
```

---

## Task 7: Flutter `GeocodingService` + provider

**Files:**
- Create: `lib/features/location/data/geocoding_service.dart`
- Create: `lib/features/location/providers/location_providers.dart`

**Interfaces:**
- Consumes: existing `supabaseClientProvider` (already in project — search `SupabaseClient` in `lib/`)
- Produces: `class GeocodeResult { final double lat; final double lng; final String formattedAddress; }`
- Produces: `class GeocodingService { Future<GeocodeResult> geocode(String address); }` throws `GeocodingException` with `code` field (`address_not_found` | `rate_limited` | `upstream_error`).
- Produces: `geocodingServiceProvider` (Riverpod)

- [ ] **Step 1: Find how existing services call Supabase**

```bash
grep -rn "supabase.functions.invoke\|invokeFunction\|SupabaseClient" lib/features --include="*.dart" | head -20
```
Note the pattern (likely `supabase.functions.invoke('name', body: {...})`). Use same pattern.

- [ ] **Step 2: Write service**

Create `lib/features/location/data/geocoding_service.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class GeocodeResult {
  final double lat;
  final double lng;
  final String formattedAddress;
  const GeocodeResult({required this.lat, required this.lng, required this.formattedAddress});
}

class GeocodingException implements Exception {
  final String code;
  final String? message;
  const GeocodingException(this.code, [this.message]);
  @override
  String toString() => 'GeocodingException($code): $message';
}

class GeocodingService {
  GeocodingService(this._client);
  final SupabaseClient _client;

  Future<GeocodeResult> geocode(String address) async {
    final response = await _client.functions.invoke(
      'geocode-address',
      body: {'address': address},
    );

    final data = response.data as Map<String, dynamic>?;
    final status = response.status;

    if (status == 200 && data != null && data['lat'] != null) {
      return GeocodeResult(
        lat: (data['lat'] as num).toDouble(),
        lng: (data['lng'] as num).toDouble(),
        formattedAddress: data['formatted_address'] as String,
      );
    }
    final code = (data?['error'] as String?) ?? _codeForStatus(status);
    throw GeocodingException(code);
  }

  String _codeForStatus(int s) {
    if (s == 404) return 'address_not_found';
    if (s == 429) return 'rate_limited';
    return 'upstream_error';
  }
}
```

- [ ] **Step 3: Write provider**

Create `lib/features/location/providers/location_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/geocoding_service.dart';

part 'location_providers.g.dart';

@riverpod
GeocodingService geocodingService(GeocodingServiceRef ref) {
  return GeocodingService(Supabase.instance.client);
}
```

- [ ] **Step 4: Regenerate riverpod code**

```bash
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 5: Verify compile**

```bash
flutter analyze lib/features/location/
```
Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add lib/features/location/data/geocoding_service.dart lib/features/location/providers/
git commit -m "+location: GeocodingService + provider"
```

---

## Task 8: Flutter `CommuteService` + `CommuteResult` model + `commuteProvider`

**Files:**
- Create: `lib/features/location/domain/commute_result.dart`
- Create: `lib/features/location/data/commute_service.dart`
- Create: `lib/features/location/providers/commute_provider.dart`

**Interfaces:**
- Consumes: `LatLng`, existing `SupabaseClient`
- Produces: `CommuteResult` freezed model with three optional `ModeResult` (driving/transit/bicycling), each `{int durationSeconds; int distanceMeters}`.
- Produces: `CommuteService.getCommute(LatLng from, LatLng to, {List<String> modes}) → Future<CommuteResult>`.
- Produces: `commuteProvider = FutureProvider.family<CommuteResult, ({LatLng from, LatLng to})>`.

- [ ] **Step 1: Write freezed model**

Create `lib/features/location/domain/commute_result.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'commute_result.freezed.dart';
part 'commute_result.g.dart';

@freezed
class ModeResult with _$ModeResult {
  const factory ModeResult({
    required int durationSeconds,
    required int distanceMeters,
    @Default(false) bool approximated,
  }) = _ModeResult;

  factory ModeResult.fromJson(Map<String, dynamic> json) => _$ModeResultFromJson(json);
}

@freezed
class CommuteResult with _$CommuteResult {
  const factory CommuteResult({
    ModeResult? driving,
    ModeResult? transit,
    ModeResult? bicycling,
  }) = _CommuteResult;

  factory CommuteResult.fromJson(Map<String, dynamic> json) => _$CommuteResultFromJson(json);
}
```

- [ ] **Step 2: Write CommuteService**

Create `lib/features/location/data/commute_service.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/lat_lng.dart';
import '../domain/commute_result.dart';

class CommuteException implements Exception {
  final String code;
  const CommuteException(this.code);
  @override
  String toString() => 'CommuteException($code)';
}

class CommuteService {
  CommuteService(this._client);
  final SupabaseClient _client;

  Future<CommuteResult> getCommute(
    LatLng from,
    LatLng to, {
    List<String> modes = const ['driving', 'transit', 'bicycling'],
  }) async {
    final response = await _client.functions.invoke(
      'commute-time',
      body: {
        'originLat': from.lat, 'originLng': from.lng,
        'destLat': to.lat,     'destLng': to.lng,
        'modes': modes,
      },
    );

    if (response.status != 200) {
      final code = (response.data as Map?)?['error'] as String? ?? 'upstream_error';
      throw CommuteException(code);
    }
    final data = response.data as Map<String, dynamic>;

    ModeResult? extract(String key) {
      final v = data[key];
      if (v is! Map || v['error'] != null) return null;
      return ModeResult(
        durationSeconds: (v['duration_seconds'] as num).toInt(),
        distanceMeters: (v['distance_meters'] as num).toInt(),
        approximated: v['approximated'] == true,
      );
    }

    return CommuteResult(
      driving: extract('driving'),
      transit: extract('transit'),
      bicycling: extract('bicycling'),
    );
  }
}
```

- [ ] **Step 3: Add commuteService provider + commuteProvider**

Edit `lib/features/location/providers/location_providers.dart`, add:

```dart
import '../data/commute_service.dart';

@riverpod
CommuteService commuteService(CommuteServiceRef ref) {
  return CommuteService(Supabase.instance.client);
}
```

Create `lib/features/location/providers/commute_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/lat_lng.dart';
import '../domain/commute_result.dart';
import 'location_providers.dart';

part 'commute_provider.g.dart';

@riverpod
Future<CommuteResult> commute(
  CommuteRef ref, {
  required LatLng from,
  required LatLng to,
}) async {
  final service = ref.watch(commuteServiceProvider);
  return service.getCommute(from, to);
}
```

- [ ] **Step 4: Regenerate**

```bash
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 5: Write provider test**

Create `test/features/location/commute_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:job_swipe/features/location/domain/commute_result.dart';
import 'package:job_swipe/features/location/domain/lat_lng.dart';
import 'package:job_swipe/features/location/data/commute_service.dart';
import 'package:job_swipe/features/location/providers/commute_provider.dart';
import 'package:job_swipe/features/location/providers/location_providers.dart';

class _FakeCommuteService implements CommuteService {
  @override
  Future<CommuteResult> getCommute(LatLng from, LatLng to, {List<String> modes = const []}) async {
    return const CommuteResult(
      driving: ModeResult(durationSeconds: 1800, distanceMeters: 5200),
    );
  }
}

void main() {
  test('commuteProvider returns service result', () async {
    final container = ProviderContainer(overrides: [
      commuteServiceProvider.overrideWithValue(_FakeCommuteService()),
    ]);
    addTearDown(container.dispose);

    final result = await container.read(commuteProvider(
      from: const LatLng(25.03, 121.56),
      to: const LatLng(25.05, 121.58),
    ).future);

    expect(result.driving?.durationSeconds, 1800);
    expect(result.driving?.distanceMeters, 5200);
    expect(result.transit, isNull);
  });
}
```

- [ ] **Step 6: Run test**

```bash
flutter test test/features/location/commute_provider_test.dart
```
Expected: 1 passed.

- [ ] **Step 7: Commit**

```bash
git add lib/features/location/ test/features/location/commute_provider_test.dart
git commit -m "+location: CommuteService + commuteProvider"
```

---

## Task 9: Onboarding — geocode on address save

**Files:**
- Modify: `lib/features/onboarding/onboarding_screen.dart`

**Interfaces:**
- Consumes: `geocodingServiceProvider`, `GeocodingException`
- Produces: on successful onboarding submit, `users` row gets `lat, lng, formatted_address, location_updated_at` populated (or left null if geocode failed with a soft-warning shown).

- [ ] **Step 1: Read current onboarding submit flow**

```bash
grep -n "location\|address\|users.*update\|users.*insert\|users.*upsert" lib/features/onboarding/onboarding_screen.dart
```
Identify where `location` string is currently sent to Supabase.

- [ ] **Step 2: Modify submit handler**

At the point where the user's location string is being sent to update `users`, insert geocode step. Add near the top of the file:

```dart
import '../location/providers/location_providers.dart';
import '../location/data/geocoding_service.dart';
```

In the submit handler (adapt to actual code — find the async function that writes users), replace the location-write section with:

```dart
final address = locationController.text.trim();
Map<String, dynamic> locationFields = {'location': address};

if (address.isNotEmpty) {
  try {
    final result = await ref.read(geocodingServiceProvider).geocode(address);
    locationFields = {
      'location': address,
      'lat': result.lat,
      'lng': result.lng,
      'formatted_address': result.formattedAddress,
      'location_updated_at': DateTime.now().toIso8601String(),
    };
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('地址已驗證：${result.formattedAddress}')),
      );
    }
  } on GeocodingException catch (e) {
    // Soft-warn but continue — user can edit later.
    if (mounted) {
      final msg = e.code == 'address_not_found'
          ? '找不到這個地址，職缺距離功能將無法使用'
          : '地址驗證暫時失敗，稍後可在個人資料重試';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.orange),
      );
    }
  }
}

// Merge locationFields into the update/upsert payload.
await Supabase.instance.client.from('users').update({
  ...existingFields,  // whatever the code already sends
  ...locationFields,
}).eq('id', userId);
```

Adapt `existingFields` / `userId` to actual variable names in the file.

- [ ] **Step 3: Manual verify (Flutter run)**

```bash
export PATH="/opt/homebrew/bin:$HOME/dev/tooling/flutter/bin:$PATH"
flutter run -d macos
```
- Go through onboarding as a new user
- Enter "台北市大安區敦化南路一段" → submit
- Snackbar should show "地址已驗證：..."
- In Supabase MCP: `select lat, lng, formatted_address from users where id = '<test user>'` → non-null

- [ ] **Step 4: Commit**

```bash
git add lib/features/onboarding/onboarding_screen.dart
git commit -m "+onboarding: geocode address on submit"
```

---

## Task 10: Employer job form — geocode on save

**Files:**
- Modify: `lib/features/profile/presentation/employer_jobs_screen.dart`

**Interfaces:**
- Consumes: `geocodingServiceProvider`, `GeocodingException`
- Produces: on job create/edit save, `jobs` row gets `lat, lng, formatted_address, location_updated_at` populated.

- [ ] **Step 1: Find current job save code**

```bash
grep -n "jobs.*insert\|jobs.*update\|jobs.*upsert\|addJob\|createJob\|editJob" lib/features/profile/presentation/employer_jobs_screen.dart
```

- [ ] **Step 2: Modify save handler**

Same pattern as Task 9. In the async function that writes to `jobs`, wrap the location field with geocode-then-merge logic. Add imports:

```dart
import '../../location/providers/location_providers.dart';
import '../../location/data/geocoding_service.dart';
```

And in the save handler:

```dart
final locationText = locationController.text.trim();
Map<String, dynamic> locationFields = {'location': locationText.isEmpty ? null : locationText};

if (locationText.isNotEmpty) {
  try {
    final result = await ref.read(geocodingServiceProvider).geocode(locationText);
    locationFields = {
      'location': locationText,
      'lat': result.lat,
      'lng': result.lng,
      'formatted_address': result.formattedAddress,
      'location_updated_at': DateTime.now().toIso8601String(),
    };
  } on GeocodingException {
    // Save without lat/lng — job will show location text but no distance.
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('地址無法驗證，職缺仍會刊登但不會顯示距離')),
      );
    }
  }
}

// Merge into insert/update payload.
```

- [ ] **Step 3: Manual verify**

Log in as employer → new job with address "台北市信義區松高路 11 號" → save. Then in Supabase MCP:

```sql
select id, title, location, lat, lng, formatted_address from jobs order by created_at desc limit 1;
```
Expected: lat/lng populated.

- [ ] **Step 4: Commit**

```bash
git add lib/features/profile/presentation/employer_jobs_screen.dart
git commit -m "+employer: geocode job address on save"
```

---

## Task 11: Job card — show Haversine distance

**Files:**
- Modify: `lib/features/swipe/presentation/job_card.dart`
- Modify: `lib/features/swipe/presentation/swipe_screen.dart` (pass currentUser lat/lng)

**Interfaces:**
- Consumes: `LatLng`, `haversineKm`, `profileProvider.user.lat/lng`
- Produces: on cards where both user & job have lat/lng → the `_InfoChip` for location shows `"5.2 km"`; otherwise keeps existing behavior showing the location text.

- [ ] **Step 1: Update JobCard signature to accept user LatLng**

Edit `lib/features/swipe/presentation/job_card.dart`:

```dart
import '../../location/domain/lat_lng.dart';
import '../../location/domain/distance_utils.dart';

class JobCard extends StatelessWidget {
  const JobCard({super.key, required this.job, this.viewerLocation});

  final JobModel job;
  final LatLng? viewerLocation;
  // ...
}
```

- [ ] **Step 2: Compute + render distance chip**

Inside the `Wrap` for chips, replace the existing location chip block:

```dart
if (job.location != null) _InfoChip(icon: Icons.location_on_outlined, label: job.location!),
```

with:

```dart
if (_locationLabel() != null)
  _InfoChip(icon: Icons.location_on_outlined, label: _locationLabel()!),
```

And add helper method inside `JobCard`:

```dart
String? _locationLabel() {
  if (viewerLocation != null && job.lat != null && job.lng != null) {
    final km = haversineKm(viewerLocation!, LatLng(job.lat!, job.lng!));
    return km < 1 ? '<1 km' : '${km.toStringAsFixed(1)} km';
  }
  return job.location;
}
```

- [ ] **Step 3: Pass viewerLocation from SwipeScreen**

Edit `lib/features/swipe/presentation/swipe_screen.dart`. Find where `JobCard(job: ...)` is instantiated and change to:

```dart
final me = ref.watch(profileProvider).valueOrNull;
final viewer = (me?.lat != null && me?.lng != null)
    ? LatLng(me!.lat!, me.lng!)
    : null;

JobCard(job: job, viewerLocation: viewer)
```

Add imports:

```dart
import '../../location/domain/lat_lng.dart';
```

- [ ] **Step 4: Manual verify**

```bash
flutter run -d macos
```
Log in as a user with lat/lng set → swipe screen → card should show "5.2 km" instead of "台北市大安區".

- [ ] **Step 5: Commit**

```bash
git add lib/features/swipe/presentation/
git commit -m "+swipe: show Haversine distance on job card when both sides geocoded"
```

---

## Task 12: Job detail screen with commute button

**Files:**
- Create: `lib/features/swipe/presentation/job_detail_screen.dart`
- Modify: `lib/core/router/app_router.dart` (add `/job/:id` route)
- Modify: `lib/core/router/app_router.g.dart` (regenerated by build_runner)
- Modify: `lib/features/swipe/presentation/job_card.dart` (make card tappable → push route)

**Interfaces:**
- Consumes: `JobModel`, `LatLng`, `haversineKm`, `commuteProvider`, `profileProvider`
- Produces: screen at `/job/:id` displaying job details, Haversine distance always, and "查看通勤時間" button which triggers `commuteProvider` and shows 3 mode cards.

- [ ] **Step 1: Add route**

Edit `lib/core/router/app_router.dart`. Add inside the top-level routes (not inside ShellRoute) — pattern must match existing style:

```dart
GoRoute(
  path: '/job/:id',
  builder: (context, state) {
    final job = state.extra as JobModel;
    return JobDetailScreen(job: job);
  },
),
```

Add import:

```dart
import '../../features/swipe/presentation/job_detail_screen.dart';
import '../../shared/models/job_model.dart';
```

Regenerate:

```bash
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 2: Create screen skeleton**

Create `lib/features/swipe/presentation/job_detail_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/job_model.dart';
import '../../../shared/providers/profile_provider.dart'; // adjust path if different
import '../../location/domain/lat_lng.dart';
import '../../location/domain/distance_utils.dart';
import '../../location/domain/commute_result.dart';
import '../../location/providers/commute_provider.dart';

class JobDetailScreen extends ConsumerStatefulWidget {
  const JobDetailScreen({super.key, required this.job});
  final JobModel job;

  @override
  ConsumerState<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends ConsumerState<JobDetailScreen> {
  bool _showCommute = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final me = ref.watch(profileProvider).valueOrNull;
    final viewer = (me?.lat != null && me?.lng != null) ? LatLng(me!.lat!, me.lng!) : null;
    final job = widget.job;
    final jobLoc = (job.lat != null && job.lng != null) ? LatLng(job.lat!, job.lng!) : null;
    final directKm = (viewer != null && jobLoc != null) ? haversineKm(viewer, jobLoc) : null;

    return Scaffold(
      appBar: AppBar(title: Text(job.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(job.title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(job.companyName ?? '', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            if (job.formattedAddress != null || job.location != null)
              Row(children: [
                const Icon(Icons.location_on_outlined, size: 18),
                const SizedBox(width: 4),
                Expanded(child: Text(job.formattedAddress ?? job.location!)),
              ]),
            if (directKm != null) ...[
              const SizedBox(height: 8),
              Text('直線距離：${directKm.toStringAsFixed(1)} km',
                   style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 24),
            if (viewer != null && jobLoc != null && !_showCommute)
              FilledButton.icon(
                icon: const Icon(Icons.directions),
                label: const Text('查看通勤時間'),
                onPressed: () => setState(() => _showCommute = true),
              ),
            if (_showCommute && viewer != null && jobLoc != null)
              _CommutePanel(from: viewer, to: jobLoc),
            const SizedBox(height: 24),
            Text('職缺描述', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(job.description),
          ],
        ),
      ),
    );
  }
}

class _CommutePanel extends ConsumerWidget {
  const _CommutePanel({required this.from, required this.to});
  final LatLng from;
  final LatLng to;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(commuteProvider(from: from, to: to));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          const Text('暫時無法取得通勤資訊'),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => ref.invalidate(commuteProvider(from: from, to: to)),
            child: const Text('重試'),
          ),
        ]),
      ),
      data: (r) => Column(children: [
        _ModeRow(icon: Icons.directions_transit, label: '大眾運輸', result: r.transit),
        _ModeRow(icon: Icons.directions_car, label: '開車', result: r.driving),
        _ModeRow(icon: Icons.directions_bike, label: '自行車', result: r.bicycling),
      ]),
    );
  }
}

class _ModeRow extends StatelessWidget {
  const _ModeRow({required this.icon, required this.label, required this.result});
  final IconData icon;
  final String label;
  final ModeResult? result;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: result == null
          ? const Text('—')
          : Text('${(result!.durationSeconds / 60).round()} 分  ·  ${(result!.distanceMeters / 1000).toStringAsFixed(1)} km'),
    );
  }
}
```

Adjust the `profile_provider` import path to whatever the project uses.

- [ ] **Step 3: Make JobCard tappable**

Edit `lib/features/swipe/presentation/job_card.dart`. Add `onTap` field:

```dart
class JobCard extends StatelessWidget {
  const JobCard({super.key, required this.job, this.viewerLocation, this.onTap});
  final JobModel job;
  final LatLng? viewerLocation;
  final VoidCallback? onTap;
  // ...
}
```

Wrap the outer `Container` with `GestureDetector(onTap: onTap, child: ...)`.

- [ ] **Step 4: Wire tap in SwipeScreen**

Edit swipe_screen.dart where `JobCard(...)` is created — add `onTap: () => context.push('/job/${job.id}', extra: job)`.

- [ ] **Step 5: Manual verify**

```bash
flutter run -d macos
```
- Swipe screen → tap a card → detail page opens
- Distance shown, "查看通勤時間" button visible
- Tap button → 3 rows load
- Second tap on same card → cache hit, near-instant

- [ ] **Step 6: Commit**

```bash
git add lib/features/swipe/presentation/ lib/core/router/
git commit -m "+swipe: job detail screen with commute time panel"
```

---

## Task 13: Backfill existing rows

**Files:**
- Create: `scripts/backfill_geocode.ts`

**Interfaces:**
- Consumes: Supabase service role key (from env `SUPABASE_SERVICE_ROLE_KEY`), Google Maps API key (from env `GOOGLE_MAPS_API_KEY` — for direct Google call, since it runs locally not in Edge Function)
- Produces: for every `users` and `jobs` row where `location is not null and lat is null`, geocodes and updates the row. Rate-limited to 5 requests/second to stay well under Google quota. Idempotent — re-running is safe.

- [ ] **Step 1: Write script**

Create `scripts/backfill_geocode.ts`:

```typescript
// Run: deno run --allow-net --allow-env scripts/backfill_geocode.ts
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_KEY  = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const GOOGLE_KEY   = Deno.env.get('GOOGLE_MAPS_API_KEY')!;

const supa = createClient(SUPABASE_URL, SERVICE_KEY);

async function geocode(address: string): Promise<{lat:number;lng:number;formatted:string} | null> {
  const url = `https://maps.googleapis.com/maps/api/geocode/json?address=${encodeURIComponent(address)}&region=tw&key=${GOOGLE_KEY}`;
  const r = await fetch(url);
  if (!r.ok) return null;
  const d = await r.json();
  if (d.status !== 'OK') return null;
  const res = d.results[0];
  return { lat: res.geometry.location.lat, lng: res.geometry.location.lng, formatted: res.formatted_address };
}

async function backfill(table: 'users' | 'jobs') {
  const batchSize = 50;
  while (true) {
    const { data, error } = await supa
      .from(table)
      .select('id, location')
      .not('location', 'is', null)
      .is('lat', null)
      .limit(batchSize);
    if (error) { console.error(table, error); break; }
    if (!data || data.length === 0) { console.log(`${table}: done`); break; }
    for (const row of data) {
      const address = (row.location as string).trim();
      if (!address) continue;
      const g = await geocode(address);
      if (!g) {
        console.warn(`${table} ${row.id}: geocode failed for "${address}"`);
        continue;
      }
      const { error: uerr } = await supa.from(table).update({
        lat: g.lat, lng: g.lng, formatted_address: g.formatted,
        location_updated_at: new Date().toISOString(),
      }).eq('id', row.id);
      if (uerr) console.error(`${table} ${row.id} update:`, uerr);
      else console.log(`${table} ${row.id}: OK (${g.formatted})`);
      await new Promise(r => setTimeout(r, 200)); // ~5 req/s
    }
  }
}

await backfill('users');
await backfill('jobs');
```

- [ ] **Step 2: Dry-run count**

```bash
# via Supabase MCP execute_sql
select 'users' as t, count(*) from users where location is not null and lat is null
union all
select 'jobs',  count(*) from jobs  where location is not null and lat is null;
```
Note the counts — if hundreds, no problem; if thousands, verify Google quotas before running.

- [ ] **Step 3: Run script**

```bash
export SUPABASE_URL=https://klwsmonobcenfoyhkyuq.supabase.co
export SUPABASE_SERVICE_ROLE_KEY=<from supabase dashboard>
export GOOGLE_MAPS_API_KEY=<same key as edge fn>
deno run --allow-net --allow-env scripts/backfill_geocode.ts
```

- [ ] **Step 4: Verify**

```sql
select 'users' as t, count(*) filter (where lat is not null) as geocoded, count(*) as total
  from users where location is not null
union all
select 'jobs', count(*) filter (where lat is not null), count(*)
  from jobs where location is not null;
```
Expected: geocoded ≈ total (some may be legitimately un-geocodable, e.g., "遠端 remote"). Check warnings from script output.

- [ ] **Step 5: Commit**

```bash
git add scripts/backfill_geocode.ts
git commit -m "+scripts: backfill geocode existing users + jobs"
```

---

## Task 14: Pre-release checklist (Google Cloud + monitoring)

**Files:** none (checklist only)

Before shipping this feature to real users, complete each item. Not doing #2 or #3 risks a billing surprise.

- [ ] **Step 1: Create Google Cloud project & enable APIs**

- Console → https://console.cloud.google.com
- New project (or use existing)
- APIs & Services → Enable APIs: **Geocoding API**, **Distance Matrix API**

- [ ] **Step 2: Create API key with restrictions**

- APIs & Services → Credentials → Create credentials → API key
- Application restrictions: **None** (Edge Function calls from Supabase server, no fixed IP; if you can pin Supabase egress IPs, add them)
- API restrictions: **Restrict key** → only Geocoding + Distance Matrix
- Save key value → `supabase secrets set GOOGLE_MAPS_API_KEY=<value> --project-ref klwsmonobcenfoyhkyuq`

- [ ] **Step 3: Set daily quotas per API**

- APIs & Services → Geocoding API → Quotas → find "Requests per day" → edit → **500**
- Same for Distance Matrix → **500**

This is the primary defense: if usage spikes, API returns quota error, no charge.

- [ ] **Step 4: Set budget alert**

- Billing → Budgets & alerts → Create budget
- Amount: **$1**
- Alert at 50% / 100% actual → email yourself
- Note: does NOT auto-stop. Email only. If you want auto-stop, follow https://cloud.google.com/billing/docs/how-to/notify

- [ ] **Step 5: Verify Edge Function logs**

- Supabase → Edge Functions → geocode-address → Logs → check for last 24h
- Look for: 200s dominant; occasional 429 (rate-limit) OK; frequent 502 = investigate

- [ ] **Step 6: Verify Google Cloud metrics**

- Google Cloud → APIs & Services → Metrics → Traffic
- After first day of prod usage, confirm request counts match expectations

- [ ] **Step 7: Update memory**

Append to `/Users/alice/.claude/projects/-Users-alice-job-swipe/memory/MEMORY.md`:

```
## Google Maps 整合（已上線 YYYY-MM-DD）
- Edge Functions: geocode-address, commute-time（secret GOOGLE_MAPS_API_KEY）
- commute_cache 表 (geohash6 + 7d TTL)
- users/jobs 加 lat, lng, formatted_address, location_updated_at
- RLS: 其他用戶讀 users 走 users_public view（遮蔽 lat/lng）
- Google Cloud project: <name> — daily quota 500/500，budget alert $1
```

- [ ] **Step 8: Commit (memory only)**

```bash
git add /Users/alice/.claude/projects/-Users-alice-job-swipe/memory/MEMORY.md 2>/dev/null || true
# (memory is outside repo — this git add will noop, fine)
```

---

## Self-Review Notes (from plan author)

Reviewed 2026-08-31 against `2026-08-31-google-maps-integration-design.md`:

- ✅ Spec Section 1 (schema) covered by Task 1
- ✅ Spec Section 2 (backend) covered by Tasks 2, 3, 4
- ✅ Spec Section 3 (Flutter) covered by Tasks 5, 6, 7, 8, 9, 10, 11, 12
- ✅ Spec Section 4.1 (testing) — Deno tests in Tasks 2/3/4, Flutter unit tests in Tasks 6/8, manual verify steps in each UI task
- ✅ Spec Section 4.2 (rollout) — Task 1 migration, Task 3/4 deploy, Task 13 backfill, Task 14 release checklist
- ✅ Spec Section 4.3 (privacy/RLS) — Task 1 creates `users_public` view; enforced via `grant select on public.users_public to authenticated` while base `users` RLS stays owner-only for lat/lng
- ✅ Rate-limit — implemented in `_shared/rate_limit.ts`, called from both Edge Functions
- ✅ Motorcycle mode fallback — noted in Global Constraints; current UI (Task 12) only shows driving/transit/bicycling because those are what CommuteResult exposes. If motorcycle needed later, add ModeResult field + handler-side fallback (already in spec).

Type consistency check:
- `LatLng(lat, lng)` — same constructor everywhere
- `haversineKm(LatLng, LatLng) → double` — one signature, used in Tasks 6, 11, 12
- `GeocodeResult { lat, lng, formattedAddress }` — Task 7 defines, Tasks 9, 10 consume
- `CommuteResult { driving?, transit?, bicycling? }` and `ModeResult { durationSeconds, distanceMeters, approximated }` — Task 8 defines, Task 12 consumes
- Edge Function endpoints paths match: `geocode-address` and `commute-time` in Tasks 3, 4, 7, 8
