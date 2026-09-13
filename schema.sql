-- ============================================================================
-- Layover — database schema
-- Paste the whole file into Supabase → SQL Editor → Run.
-- Safe to re-run: it drops and recreates its own objects.
-- ============================================================================

drop table if exists public.friendships   cascade;
drop table if exists public.gate_members  cascade;
drop table if exists public.gates         cascade;
drop table if exists public.classes       cascade;
drop table if exists public.profiles      cascade;
drop function if exists public.my_profile_id() cascade;
drop function if exists public.handle_new_user() cascade;

-- ---------------------------------------------------------------- profiles --
-- A profile is separable from an auth user so the demo students (user_id null)
-- can sit on the same board as real ones.
create table public.profiles (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid unique references auth.users(id) on delete cascade,
  display_name  text not null check (char_length(display_name) between 1 and 40),
  major         text not null default '',
  year          text not null default '',
  route         text not null default 'qusais',
  place         text not null default 'Innovation Center atrium',
  quiet         boolean not null default false,
  visible       boolean not null default true,   -- show me on the board
  is_demo       boolean not null default false,
  created_at    timestamptz not null default now()
);

-- ----------------------------------------------------------------- classes --
create table public.classes (
  id          uuid primary key default gen_random_uuid(),
  profile_id  uuid not null references public.profiles(id) on delete cascade,
  code        text not null check (char_length(code) between 1 and 16),
  day         text not null check (day in ('Mon','Tue','Wed','Thu','Fri')),
  start_min   int  not null check (start_min between 0 and 1439),
  end_min     int  not null check (end_min   between 1 and 1440),
  check (end_min > start_min)
);
create index classes_profile_idx on public.classes(profile_id);

-- ------------------------------------------------------------------- gates --
create table public.gates (
  id          uuid primary key default gen_random_uuid(),
  host_id     uuid not null references public.profiles(id) on delete cascade,
  title       text not null check (char_length(title) between 1 and 80),
  kind        text not null default 'study' check (kind in ('study','coop','move','quiet')),
  place       text not null,
  day         text not null check (day in ('Mon','Tue','Wed','Thu','Fri')),
  start_min   int  not null check (start_min between 0 and 1439),
  end_min     int  not null check (end_min   between 1 and 1440),
  capacity    int  not null default 6 check (capacity between 2 and 40),
  note        text not null default '',
  created_at  timestamptz not null default now(),
  check (end_min > start_min)
);

create table public.gate_members (
  gate_id    uuid not null references public.gates(id)    on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  joined_at  timestamptz not null default now(),
  primary key (gate_id, profile_id)
);

-- ------------------------------------------------------------- friendships --
create table public.friendships (
  id            uuid primary key default gen_random_uuid(),
  requester_id  uuid not null references public.profiles(id) on delete cascade,
  addressee_id  uuid not null references public.profiles(id) on delete cascade,
  status        text not null default 'pending' check (status in ('pending','accepted')),
  created_at    timestamptz not null default now(),
  unique (requester_id, addressee_id),
  check (requester_id <> addressee_id)
);

-- ----------------------------------------------------------------- helpers --
create or replace function public.my_profile_id()
returns uuid language sql stable security definer set search_path = public as $$
  select id from public.profiles where user_id = auth.uid()
$$;

-- a profile row is created automatically the moment someone signs up
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (user_id, display_name)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data->>'display_name',''), split_part(new.email,'@',1))
  );
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ================================ ROW LEVEL SECURITY ========================
alter table public.profiles     enable row level security;
alter table public.classes      enable row level security;
alter table public.gates        enable row level security;
alter table public.gate_members enable row level security;
alter table public.friendships  enable row level security;

-- profiles: anyone may read the ones that opted in; you may only write your own
create policy profiles_read   on public.profiles for select
  using (visible or user_id = auth.uid());
create policy profiles_insert on public.profiles for insert
  with check (user_id = auth.uid());
