-- EVYAHE role-based access control, enforced with row-level security.
--
-- Platform roles (profiles.role): admin, member, guest, provider.
-- Group roles (community_members.role): leader, officer, member.
-- Every request from the app goes through these policies.

-- ───────────────────────── Helper functions ─────────────────────────
-- SECURITY DEFINER so they can read membership without tripping the
-- policies that call them.

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from profiles where id = auth.uid() and role = 'admin'
  );
$$;

-- Members can post, review, RSVP, vote and file concerns. Guests cannot.
create or replace function public.is_participant() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from profiles where id = auth.uid() and role = 'member'
  );
$$;

create or replace function public.is_member(cid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from community_members
    where community_id = cid and user_id = auth.uid()
  );
$$;

-- Leaders and officers manage their own community or tribe.
create or replace function public.can_manage(cid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from community_members
    where community_id = cid and user_id = auth.uid()
      and role in ('leader', 'officer')
  );
$$;

create or replace function public.is_leader(cid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from community_members
    where community_id = cid and user_id = auth.uid() and role = 'leader'
  );
$$;

-- Content of an approval-based group is visible to its members only.
create or replace function public.can_view(cid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from communities c
    where c.id = cid and c.status = 'approved'
      and (
        c.join_policy = 'open'
        or public.is_admin()
        or public.is_member(c.id)
      )
  );
$$;

-- Whether the caller may become a member right away (open groups only).
create or replace function public.can_join_directly(cid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from communities c
    join profiles p on p.id = auth.uid()
    where c.id = cid
      and c.status = 'approved'
      and c.join_policy = 'open'
      and p.role in ('member', 'guest')
      and (not c.requires_verification or p.verification = 'verified')
      and (c.parent_id is null or public.is_member(c.parent_id))
  );
$$;

-- Whether the caller may file a join request (approval-based groups).
create or replace function public.can_request_to_join(cid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from communities c
    join profiles p on p.id = auth.uid()
    where c.id = cid
      and c.status = 'approved'
      and c.join_policy = 'approval'
      and p.role = 'member'
      and (not c.requires_verification or p.verification = 'verified')
      and (c.parent_id is null or public.is_member(c.parent_id))
  );
$$;

-- Event visibility: tribe, community (the group or its parent), or public.
create or replace function public.can_see_event(cid uuid, vis text) returns boolean
language sql stable security definer set search_path = public as $$
  select public.is_admin()
    or vis = 'public'
    or public.is_member(cid)
    or (
      vis = 'community'
      and exists (
        select 1 from communities c
        where c.id = cid and c.parent_id is not null
          and public.is_member(c.parent_id)
      )
    );
$$;

-- ───────────────────────────── Triggers ─────────────────────────────
-- auth.uid() is null in the SQL editor and for the service role, so the
-- guards below let trusted maintenance through.

-- Creates the profile when someone registers. The role comes from the
-- sign-up form and can only be member, guest or provider.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, name, role, region)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data ->> 'name', ''), split_part(new.email, '@', 1)),
    case
      when new.raw_user_meta_data ->> 'role' in ('guest', 'provider')
        then new.raw_user_meta_data ->> 'role'
      else 'member'
    end,
    coalesce(new.raw_user_meta_data ->> 'region', '')
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Users edit their own profile but cannot change their role, and can only
-- move verification to "pending". Changing the vehicle resets verification.
create or replace function public.guard_profile_update() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or public.is_admin() then
    return new;
  end if;
  new.role := old.role;
  if new.vehicle_id is distinct from old.vehicle_id then
    new.verification := 'none';
  elsif new.verification is distinct from old.verification
    and not (new.verification = 'pending' and old.verification in ('none', 'rejected')) then
    new.verification := old.verification;
  end if;
  return new;
end;
$$;

create trigger guard_profile_update
  before update on public.profiles
  for each row execute function public.guard_profile_update();

-- New communities wait for admin approval, to prevent impersonation of real
-- clubs. Tribes are created by the managers of an approved community.
create or replace function public.prepare_community() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and not public.is_admin() then
    new.created_by := auth.uid();
    new.status := case when new.parent_id is null then 'pending' else 'approved' end;
  end if;
  return new;
end;
$$;

create trigger prepare_community
  before insert on public.communities
  for each row execute function public.prepare_community();

-- The creator becomes the leader.
create or replace function public.add_community_leader() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.created_by is not null then
    insert into community_members (community_id, user_id, role)
    values (new.id, new.created_by, 'leader')
    on conflict do nothing;
  end if;
  return new;
