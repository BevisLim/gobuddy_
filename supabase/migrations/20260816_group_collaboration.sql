-- GoBuddy: Group Communication and Collaboration
-- Run this in Supabase SQL Editor after the matchmaking schema is installed.

create table if not exists public.trip_members (
  trip_id uuid not null references public.matchmaking_trips(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  muted_until timestamptz,
  created_at timestamptz not null default now(),
  primary key (trip_id, user_id)
);

create table if not exists public.trip_messages (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.matchmaking_trips(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(trim(body)) between 1 and 2000),
  sent_at timestamptz not null default now()
);

create table if not exists public.trip_activities (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.matchmaking_trips(id) on delete cascade,
  title text not null check (char_length(trim(title)) between 1 and 160),
  location text,
  start_time timestamptz not null,
  is_pinned boolean not null default false,
  is_locked boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.trip_polls (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.matchmaking_trips(id) on delete cascade,
  question text not null check (char_length(trim(question)) between 1 and 280),
  created_at timestamptz not null default now()
);

create table if not exists public.trip_poll_options (
  id uuid primary key default gen_random_uuid(),
  poll_id uuid not null references public.trip_polls(id) on delete cascade,
  label text not null check (char_length(trim(label)) between 1 and 160),
  created_at timestamptz not null default now()
);

create table if not exists public.trip_poll_votes (
  poll_id uuid not null references public.trip_polls(id) on delete cascade,
  option_id uuid not null references public.trip_poll_options(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (poll_id, user_id)
);

create table if not exists public.trip_files (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.matchmaking_trips(id) on delete cascade,
  file_name text not null,
  file_url text not null,
  storage_path text not null unique,
  uploaded_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.trip_calls (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.matchmaking_trips(id) on delete cascade,
  initiated_by uuid not null default auth.uid() references auth.users(id),
  call_type text not null check (call_type in ('voice', 'video')),
  status text not null default 'ringing' check (status in ('ringing', 'active', 'ended')),
  created_at timestamptz not null default now()
);

create index if not exists trip_messages_trip_sent_idx on public.trip_messages(trip_id, sent_at);
create index if not exists trip_activities_trip_time_idx on public.trip_activities(trip_id, is_pinned desc, start_time);
create index if not exists trip_files_trip_created_idx on public.trip_files(trip_id, created_at desc);

-- Seed collaboration access for existing trip owners and accepted members.
insert into public.trip_members (trip_id, user_id)
select id, owner_id from public.matchmaking_trips
on conflict (trip_id, user_id) do nothing;

insert into public.trip_members (trip_id, user_id)
select trip_id, user_id from public.matchmaking_trip_members
on conflict (trip_id, user_id) do nothing;

create or replace function public.add_collaboration_member_for_matchmaking_trip()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.trip_members (trip_id, user_id)
  values (new.trip_id, new.user_id)
  on conflict (trip_id, user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists sync_matchmaking_trip_member_to_collaboration on public.matchmaking_trip_members;
create trigger sync_matchmaking_trip_member_to_collaboration
  after insert on public.matchmaking_trip_members
  for each row execute procedure public.add_collaboration_member_for_matchmaking_trip();

-- Security helper: avoids cyclic RLS lookups on trip_members.
create or replace function public.is_trip_member(p_trip_id uuid)
returns boolean language sql security definer set search_path = public stable as $$
  select exists (select 1 from public.trip_members where trip_id = p_trip_id and user_id = auth.uid());
$$;

create or replace function public.is_trip_creator(p_trip_id uuid)
returns boolean language sql security definer set search_path = public stable as $$
  select exists (select 1 from public.matchmaking_trips where id = p_trip_id and owner_id = auth.uid());
$$;

-- One vote per person per poll. The RPC replaces an earlier vote atomically.
create or replace function public.cast_trip_poll_vote(p_poll_id uuid, p_option_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_trip_id uuid;
begin
  select trip_id into v_trip_id from public.trip_polls where id = p_poll_id;
  if v_trip_id is null or not public.is_trip_member(v_trip_id) then
    raise exception 'Not permitted to vote in this poll';
  end if;
  if not exists (select 1 from public.trip_poll_options where id = p_option_id and poll_id = p_poll_id) then
    raise exception 'Option does not belong to this poll';
  end if;
  delete from public.trip_poll_votes where poll_id = p_poll_id and user_id = auth.uid();
  insert into public.trip_poll_votes(poll_id, option_id, user_id) values (p_poll_id, p_option_id, auth.uid());
end;
$$;

alter table public.trip_members enable row level security;
alter table public.trip_messages enable row level security;
alter table public.trip_activities enable row level security;
alter table public.trip_polls enable row level security;
alter table public.trip_poll_options enable row level security;
alter table public.trip_poll_votes enable row level security;
alter table public.trip_files enable row level security;
alter table public.trip_calls enable row level security;

drop policy if exists "members can read membership" on public.trip_members;
drop policy if exists "creator can manage membership" on public.trip_members;
drop policy if exists "members read messages" on public.trip_messages;
drop policy if exists "unmuted members send messages" on public.trip_messages;
drop policy if exists "members read activities" on public.trip_activities;
drop policy if exists "members add activities" on public.trip_activities;
drop policy if exists "members edit unlocked activities" on public.trip_activities;
drop policy if exists "members read polls" on public.trip_polls;
drop policy if exists "members read options" on public.trip_poll_options;
drop policy if exists "members read votes" on public.trip_poll_votes;
drop policy if exists "members read files" on public.trip_files;
drop policy if exists "members add files" on public.trip_files;
drop policy if exists "members read calls" on public.trip_calls;
drop policy if exists "members start calls" on public.trip_calls;
drop policy if exists "members upload trip documents" on storage.objects;
drop policy if exists "members read trip documents" on storage.objects;

create policy "members can read membership" on public.trip_members for select using (public.is_trip_member(trip_id));
create policy "creator can manage membership" on public.trip_members for all using (public.is_trip_creator(trip_id)) with check (public.is_trip_creator(trip_id));
create policy "members read messages" on public.trip_messages for select using (public.is_trip_member(trip_id));
create policy "unmuted members send messages" on public.trip_messages for insert with check (
  sender_id = auth.uid() and public.is_trip_member(trip_id) and not exists (
    select 1 from public.trip_members where trip_id = trip_messages.trip_id and user_id = auth.uid() and muted_until > now()
  )
);
create policy "members read activities" on public.trip_activities for select using (public.is_trip_member(trip_id));
create policy "members add activities" on public.trip_activities for insert with check (public.is_trip_member(trip_id));
create policy "members edit unlocked activities" on public.trip_activities for update using (public.is_trip_member(trip_id) and (not is_locked or public.is_trip_creator(trip_id)));
create policy "members read polls" on public.trip_polls for select using (public.is_trip_member(trip_id));
create policy "members read options" on public.trip_poll_options for select using (exists (select 1 from public.trip_polls p where p.id = poll_id and public.is_trip_member(p.trip_id)));
create policy "members read votes" on public.trip_poll_votes for select using (exists (select 1 from public.trip_polls p where p.id = poll_id and public.is_trip_member(p.trip_id)));
create policy "members read files" on public.trip_files for select using (public.is_trip_member(trip_id));
create policy "members add files" on public.trip_files for insert with check (uploaded_by = auth.uid() and public.is_trip_member(trip_id));
create policy "members read calls" on public.trip_calls for select using (public.is_trip_member(trip_id));
create policy "members start calls" on public.trip_calls for insert with check (initiated_by = auth.uid() and public.is_trip_member(trip_id));

insert into storage.buckets (id, name, public) values ('trip-documents', 'trip-documents', true) on conflict (id) do nothing;
create policy "members upload trip documents" on storage.objects for insert to authenticated with check (
  bucket_id = 'trip-documents' and public.is_trip_member((storage.foldername(name))[1]::uuid)
);
create policy "members read trip documents" on storage.objects for select to authenticated using (
  bucket_id = 'trip-documents' and public.is_trip_member((storage.foldername(name))[1]::uuid)
);

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'trip_messages'
  ) then
    alter publication supabase_realtime add table public.trip_messages;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'trip_activities'
  ) then
    alter publication supabase_realtime add table public.trip_activities;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'trip_files'
  ) then
    alter publication supabase_realtime add table public.trip_files;
  end if;
end;
$$;
