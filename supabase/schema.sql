-- 地方選舉候選人管理系統：Supabase 第一階段資料庫
-- 在 Supabase SQL Editor 以管理員身分執行一次。
create extension if not exists pgcrypto;

create table if not exists public.candidates (
  id uuid primary key default gen_random_uuid(),
  data jsonb not null,
  published_data jsonb,
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid,
  action text not null,
  candidate_id uuid,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create or replace function public.is_authorized_election_admin()
returns boolean
language sql
stable
security invoker
set search_path = public
as $$
  select auth.uid() = 'feec62cf-3af7-4315-add9-96b6aeb117ff'::uuid
     and coalesce(auth.jwt() ->> 'aal', '') = 'aal2';
$$;

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists candidates_set_updated_at on public.candidates;
create trigger candidates_set_updated_at
before update on public.candidates
for each row execute function public.set_updated_at();

create or replace function public.log_candidate_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_action text;
  v_id uuid;
begin
  if tg_op = 'INSERT' then
    v_action := 'insert'; v_id := new.id;
  elsif tg_op = 'UPDATE' then
    v_action := case when old.is_published is distinct from new.is_published
                     then 'publication_status_changed' else 'update' end;
    v_id := new.id;
  else
    v_action := 'delete'; v_id := old.id;
  end if;
  insert into public.audit_logs(actor_id, action, candidate_id, details)
  values (auth.uid(), v_action, v_id,
          jsonb_build_object('table', 'candidates', 'operation', tg_op));
  if tg_op = 'DELETE' then return old; else return new; end if;
end;
$$;

drop trigger if exists candidates_audit on public.candidates;
create trigger candidates_audit
after insert or update or delete on public.candidates
for each row execute function public.log_candidate_change();

alter table public.candidates enable row level security;
alter table public.audit_logs enable row level security;

-- 公開訪客只看已發布的列；欄位權限也限制只讀 published_data。
revoke all on public.candidates from anon, authenticated;
grant select (id, published_data, is_published, created_at, updated_at)
  on public.candidates to anon;
grant select (id, data, published_data, is_published, created_at, updated_at),
      insert (data, published_data, is_published),
      update (data, published_data, is_published),
      delete
  on public.candidates to authenticated;

drop policy if exists "public_read_published_candidates" on public.candidates;
create policy "public_read_published_candidates"
on public.candidates for select to anon
using (is_published = true and published_data is not null);

drop policy if exists "admin_select_candidates_aal2" on public.candidates;
create policy "admin_select_candidates_aal2"
on public.candidates for select to authenticated
using (public.is_authorized_election_admin());

drop policy if exists "admin_insert_candidates_aal2" on public.candidates;
create policy "admin_insert_candidates_aal2"
on public.candidates for insert to authenticated
with check (public.is_authorized_election_admin() and is_published = false and published_data is null);

drop policy if exists "admin_update_candidates_aal2" on public.candidates;
create policy "admin_update_candidates_aal2"
on public.candidates for update to authenticated
using (public.is_authorized_election_admin())
with check (public.is_authorized_election_admin());

drop policy if exists "admin_delete_candidates_aal2" on public.candidates;
create policy "admin_delete_candidates_aal2"
on public.candidates for delete to authenticated
using (public.is_authorized_election_admin());

grant select on public.audit_logs to authenticated;
drop policy if exists "admin_read_audit_logs_aal2" on public.audit_logs;
create policy "admin_read_audit_logs_aal2"
on public.audit_logs for select to authenticated
using (public.is_authorized_election_admin());

create or replace function public.publish_candidate(candidate_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare v_row public.candidates;
begin
  if not public.is_authorized_election_admin() then
    raise exception 'admin AAL2 required';
  end if;
  update public.candidates
     set published_data = data, is_published = true
   where id = candidate_id
   returning * into v_row;
  if not found then raise exception 'candidate not found'; end if;
  return jsonb_build_object('id', v_row.id, 'is_published', v_row.is_published);
end;
$$;

create or replace function public.publish_all_candidate_drafts()
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare v_count integer;
begin
  if not public.is_authorized_election_admin() then
    raise exception 'admin AAL2 required';
  end if;
  update public.candidates
     set published_data = data, is_published = true
   where is_published = false;
  get diagnostics v_count = row_count;
  return jsonb_build_object('published_count', v_count);
end;
$$;

grant execute on function public.publish_candidate(uuid) to authenticated;
grant execute on function public.publish_all_candidate_drafts() to authenticated;

-- 匯入資料一律為草稿；管理員需在後台逐筆或全部發布。
