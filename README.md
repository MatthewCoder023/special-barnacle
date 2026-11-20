# EVYAHE

A community-centered information system for electric vehicle owner communities in the Philippines. Flutter app for iOS and Android.

Built from the community-centered revision of the thesis proposal (modules M1 to M5). It runs on a Supabase backend, or on bundled sample data when started without backend settings. Google Maps Platform is not connected yet.

## Run

```bash
flutter pub get
flutter run
```

```bash
flutter test
```

The sign-in screen offers one sample account per role: member, community leader, guest, service provider and platform administrator.

### Building on a Mac with iCloud Desktop sync

If the project sits in a folder that iCloud syncs (Desktop or Documents), the iOS build fails with `Uncategorized (Xcode): Exited with status code 255`. The verbose log shows `Failed to codesign ... Flutter.framework` and `resource fork, Finder information, or similar detritus not allowed`: iCloud tags the built framework folder with metadata that code signing rejects.

On this machine `build` is a symlink to `~/Library/Caches/evyahe-build`, which iCloud does not sync, and the build works. `flutter clean` deletes that symlink, so recreate it afterwards:

```bash
mkdir -p ~/Library/Caches/evyahe-build && rm -rf build && ln -s ~/Library/Caches/evyahe-build build
```

Moving the whole project to a folder outside iCloud (for example `~/Developer/evyahe`) removes the problem for good and needs no symlink.

## Navigation

Five tabs, icons only, with Home in the middle and shown first. The active tab has a sky disc behind its icon and a small pink dot; each tab keeps its name for screen readers and a long-press tooltip.

| Role | Tabs |
|---|---|
| Member, leader, guest | Community, Route, **Home**, Services, Profile |
| Service provider | Listings, Route, **Home**, Services, Profile |
| Platform administrator | Admin, Community, **Home**, Route, Profile |

- **Home** is the hub: battery and range, quick access to the modules, what is waiting on the user, and the EV news feed.
- **Community** holds groups, discovery and events. Events have no tab of their own; each community and tribe also has its own Events tab.
- **Route** is the map: stations, route planning and the navigation view.
- **Services** is the service and parts directory plus the cost comparison.
- **Profile** is the account: photo, name and username, My EV and charging preferences, communities and activity, notification and privacy preferences, password, sign out.

Inside a module, functions are switched with text tabs (bold label, short pink line under the active one), not pills or outlined buttons. `PillRow` and `SegmentedTabs` in `lib/core/widgets/basics.dart` are the only two tab styles. `ChoicePill` is kept for form choices such as a category or tags, not for navigation.

## Modules

| Module | Where | What it covers |
|---|---|---|
| M1 Community & Tribe Management | `lib/features/community` | Create communities and tribes, join requests and approval, leader/officer/member roles, verification requirement, membership criteria |
| M2 Community Engagement & Governance | `lib/features/engagement` | Announcements, tagged discussions and Q&A, reviews, helpfulness votes, proposals and polls (single and ranked choice, deadline, quorum), Community Voice concern board and position summaries, content reports |
| M3 Events & Group Trips | `lib/features/events` (shown inside Community) | Month calendar, create events with an optional announcement, RSVP with vehicle and starting battery level, route check with one planned charging stop |
| M4 EV Charging & Services | `lib/features/route`, `lib/features/charging` | Map with ranked compatible stations, trip planning with up to two charging stops, a safety reserve, detours and alternatives, round-trip range check, status reports and queue check-ins, service directory with tribe recommendations, cost comparison |
| M5 Admin & Community Insights | `lib/features/admin`, `lib/features/provider` | Approvals, owner verification, moderation queue, reference data, audit log, leader dashboard, provider listings |

## Structure

```
lib/
  core/       theme (colors, motion), reusable widgets, formatting
  data/       models and sample data
  domain/     rules as plain functions: charging, event route check, voting, costs
  state/      AppState: records, role rules (RBAC) and every action
  features/   one folder per module, plus auth, shell, home, profile, shared
```

The rules in `lib/domain` have no Flutter or backend dependencies, so they can move into Supabase Edge Functions unchanged. Each public method on `AppState` maps to one backend operation.

## EV news

Home shows EV news, Philippine coverage first. It is not part of modules M1 to M5 in the proposal, so the paper needs a line for it.