create policy profiles_update on public.profiles for update
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- classes: readable when the owning profile is on the board; writable only by its owner
create policy classes_read on public.classes for select
  using (exists (select 1 from public.profiles p
                 where p.id = profile_id and (p.visible or p.user_id = auth.uid())));
create policy classes_write on public.classes for all
  using      (profile_id = public.my_profile_id())
  with check (profile_id = public.my_profile_id());

-- gates: public to read, host-only to change
create policy gates_read   on public.gates for select using (true);
create policy gates_insert on public.gates for insert with check (host_id = public.my_profile_id());
create policy gates_update on public.gates for update
  using (host_id = public.my_profile_id()) with check (host_id = public.my_profile_id());
create policy gates_delete on public.gates for delete using (host_id = public.my_profile_id());

-- membership: visible to everyone (capacity is public), but you only join/leave as yourself
create policy members_read  on public.gate_members for select using (true);
create policy members_join  on public.gate_members for insert with check (profile_id = public.my_profile_id());
create policy members_leave on public.gate_members for delete using (profile_id = public.my_profile_id());

-- friendships: only the two people involved can see the row
create policy friends_read on public.friendships for select
  using (requester_id = public.my_profile_id() or addressee_id = public.my_profile_id());
create policy friends_ask on public.friendships for insert
  with check (requester_id = public.my_profile_id());
create policy friends_accept on public.friendships for update      -- only the addressee accepts
  using (addressee_id = public.my_profile_id()) with check (addressee_id = public.my_profile_id());
create policy friends_remove on public.friendships for delete
  using (requester_id = public.my_profile_id() or addressee_id = public.my_profile_id());

-- =============================== REALTIME ===================================
alter publication supabase_realtime add table public.gates;
alter publication supabase_realtime add table public.gate_members;
alter publication supabase_realtime add table public.classes;
alter publication supabase_realtime add table public.profiles;

-- ============================ DEMO POPULATION ===============================
-- So a judge who never signs in still sees a working, populated board.
-- These rows have no auth user behind them and are flagged is_demo.
insert into public.profiles (id, display_name, major, year, route, place, quiet, is_demo) values
  ('11111111-1111-4111-8111-000000000001','Aisha R.',  'Mechanical Eng',    'Y2','sharjah','Library L2 — Quiet Wing',      false,true),
  ('11111111-1111-4111-8111-000000000002','Rayan K.',  'Computing Security','Y2','qusais', 'Innovation Center atrium',     false,true),
  ('11111111-1111-4111-8111-000000000003','Mariam H.', 'Business',          'Y3','ajman',  'Building 1 food court',        true, true),
  ('11111111-1111-4111-8111-000000000004','Yusuf A.',  'Electrical Eng',    'Y1','deira',  'Makerspace',                   false,true),
  ('11111111-1111-4111-8111-000000000005','Nikhil S.', 'Software Eng',      'Y3','mirdif', 'Sports hall',                  false,true),
  ('11111111-1111-4111-8111-000000000006','Sara M.',   'Industrial Eng',    'Y2','barsha', 'Prayer room',                  true, true),
  ('11111111-1111-4111-8111-000000000007','Omar B.',   'Computing',         'Y1','qusais', 'Co-op office corridor',        false,true),
  ('11111111-1111-4111-8111-000000000008','Fatima Z.', 'Chemical Eng',      'Y2','sharjah','Shaded courtyard',             false,true),
  ('11111111-1111-4111-8111-000000000009','Daniyal I.','Software Eng',      'Y2','ajman',  'Study pods B2',                false,true),
  ('11111111-1111-4111-8111-00000000000a','Leen F.',   'Business Analytics','Y3','dso',    'Library L1 — group tables',    true, true),
  ('11111111-1111-4111-8111-00000000000b','Tariq E.',  'Business',          'Y2','qusais', 'Sports hall',                  false,true),
  ('11111111-1111-4111-8111-00000000000c','Noor J.',   'Computing',         'Y2','sharjah','Prayer room',                  true, true);

