-- EV news for the Home feed.
--
-- A scheduled Edge Function (supabase/functions/fetch-ev-news) reads the RSS
-- feeds listed in news_sources once a day and stores each item's headline,
-- summary, image link and link to the original. The app reads news_articles.
-- Only what the feed itself publishes is stored; full articles stay on the
-- publishers' sites.

create table public.news_sources (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  feed_url text not null unique,
  -- Philippine coverage (true) or world EV news (false).
  philippines boolean not null default true,
  -- True when the whole feed is about EVs. Otherwise items are kept only
  -- when they mention EV terms.
  ev_only boolean not null default false,
  enabled boolean not null default true
);

create table public.news_articles (
  id uuid primary key default gen_random_uuid(),
  url text not null unique,
  title text not null,
  summary text not null default '',
  image_url text,
  source text not null,
  philippines boolean not null default true,
  published_at timestamptz not null,
  fetched_at timestamptz not null default now()
);
create index news_articles_published_idx
  on public.news_articles (published_at desc);

alter table public.news_sources enable row level security;
alter table public.news_articles enable row level security;

-- Everyone signed in reads the news. The Edge Function writes with the
-- service role, which bypasses these policies. The admin can remove an
-- article or switch a source off.
create policy "read news" on public.news_articles
  for select to authenticated using (true);
create policy "admin removes news" on public.news_articles
  for delete to authenticated using (public.is_admin());

create policy "admin reads news sources" on public.news_sources
  for select to authenticated using (public.is_admin());
create policy "admin maintains news sources" on public.news_sources
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

insert into public.news_sources (name, feed_url, philippines, ev_only) values
  ('Google News', 'https://news.google.com/rss/search?q=%22electric+vehicle%22+Philippines+when:14d&hl=en-PH&gl=PH&ceid=PH:en', true, true),
  ('CarGuide.PH', 'https://www.carguide.ph/feeds/posts/default?alt=rss&max-results=50', true, false),
  ('Top Gear Philippines', 'https://www.topgear.com.ph/feed/rss1', true, false),
  ('Electrek', 'https://electrek.co/feed/', false, true)
on conflict (feed_url) do nothing;