- The Edge Function `supabase/functions/fetch-ev-news` reads the RSS feeds listed in the `news_sources` table and stores each item in `news_articles`. A database schedule runs it every day at 6:00 AM Philippine time (`supabase/schedule_news.sql`).
- Sources today: Google News (Philippine EV search), CarGuide.PH, Top Gear Philippines and Electrek (world). General motoring feeds are filtered to stories that mention EV terms. To add or drop a source, edit `news_sources`.
- Only what the feed publishes is stored: headline, a summary of up to 300 characters, the image link and the link to the original. The article page shows that, then opens the full story on the publisher's site in an in-app browser. Article bodies are never copied.
- Without a backend the feed shows placeholder items marked "Sample".

## Route planning: what is real and what is simulated

| Part | Status |
|---|---|
| Stations, connector compatibility, status reports, queue | Real data and rules |
| Battery, range, safety reserve, charging stops, battery on arrival | Real rules (`lib/domain/route_planner.dart`, `charging_rules.dart`) |
| Hand-off to Google Maps | Works today |
| Distances, travel times, charging time | **Estimated** from straight-line distance |
| The map | **Stand-in**: a schematic grid, not real streets (`lib/features/route/ev_map.dart`) |
| Movement in the navigation view | **Simulated**, labelled on screen |
| Destination search | Preset places, stations and providers only |

To connect Google Maps:

1. Replace `EvMapView` with a `GoogleMap` widget from `google_maps_flutter`. It takes the same inputs: markers, route lines and a camera fit.
2. Implement `RouteService` (`lib/domain/route_planner.dart`) with a class that calls the Routes API through a Supabase Edge Function, so the key stays off the phone, and change the one line at the bottom of that file.
3. Replace the destination search list with Places Autocomplete.

### How trips with charging stops are planned

The user picks a start (current location by default) and a destination, and sets the battery level, a safety reserve (default 10%) and the level to charge to at each stop (default 80%). The planner then:

1. Checks whether the vehicle reaches the destination with the reserve still in hand. If so, Direct is offered first, plus up to two top-up options on the way.
2. Otherwise it picks a compatible station within 2 km of the remaining route that the vehicle can reach above the reserve and that brings it closer, charges there, and repeats, up to two stops. A charger near the start is allowed (charge before leaving); a charger at the destination is not a stop.
3. It builds up to three options this way: fewest stops, fastest chargers, and most reliable by recent status reports. Stations reported not working in the last 24 hours go last. Each option shows driving and charging time, extra distance against driving direct, the battery level on reaching each stop and on arrival.

With Google Maps connected, only the distances and times change: Routes API Compute Routes gives the road route, traffic-aware time and alternatives; Route Matrix gives the distances to candidate stations along it; Places (with EV charging options) can add stations EVYAHE does not list. The stop rules above stay as they are. The paid calls belong in one Supabase Edge Function so the key never ships in the app; `stations_near_line` in the schema already finds stations near a route.

**Paper conflicts.** The 9 November proposal states one charging stop at most, no separate safety reserve, and no turn-by-turn navigation. This version plans up to two stops (`EstimatedRouteService.maxStops`), keeps a configurable reserve, and has a simulated built-in navigation view. The limitations section needs updating, or `maxStops` set back to 1 and the reserve to 0.

## Google and Apple sign-in

The sign-in screen shows a "Continue with Google" or "Continue with Apple" button only when that provider is switched on in Supabase, so there are no dead buttons. To switch one on:

1. Supabase dashboard, Authentication > Sign In / Providers: enable Google (needs an OAuth client from Google Cloud Console) or Apple (needs the paid Apple Developer Program, a Services ID and a key).
2. Authentication > URL Configuration: add `ph.evyahe.evyahe://login-callback` to the redirect URLs. The iOS and Android projects already register that scheme.

This path is written but has not been run, because no provider is enabled yet.

## Supabase backend

The app runs in one of two modes, chosen at build time:

- **Sample data** (default): no backend, a sample account picker, data resets on restart.
- **Supabase**: email sign-in and registration, records loaded from the database, every action saved to it.

The project `evyahe` (Singapore region) already has the six migrations, the seed data, the news function and its daily schedule applied, and `supabase.json` on this machine points at it. A teammate setting up from scratch does this:

