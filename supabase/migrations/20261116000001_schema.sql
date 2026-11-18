-- EVYAHE database schema (Supabase / PostgreSQL + PostGIS).
-- Tables are grouped by the module that owns them. Row-level security is in
-- the next migration.

create extension if not exists postgis with schema extensions;

-- ───────────────────────── Reference data (M5) ─────────────────────────

create table public.vehicles (
  id uuid primary key default gen_random_uuid(),
  brand text not null,
  model text not null,
  type text not null check (type in ('bev', 'phev', 'reev')),
  connectors text[] not null,
  battery_kwh numeric not null check (battery_kwh > 0),
  -- Rated energy use. Electric-only figure for PHEV and REEV.
  kwh_per_km numeric not null check (kwh_per_km > 0),
  source text not null default '',
  collected_on date not null default current_date,
  unique (brand, model)
);

create table public.reference_data (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  value text not null,
  source text not null,
  collected_on date not null default current_date
);

-- ───────────────────────── Users (RBAC) ─────────────────────────

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  name text not null,
  -- Platform role. Leader and officer are per-community roles.
  role text not null default 'member'
    check (role in ('admin', 'member', 'guest', 'provider')),
  region text not null default '',
  vehicle_id uuid references public.vehicles (id) on delete set null,
  verification text not null default 'none'
    check (verification in ('none', 'pending', 'verified', 'rejected')),
  created_at timestamptz not null default now()
);

-- ─────────────────── M1 Community & Tribe Management ───────────────────

create table public.communities (
  id uuid primary key default gen_random_uuid(),
  -- Set for a tribe; null for a community.
  parent_id uuid references public.communities (id) on delete cascade,
  name text not null check (char_length(name) >= 3),
  type text not null check (type in ('brand', 'model', 'region', 'interest')),
  description text not null default '',
  rules text not null default '',
  join_policy text not null default 'open'
    check (join_policy in ('open', 'approval')),
  requires_verification boolean not null default false,
  criteria_model text,
  criteria_region text,
  members_can_propose boolean not null default true,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);
create index communities_parent_idx on public.communities (parent_id);