insert into public.classes (profile_id, code, day, start_min, end_min) values
  ('11111111-1111-4111-8111-000000000001','MECE-205','Mon',480,590),('11111111-1111-4111-8111-000000000001','MATH-182','Mon',800,910),
  ('11111111-1111-4111-8111-000000000001','PHYS-211','Tue',600,710),('11111111-1111-4111-8111-000000000001','MECE-205','Wed',480,590),
  ('11111111-1111-4111-8111-000000000001','PHYS-211','Thu',600,710),
  ('11111111-1111-4111-8111-000000000002','CSCI-142','Mon',780,910),('11111111-1111-4111-8111-000000000002','ISTE-230','Tue',540,650),
  ('11111111-1111-4111-8111-000000000002','MGMT-101','Tue',840,910),('11111111-1111-4111-8111-000000000002','CSCI-142','Wed',660,770),
  ('11111111-1111-4111-8111-000000000002','ISTE-230','Thu',540,650),
  ('11111111-1111-4111-8111-000000000003','ACCT-110','Mon',540,650),('11111111-1111-4111-8111-000000000003','MGMT-101','Mon',810,920),
  ('11111111-1111-4111-8111-000000000003','MKTG-230','Tue',720,830),('11111111-1111-4111-8111-000000000003','ACCT-110','Wed',540,650),
  ('11111111-1111-4111-8111-000000000003','MKTG-230','Thu',720,830),
  ('11111111-1111-4111-8111-000000000004','EEEE-281','Mon',600,710),('11111111-1111-4111-8111-000000000004','MATH-181','Tue',480,590),
  ('11111111-1111-4111-8111-000000000004','PHYS-211','Tue',780,890),('11111111-1111-4111-8111-000000000004','EEEE-281','Wed',600,710),
  ('11111111-1111-4111-8111-000000000004','MATH-181','Thu',480,590),
  ('11111111-1111-4111-8111-000000000005','SWEN-261','Mon',840,950),('11111111-1111-4111-8111-000000000005','CSCI-142','Tue',660,770),
  ('11111111-1111-4111-8111-000000000005','SWEN-261','Wed',840,950),('11111111-1111-4111-8111-000000000005','CSCI-142','Thu',660,770),
  ('11111111-1111-4111-8111-000000000005','ISTE-230','Thu',960,1070),
  ('11111111-1111-4111-8111-000000000006','STAT-145','Mon',720,830),('11111111-1111-4111-8111-000000000006','MECE-205','Tue',900,1010),
  ('11111111-1111-4111-8111-000000000006','STAT-145','Wed',720,830),('11111111-1111-4111-8111-000000000006','MECE-205','Thu',900,1010),
  ('11111111-1111-4111-8111-000000000007','CSCI-141','Mon',540,650),('11111111-1111-4111-8111-000000000007','MATH-181','Tue',540,650),
  ('11111111-1111-4111-8111-000000000007','CSCI-141','Wed',540,650),('11111111-1111-4111-8111-000000000007','ENGL-210','Wed',960,1070),
  ('11111111-1111-4111-8111-000000000007','MATH-181','Thu',540,650),
  ('11111111-1111-4111-8111-000000000008','CHMG-141','Mon',480,590),('11111111-1111-4111-8111-000000000008','MATH-182','Mon',900,1010),
  ('11111111-1111-4111-8111-000000000008','CHMG-141','Tue',780,890),('11111111-1111-4111-8111-000000000008','CHMG-141','Wed',480,590),
  ('11111111-1111-4111-8111-000000000008','PHYS-211','Thu',780,890),
  ('11111111-1111-4111-8111-000000000009','SWEN-261','Mon',660,770),('11111111-1111-4111-8111-000000000009','ISTE-230','Tue',600,710),
  ('11111111-1111-4111-8111-000000000009','SWEN-261','Wed',660,770),('11111111-1111-4111-8111-000000000009','ISTE-230','Thu',600,710),
  ('11111111-1111-4111-8111-00000000000a','STAT-145','Mon',780,890),('11111111-1111-4111-8111-00000000000a','MKTG-230','Tue',660,770),
  ('11111111-1111-4111-8111-00000000000a','STAT-145','Wed',780,890),('11111111-1111-4111-8111-00000000000a','ACCT-110','Thu',960,1070),
  ('11111111-1111-4111-8111-00000000000b','MGMT-101','Mon',840,910),('11111111-1111-4111-8111-00000000000b','ACCT-110','Tue',600,710),
  ('11111111-1111-4111-8111-00000000000b','MGMT-101','Wed',840,910),('11111111-1111-4111-8111-00000000000b','ACCT-110','Thu',600,710),
  ('11111111-1111-4111-8111-00000000000b','MKTG-230','Thu',960,1070),
  ('11111111-1111-4111-8111-00000000000c','CSCI-142','Mon',800,915),('11111111-1111-4111-8111-00000000000c','ISTE-230','Tue',780,890),
  ('11111111-1111-4111-8111-00000000000c','CSCI-142','Wed',780,890),('11111111-1111-4111-8111-00000000000c','SWEN-261','Thu',660,770);

