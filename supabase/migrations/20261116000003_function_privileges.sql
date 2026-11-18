-- Tightens who can call the SECURITY DEFINER functions through the API
-- (Supabase security advisor lints 0028 and 0029).

-- Trigger functions are never called directly. Triggers still fire, because
-- EXECUTE is checked when a trigger is created, not when it runs.
revoke execute on function
  public.handle_new_user(),
  public.guard_profile_update(),
  public.prepare_community(),
  public.add_community_leader(),
  public.guard_community_update(),
  public.guard_provider()
from public, anon, authenticated;

-- The role helpers are used by the row-level security policies, which run as
-- the signed-in user, so `authenticated` keeps EXECUTE. Each one only answers
-- a yes/no question about the caller. Signed-out callers get nothing.
revoke execute on function
  public.is_admin(),
  public.is_participant(),
  public.is_member(uuid),
  public.can_manage(uuid),
  public.is_leader(uuid),
  public.can_view(uuid),
  public.can_join_directly(uuid),
  public.can_request_to_join(uuid),
  public.can_see_event(uuid, text)
from public, anon;

grant execute on function
  public.is_admin(),
  public.is_participant(),
  public.is_member(uuid),
  public.can_manage(uuid),
  public.is_leader(uuid),
  public.can_view(uuid),
  public.can_join_directly(uuid),
  public.can_request_to_join(uuid),
  public.can_see_event(uuid, text)
to authenticated;

-- The route helper reads stations, which only signed-in users may see.
revoke execute on function
  public.stations_near_line(double precision, double precision, double precision, double precision, double precision)
from public, anon;
