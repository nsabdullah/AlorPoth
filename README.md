# মৌলিক ইসলাম (Moulik Islam) — Islamic Knowledge Platform

A single-page, real-time Islamic knowledge platform: browse Qur'anic ayat, hadith, and their explanations (বেখ্যা), organized by topic. Built with vanilla JS, Tailwind CSS, and Supabase — no build step required.

## Contents

| File | Purpose |
|---|---|
| `index.html` | The complete app — HTML, Tailwind config, and JS all in one file |
| `schema.sql` | Supabase database schema, RLS policies, indexes, and sample seed data |
| `README.md` | This file |

## 1. Set up Supabase

1. Create a project at [supabase.com](https://supabase.com) (free tier is fine).
2. Open **SQL Editor** in your project dashboard, paste the full contents of `schema.sql`, and run it.
   - This creates the `topics` and `sources` tables, the `sources_with_topic` view, full-text search indexes, Row Level Security policies (public read-only), and a few sample entries so the app isn't empty on first load.
3. Go to **Project Settings → API** and copy:
   - **Project URL**
   - **`anon` `public` key**

## 2. Connect the app

Open `index.html` and find this block near the top of the `<script>` section:

```js
const SUPABASE_URL = 'https://YOUR-PROJECT-REF.supabase.co';
const SUPABASE_ANON_KEY = 'YOUR-SUPABASE-ANON-PUBLIC-KEY';
```

Replace both values with the ones from step 1. That's it — no build tools, no `npm install`. Just open `index.html` in a browser, or serve it with any static host.

> The `anon` key is safe to expose in frontend code — it only allows what your RLS policies permit (public read-only, per `schema.sql`).

## 3. Data model

```
topics                     sources
─────────                  ─────────────────────
id                         id
name_bn / name_en          topic_id  ──► topics.id
slug                       type        (quran | hadith | athar | fatwa)
description                title
icon                       reference
sort_order                 arabic_text
                           translation_bn
                           explanation      ← the "বেখ্যা"
                           narrator / grade  (hadith only)
                           tags[]
                           is_featured
                           search_vector    (auto-generated, full-text index)
```

The frontend reads from the **`sources_with_topic`** view (a join of `sources` + `topics`), so you never need to manually join anything client-side.

### Adding new content

Just insert rows into Supabase — either through the **Table Editor** UI or SQL:

```sql
insert into public.sources
  (topic_id, type, title, reference, arabic_text, translation_bn, explanation, tags)
values
  ('<topic-uuid>', 'quran', 'শিরোনাম', 'সূরা ...আয়াত ...',
   'العربية...', 'বাংলা অনুবাদ...', 'বিস্তারিত ব্যাখ্যা...', array['ট্যাগ১','ট্যাগ২']);
```

New rows appear on the frontend:
- **Instantly**, if you've enabled Realtime (see below)
- **Within 30 minutes** otherwise, since the app also refreshes from Supabase every time it's opened (the 30-minute figure is just the local cache's "freshness" window — a fresh network fetch still happens on every page load)

To add a brand-new **topic** (e.g. "Zakat"), insert a row into `topics` — it will automatically show up as a new filter pill, no frontend code changes needed.

### Enabling live/instant sync (optional but recommended)

1. In Supabase, go to **Database → Replication**.
2. Turn on replication for the `sources` table (and `topics` if you want instant topic updates too).
3. That's it — `index.html` already contains a Realtime subscription (`subscribeRealtime()`) that listens for changes and re-renders automatically.

## 4. How the app works

- **On load**: instantly renders whatever is in `localStorage` (if anything), so returning visitors see content immediately — even on a slow connection — then fetches fresh data from Supabase in the background and re-renders.
- **Search**: the top search bar filters client-side (title, reference, translation, explanation, topic name, tags) with a 120ms debounce, so results update as you type.
- **Filters**: topic pills (Iman, Salah, Akhlaq, …) and type pills (Qur'an / Hadith / Athar / Fatwa) combine with the search query.
- **Connection badge**: top-right indicator shows **লাইভ সংযুক্ত** (live), **ক্যাশ থেকে দেখানো হচ্ছে** (showing cached data), or **অফলাইন মোড** (offline — network failed and no cache exists).
- **Explanations** are collapsed by default per card and expand on tap, keeping the list scannable.

## 5. Customizing

- **Colors / fonts**: edit the `tailwind.config` block inside `index.html` (`emerald`, `gold`, `paper`, `slate` colors; `Fraunces` / `Inter` / `Noto Naskh Arabic` / `Noto Sans Bengali` fonts).
- **Source types**: add a new value to the `source_type` enum in `schema.sql` (e.g. `'ijma'`) and add a matching entry to `TYPE_META` in `index.html`'s JS so it gets a label, icon, and color.
- **Cache duration**: change `CACHE_TTL_MS` in `index.html` (currently 30 minutes).

## 6. Deploying

Since it's a single static file, you can deploy it anywhere:
- **Netlify / Vercel**: drag-and-drop `index.html` or connect a repo.
- **GitHub Pages**: push to a repo, enable Pages on the branch.
- **Supabase Storage**: upload as a static site bucket.

## 7. Turning it into a PWA / APK

The app is responsive and structured for this, but two things aren't included yet and you'll want to add them:

1. **`manifest.json`** — app name, icons, theme color (`#0B3D2E`), `display: standalone`.
2. **A service worker** — to cache `index.html` and enable installability/offline app-shell loading (separate from the existing localStorage data cache, which already handles offline *content*).

Once you have a manifest + service worker, tools like [PWABuilder](https://www.pwabuilder.com/) can wrap the site into an installable APK for Android.

## 8. Notes & limits

- Writes (inserting/editing content) are intentionally **not** exposed to the `anon` key — RLS only grants `select`. Manage content via the Supabase dashboard, SQL editor, or a separate authenticated admin tool.
- Full-text search (`search_vector`) is set up in Postgres for future server-side search (e.g. if your content grows large enough that client-side filtering becomes slow) — the current frontend does simple client-side filtering, which is enough for a moderate content size.