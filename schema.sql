-- =========================================================
--  ILM — Islamic Knowledge Platform
--  Supabase schema (PostgreSQL)
--  Hierarchy:  topics  ->  sources (Quran/Hadith/Athar)  ->  explanation
-- =========================================================

-- Clean slate (safe to re-run while developing)
drop table if exists public.sources cascade;
drop table if exists public.topics cascade;
drop type  if exists public.source_type;

-- ---------------------------------------------------------
-- 1. TOPICS  (e.g. Iman, Salah, Akhlaq — the top-level field)
-- ---------------------------------------------------------
create table public.topics (
  id           uuid primary key default gen_random_uuid(),
  name_bn      text not null,                 -- e.g. "ঈমান"
  name_en      text not null,                 -- e.g. "Iman"
  slug         text not null unique,          -- e.g. "iman"
  description  text,
  icon         text default 'book-open',      -- lucide icon name
  sort_order   int  default 0,
  created_at   timestamptz default now()
);

-- ---------------------------------------------------------
-- 2. SOURCE TYPE  (the sub-category: Quran / Hadith / Athar / Fatwa)
-- ---------------------------------------------------------
create type public.source_type as enum ('quran', 'hadith', 'athar', 'fatwa');

-- ---------------------------------------------------------
-- 3. SOURCES  (the actual entries: ayat / hadith + explanation)
-- ---------------------------------------------------------
create table public.sources (
  id              uuid primary key default gen_random_uuid(),
  topic_id        uuid not null references public.topics(id) on delete cascade,
  type            public.source_type not null,
  title           text not null,              -- short heading, e.g. "সূরা আল-বাকারা: ২৮৫"
  reference       text,                        -- optional; may be null or empty
  arabic_text     text,                        -- optional; may be null or empty
  translation_bn  text,                        -- optional if you keep some entries without a Bengali translation
  explanation     text not null,               -- required detailed explanation
  narrator        text,                        -- optional for hadith: rawi name
  grade           text,                        -- optional for hadith: sahih/hasan/da'if
  tags            text[] default '{}',
  is_featured     boolean default false,
  sort_order      int default 0,
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);

-- ---------------------------------------------------------
-- Indexes for fast browsing + search
-- ---------------------------------------------------------
create index idx_sources_topic       on public.sources (topic_id);
create index idx_sources_type        on public.sources (type);
create index idx_sources_tags        on public.sources using gin (tags);

-- Full-text search index across title, translation and explanation
alter table public.sources add column search_vector tsvector
  generated always as (
    setweight(to_tsvector('simple', coalesce(title, '')), 'A') ||
    setweight(to_tsvector('simple', coalesce(translation_bn, '')), 'B') ||
    setweight(to_tsvector('simple', coalesce(explanation, '')), 'C') ||
    setweight(to_tsvector('simple', coalesce(reference, '')), 'B')
  ) stored;

create index idx_sources_search on public.sources using gin (search_vector);

-- ---------------------------------------------------------
-- updated_at trigger
-- ---------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger trg_sources_updated_at
  before update on public.sources
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------
-- Row Level Security — public read-only access
-- (Writes should go through the Supabase dashboard or an
--  authenticated admin role, not the anon client.)
-- ---------------------------------------------------------
alter table public.topics  enable row level security;
alter table public.sources enable row level security;

create policy "Public can read topics"
  on public.topics for select
  using (true);

create policy "Public can read sources"
  on public.sources for select
  using (true);

-- ---------------------------------------------------------
-- Seed data (sample) — remove or replace freely
-- ---------------------------------------------------------
insert into public.topics (name_bn, name_en, slug, description, icon, sort_order) values
  ('ঈমান', 'Iman', 'iman', 'বিশ্বাস ও আকীদাহ সংক্রান্ত জ্ঞান', 'moon-star', 1),
  ('সালাত', 'Salah', 'salah', 'নামাজ সংক্রান্ত বিধি-বিধান', 'hand', 2),
  ('আখলাক', 'Akhlaq', 'akhlaq', 'উত্তম চরিত্র ও আচরণ', 'heart', 3);

insert into public.sources
  (topic_id, type, title, reference, arabic_text, translation_bn, explanation, narrator, grade, tags, is_featured, sort_order)
