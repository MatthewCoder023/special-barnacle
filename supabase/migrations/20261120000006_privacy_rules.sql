-- Privacy rules from the proposal (Section 3.11, Ethical and Data Privacy
-- Considerations):
--   * community membership lists are visible only to the members of each
--     community;
--   * votes are counted without showing how each member voted;
--   * the battery level entered for an event is visible only to the member
--     and the event's organizers.
-- Everyone else gets counts and anonymous ballots through the functions
-- below, so member counts, poll results and "N of M going" still work.

-- ───────────────────────────── Memberships ─────────────────────────────

drop policy "read memberships" on public.community_members;
create policy "members read their group's members" on public.community_members
  for select to authenticated
  using (public.is_member(community_id) or public.is_admin());

-- Member counts for every community the user can see listed.
create or replace function public.member_counts()
returns table (community_id uuid, members int)
language sql stable security definer set search_path = public as $$
  select m.community_id, count(*)::int
  from community_members m
  join communities c on c.id = m.community_id
  where c.status = 'approved' or public.is_admin() or public.is_member(c.id)
  group by m.community_id;
$$;

-- ──────────────────────────────── Votes ────────────────────────────────

drop policy "read votes" on public.votes;
create policy "members read their own vote" on public.votes
  for select to authenticated
  using (user_id = auth.uid());

-- Everyone else's ballots for the polls the user can see, with no voter
-- attached. Sorted by content, not by when they were cast, so the order
-- does not reveal who voted how. The caller's own vote is read from the
-- votes table instead, so it is not counted twice.
create or replace function public.poll_ballots()
returns table (proposal_id uuid, choice int[])
language sql stable security definer set search_path = public as $$
  select v.proposal_id, v.choice
  from votes v
  join proposals p on p.id = v.proposal_id
  where public.can_view(p.community_id)
    and v.user_id <> auth.uid()
  order by v.proposal_id, v.choice;
$$;

-- ──────────────────────────────── RSVPs ────────────────────────────────

-- An RSVP holds the attendee's vehicle and starting battery level, so only
-- the attendee and the event's organizers (its creator and the community's
-- leaders and officers) can read it.
drop policy "read rsvps of visible events" on public.rsvps;
create policy "attendee and organizers read rsvps" on public.rsvps
  for select to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1 from public.events e
      where e.id = event_id
        and (e.creator_id = auth.uid() or public.can_manage(e.community_id))
    )
  );

-- Head counts for every event the user can see.
create or replace function public.event_attendance()
returns table (event_id uuid, attendees int)
language sql stable security definer set search_path = public as $$
  select r.event_id, count(*)::int
  from rsvps r
  join events e on e.id = r.event_id
  where public.can_see_event(e.community_id, e.visibility)
  group by r.event_id;
$$;

-- Same privileges as the other helpers: signed-in users only.
revoke execute on function public.member_counts() from public, anon;
revoke execute on function public.poll_ballots() from public, anon;
revoke execute on function public.event_attendance() from public, anon;
grant execute on function public.member_counts() to authenticated;
grant execute on function public.poll_ballots() to authenticated;
grant execute on function public.event_attendance() to authenticated;
