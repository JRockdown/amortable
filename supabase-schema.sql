-- Amortable — cloud Save/Recall schema (Supabase / Postgres)
-- Run this once in the Supabase SQL editor (Project → SQL → New query → paste → Run).
-- Interim model: no login. A random client "workspace" code namespaces each user's data.
-- The table is not directly readable; all access goes through the RPCs below, which require
-- the workspace code. A 128-bit random code is effectively a private key.
-- Later, real accounts: replace the `ws` argument with auth.uid() and add per-user RLS.

create table if not exists public.leases (
  workspace  text        not null,
  kind       text        not null check (kind in ('lease','template')),
  name       text        not null,
  data       jsonb       not null,
  updated_at timestamptz not null default now(),
  primary key (workspace, kind, name)
);

-- Lock the table: RLS on and no policies => anon/authenticated cannot touch it directly.
alter table public.leases enable row level security;

-- Access is only via these SECURITY DEFINER functions, which scope everything to `ws`.
create or replace function public.leases_list(ws text)
returns table(kind text, name text, updated_at timestamptz)
language sql security definer set search_path = public as $$
  select kind, name, updated_at from public.leases where workspace = ws order by kind, name;
$$;

create or replace function public.leases_get(ws text, k text, n text)
returns jsonb
language sql security definer set search_path = public as $$
  select data from public.leases where workspace = ws and kind = k and name = n;
$$;

create or replace function public.leases_put(ws text, k text, n text, d jsonb)
returns void
language sql security definer set search_path = public as $$
  insert into public.leases(workspace, kind, name, data, updated_at)
  values (ws, k, n, d, now())
  on conflict (workspace, kind, name) do update set data = excluded.data, updated_at = now();
$$;

create or replace function public.leases_delete(ws text, k text, n text)
returns void
language sql security definer set search_path = public as $$
  delete from public.leases where workspace = ws and kind = k and name = n;
$$;

-- Allow the public (anon) key to execute the RPCs. Callers must still supply a valid `ws`.
grant execute on function public.leases_list(text)               to anon;
grant execute on function public.leases_get(text, text, text)    to anon;
grant execute on function public.leases_put(text, text, text, jsonb) to anon;
grant execute on function public.leases_delete(text, text, text) to anon;