insert into public.gates (id, host_id, title, kind, place, day, start_min, end_min, capacity, note) values
  ('22222222-2222-4222-8222-000000000001','11111111-1111-4111-8111-000000000007','MATH-181 problem set, together','study','Library L1 — group tables','Mon',910,1000,6,'Bring the question you are stuck on. Nobody teaches, everyone works.'),
  ('22222222-2222-4222-8222-000000000002','11111111-1111-4111-8111-000000000003','Co-op mock interview — 20 min each','coop','Co-op office corridor','Tue',920,1020,8,'Two chairs, one timer, questions from last year''s placements.'),
  ('22222222-2222-4222-8222-000000000003','11111111-1111-4111-8111-000000000006','Quiet Gate — company, no conversation','quiet','Library L2 — Quiet Wing','Mon',900,1080,12,'Sit together, do not talk. That is the whole rule.'),
  ('22222222-2222-4222-8222-000000000004','11111111-1111-4111-8111-000000000002','Sports hall — pickup, 5-a-side','move','Sports hall','Wed',915,1050,14,'Indoor and air-conditioned. Ends 17:30, so the 18:00 is safe.'),
  ('22222222-2222-4222-8222-000000000005','11111111-1111-4111-8111-000000000005','SWEN-261 lab catch-up','study','Study pods B2','Thu',780,885,5,'Whiteboard booked.'),
  ('22222222-2222-4222-8222-000000000006','11111111-1111-4111-8111-000000000004','Iced karak + laps of the courtyard','move','Shaded courtyard','Tue',910,955,10,'Forty-five minutes, no commitment.'),
  ('22222222-2222-4222-8222-000000000007','11111111-1111-4111-8111-000000000008','PHYS-211 exam review, whiteboard','study','Library L1 — group tables','Wed',960,1065,8,'Last year''s paper, worked from the marking scheme. Bring your own copy.'),
  ('22222222-2222-4222-8222-000000000008','11111111-1111-4111-8111-00000000000a','CV surgery — 15 minutes, one page','coop','Innovation Center atrium','Thu',910,1020,6,'Third-years who have done co-op read your CV.'),
  ('22222222-2222-4222-8222-000000000009','11111111-1111-4111-8111-00000000000a','Reading hour — phones in the box','quiet','Library L2 — Quiet Wing','Thu',975,1065,10,'Anything that is not coursework. Phones go in the box.'),
  ('22222222-2222-4222-8222-00000000000a','11111111-1111-4111-8111-000000000009','First-year drop-in — ask anything','study','Building 1 food court','Mon',720,810,12,'Add/drop, office hours, co-op deadlines. No question is too basic.');

-- a plausible amount of existing interest in each gate
insert into public.gate_members (gate_id, profile_id)
select g.id, p.id
from public.gates g
join lateral (
  select id from public.profiles
  where is_demo and id <> g.host_id
  order by md5(id::text || g.id::text)
  limit greatest(1, (g.capacity / 2))
) p on true;