select id, 'quran',
  'সূরা আল-বাকারা: ২৮৫',
  'সূরা আল-বাকারা, আয়াত ২৮৫',
  'آمَنَ الرَّسُولُ بِمَا أُنزِلَ إِلَيْهِ مِن رَّبِّهِ وَالْمُؤْمِنُونَ ۚ كُلٌّ آمَنَ بِاللَّهِ وَمَلَائِكَتِهِ وَكُتُبِهِ وَرُسُلِهِ',
  'রাসূল তাঁর রবের পক্ষ থেকে তাঁর প্রতি যা অবতীর্ণ হয়েছে তাতে ঈমান এনেছেন এবং মুমিনগণও। তারা প্রত্যেকে আল্লাহ, তাঁর ফেরেশতাগণ, তাঁর কিতাবসমূহ ও তাঁর রাসূলগণের প্রতি ঈমান এনেছে।',
  'এই আয়াতে ঈমানের মূল স্তম্ভগুলো উল্লেখ করা হয়েছে — আল্লাহর প্রতি বিশ্বাস, ফেরেশতাদের প্রতি বিশ্বাস, কিতাবসমূহের প্রতি বিশ্বাস এবং রাসূলগণের প্রতি বিশ্বাস। এটি ঈমানে মুফাসসালের একটি সংক্ষিপ্ত রূপ, যা প্রতিটি মুমিনের অন্তরে দৃঢ়ভাবে প্রোথিত থাকা আবশ্যক।',
  null, null, array['ঈমান','আকীদাহ','বাকারা'], true, 1
from public.topics where slug = 'iman';

insert into public.sources
  (topic_id, type, title, reference, arabic_text, translation_bn, explanation, narrator, grade, tags, is_featured, sort_order)
select id, 'hadith',
  'ঈমানের সংজ্ঞা — হাদিসে জিবরীল',
  'সহীহ মুসলিম, হাদিস নং ৮',
  'الْإِيمَانُ أَنْ تُؤْمِنَ بِاللَّهِ وَمَلَائِكَتِهِ وَكُتُبِهِ وَرُسُلِهِ وَالْيَوْمِ الْآخِرِ وَتُؤْمِنَ بِالْقَدَرِ خَيْرِهِ وَشَرِّهِ',
  'ঈমান হলো: তুমি আল্লাহ, তাঁর ফেরেশতাগণ, তাঁর কিতাবসমূহ, তাঁর রাসূলগণ ও শেষ দিবসের প্রতি বিশ্বাস স্থাপন করবে এবং তাকদীরের ভালো-মন্দের প্রতিও বিশ্বাস রাখবে।',
  'এই বিখ্যাত হাদিসটি জিবরীল (আ.)-এর প্রশ্নের জবাবে রাসূলুল্লাহ (সা.) বর্ণনা করেছেন। এখানে ঈমানের ছয়টি স্তম্ভ স্পষ্টভাবে উল্লেখ করা হয়েছে, যা প্রতিটি মুসলিমের আকীদার ভিত্তি।',
  'উমর ইবনুল খাত্তাব (রাঃ)', 'সহীহ', array['ঈমান','জিবরীল','আকীদাহ'], true, 2
from public.topics where slug = 'iman';

insert into public.sources
  (topic_id, type, title, reference, arabic_text, translation_bn, explanation, narrator, grade, tags, is_featured, sort_order)
select id, 'hadith',
  'নামাজের গুরুত্ব',
  'সহীহ বুখারী, হাদিস নং ৫২৭',
  'الصَّلَاةُ عِمَادُ الدِّينِ',
  'নামাজ হলো দ্বীনের স্তম্ভ।',
  'এই হাদিসে নামাজকে দ্বীন ইসলামের মূল স্তম্ভ হিসেবে আখ্যায়িত করা হয়েছে। স্তম্ভ ছাড়া যেমন কোনো ঘর দাঁড়িয়ে থাকতে পারে না, তেমনি নামাজ ছাড়া একজন মুসলিমের দ্বীনও পূর্ণাঙ্গ হয় না।',
  'আনাস ইবনে মালিক (রাঃ)', 'সহীহ', array['সালাত','নামাজ'], false, 1
from public.topics where slug = 'salah';

insert into public.sources
  (topic_id, type, title, reference, arabic_text, translation_bn, explanation, narrator, grade, tags, is_featured, sort_order)
select id, 'hadith',
  'উত্তম চরিত্রের মর্যাদা',
  'সুনানে আবু দাউদ, হাদিস নং ৪৭৯৯',
  'أَكْمَلُ الْمُؤْمِنِينَ إِيمَانًا أَحْسَنُهُمْ خُلُقًا',
  'ঈমানের দিক থেকে পরিপূর্ণ মুমিন সেই ব্যক্তি, যার চরিত্র সবচেয়ে উত্তম।',
  'এই হাদিস থেকে বোঝা যায়, ঈমানের পূর্ণতা শুধু ইবাদতের মধ্যে সীমাবদ্ধ নয়; বরং উত্তম আচরণ ও চরিত্রও ঈমানের অবিচ্ছেদ্য অংশ। একজন মুমিনের আচরণ তার ঈমানের প্রতিফলন।',
  'আবু হুরায়রা (রাঃ)', 'সহীহ', array['আখলাক','চরিত্র'], true, 1
from public.topics where slug = 'akhlaq';

-- ---------------------------------------------------------
-- Handy view: sources joined with topic info (used by the app)
-- ---------------------------------------------------------
create or replace view public.sources_with_topic as
select
  s.*,
  t.name_bn  as topic_name_bn,
  t.name_en  as topic_name_en,
  t.slug     as topic_slug,
  t.icon     as topic_icon
from public.sources s
join public.topics t on t.id = s.topic_id;