end;
$$;

create trigger add_community_leader
  after insert on public.communities
  for each row execute function public.add_community_leader();

-- Only the platform admin changes a community's approval status.
create or replace function public.guard_community_update() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and not public.is_admin() then
    new.status := old.status;
    new.parent_id := old.parent_id;
    new.created_by := old.created_by;
  end if;
  return new;
end;
$$;

create trigger guard_community_update
  before update on public.communities
  for each row execute function public.guard_community_update();

-- Provider listings wait for admin verification; owners cannot approve
-- their own.
create or replace function public.guard_provider() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and not public.is_admin() then
    if tg_op = 'INSERT' then
      new.status := 'pending';
      new.owner_id := auth.uid();
    else
      new.status := old.status;
      new.owner_id := old.owner_id;
    end if;
  end if;
  return new;
end;
$$;

create trigger guard_provider
  before insert or update on public.providers
  for each row execute function public.guard_provider();

-- ─────────────────────── Row-level security ───────────────────────

alter table public.vehicles enable row level security;
alter table public.reference_data enable row level security;
alter table public.profiles enable row level security;
alter table public.communities enable row level security;
alter table public.community_members enable row level security;
alter table public.join_requests enable row level security;
alter table public.stations enable row level security;
alter table public.status_reports enable row level security;
alter table public.check_ins enable row level security;
alter table public.providers enable row level security;
alter table public.provider_recommendations enable row level security;
alter table public.announcements enable row level security;
alter table public.discussions enable row level security;
alter table public.replies enable row level security;
alter table public.reviews enable row level security;
alter table public.helpful_votes enable row level security;
alter table public.proposals enable row level security;
alter table public.votes enable row level security;
alter table public.concerns enable row level security;
alter table public.concern_supporters enable row level security;
alter table public.position_summaries enable row level security;
alter table public.content_reports enable row level security;
alter table public.events enable row level security;
alter table public.rsvps enable row level security;
alter table public.audit_log enable row level security;
alter table public.notifications enable row level security;

-- Reference data: everyone signed in reads, the admin maintains.
create policy "read vehicles" on public.vehicles
  for select to authenticated using (true);
create policy "admin maintains vehicles" on public.vehicles
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "read reference data" on public.reference_data
  for select to authenticated using (true);
create policy "admin maintains reference data" on public.reference_data
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "read stations" on public.stations
  for select to authenticated using (true);
create policy "admin maintains stations" on public.stations
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- Profiles: names and badges are visible to signed-in users.
create policy "read profiles" on public.profiles
  for select to authenticated using (true);
create policy "update own profile or admin" on public.profiles
  for update to authenticated
  using (id = auth.uid() or public.is_admin())
  with check (id = auth.uid() or public.is_admin());

-- M1 Communities and tribes.
create policy "read approved or own communities" on public.communities
  for select to authenticated
  using (status = 'approved' or created_by = auth.uid() or public.is_admin());
create policy "members create communities and tribes" on public.communities
  for insert to authenticated
  with check (
    public.is_participant()
    and (parent_id is null or public.can_manage(parent_id))
  );
create policy "managers and admin update communities" on public.communities
  for update to authenticated
  using (public.can_manage(id) or public.is_admin())
  with check (public.can_manage(id) or public.is_admin());

create policy "read memberships" on public.community_members
  for select to authenticated using (true);
create policy "join open groups or be admitted" on public.community_members
  for insert to authenticated
  with check (
    (user_id = auth.uid() and role = 'member' and public.can_join_directly(community_id))
    or (role = 'member' and public.can_manage(community_id))
    or public.is_admin()
  );
-- Only the leader assigns officers; the admin can reassign an inactive leader.
create policy "leader assigns roles" on public.community_members
  for update to authenticated
  using (
    (public.is_leader(community_id) and user_id <> auth.uid())
    or public.is_admin()
  )
  with check (
    (public.is_leader(community_id) and role in ('officer', 'member'))
    or public.is_admin()
  );
create policy "leave or be removed" on public.community_members
  for delete to authenticated
  using (
    (user_id = auth.uid() and role <> 'leader')
    or (public.can_manage(community_id) and role <> 'leader')
    or public.is_admin()
  );

create policy "read own or managed join requests" on public.join_requests
  for select to authenticated
  using (user_id = auth.uid() or public.can_manage(community_id) or public.is_admin());