1. Create a project at supabase.com, or get access to the existing one.
2. In the SQL editor, run these files in order (skip if using the existing project):
   - `supabase/migrations/20261116000001_schema.sql` (tables, PostGIS)
   - `supabase/migrations/20261116000002_policies.sql` (role rules as row-level security, triggers)
   - `supabase/migrations/20261116000003_function_privileges.sql` (limits who can call the helper functions)
   - `supabase/migrations/20261117000004_news.sql` (news tables and sources), then deploy `supabase/functions/fetch-ev-news` and run `supabase/schedule_news.sql`
   - `supabase/migrations/20261117000005_profile_settings.sql` (username, photo, charging, notification and privacy preferences; the `avatars` storage bucket and its policies)
   - `supabase/migrations/20261120000006_privacy_rules.sql` (private membership lists, secret ballots and private RSVPs; see below)
   - `supabase/seed.sql` (sample vehicles, stations, providers and reference data)
3. Copy `supabase.example.json` to `supabase.json` and fill in the project URL and publishable key from Project Settings > API. `supabase.json` is ignored by git.
4. Run the app with the settings:

   ```bash
   flutter run --dart-define-from-file=supabase.json
   ```

5. Register an account in the app. To make it the platform administrator, run in the SQL editor, with the user's id from Authentication > Users:

   ```sql
   update public.profiles set role = 'admin' where id = '<user id>';
   ```

Supabase asks new users to confirm their email by default. For development you can turn that off under Authentication > Sign In / Providers > Email.

How it fits together:

- `lib/data/remote/remote_store.dart` is the interface the app depends on; `supabase_store.dart` implements it.
- `lib/data/remote/row_mapping.dart` converts database rows to models and back.
- `AppState` applies a change in memory first, then sends it. If the server rejects it, the user sees the message and the records reload. Pull down on any tab to reload.
- The role rules are checked twice: in `AppState` so the screens hide what a role cannot do, and in the row-level security policies so the server refuses it regardless.

Privacy rules, from Section 3.11 of the proposal:

- **Membership lists** are readable only by a community's own members and by administrators. Everyone else gets a member count from `member_counts()`.
- **Votes** are secret: each member can read only their own vote. Poll results are counted from `poll_ballots()`, which returns the other ballots without voters, sorted by content so the order gives nothing away.
- **RSVPs**, which hold the attendee's vehicle and starting battery level, are readable only by the attendee and the event's organizers (its creator and the community's leaders and officers). Everyone else gets a head count from `event_attendance()`.

The app loads these three functions with the tables (`remoteFunctions` in `row_mapping.dart`) and shows counts with `Community.memberCount`, `CommunityEvent.attendeeCount` and `Proposal.ballots`. The rules were checked on the live database as an outsider, a member and a leader.

Known limits of this first version:

- Notifications are inserted by the app, so a signed-in user could send arbitrary ones. Moving them to database triggers closes that.
- Event capacity is checked in the app only.
- All visible records load at once (PostgREST returns at most 1,000 rows per table by default). Fine at thesis scale; paginate later.
- Privacy preferences (hide my vehicle, hide my name on station reports) are applied by the app. Profiles stay readable to every signed-in user at the database level, so a determined user could still read them.
- Profile photos go to the public `avatars` bucket (2 MB, images only). Each user can write only inside a folder named after their own id; anyone with the link can view a photo.
- Changing the password asks for the current one and signs in with it first, then sets the new one.
- Station recommendations and trip checks still run in the app. The proposal places them in Edge Functions that call the Google Routes API; `stations_near_line` in the schema is ready for that.

## Not connected yet

- **Supabase Storage** for concern photos and ownership proof. Storage is used for profile photos only.
- **Google Maps Platform**. The station map is a schematic placeholder, and road distance and travel time are estimated from straight-line distance (`Geo` in `lib/domain/charging_rules.dart`).
- **Device location**. The driver location is a fixed point in Makati.
- **Photo and document upload** for concern evidence and ownership proof. Profile photos can be uploaded, changed and removed (`image_picker`, gallery only).

Station, provider, vehicle and rate records in `lib/data/seed_data.dart` are illustrative placeholders, not collected data.

## Design

Palette: sky blue `#87CEEB`, white `#FFFFFF`, hot pink `#FF69B4` (`lib/core/theme/app_colors.dart`). Motion follows `rules-for-the-ui.md` (`lib/core/theme/app_motion.dart`) and respects the device's reduce-motion setting.