create table public.community_members (
  community_id uuid not null references public.communities (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  role text not null default 'member'
    check (role in ('leader', 'officer', 'member')),
  joined_at timestamptz not null default now(),
  primary key (community_id, user_id)
);
create index community_members_user_idx on public.community_members (user_id);

create table public.join_requests (
  community_id uuid not null references public.communities (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (community_id, user_id)
);

-- ───────────────────── M4 EV Charging & Services ─────────────────────
-- Stations come first because concerns and events refer to them.

create table public.stations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  operator text not null default '',
  address text not null default '',
  city text not null default '',
  lat double precision not null,
  lng double precision not null,
  location extensions.geography (point, 4326) generated always as (
    extensions.st_setsrid(extensions.st_makepoint(lng, lat), 4326)::extensions.geography
  ) stored,
  -- [{"type": "ccs2", "power_kw": 60}, ...]
  connectors jsonb not null default '[]',
  fee text not null default '',
  fee_date date not null default current_date,
  hours text not null default '',
  parking text not null default '',
  source text not null,
  source_date date not null default current_date
);
create index stations_location_idx on public.stations using gist (location);

create table public.status_reports (
  id uuid primary key default gen_random_uuid(),
  station_id uuid not null references public.stations (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  working boolean not null,
  note text not null default '',
  created_at timestamptz not null default now()
);
create index status_reports_station_idx
  on public.status_reports (station_id, created_at desc);

-- One open check-in per user per station. The app treats check-ins older
-- than two hours as expired.
create table public.check_ins (
  station_id uuid not null references public.stations (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  charging boolean not null,
  created_at timestamptz not null default now(),
  primary key (station_id, user_id)
);

create table public.providers (
  id uuid primary key default gen_random_uuid(),
  -- Null for directory entries seeded from brand service networks.
  owner_id uuid references public.profiles (id) on delete set null,
  name text not null,
  category text not null
    check (category in ('service', 'parts', 'tires', 'dealership')),
  description text not null default '',
  brands text[] not null default '{}',
  services text[] not null default '{}',
  address text not null default '',
  city text not null default '',
  lat double precision not null,
  lng double precision not null,
  contact text not null default '',
  -- Approved listings are shown as verified providers.
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now()
);

-- "Recommended by our tribe" marks.
create table public.provider_recommendations (
  provider_id uuid not null references public.providers (id) on delete cascade,
  tribe_id uuid not null references public.communities (id) on delete cascade,
  primary key (provider_id, tribe_id)
);

-- ─────────────── M2 Community Engagement & Governance ───────────────

create table public.announcements (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities (id) on delete cascade,
  author_id uuid not null references public.profiles (id) on delete cascade,
  title text not null,
  body text not null,
  pinned boolean not null default false,
  created_at timestamptz not null default now()
);
create index announcements_community_idx on public.announcements (community_id);

create table public.discussions (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities (id) on delete cascade,
  author_id uuid not null references public.profiles (id) on delete cascade,
  title text not null,
  body text not null,
  topic text not null,
  vehicle_model text,
  is_question boolean not null default false,
  created_at timestamptz not null default now()
);
create index discussions_community_idx on public.discussions (community_id);

create table public.replies (
  id uuid primary key default gen_random_uuid(),
  discussion_id uuid not null references public.discussions (id) on delete cascade,
  author_id uuid not null references public.profiles (id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now()
);
create index replies_discussion_idx on public.replies (discussion_id);

create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  target_type text not null check (target_type in ('station', 'provider')),
  target_id uuid not null,
  author_id uuid not null references public.profiles (id) on delete cascade,
  rating int not null check (rating between 1 and 5),
  tags text[] not null default '{}',
  body text not null,
  created_at timestamptz not null default now()
);
create index reviews_target_idx on public.reviews (target_type, target_id);

-- Helpfulness votes on discussions, replies and reviews.
create table public.helpful_votes (
  target_type text not null check (target_type in ('discussion', 'reply', 'review')),
  target_id uuid not null,
  user_id uuid not null references public.profiles (id) on delete cascade,
  primary key (target_type, target_id, user_id)
);

create table public.proposals (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities (id) on delete cascade,
  author_id uuid not null references public.profiles (id) on delete cascade,
  title text not null,
  description text not null default '',
  options text[] not null check (cardinality(options) >= 2),
  ranked boolean not null default false,
  deadline timestamptz not null,
  -- Minimum number of votes for the result to stand.
  quorum int not null check (quorum >= 1),
  closed boolean not null default false,
  outcome text,
  created_at timestamptz not null default now()
);
create index proposals_community_idx on public.proposals (community_id);

-- One ballot per member. `choice` holds option indexes: one for single
-- choice, all of them in preference order for ranked choice.
create table public.votes (
  proposal_id uuid not null references public.proposals (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  choice int[] not null check (cardinality(choice) >= 1),
  updated_at timestamptz not null default now(),
  primary key (proposal_id, user_id)
);

create table public.concerns (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities (id) on delete cascade,
  author_id uuid not null references public.profiles (id) on delete cascade,
  category text not null,
  title text not null,
  details text not null,
  location text not null,
  station_id uuid references public.stations (id) on delete set null,
  has_photo boolean not null default false,
  created_at timestamptz not null default now()
);
create index concerns_community_idx on public.concerns (community_id);

create table public.concern_supporters (
  concern_id uuid not null references public.concerns (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  primary key (concern_id, user_id)
);

create table public.position_summaries (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities (id) on delete cascade,
  author_id uuid not null references public.profiles (id) on delete cascade,
  title text not null,
  category text not null,
  body text not null,
  concern_count int not null,
  support_count int not null,
  created_at timestamptz not null default now()
);

create table public.content_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles (id) on delete cascade,
  content_type text not null
    check (content_type in ('discussion', 'reply', 'review', 'concern')),
  content_id uuid not null,
  content_title text not null,
  reason text not null,
  -- Null for content outside communities (reviews); those go to the admin.
  community_id uuid references public.communities (id) on delete cascade,
  status text not null default 'open'
    check (status in ('open', 'escalated', 'removed', 'dismissed')),
  created_at timestamptz not null default now()
);

-- ───────────────────── M3 Events & Group Trips ─────────────────────

create table public.events (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities (id) on delete cascade,
  creator_id uuid not null references public.profiles (id) on delete cascade,
  title text not null,
  type text not null check (type in ('meetup', 'convoy', 'drive', 'outreach')),
  description text not null default '',
  starts_at timestamptz not null,
  -- Venue, or the destination of a convoy or drive.
  venue_name text not null,
  venue_lat double precision not null,
  venue_lng double precision not null,
  -- Starting point of a convoy or drive.
  origin_name text,
  origin_lat double precision,
  origin_lng double precision,
  capacity int not null check (capacity >= 1),
  visibility text not null default 'community'
    check (visibility in ('tribe', 'community', 'public')),
  -- The one planned charging stop.
  stop_station_id uuid references public.stations (id) on delete set null,
  cancelled boolean not null default false,
  created_at timestamptz not null default now()
);
create index events_community_idx on public.events (community_id);

create table public.rsvps (
  event_id uuid not null references public.events (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  -- Attending vehicle, from the member's profile at the time of the RSVP.
  vehicle_id uuid references public.vehicles (id) on delete set null,
  start_battery_pct numeric not null check (start_battery_pct between 0 and 100),
  created_at timestamptz not null default now(),
  primary key (event_id, user_id)
);

-- ───────────────────── M5 Admin & Community Insights ─────────────────────

create table public.audit_log (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid not null references public.profiles (id) on delete cascade,
  action text not null,
  created_at timestamptz not null default now()
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  title text not null,
  body text not null,
  read boolean not null default false,
  created_at timestamptz not null default now()
);
create index notifications_user_idx
  on public.notifications (user_id, created_at desc);

-- ───────────────────────── PostGIS helper ─────────────────────────

-- Stations within `max_km` of the straight line A–B. The trip check uses it
-- to find charging stops within 2 km of a route. Once the Google Routes API
-- is connected, pass the route polyline instead of a straight line.
create or replace function public.stations_near_line(
  a_lat double precision,
  a_lng double precision,
  b_lat double precision,
  b_lng double precision,
  max_km double precision default 2
) returns setof public.stations
language sql stable
set search_path = public
as $$
  select s.*
  from public.stations s
  where extensions.st_dwithin(
    s.location,
    extensions.st_setsrid(
      extensions.st_makeline(
        extensions.st_makepoint(a_lng, a_lat),
        extensions.st_makepoint(b_lng, b_lat)
      ),
      4326
    )::extensions.geography,
    max_km * 1000
  );
$$;
