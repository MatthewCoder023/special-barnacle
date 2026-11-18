// Collects EV news from the RSS feeds in `news_sources` into `news_articles`.
//
// Runs once a day from a database schedule (see supabase/schedule_news.sql)
// and can be called by hand. It stores only what each feed publishes: the
// headline, a short summary, the image link and the link to the original.
// It never downloads or stores article bodies.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

type Source = {
  name: string;
  feed_url: string;
  philippines: boolean;
  ev_only: boolean;
};

type Article = {
  url: string;
  title: string;
  summary: string;
  image_url: string | null;
  source: string;
  philippines: boolean;
  published_at: string;
};

const MAX_PER_SOURCE = 15;
const MAX_AGE_DAYS = 30;
const KEEP_DAYS = 45;
const MIN_MINUTES_BETWEEN_RUNS = 30;

// Terms that mark a story as being about electric vehicles, for feeds that
// cover motoring in general.
const EV_TERMS =
  /\b(electric (vehicle|car|suv|sedan|pickup|truck|bus|jeepney|motorcycle|scooter|tricycle)s?|e-?vehicles?|evs?|bevs?|phevs?|reevs?|plug-?in|charging stations?|ev chargers?|fast chargers?|evida|byd|tesla|vinfast)\b/i;

const ENTITIES: Record<string, string> = {
  amp: "&", lt: "<", gt: ">", quot: '"', apos: "'", nbsp: " ",
  rsquo: "’", lsquo: "‘", rdquo: "”", ldquo: "“",
  ndash: "–", mdash: "—", hellip: "…",
};

function decode(text: string): string {
  return text
    .replace(/&#x([0-9a-f]+);/gi, (_, h) => String.fromCodePoint(parseInt(h, 16)))
    .replace(/&#(\d+);/g, (_, d) => String.fromCodePoint(parseInt(d, 10)))
    .replace(/&([a-z]+);/gi, (m, name) => ENTITIES[name.toLowerCase()] ?? m);
}

/** Contents of the first <name> element, with CDATA unwrapped. */
function tag(xml: string, name: string): string {
  const m = xml.match(new RegExp(`<${name}(?:\\s[^>]*)?>([\\s\\S]*?)</${name}>`, "i"));
  if (!m) return "";
  return m[1].replace(/^\s*<!\[CDATA\[/, "").replace(/\]\]>\s*$/, "").trim();
}

/** Value of an attribute on the first <name ...> element. */
function attr(xml: string, name: string, attribute: string): string {
  const m = xml.match(new RegExp(`<${name}\\s[^>]*${attribute}="([^"]+)"`, "i"));
  return m ? decode(m[1]) : "";
}

/** Plain text from HTML, collapsed and cut at a word boundary. */
function plain(html: string, max = 300): string {
  const text = decode(decode(html).replace(/<[^>]+>/g, " ")).replace(/\s+/g, " ").trim();
  if (text.length <= max) return text;
  const cut = text.slice(0, max);
  return cut.slice(0, cut.lastIndexOf(" ")).replace(/[,;:.\s]+$/, "") + "…";
}

function imageOf(item: string, html: string): string | null {
  const direct =
    attr(item, "media:content", "url") ||
    attr(item, "media:thumbnail", "url") ||
    attr(item, "enclosure", "url");
  const inline = html.match(/<img[^>]+src="([^"]+)"/i)?.[1] ?? "";
  let url = decode(direct || inline);
  if (!url.startsWith("http")) return null;
  // Blogger thumbnails are 72 px; ask for a larger rendition of the same image.
  url = url.replace(/\/s72(-[a-z0-9-]+)?\//, "/s800/");
  return url;
}

function parse(xml: string, source: Source): Article[] {
  const items = xml.match(/<item[\s>][\s\S]*?<\/item>/gi) ?? [];
  const oldest = Date.now() - MAX_AGE_DAYS * 86_400_000;
  const out: Article[] = [];
  for (const item of items) {
    const rawTitle = plain(tag(item, "title"), 220);
    const link = decode(tag(item, "link"));
    const published = new Date(tag(item, "pubDate"));
    if (!rawTitle || !link.startsWith("http") || isNaN(published.getTime())) continue;
    if (published.getTime() < oldest) continue;

    const description = tag(item, "description");
    const body = tag(item, "content:encoded");
    const text = plain(description || body, 2000);
    const categories = (item.match(/<category[^>]*>[\s\S]*?<\/category>/gi) ?? []).join(" ");
    if (!source.ev_only && !EV_TERMS.test(`${rawTitle} ${text} ${plain(categories)}`)) continue;

    // Google News puts the outlet in <source> and appends it to the title.
    const outlet = plain(tag(item, "source"), 80);
    const title = outlet && rawTitle.endsWith(` - ${outlet}`)
      ? rawTitle.slice(0, -(outlet.length + 3))
      : rawTitle;
    let summary = plain(description || body);
    // Some feeds repeat the headline as the description; that adds nothing.
    if (summary.toLowerCase().startsWith(title.toLowerCase().slice(0, 40))) summary = "";

    out.push({
      url: link,
      title,
      summary,
      image_url: imageOf(item, `${description} ${body}`),
      source: outlet || source.name,
      philippines: source.philippines,
      published_at: published.toISOString(),
    });
    if (out.length >= MAX_PER_SOURCE) break;
  }
  return out;
}

Deno.serve(async () => {
  const db = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { "Content-Type": "application/json" },
    });

  // Anyone with the public key can call this, so refuse to run too often.
  const { data: latest } = await db
    .from("news_articles")
    .select("fetched_at")
    .order("fetched_at", { ascending: false })
    .limit(1);
  const last = latest?.[0]?.fetched_at ? new Date(latest[0].fetched_at).getTime() : 0;
  if (Date.now() - last < MIN_MINUTES_BETWEEN_RUNS * 60_000) {
    return json({ skipped: true, reason: "Ran recently", last_run: latest![0].fetched_at });
  }

  const { data: sources, error } = await db
    .from("news_sources")
    .select("name, feed_url, philippines, ev_only")
    .eq("enabled", true);
  if (error) return json({ error: error.message }, 500);

  const report: Record<string, string | number> = {};
  const articles: Article[] = [];
  await Promise.all((sources as Source[]).map(async (source) => {
    try {
      const response = await fetch(source.feed_url, {
        headers: { "User-Agent": "Mozilla/5.0 (compatible; EVYAHE news reader)" },
        signal: AbortSignal.timeout(15_000),
      });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const found = parse(await response.text(), source);
      articles.push(...found);
      report[source.name] = found.length;
    } catch (e) {
      // One feed being down must not stop the others.
      report[source.name] = `failed: ${(e as Error).message}`;
    }
  }));

  // The same story can appear in two feeds; keep the first copy of each link.
  const unique = [...new Map(articles.map((a) => [a.url, a])).values()];
  let stored = 0;
  if (unique.length > 0) {
    const { error: writeError, count } = await db
      .from("news_articles")
      .upsert(
        unique.map((a) => ({ ...a, fetched_at: new Date().toISOString() })),
        { onConflict: "url", count: "exact" },
      );
    if (writeError) return json({ error: writeError.message, report }, 500);
    stored = count ?? unique.length;
  }

  const cutoff = new Date(Date.now() - KEEP_DAYS * 86_400_000).toISOString();
  await db.from("news_articles").delete().lt("published_at", cutoff);

  return json({ stored, sources: report });
});