create policy "request to join" on public.join_requests
  for insert to authenticated
  with check (user_id = auth.uid() and public.can_request_to_join(community_id));
create policy "cancel or decide join requests" on public.join_requests
  for delete to authenticated
  using (user_id = auth.uid() or public.can_manage(community_id) or public.is_admin());

-- M2 Engagement and governance.
create policy "read announcements" on public.announcements
  for select to authenticated using (public.can_view(community_id));
create policy "managers announce" on public.announcements
  for insert to authenticated
  with check (author_id = auth.uid() and public.can_manage(community_id));
create policy "managers pin" on public.announcements
  for update to authenticated
  using (public.can_manage(community_id)) with check (public.can_manage(community_id));
create policy "managers remove announcements" on public.announcements
  for delete to authenticated
  using (public.can_manage(community_id) or public.is_admin());

create policy "read discussions" on public.discussions
  for select to authenticated using (public.can_view(community_id));
create policy "members post discussions" on public.discussions
  for insert to authenticated
  with check (
    author_id = auth.uid() and public.is_participant() and public.is_member(community_id)
  );
create policy "moderate discussions" on public.discussions
  for delete to authenticated
  using (author_id = auth.uid() or public.can_manage(community_id) or public.is_admin());

create policy "read replies" on public.replies
  for select to authenticated
  using (exists (
    select 1 from public.discussions d
    where d.id = discussion_id and public.can_view(d.community_id)
  ));
create policy "members reply" on public.replies
  for insert to authenticated
  with check (
    author_id = auth.uid() and public.is_participant()
    and exists (
      select 1 from public.discussions d
      where d.id = discussion_id and public.is_member(d.community_id)
    )
  );
create policy "moderate replies" on public.replies
  for delete to authenticated
  using (
    author_id = auth.uid() or public.is_admin()
    or exists (
      select 1 from public.discussions d
      where d.id = discussion_id and public.can_manage(d.community_id)
    )
  );

create policy "read reviews" on public.reviews
  for select to authenticated using (true);
create policy "members review" on public.reviews
  for insert to authenticated
  with check (author_id = auth.uid() and public.is_participant());
-- Reviews sit outside communities, so only the admin moderates them.
create policy "author or admin removes reviews" on public.reviews
  for delete to authenticated
  using (author_id = auth.uid() or public.is_admin());

create policy "read helpful votes" on public.helpful_votes
  for select to authenticated using (true);
create policy "members vote helpful" on public.helpful_votes
  for insert to authenticated
  with check (user_id = auth.uid() and public.is_participant());
create policy "withdraw helpful vote" on public.helpful_votes
  for delete to authenticated using (user_id = auth.uid());

create policy "read proposals" on public.proposals
  for select to authenticated using (public.can_view(community_id));
create policy "open proposals by community rule" on public.proposals
  for insert to authenticated
  with check (
    author_id = auth.uid()
    and (
      public.can_manage(community_id)
      or (
        public.is_participant() and public.is_member(community_id)
        and exists (
          select 1 from public.communities c
          where c.id = community_id and c.members_can_propose
        )
      )
    )
  );
create policy "managers close proposals" on public.proposals
  for update to authenticated
  using (public.can_manage(community_id)) with check (public.can_manage(community_id));

-- Results are visible: ballots can be read by anyone who can see the proposal.
create policy "read votes" on public.votes
  for select to authenticated
  using (exists (
    select 1 from public.proposals p
    where p.id = proposal_id and public.can_view(p.community_id)
  ));
create policy "members vote while open" on public.votes
  for insert to authenticated
  with check (
    user_id = auth.uid() and public.is_participant()
    and exists (
      select 1 from public.proposals p
      where p.id = proposal_id and not p.closed and p.deadline > now()
        and public.is_member(p.community_id)
    )
  );
create policy "members change vote while open" on public.votes
  for update to authenticated
  using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.proposals p
      where p.id = proposal_id and not p.closed and p.deadline > now()
    )
  );

create policy "read concerns" on public.concerns
  for select to authenticated using (public.can_view(community_id));
create policy "members file concerns" on public.concerns
  for insert to authenticated
  with check (
    author_id = auth.uid() and public.is_participant() and public.is_member(community_id)
  );
create policy "moderate concerns" on public.concerns
  for delete to authenticated
  using (author_id = auth.uid() or public.can_manage(community_id) or public.is_admin());

create policy "read concern supporters" on public.concern_supporters
  for select to authenticated
  using (exists (
    select 1 from public.concerns k
    where k.id = concern_id and public.can_view(k.community_id)
  ));
create policy "members support concerns" on public.concern_supporters
  for insert to authenticated
  with check (
    user_id = auth.uid() and public.is_participant()
    and exists (
      select 1 from public.concerns k
      where k.id = concern_id and public.is_member(k.community_id)
    )
  );
create policy "withdraw support" on public.concern_supporters
  for delete to authenticated using (user_id = auth.uid());

create policy "read position summaries" on public.position_summaries
  for select to authenticated using (public.can_view(community_id));
create policy "managers publish summaries" on public.position_summaries
  for insert to authenticated
  with check (author_id = auth.uid() and public.can_manage(community_id));

-- Reports: officers review their own group's; the admin has the final say.
create policy "read relevant reports" on public.content_reports
  for select to authenticated
  using (
    reporter_id = auth.uid()
    or public.is_admin()
    or (community_id is not null and public.can_manage(community_id))
  );
create policy "anyone signed in reports" on public.content_reports
  for insert to authenticated with check (reporter_id = auth.uid());
create policy "review reports" on public.content_reports
  for update to authenticated
  using (
    public.is_admin()
    or (community_id is not null and public.can_manage(community_id))
  )
  with check (
    public.is_admin()
    or (community_id is not null and public.can_manage(community_id))
  );

-- M3 Events and group trips.
create policy "read visible events" on public.events
  for select to authenticated
  using (public.can_see_event(community_id, visibility));
create policy "managers create events" on public.events
  for insert to authenticated
  with check (creator_id = auth.uid() and public.can_manage(community_id));
create policy "managers edit events" on public.events
  for update to authenticated
  using (public.can_manage(community_id)) with check (public.can_manage(community_id));

create policy "read rsvps of visible events" on public.rsvps
  for select to authenticated
  using (exists (
    select 1 from public.events e
    where e.id = event_id and public.can_see_event(e.community_id, e.visibility)
  ));
create policy "members rsvp" on public.rsvps
  for insert to authenticated
  with check (
    user_id = auth.uid() and public.is_participant()
    and exists (
      select 1 from public.events e
      where e.id = event_id and not e.cancelled
        and public.can_see_event(e.community_id, e.visibility)
    )
  );
create policy "members update own rsvp" on public.rsvps
  for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "members cancel own rsvp" on public.rsvps
  for delete to authenticated using (user_id = auth.uid());

-- M4 Charging and services.
create policy "read status reports" on public.status_reports
  for select to authenticated using (true);
create policy "members report status" on public.status_reports
  for insert to authenticated
  with check (user_id = auth.uid() and public.is_participant());

create policy "read check-ins" on public.check_ins
  for select to authenticated using (true);
create policy "members check in" on public.check_ins
  for insert to authenticated
  with check (user_id = auth.uid() and public.is_participant());
create policy "members update own check-in" on public.check_ins
  for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "members check out" on public.check_ins
  for delete to authenticated using (user_id = auth.uid());

create policy "read verified or own listings" on public.providers
  for select to authenticated
  using (status = 'approved' or owner_id = auth.uid() or public.is_admin());
create policy "providers add listings" on public.providers
  for insert to authenticated
  with check (
    public.is_admin()
    or exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'provider'
    )
  );
create policy "owners and admin update listings" on public.providers
  for update to authenticated
  using (owner_id = auth.uid() or public.is_admin())
  with check (owner_id = auth.uid() or public.is_admin());

create policy "read recommendations" on public.provider_recommendations
  for select to authenticated using (true);
create policy "tribe managers recommend" on public.provider_recommendations
  for insert to authenticated with check (public.can_manage(tribe_id));
create policy "tribe managers withdraw recommendation" on public.provider_recommendations
  for delete to authenticated using (public.can_manage(tribe_id));

-- M5 Admin.
create policy "admin reads audit log" on public.audit_log
  for select to authenticated using (public.is_admin());
create policy "admin writes audit log" on public.audit_log
  for insert to authenticated
  with check (actor_id = auth.uid() and public.is_admin());

-- Notifications are written by the app on behalf of the acting user. Moving
-- this to database triggers would stop a signed-in user from sending
-- arbitrary notifications; it is acceptable for the thesis prototype.
create policy "read own notifications" on public.notifications
  for select to authenticated using (user_id = auth.uid());
create policy "send notifications" on public.notifications
  for insert to authenticated with check (true);
create policy "mark own notifications read" on public.notifications
  for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
