-- =============================================================================
-- Panthera — initial schema (v1 draft)
-- Supabase Postgres 15+ (uses ON DELETE SET NULL (column) on composite FKs)
--
-- Scope of this migration: tables, enums, constraints, indexes, integrity
-- triggers and invoker business functions. RLS is ENABLED on every table but
-- policies come in step 2 (access matrix). Until then, nothing is readable
-- through the API, which is the safe default.
--
-- Tenancy pattern: every tenant table carries company_id. Parents expose
-- UNIQUE (id, company_id) and children reference (x_id, company_id), so a row
-- can never point at a parent in another company. People inside a company are
-- referenced through memberships (company_id, user_id), never bare profiles.
-- =============================================================================

create extension if not exists moddatetime with schema extensions;

create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated, service_role;
-- private is NOT in the API's exposed schemas: nothing here is callable via /rpc.

-- -----------------------------------------------------------------------------
-- Enums
-- -----------------------------------------------------------------------------
create type public.member_role        as enum ('owner', 'admin', 'teacher', 'student');
create type public.visibility         as enum ('private', 'company');
create type public.assignment_status  as enum ('assigned', 'in_progress', 'submitted', 'reviewed', 'returned');
create type public.submission_outcome as enum ('reviewed', 'returned');
create type public.review_verdict     as enum ('correct', 'partial', 'incorrect');
create type public.event_status       as enum ('scheduled', 'cancelled');
create type public.participant_role   as enum ('teacher', 'student');
create type public.attendance_status  as enum ('present', 'absent', 'excused');
create type public.push_platform      as enum ('ios', 'android');
create type public.redeem_invite_result as enum
  ('ok', 'invalid', 'expired', 'revoked', 'exhausted', 'role_conflict', 'rate_limited');

-- -----------------------------------------------------------------------------
-- Small private utilities (security invoker, no registry entry needed)
-- -----------------------------------------------------------------------------
create function private.is_valid_timezone(tz text)
returns boolean
language sql stable
set search_path = ''
as $$
  select exists (select 1 from pg_catalog.pg_timezone_names where name = tz);
$$;

-- 8 chars from the plan's alphabet: no 0/O, 1/I/L  -> 23456789ABCDEFGHJKMNPQRSTUVWXYZ
create function private.generate_invite_code()
returns text
language sql volatile
set search_path = ''
as $$
  select string_agg(
           substr('23456789ABCDEFGHJKMNPQRSTUVWXYZ',
                  1 + floor(random() * 31)::int, 1), '')
  from generate_series(1, 8);
$$;
-- NOTE: random() is not a CSPRNG. Fine for 8-char, expiring, rate-limited
-- codes; switch to pgcrypto gen_random_bytes if we want to be strict.

-- =============================================================================
-- 1. Accounts and tenancy
-- =============================================================================

create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  full_name   text not null default '' check (char_length(full_name) <= 200),
  timezone    text not null default 'Europe/Warsaw'
              check (private.is_valid_timezone(timezone)),
  avatar_path text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
comment on table public.profiles is
  'One per auth user. No role, no company. Created by the handle_new_user trigger on auth.users.';

create table public.companies (
  id          uuid primary key default gen_random_uuid(),
  name        text not null check (char_length(btrim(name)) between 1 and 200),
  is_personal boolean not null default false,
  created_by  uuid references public.profiles (id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
-- one personal workspace per user
create unique index companies_one_personal_per_user
  on public.companies (created_by) where is_personal;

create table public.memberships (
  id          uuid primary key default gen_random_uuid(),
  company_id  uuid not null references public.companies (id) on delete cascade,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  role        public.member_role not null,
  -- role = permissions, can_teach = teaching. teacher => true, student => false,
  -- owner/admin => optional (true in personal workspaces).
  can_teach   boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (company_id, user_id),
  constraint memberships_can_teach_matches_role check (
       (role = 'teacher' and can_teach)
    or (role = 'student' and not can_teach)
    or role in ('owner', 'admin')
  )
);
create index memberships_user_id_idx on public.memberships (user_id);

-- Which students a teacher works with. A row exists if the link is direct
-- (invite / manual) OR derived from a group both are in. is_direct = false
-- means "group-only": removed automatically when the last group path goes.
create table public.teacher_students (
  id          uuid primary key default gen_random_uuid(),
  company_id  uuid not null,
  teacher_id  uuid not null,
  student_id  uuid not null,
  is_direct   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (company_id, teacher_id, student_id),
  check (teacher_id <> student_id),
  foreign key (company_id, teacher_id) references public.memberships (company_id, user_id) on delete cascade,
  foreign key (company_id, student_id) references public.memberships (company_id, user_id) on delete cascade
);
create index teacher_students_student_idx on public.teacher_students (company_id, student_id);

-- Groups: tables ship now, UI later. Created by owner/admin or by teachers.
create table public.groups (
  id          uuid primary key default gen_random_uuid(),
  company_id  uuid not null references public.companies (id) on delete cascade,
  name        text not null check (char_length(btrim(name)) between 1 and 200),
  created_by  uuid references public.profiles (id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (id, company_id)
);
create index groups_company_idx on public.groups (company_id);

create table public.group_members (
  group_id    uuid not null,
  company_id  uuid not null,
  student_id  uuid not null,
  created_at  timestamptz not null default now(),
  primary key (group_id, student_id),
  foreign key (group_id, company_id) references public.groups (id, company_id) on delete cascade,
  foreign key (company_id, student_id) references public.memberships (company_id, user_id) on delete cascade
);
create index group_members_student_idx on public.group_members (company_id, student_id);

create table public.group_teachers (
  group_id    uuid not null,
  company_id  uuid not null,
  teacher_id  uuid not null,
  created_at  timestamptz not null default now(),
  primary key (group_id, teacher_id),
  foreign key (group_id, company_id) references public.groups (id, company_id) on delete cascade,
  foreign key (company_id, teacher_id) references public.memberships (company_id, user_id) on delete cascade
);
create index group_teachers_teacher_idx on public.group_teachers (company_id, teacher_id);

-- =============================================================================
-- 2. Invites (plan §8)
-- =============================================================================

create table public.invites (
  id          uuid primary key default gen_random_uuid(),
  code        text not null unique default private.generate_invite_code()
              check (code ~ '^[2-9A-HJKMNP-Z]{8}$'),
  company_id  uuid not null references public.companies (id) on delete cascade,
  created_by  uuid not null references public.profiles (id) on delete cascade,
  role        public.member_role not null default 'student'
              check (role in ('admin', 'teacher', 'student')),
  -- { "group_ids": [uuid, ...] } — validated by trigger, applied by redeem_invite
  payload     jsonb not null default '{}' check (jsonb_typeof(payload) = 'object'),
  max_uses    int not null default 1 check (max_uses >= 1),
  use_count   int not null default 0 check (use_count >= 0 and use_count <= max_uses),
  expires_at  timestamptz not null,
  revoked_at  timestamptz,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index invites_company_idx on public.invites (company_id);
create index invites_created_by_idx on public.invites (created_by);

create table public.invite_redemptions (
  id          uuid primary key default gen_random_uuid(),
  invite_id   uuid not null references public.invites (id) on delete cascade,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  redeemed_at timestamptz not null default now(),
  unique (invite_id, user_id)
);
create index invite_redemptions_user_idx on public.invite_redemptions (user_id);

create table public.invite_failed_attempts (
  id           bigint generated always as identity primary key,
  user_id      uuid not null references public.profiles (id) on delete cascade,
  attempted_at timestamptz not null default now()
);
create index invite_failed_attempts_user_time_idx
  on public.invite_failed_attempts (user_id, attempted_at desc);

-- =============================================================================
-- 3. Resources bank (teacher's bank). Private by default, opt-in company share.
-- =============================================================================

create table public.levels (
  id          uuid primary key default gen_random_uuid(),
  company_id  uuid not null references public.companies (id) on delete cascade,
  name        text not null check (char_length(btrim(name)) between 1 and 100),
  position    int not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (id, company_id)
);
create unique index levels_company_name_uq on public.levels (company_id, lower(name));

create table public.school_classes (
  id          uuid primary key default gen_random_uuid(),
  company_id  uuid not null references public.companies (id) on delete cascade,
  name        text not null check (char_length(btrim(name)) between 1 and 100),
  position    int not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (id, company_id)
);
create unique index school_classes_company_name_uq on public.school_classes (company_id, lower(name));

create table public.exercise_templates (
  id              uuid primary key default gen_random_uuid(),
  company_id      uuid not null references public.companies (id) on delete cascade,
  author_id       uuid,
  visibility      public.visibility not null default 'private',
  description     text not null check (char_length(description) between 1 and 20000),
  level_id        uuid,
  school_class_id uuid,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (id, company_id),
  foreign key (company_id, author_id) references public.memberships (company_id, user_id)
    on delete set null (author_id),
  foreign key (level_id, company_id) references public.levels (id, company_id)
    on delete set null (level_id),
  foreign key (school_class_id, company_id) references public.school_classes (id, company_id)
    on delete set null (school_class_id)
);
create index exercise_templates_company_vis_idx on public.exercise_templates (company_id, visibility);
create index exercise_templates_author_idx on public.exercise_templates (company_id, author_id);

-- Images in the bank are immutable: a new edit = a new storage path.
create table public.exercise_template_images (
  id           uuid primary key default gen_random_uuid(),
  template_id  uuid not null,
  company_id   uuid not null,
  storage_path text not null,
  position     int not null default 0,
  created_at   timestamptz not null default now(),
  foreign key (template_id, company_id) references public.exercise_templates (id, company_id) on delete cascade
);
create index exercise_template_images_template_idx on public.exercise_template_images (template_id, position);

create table public.notes (
  id              uuid primary key default gen_random_uuid(),
  company_id      uuid not null references public.companies (id) on delete cascade,
  author_id       uuid,
  visibility      public.visibility not null default 'private',
  title           text not null check (char_length(btrim(title)) between 1 and 300),
  body            text not null default '' check (char_length(body) <= 100000),
  level_id        uuid,
  school_class_id uuid,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (id, company_id),
  foreign key (company_id, author_id) references public.memberships (company_id, user_id)
    on delete set null (author_id),
  foreign key (level_id, company_id) references public.levels (id, company_id)
    on delete set null (level_id),
  foreign key (school_class_id, company_id) references public.school_classes (id, company_id)
    on delete set null (school_class_id)
);
create index notes_company_vis_idx on public.notes (company_id, visibility);
create index notes_author_idx on public.notes (company_id, author_id);

create table public.note_images (
  id           uuid primary key default gen_random_uuid(),
  note_id      uuid not null,
  company_id   uuid not null,
  storage_path text not null,
  position     int not null default 0,
  created_at   timestamptz not null default now(),
  foreign key (note_id, company_id) references public.notes (id, company_id) on delete cascade
);
create index note_images_note_idx on public.note_images (note_id, position);

-- Tags follow item visibility: private (owned by a teacher) until attached to
-- a company-visible item, then promoted to a company tag (merged by name).
create table public.tags (
  id          uuid primary key default gen_random_uuid(),
  company_id  uuid not null references public.companies (id) on delete cascade,
  owner_id    uuid,
  visibility  public.visibility not null default 'private',
  name        text not null check (char_length(btrim(name)) between 1 and 60),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (id, company_id),
  foreign key (company_id, owner_id) references public.memberships (company_id, user_id)
    on delete set null (owner_id)
);
create unique index tags_private_name_uq on public.tags (company_id, owner_id, lower(name))
  where visibility = 'private';
create unique index tags_company_name_uq on public.tags (company_id, lower(name))
  where visibility = 'company';

create table public.template_tags (
  template_id uuid not null,
  tag_id      uuid not null,
  company_id  uuid not null,
  created_at  timestamptz not null default now(),
  primary key (template_id, tag_id),
  foreign key (template_id, company_id) references public.exercise_templates (id, company_id) on delete cascade,
  foreign key (tag_id, company_id) references public.tags (id, company_id) on delete cascade
);
create index template_tags_tag_idx on public.template_tags (tag_id);

create table public.note_tags (
  note_id     uuid not null,
  tag_id      uuid not null,
  company_id  uuid not null,
  created_at  timestamptz not null default now(),
  primary key (note_id, tag_id),
  foreign key (note_id, company_id) references public.notes (id, company_id) on delete cascade,
  foreign key (tag_id, company_id) references public.tags (id, company_id) on delete cascade
);
create index note_tags_tag_idx on public.note_tags (tag_id);

-- =============================================================================
-- 4. Calendar
-- =============================================================================

-- Company-defined event types. Each company is seeded with 'Lesson'.
-- Teachers, owners and admins can add more (enforced by RLS in step 2).
create table public.event_types (
  id          uuid primary key default gen_random_uuid(),
  company_id  uuid not null references public.companies (id) on delete cascade,
  name        text not null check (char_length(btrim(name)) between 1 and 60),
  is_default  boolean not null default false,
  created_by  uuid references public.profiles (id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (id, company_id)
);
create unique index event_types_company_name_uq on public.event_types (company_id, lower(name));
create unique index event_types_one_default on public.event_types (company_id) where is_default;

-- Recurring lessons. RRULE (RFC 5545) is expanded in TypeScript (Yoga) and
-- the concrete occurrences are inserted in ONE transaction by
-- create_lesson_series(). End date is mandatory (UNTIL or COUNT), all rows
-- are generated up front, max 12 months.
create table public.lesson_series (
  id                   uuid primary key default gen_random_uuid(),
  company_id           uuid not null references public.companies (id) on delete cascade,
  event_type_id        uuid not null,
  title                text check (title is null or char_length(btrim(title)) between 1 and 200),
  description          text check (description is null or char_length(description) <= 10000),
  location             text check (location is null or char_length(location) <= 500),
  meeting_url          text check (meeting_url is null or meeting_url ~* '^https://'),
  rrule                text not null check (
                            rrule ~ '^FREQ=(DAILY|WEEKLY|MONTHLY|YEARLY)(;[A-Z]+=[A-Za-z0-9,+:-]+)*$'
                        and rrule ~ '(^|;)(UNTIL|COUNT)='
                        and rrule !~ 'DTSTART'),
  timezone             text not null check (private.is_valid_timezone(timezone)),
  duration             interval not null check (duration > interval '0' and duration <= interval '24 hours'),
  first_starts_at      timestamptz not null,
  last_starts_at       timestamptz not null,
  split_from_series_id uuid references public.lesson_series (id) on delete set null,
  source_group_id      uuid,
  created_by           uuid references public.profiles (id) on delete set null,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  unique (id, company_id),
  check (last_starts_at >= first_starts_at),
  check (last_starts_at <= first_starts_at + interval '12 months'),
  foreign key (event_type_id, company_id) references public.event_types (id, company_id),
  foreign key (source_group_id, company_id) references public.groups (id, company_id)
    on delete set null (source_group_id)
);
create index lesson_series_company_idx on public.lesson_series (company_id);

-- Template participants copied onto every generated event.
create table public.lesson_series_participants (
  series_id   uuid not null,
  company_id  uuid not null,
  user_id     uuid not null,
  role        public.participant_role not null,
  created_at  timestamptz not null default now(),
  primary key (series_id, user_id),
  foreign key (series_id, company_id) references public.lesson_series (id, company_id) on delete cascade,
  foreign key (company_id, user_id) references public.memberships (company_id, user_id) on delete cascade
);
create index lesson_series_participants_user_idx on public.lesson_series_participants (company_id, user_id);

create table public.events (
  id                 uuid primary key default gen_random_uuid(),
  company_id         uuid not null references public.companies (id) on delete cascade,
  event_type_id      uuid not null,
  series_id          uuid,
  -- occurrence identity inside a series (the generated start, never edited)
  original_starts_at timestamptz,
  -- true once this occurrence was edited on its own ("this one")
  is_detached        boolean not null default false,
  title              text check (title is null or char_length(btrim(title)) between 1 and 200),
  description        text check (description is null or char_length(description) <= 10000),
  location           text check (location is null or char_length(location) <= 500),
  meeting_url        text check (meeting_url is null or meeting_url ~* '^https://'),
  starts_at          timestamptz not null,
  ends_at            timestamptz not null,
  status             public.event_status not null default 'scheduled',
  cancelled_at       timestamptz,
  source_group_id    uuid,
  created_by         uuid references public.profiles (id) on delete set null,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  unique (id, company_id),
  unique (series_id, original_starts_at),
  check (ends_at > starts_at),
  check ((series_id is null) = (original_starts_at is null)),
  check ((status = 'cancelled') = (cancelled_at is not null)),
  foreign key (event_type_id, company_id) references public.event_types (id, company_id),
  -- series are never deleted while they have events (NO ACTION)
  foreign key (series_id, company_id) references public.lesson_series (id, company_id),
  foreign key (source_group_id, company_id) references public.groups (id, company_id)
    on delete set null (source_group_id)
);
create index events_company_time_idx on public.events (company_id, starts_at);
create index events_series_idx on public.events (series_id, original_starts_at);

create table public.event_participants (
  id           uuid primary key default gen_random_uuid(),
  event_id     uuid not null,
  company_id   uuid not null,
  user_id      uuid not null,
  role         public.participant_role not null,
  attendance   public.attendance_status,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (event_id, user_id),
  check (role = 'student' or attendance is null),
  foreign key (event_id, company_id) references public.events (id, company_id) on delete cascade,
  foreign key (company_id, user_id) references public.memberships (company_id, user_id) on delete cascade
);
create index event_participants_user_idx on public.event_participants (company_id, user_id);

-- =============================================================================
-- 5. Homework, answers, review
-- =============================================================================

create table public.homeworks (
  id              uuid primary key default gen_random_uuid(),
  company_id      uuid not null references public.companies (id) on delete cascade,
  -- the teacher responsible (only reviewer). NULL = author left/deleted =>
  -- homework is read-only forever.
  author_id       uuid,
  -- who actually created it (owner/admin acting on behalf of a teacher)
  created_by      uuid references public.profiles (id) on delete set null,
  title           text not null check (char_length(btrim(title)) between 1 and 200),
  description     text check (description is null or char_length(description) <= 10000),
  due_at          timestamptz not null,
  event_id        uuid,
  source_group_id uuid,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (id, company_id),
  foreign key (company_id, author_id) references public.memberships (company_id, user_id)
    on delete set null (author_id),
  foreign key (event_id, company_id) references public.events (id, company_id)
    on delete set null (event_id),
  foreign key (source_group_id, company_id) references public.groups (id, company_id)
    on delete set null (source_group_id)
);
create index homeworks_company_due_idx on public.homeworks (company_id, due_at);
create index homeworks_author_idx on public.homeworks (company_id, author_id);
create index homeworks_event_idx on public.homeworks (event_id);

-- Copy-on-assign: copied from exercise_templates, always editable,
-- deletion blocked once any answer exists.
create table public.homework_exercises (
  id                 uuid primary key default gen_random_uuid(),
  homework_id        uuid not null,
  company_id         uuid not null,
  position           int not null default 0,
  description        text not null check (char_length(description) between 1 and 20000),
  source_template_id uuid references public.exercise_templates (id) on delete set null,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  unique (id, company_id),
  foreign key (homework_id, company_id) references public.homeworks (id, company_id) on delete cascade
);
create index homework_exercises_homework_idx on public.homework_exercises (homework_id, position);
create index homework_exercises_template_idx on public.homework_exercises (source_template_id);

create table public.homework_exercise_images (
  id           uuid primary key default gen_random_uuid(),
  exercise_id  uuid not null,
  company_id   uuid not null,
  storage_path text not null,
  position     int not null default 0,
  created_at   timestamptz not null default now(),
  foreign key (exercise_id, company_id) references public.homework_exercises (id, company_id) on delete cascade
);
create index homework_exercise_images_exercise_idx on public.homework_exercise_images (exercise_id, position);

-- One row per student per homework (snapshot at send time, also for groups).
create table public.assignments (
  id               uuid primary key default gen_random_uuid(),
  homework_id      uuid not null,
  company_id       uuid not null,
  student_id       uuid not null,
  status           public.assignment_status not null default 'assigned',
  current_attempt  smallint not null default 1 check (current_attempt >= 1),
  -- per-student extension; late = submitted_at > coalesce(due_at_override, homeworks.due_at)
  due_at_override  timestamptz,
  started_at       timestamptz,
  submitted_at     timestamptz,
  reviewed_at      timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  unique (id, company_id),
  unique (homework_id, student_id),
  foreign key (homework_id, company_id) references public.homeworks (id, company_id) on delete cascade,
  foreign key (company_id, student_id) references public.memberships (company_id, user_id) on delete cascade
);
create index assignments_student_idx on public.assignments (company_id, student_id, status);
create index assignments_homework_status_idx on public.assignments (homework_id, status);

-- History of submit rounds (one per attempt). Written by triggers only.
create table public.assignment_submissions (
  id            uuid primary key default gen_random_uuid(),
  assignment_id uuid not null,
  company_id    uuid not null,
  attempt_no    smallint not null check (attempt_no >= 1),
  submitted_at  timestamptz not null default now(),
  outcome       public.submission_outcome,
  outcome_at    timestamptz,
  reviewed_by   uuid references public.profiles (id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (assignment_id, attempt_no),
  check ((outcome is null) = (outcome_at is null)),
  foreign key (assignment_id, company_id) references public.assignments (id, company_id) on delete cascade
);

-- Written only by the student. One per assignment + exercise + attempt.
-- Attempt N+1 only contains exercises whose latest review was not 'correct';
-- the others carry over from earlier attempts (the "current answer" of an
-- exercise = its row with the highest attempt_no).
create table public.answers (
  id            uuid primary key default gen_random_uuid(),
  assignment_id uuid not null,
  company_id    uuid not null,
  exercise_id   uuid not null,
  attempt_no    smallint not null check (attempt_no >= 1),
  body          text not null default '' check (char_length(body) <= 20000),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (id, company_id),
  unique (assignment_id, exercise_id, attempt_no),
  foreign key (assignment_id, company_id) references public.assignments (id, company_id) on delete cascade,
  -- NO ACTION: deleting an answered exercise is blocked (cascades from
  -- company deletion still work: checked at end of statement)
  foreign key (exercise_id, company_id) references public.homework_exercises (id, company_id)
);
create index answers_exercise_idx on public.answers (exercise_id);

create table public.answer_images (
  id           uuid primary key default gen_random_uuid(),
  answer_id    uuid not null,
  company_id   uuid not null,
  storage_path text not null,
  position     int not null default 0,
  created_at   timestamptz not null default now(),
  foreign key (answer_id, company_id) references public.answers (id, company_id) on delete cascade
);
create index answer_images_answer_idx on public.answer_images (answer_id, position);

-- Written only by the homework author. Verdict + comment (points: backlog).
create table public.answer_reviews (
  id          uuid primary key default gen_random_uuid(),
  answer_id   uuid not null unique,
  company_id  uuid not null,
  reviewer_id uuid references public.profiles (id) on delete set null,
  verdict     public.review_verdict not null,
  comment     text check (comment is null or char_length(comment) <= 10000),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  foreign key (answer_id, company_id) references public.answers (id, company_id) on delete cascade
);

-- =============================================================================
-- 6. Shared notes (snapshots of bank notes). Attached to a homework, to a
--    lesson, or shared directly with students. Copied, like exercises.
-- =============================================================================

create table public.note_copies (
  id              uuid primary key default gen_random_uuid(),
  company_id      uuid not null references public.companies (id) on delete cascade,
  source_note_id  uuid references public.notes (id) on delete set null,
  author_id       uuid,
  title           text not null check (char_length(btrim(title)) between 1 and 300),
  body            text not null default '' check (char_length(body) <= 100000),
  homework_id     uuid,
  event_id        uuid,
  source_group_id uuid,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (id, company_id),
  -- attached to a homework, OR a lesson, OR neither (= direct share via recipients)
  check (num_nonnulls(homework_id, event_id) <= 1),
  foreign key (company_id, author_id) references public.memberships (company_id, user_id)
    on delete set null (author_id),
  foreign key (homework_id, company_id) references public.homeworks (id, company_id) on delete cascade,
  foreign key (event_id, company_id) references public.events (id, company_id) on delete cascade,
  foreign key (source_group_id, company_id) references public.groups (id, company_id)
    on delete set null (source_group_id)
);
create index note_copies_homework_idx on public.note_copies (homework_id);
create index note_copies_event_idx on public.note_copies (event_id);

create table public.note_copy_images (
  id           uuid primary key default gen_random_uuid(),
  note_copy_id uuid not null,
  company_id   uuid not null,
  storage_path text not null,
  position     int not null default 0,
  created_at   timestamptz not null default now(),
  foreign key (note_copy_id, company_id) references public.note_copies (id, company_id) on delete cascade
);
create index note_copy_images_copy_idx on public.note_copy_images (note_copy_id, position);

-- Direct shares (also group shares, expanded to students at share time).
create table public.note_copy_recipients (
  note_copy_id uuid not null,
  company_id   uuid not null,
  student_id   uuid not null,
  created_at   timestamptz not null default now(),
  primary key (note_copy_id, student_id),
  foreign key (note_copy_id, company_id) references public.note_copies (id, company_id) on delete cascade,
  foreign key (company_id, student_id) references public.memberships (company_id, user_id) on delete cascade
);
create index note_copy_recipients_student_idx on public.note_copy_recipients (company_id, student_id);

-- =============================================================================
-- 7. Notifications groundwork (backlog says: add now)
-- =============================================================================

create table public.push_tokens (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles (id) on delete cascade,
  token       text not null unique,
  platform    public.push_platform not null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index push_tokens_user_idx on public.push_tokens (user_id);

-- =============================================================================
-- 8. updated_at triggers
-- =============================================================================
do $$
declare t text;
begin
  foreach t in array array[
    'profiles','companies','memberships','teacher_students','groups','invites',
    'levels','school_classes','exercise_templates','notes','tags',
    'event_types','lesson_series','events','event_participants',
    'homeworks','homework_exercises','assignments','assignment_submissions',
    'answers','answer_reviews','note_copies','push_tokens'
  ] loop
    execute format(
      'create trigger set_updated_at before update on public.%I
         for each row execute function extensions.moddatetime(updated_at)', t);
  end loop;
end $$;

-- =============================================================================
-- 9. Integrity triggers (security invoker; RLS in step 2 must allow the
--    reads/writes they do — see DB decisions doc, "Step 2 notes")
-- =============================================================================

-- 9.1 Role assertions -----------------------------------------------------------
-- kind: 'teacher' => membership.can_teach ; 'student' => role = 'student'
create function private.assert_member_kind(p_company uuid, p_user uuid, p_kind text)
returns void
language plpgsql stable
set search_path = ''
as $$
begin
  if p_kind = 'teacher' and not exists (
       select 1 from public.memberships
       where company_id = p_company and user_id = p_user and can_teach) then
    raise exception 'user % is not a teacher in company %', p_user, p_company
      using errcode = '23514';
  elsif p_kind = 'student' and not exists (
       select 1 from public.memberships
       where company_id = p_company and user_id = p_user and role = 'student') then
    raise exception 'user % is not a student in company %', p_user, p_company
      using errcode = '23514';
  end if;
end $$;

create function private.trg_check_member_kinds()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  case tg_table_name
    when 'teacher_students' then
      perform private.assert_member_kind(new.company_id, new.teacher_id, 'teacher');
      perform private.assert_member_kind(new.company_id, new.student_id, 'student');
    when 'group_members', 'assignments', 'note_copy_recipients' then
      perform private.assert_member_kind(new.company_id, new.student_id, 'student');
    when 'group_teachers' then
      perform private.assert_member_kind(new.company_id, new.teacher_id, 'teacher');
    when 'event_participants', 'lesson_series_participants' then
      perform private.assert_member_kind(new.company_id, new.user_id, new.role::text);
    when 'homeworks', 'note_copies', 'exercise_templates', 'notes' then
      if new.author_id is not null then
        if tg_op = 'INSERT' then
          perform private.assert_member_kind(new.company_id, new.author_id, 'teacher');
        elsif new.author_id is distinct from old.author_id then
          perform private.assert_member_kind(new.company_id, new.author_id, 'teacher');
        end if;
      end if;
  end case;
  return new;
end $$;

create trigger check_member_kinds before insert or update on public.teacher_students
  for each row execute function private.trg_check_member_kinds();
create trigger check_member_kinds before insert or update on public.group_members
  for each row execute function private.trg_check_member_kinds();
create trigger check_member_kinds before insert or update on public.group_teachers
  for each row execute function private.trg_check_member_kinds();
create trigger check_member_kinds before insert or update on public.assignments
  for each row execute function private.trg_check_member_kinds();
create trigger check_member_kinds before insert or update on public.note_copy_recipients
  for each row execute function private.trg_check_member_kinds();
create trigger check_member_kinds before insert or update on public.event_participants
  for each row execute function private.trg_check_member_kinds();
create trigger check_member_kinds before insert or update on public.lesson_series_participants
  for each row execute function private.trg_check_member_kinds();
create trigger check_member_kinds before insert or update of author_id on public.homeworks
  for each row execute function private.trg_check_member_kinds();
create trigger check_member_kinds before insert or update of author_id on public.note_copies
  for each row execute function private.trg_check_member_kinds();
create trigger check_member_kinds before insert or update of author_id on public.exercise_templates
  for each row execute function private.trg_check_member_kinds();
create trigger check_member_kinds before insert or update of author_id on public.notes
  for each row execute function private.trg_check_member_kinds();

-- 9.2 Memberships: can_teach normalization + owner protection -------------------
create function private.trg_memberships_normalize()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.role = 'teacher' then new.can_teach := true;
  elsif new.role = 'student' then new.can_teach := false;
  end if;
  return new;
end $$;

create trigger normalize_can_teach before insert or update of role, can_teach on public.memberships
  for each row execute function private.trg_memberships_normalize();

-- Multiple owners allowed; the last owner of a NON-personal company can't
-- leave, be demoted, or delete their account. Skipped when the company itself
-- is being deleted (cascade: the company row is already gone).
create function private.trg_memberships_protect_last_owner()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.role = 'owner'
     and (tg_op = 'DELETE' or new.role <> 'owner')
     and exists (select 1 from public.companies c
                 where c.id = old.company_id and not c.is_personal)
     and not exists (select 1 from public.memberships m
                     where m.company_id = old.company_id
                       and m.role = 'owner'
                       and m.id <> old.id) then
    raise exception 'company % must keep at least one owner; transfer ownership first', old.company_id
      using errcode = '23514';
  end if;
  return coalesce(new, old);
end $$;

create trigger protect_last_owner before delete or update of role on public.memberships
  for each row execute function private.trg_memberships_protect_last_owner();

-- A personal workspace lives and dies with its owner: when the owner's
-- membership goes (account deletion or leaving), the whole company is
-- deleted, including students' homework, answers and lessons in it.
create function private.trg_memberships_delete_personal_company()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.role = 'owner' then
    delete from public.companies c
     where c.id = old.company_id and c.is_personal;
  end if;
  return null;
end $$;

create trigger delete_personal_company after delete on public.memberships
  for each row execute function private.trg_memberships_delete_personal_company();

-- 9.3 Companies: seed default event type ----------------------------------------
create function private.trg_companies_seed()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  insert into public.event_types (company_id, name, is_default, created_by)
  values (new.id, 'Lesson', true, new.created_by);
  return null;
end $$;

-- Deferred to commit, so the creator's owner membership already exists when
-- event_types RLS evaluates the insert (see create_personal_workspace).
create constraint trigger seed_company after insert on public.companies
  deferrable initially deferred
  for each row execute function private.trg_companies_seed();

-- 9.4 Group -> teacher_students live sync ---------------------------------------
-- Recomputes one (teacher, student) pair: ensures a row exists if any group
-- path exists, removes a group-only row (is_direct = false) if none does.
create function private.sync_teacher_student(p_company uuid, p_teacher uuid, p_student uuid)
returns void
language plpgsql
set search_path = ''
as $$
begin
  if exists (
    select 1
    from public.group_members gm
    join public.group_teachers gt on gt.group_id = gm.group_id
    where gm.company_id = p_company
      and gm.student_id = p_student
      and gt.teacher_id = p_teacher
  ) then
    insert into public.teacher_students (company_id, teacher_id, student_id, is_direct)
    values (p_company, p_teacher, p_student, false)
    on conflict (company_id, teacher_id, student_id) do nothing;
  else
    delete from public.teacher_students
    where company_id = p_company
      and teacher_id = p_teacher
      and student_id = p_student
      and not is_direct;
  end if;
end $$;

create function private.trg_group_members_sync()
returns trigger
language plpgsql
set search_path = ''
as $$
declare r record; v_row public.group_members;
begin
  v_row := coalesce(new, old);
  for r in select teacher_id from public.group_teachers where group_id = v_row.group_id loop
    perform private.sync_teacher_student(v_row.company_id, r.teacher_id, v_row.student_id);
  end loop;
  return null;
end $$;

create function private.trg_group_teachers_sync()
returns trigger
language plpgsql
set search_path = ''
as $$
declare r record; v_row public.group_teachers;
begin
  v_row := coalesce(new, old);
  for r in select student_id from public.group_members where group_id = v_row.group_id loop
    perform private.sync_teacher_student(v_row.company_id, v_row.teacher_id, r.student_id);
  end loop;
  return null;
end $$;

create trigger sync_teacher_students after insert or delete on public.group_members
  for each row execute function private.trg_group_members_sync();
create trigger sync_teacher_students after insert or delete on public.group_teachers
  for each row execute function private.trg_group_teachers_sync();

-- Whole-group delete: the cascaded member/teacher rows are gone before their
-- row triggers run, so resync the company's group-only links afterwards.
create function private.trg_groups_resync()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  delete from public.teacher_students ts
   where ts.company_id = old.company_id
     and not ts.is_direct
     and not exists (select 1 from public.group_members gm
                     join public.group_teachers gt on gt.group_id = gm.group_id
                     where gm.company_id = ts.company_id
                       and gm.student_id = ts.student_id
                       and gt.teacher_id = ts.teacher_id);
  return null;
end $$;

create trigger resync_teacher_students after delete on public.groups
  for each row execute function private.trg_groups_resync();

-- Removing a direct link keeps a group-derived one: the app calls
-- unlink_teacher_student() instead of deleting the row.
create function public.unlink_teacher_student(p_company uuid, p_teacher uuid, p_student uuid)
returns void
language plpgsql
set search_path = ''
as $$
begin
  update public.teacher_students
     set is_direct = false
   where company_id = p_company and teacher_id = p_teacher and student_id = p_student;
  perform private.sync_teacher_student(p_company, p_teacher, p_student);
end $$;

-- 9.5 Invites: validate payload ---------------------------------------------------
create function private.trg_invites_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
declare v_gid text;
begin
  if new.payload ? 'group_ids' then
    if jsonb_typeof(new.payload -> 'group_ids') <> 'array' then
      raise exception 'payload.group_ids must be an array' using errcode = '22023';
    end if;
    if new.role <> 'student' and jsonb_array_length(new.payload -> 'group_ids') > 0 then
      raise exception 'only student invites can carry groups' using errcode = '22023';
    end if;
    for v_gid in select jsonb_array_elements_text(new.payload -> 'group_ids') loop
      if not exists (select 1 from public.groups
                     where id = v_gid::uuid and company_id = new.company_id) then
        raise exception 'group % does not belong to company %', v_gid, new.company_id
          using errcode = '23503';
      end if;
    end loop;
  end if;
  if (new.payload - 'group_ids') <> '{}'::jsonb then
    raise exception 'unknown payload keys: %', (new.payload - 'group_ids') using errcode = '22023';
  end if;
  return new;
end $$;

create trigger validate_invite before insert or update of payload, role on public.invites
  for each row execute function private.trg_invites_validate();

-- 9.6 Tags follow item visibility ---------------------------------------------------
-- Promote one private tag to company scope; merge into an existing company
-- tag with the same name if there is one.
create function private.promote_tag(p_tag uuid)
returns void
language plpgsql
set search_path = ''
as $$
declare v_tag public.tags; v_existing uuid;
begin
  select * into v_tag from public.tags where id = p_tag;
  if not found or v_tag.visibility = 'company' then return; end if;

  select id into v_existing from public.tags
   where company_id = v_tag.company_id and visibility = 'company'
     and lower(name) = lower(v_tag.name);

  if v_existing is null then
    update public.tags set visibility = 'company' where id = p_tag;
  else
    insert into public.template_tags (template_id, tag_id, company_id)
      select template_id, v_existing, company_id from public.template_tags where tag_id = p_tag
      on conflict do nothing;
    insert into public.note_tags (note_id, tag_id, company_id)
      select note_id, v_existing, company_id from public.note_tags where tag_id = p_tag
      on conflict do nothing;
    delete from public.tags where id = p_tag;   -- cascades old links
  end if;
end $$;

-- On link: the tag must be a company tag or owned by the item's author;
-- if the item is company-visible, promote the tag.
create function private.trg_item_tags_check()
returns trigger
language plpgsql
set search_path = ''
as $$
declare v_item_author uuid; v_item_vis public.visibility; v_tag public.tags;
begin
  if tg_table_name = 'template_tags' then
    select author_id, visibility into v_item_author, v_item_vis
      from public.exercise_templates where id = new.template_id;
  else
    select author_id, visibility into v_item_author, v_item_vis
      from public.notes where id = new.note_id;
  end if;
  select * into v_tag from public.tags where id = new.tag_id;

  if v_tag.visibility = 'private' and v_tag.owner_id is distinct from v_item_author then
    raise exception 'private tag % belongs to another teacher', new.tag_id using errcode = '42501';
  end if;
  if v_item_vis = 'company' and v_tag.visibility = 'private' then
    perform private.promote_tag(new.tag_id);
  end if;
  return null;
end $$;

create trigger check_tag after insert on public.template_tags
  for each row execute function private.trg_item_tags_check();
create trigger check_tag after insert on public.note_tags
  for each row execute function private.trg_item_tags_check();

-- On share: promote all private tags of the item.
create function private.trg_item_shared_promote_tags()
returns trigger
language plpgsql
set search_path = ''
as $$
declare r record;
begin
  if new.visibility = 'company' and old.visibility = 'private' then
    if tg_table_name = 'exercise_templates' then
      for r in select tt.tag_id from public.template_tags tt
               join public.tags t on t.id = tt.tag_id
               where tt.template_id = new.id and t.visibility = 'private' loop
        perform private.promote_tag(r.tag_id);
      end loop;
    else
      for r in select nt.tag_id from public.note_tags nt
               join public.tags t on t.id = nt.tag_id
               where nt.note_id = new.id and t.visibility = 'private' loop
        perform private.promote_tag(r.tag_id);
      end loop;
    end if;
  end if;
  return null;
end $$;

create trigger promote_tags_on_share after update of visibility on public.exercise_templates
  for each row execute function private.trg_item_shared_promote_tags();
create trigger promote_tags_on_share after update of visibility on public.notes
  for each row execute function private.trg_item_shared_promote_tags();

-- 9.7 Events: cancelled_at + detach on "this one" edits ---------------------------
create function private.trg_events_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status = 'cancelled' then
    new.cancelled_at := coalesce(new.cancelled_at, now());
  else
    new.cancelled_at := null;
  end if;

  if tg_op = 'UPDATE' then
    if new.original_starts_at is distinct from old.original_starts_at
       or new.series_id is distinct from old.series_id then
      raise exception 'series_id / original_starts_at are immutable' using errcode = '42501';
    end if;
    if new.series_id is not null and (
         new.starts_at       is distinct from old.starts_at
      or new.ends_at         is distinct from old.ends_at
      or new.title           is distinct from old.title
      or new.description     is distinct from old.description
      or new.location        is distinct from old.location
      or new.meeting_url     is distinct from old.meeting_url
      or new.event_type_id   is distinct from old.event_type_id
      or new.status          is distinct from old.status) then
      new.is_detached := true;
    end if;
  end if;
  return new;
end $$;

create trigger before_write before insert or update on public.events
  for each row execute function private.trg_events_before_write();

-- 9.8 Homework: delete guards ------------------------------------------------------
-- Blocked once any answer exists. Not blocked when the parent is being
-- deleted by cascade (company / homework row already gone).
create function private.trg_homeworks_block_delete()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if exists (select 1 from public.companies where id = old.company_id)
     and exists (select 1 from public.answers a
                 join public.assignments s on s.id = a.assignment_id
                 where s.homework_id = old.id) then
    raise exception 'homework % has answers and cannot be deleted', old.id
      using errcode = '23503';
  end if;
  return old;
end $$;

create trigger block_delete_if_answered before delete on public.homeworks
  for each row execute function private.trg_homeworks_block_delete();

create function private.trg_homework_exercises_block_delete()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if exists (select 1 from public.homeworks where id = old.homework_id)
     and exists (select 1 from public.answers where exercise_id = old.id) then
    raise exception 'exercise % has answers and cannot be deleted', old.id
      using errcode = '23503';
  end if;
  return old;
end $$;

create trigger block_delete_if_answered before delete on public.homework_exercises
  for each row execute function private.trg_homework_exercises_block_delete();

-- 9.9 Assignment status machine ------------------------------------------------------
--   assigned    -> in_progress   (first answer saved; automatic)
--   in_progress -> submitted     (student)
--   submitted   -> reviewed      (author)
--   submitted   -> returned      (author)  => current_attempt + 1
--   returned    -> in_progress   (first answer of the new attempt; automatic)
-- Homework with author_id NULL is read-only: no submit, no review.
create function private.trg_assignments_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
declare v_author uuid;
begin
  if tg_op = 'INSERT' then
    if new.status <> 'assigned' or new.current_attempt <> 1
       or new.started_at is not null or new.submitted_at is not null or new.reviewed_at is not null then
      raise exception 'new assignments start as assigned, attempt 1' using errcode = '23514';
    end if;
    return new;
  end if;

  if new.homework_id <> old.homework_id or new.student_id <> old.student_id
     or new.company_id <> old.company_id then
    raise exception 'assignment identity is immutable' using errcode = '42501';
  end if;

  if new.status = old.status then
    -- columns owned by the state machine can't be edited directly
    if new.current_attempt is distinct from old.current_attempt
       or new.started_at   is distinct from old.started_at
       or new.submitted_at is distinct from old.submitted_at
       or new.reviewed_at  is distinct from old.reviewed_at then
      raise exception 'state columns are managed by the status machine' using errcode = '42501';
    end if;
    return new;   -- e.g. due_at_override change
  end if;

  select author_id into v_author from public.homeworks where id = new.homework_id;
  if v_author is null then
    raise exception 'homework is read-only (its teacher left)' using errcode = '42501';
  end if;

  -- reset any state columns the caller tried to set; we own them
  new.current_attempt := old.current_attempt;
  new.started_at      := old.started_at;
  new.submitted_at    := old.submitted_at;
  new.reviewed_at     := old.reviewed_at;

  case
    when old.status in ('assigned', 'returned') and new.status = 'in_progress' then
      new.started_at := coalesce(old.started_at, now());
    when old.status = 'in_progress' and new.status = 'submitted' then
      new.submitted_at := now();
    when old.status = 'submitted' and new.status = 'reviewed' then
      new.reviewed_at := now();
    when old.status = 'submitted' and new.status = 'returned' then
      new.current_attempt := old.current_attempt + 1;
    else
      raise exception 'invalid assignment transition % -> %', old.status, new.status
        using errcode = '23514';
  end case;
  return new;
end $$;

create trigger transition before insert or update on public.assignments
  for each row execute function private.trg_assignments_transition();

-- Submission history rows follow the status changes.
create function private.trg_assignments_after_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status = old.status then return null; end if;

  if new.status = 'submitted' then
    insert into public.assignment_submissions (assignment_id, company_id, attempt_no, submitted_at)
    values (new.id, new.company_id, new.current_attempt, new.submitted_at);
  elsif new.status in ('reviewed', 'returned') then
    update public.assignment_submissions
       set outcome     = new.status::text::public.submission_outcome,
           outcome_at  = now(),
           reviewed_by = (select auth.uid())
     where assignment_id = new.id
       and attempt_no = old.current_attempt;
  end if;
  return null;
end $$;

create trigger after_transition after update of status on public.assignments
  for each row execute function private.trg_assignments_after_transition();

-- 9.10 Answers: editable only in the current, open attempt --------------------------
create function private.assert_answer_writable(p_assignment uuid, p_exercise uuid, p_attempt smallint)
returns void
language plpgsql
set search_path = ''
as $$
declare v_a public.assignments; v_author uuid; v_hw uuid;
begin
  select * into v_a from public.assignments where id = p_assignment;
  select author_id into v_author from public.homeworks where id = v_a.homework_id;
  select homework_id into v_hw from public.homework_exercises where id = p_exercise;

  if v_hw is distinct from v_a.homework_id then
    raise exception 'exercise does not belong to this homework' using errcode = '23514';
  end if;
  if v_author is null then
    raise exception 'homework is read-only (its teacher left)' using errcode = '42501';
  end if;
  if v_a.status not in ('assigned', 'in_progress', 'returned') then
    raise exception 'answers are locked while status is %', v_a.status using errcode = '42501';
  end if;
  if p_attempt <> v_a.current_attempt then
    raise exception 'only the current attempt (%) is editable', v_a.current_attempt
      using errcode = '42501';
  end if;
  -- attempt > 1: only exercises whose latest review was not 'correct'
  if p_attempt > 1 and exists (
       select 1 from (
         select r.verdict
         from public.answers prev
         left join public.answer_reviews r on r.answer_id = prev.id
         where prev.assignment_id = p_assignment
           and prev.exercise_id = p_exercise
           and prev.attempt_no < p_attempt
         order by prev.attempt_no desc
         limit 1
       ) latest
       where latest.verdict = 'correct') then
    raise exception 'this exercise was already marked correct' using errcode = '42501';
  end if;
end $$;

create function private.trg_answers_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    -- cascades (assignment/homework/company deleted) skip the guard
    if not exists (select 1 from public.assignments where id = old.assignment_id) then
      return old;
    end if;
    perform private.assert_answer_writable(old.assignment_id, old.exercise_id, old.attempt_no);
    return old;
  end if;

  if tg_op = 'UPDATE' then
    if new.assignment_id <> old.assignment_id or new.exercise_id <> old.exercise_id
       or new.attempt_no <> old.attempt_no then
      raise exception 'answer identity is immutable' using errcode = '42501';
    end if;
  elsif new.attempt_no is null then
    -- client may omit attempt_no: default to the current attempt
    select current_attempt into new.attempt_no
      from public.assignments where id = new.assignment_id;
  end if;

  perform private.assert_answer_writable(new.assignment_id, new.exercise_id, new.attempt_no);
  return new;
end $$;

create trigger guard before insert or update or delete on public.answers
  for each row execute function private.trg_answers_guard();

-- First write in an attempt moves the assignment to in_progress.
create function private.trg_answers_start_assignment()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  update public.assignments
     set status = 'in_progress'
   where id = new.assignment_id
     and status in ('assigned', 'returned');
  return null;
end $$;

create trigger start_assignment after insert or update on public.answers
  for each row execute function private.trg_answers_start_assignment();

create function private.trg_answer_images_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare v_ans public.answers;
begin
  select * into v_ans from public.answers where id = coalesce(new.answer_id, old.answer_id);
  if not found then return coalesce(new, old); end if;  -- cascade delete
  perform private.assert_answer_writable(v_ans.assignment_id, v_ans.exercise_id, v_ans.attempt_no);
  return coalesce(new, old);
end $$;

create trigger guard before insert or update or delete on public.answer_images
  for each row execute function private.trg_answer_images_guard();

-- 9.11 Reviews: only for the submitted attempt of a non-orphaned homework ------------
create function private.trg_answer_reviews_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare v_ans public.answers; v_a public.assignments; v_author uuid;
begin
  -- let FK actions through (reviewer_id SET NULL on profile deletion)
  if tg_op = 'UPDATE'
     and new.verdict is not distinct from old.verdict
     and new.comment is not distinct from old.comment
     and new.answer_id = old.answer_id then
    return new;
  end if;
  if tg_op = 'DELETE' and not exists (select 1 from public.answers where id = old.answer_id) then
    return old;  -- cascade
  end if;
  select * into v_ans from public.answers where id = coalesce(new.answer_id, old.answer_id);
  select * into v_a from public.assignments where id = v_ans.assignment_id;
  select author_id into v_author from public.homeworks where id = v_a.homework_id;

  if v_author is null then
    raise exception 'homework is read-only (its teacher left)' using errcode = '42501';
  end if;
  if v_a.status <> 'submitted' or v_ans.attempt_no <> v_a.current_attempt then
    raise exception 'only answers of the submitted attempt can be reviewed' using errcode = '42501';
  end if;
  if tg_op <> 'DELETE' then
    new.reviewer_id := (select auth.uid());
  end if;
  return coalesce(new, old);
end $$;

create trigger guard before insert or update or delete on public.answer_reviews
  for each row execute function private.trg_answer_reviews_guard();

-- =============================================================================
-- 10. Business functions (security invoker => RLS applies; no registry entry)
-- =============================================================================

create function public.submit_assignment(p_assignment_id uuid)
returns public.assignments
language sql
set search_path = ''
as $$
  update public.assignments set status = 'submitted'
   where id = p_assignment_id
  returning *;
$$;

create function public.review_assignment(p_assignment_id uuid, p_outcome public.submission_outcome)
returns public.assignments
language sql
set search_path = ''
as $$
  update public.assignments set status = p_outcome::text::public.assignment_status
   where id = p_assignment_id
  returning *;
$$;

-- Standalone teacher onboarding: "I'm a teacher" without an invite.
create function public.create_personal_workspace(p_name text default null)
returns uuid
language plpgsql
set search_path = ''
as $$
declare
  v_uid     uuid := (select auth.uid());
  v_company uuid := gen_random_uuid();   -- no RETURNING: row isn't visible until membership exists
  v_name    text;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  select coalesce(nullif(btrim(p_name), ''), nullif(btrim(full_name), ''), 'My workspace')
    into v_name from public.profiles where id = v_uid;

  insert into public.companies (id, name, is_personal, created_by)
  values (v_company, coalesce(v_name, 'My workspace'), true, v_uid);

  insert into public.memberships (company_id, user_id, role, can_teach)
  values (v_company, v_uid, 'owner', true);

  return v_company;
end $$;

-- Create a series and all its occurrences in ONE transaction.
-- p_occurrences: starts expanded from the RRULE in TypeScript (in the
-- series timezone, converted to timestamptz). ends_at = start + duration.
-- p_participants: [{ "user_id": uuid, "role": "teacher" | "student" }]
create function public.create_lesson_series(
  p_company_id      uuid,
  p_event_type_id   uuid,
  p_rrule           text,
  p_timezone        text,
  p_duration        interval,
  p_occurrences     timestamptz[],
  p_participants    jsonb,
  p_title           text default null,
  p_description     text default null,
  p_location        text default null,
  p_meeting_url     text default null,
  p_source_group_id uuid default null
)
returns uuid
language plpgsql
set search_path = ''
as $$
declare
  v_series uuid := gen_random_uuid();
  v_occ    timestamptz[];
begin
  select array_agg(o order by o) into v_occ
    from (select distinct unnest(p_occurrences) o) s;
  if v_occ is null or array_length(v_occ, 1) = 0 then
    raise exception 'a series needs at least one occurrence' using errcode = '22023';
  end if;
  if array_length(v_occ, 1) <> array_length(p_occurrences, 1) then
    raise exception 'duplicate occurrences' using errcode = '22023';
  end if;

  insert into public.lesson_series (
    id, company_id, event_type_id, title, description, location, meeting_url,
    rrule, timezone, duration, first_starts_at, last_starts_at, source_group_id, created_by)
  values (
    v_series, p_company_id, p_event_type_id, p_title, p_description, p_location, p_meeting_url,
    p_rrule, p_timezone, p_duration, v_occ[1], v_occ[array_length(v_occ, 1)],
    p_source_group_id, (select auth.uid()));

  insert into public.lesson_series_participants (series_id, company_id, user_id, role)
  select v_series, p_company_id, (p->>'user_id')::uuid, (p->>'role')::public.participant_role
    from jsonb_array_elements(p_participants) p;

  perform private.generate_series_events(v_series, v_occ);
  return v_series;
end $$;

create function private.generate_series_events(p_series uuid, p_occurrences timestamptz[])
returns void
language plpgsql
set search_path = ''
as $$
declare s public.lesson_series;
begin
  select * into s from public.lesson_series where id = p_series;

  insert into public.events (
    company_id, event_type_id, series_id, original_starts_at,
    title, description, location, meeting_url, starts_at, ends_at,
    source_group_id, created_by)
  select s.company_id, s.event_type_id, s.id, o,
         s.title, s.description, s.location, s.meeting_url, o, o + s.duration,
         s.source_group_id, (select auth.uid())
    from unnest(p_occurrences) o;

  insert into public.event_participants (event_id, company_id, user_id, role)
  select e.id, e.company_id, sp.user_id, sp.role
    from public.events e
    join public.lesson_series_participants sp on sp.series_id = e.series_id
   where e.series_id = p_series
     and e.original_starts_at = any (p_occurrences);
end $$;

-- "This and following": end the old series before p_from (an occurrence's
-- original_starts_at), delete its occurrences from p_from on, and create a new
-- series (split_from_series_id = old) with the new rule/fields/occurrences.
-- Occurrences that already have attendance are kept and block the split.
create function public.split_lesson_series(
  p_series_id       uuid,
  p_from            timestamptz,
  p_old_rrule       text,          -- old rule re-written with UNTIL < p_from (from TS)
  p_rrule           text,
  p_timezone        text,
  p_duration        interval,
  p_occurrences     timestamptz[],
  p_participants    jsonb,
  p_event_type_id   uuid default null,
  p_title           text default null,
  p_description     text default null,
  p_location        text default null,
  p_meeting_url     text default null
)
returns uuid
language plpgsql
set search_path = ''
as $$
declare
  s          public.lesson_series;
  v_new      uuid;
  v_last_old timestamptz;
begin
  select * into s from public.lesson_series where id = p_series_id for update;
  if not found then
    raise exception 'series not found' using errcode = 'P0002';
  end if;
  if p_from <= s.first_starts_at then
    raise exception 'split point must be after the first occurrence; edit the whole series instead'
      using errcode = '22023';
  end if;
  if exists (select 1 from unnest(p_occurrences) o where o < p_from) then
    raise exception 'new occurrences must start at or after the split point' using errcode = '22023';
  end if;
  if exists (select 1 from public.event_participants ep
             join public.events e on e.id = ep.event_id
             where e.series_id = p_series_id and e.original_starts_at >= p_from
               and ep.attendance is not null) then
    raise exception 'future occurrences already have attendance' using errcode = '23514';
  end if;

  select max(original_starts_at) into v_last_old
    from public.events where series_id = p_series_id and original_starts_at < p_from;
  if v_last_old is null then
    raise exception 'no remaining occurrences before split point' using errcode = '22023';
  end if;

  delete from public.events
   where series_id = p_series_id and original_starts_at >= p_from;

  update public.lesson_series
     set rrule = p_old_rrule, last_starts_at = v_last_old
   where id = p_series_id;

  v_new := public.create_lesson_series(
    s.company_id, coalesce(p_event_type_id, s.event_type_id), p_rrule, p_timezone, p_duration,
    p_occurrences, p_participants, p_title, p_description, p_location, p_meeting_url,
    s.source_group_id);

  update public.lesson_series set split_from_series_id = p_series_id where id = v_new;
  return v_new;
end $$;

-- =============================================================================
-- 11. Privileged paths (approved in plan §7.2). Listed in
--     docs/security-definer-registry.md. search_path = '', qualified names,
--     caller identified only via (select auth.uid()).
-- =============================================================================

-- Profile on sign-up (approved 2026-10-07). Runs as the table owner because
-- Supabase's auth role can't write public.profiles. No caller input; not
-- callable through the API. Apple: the app saves the name after first sign-in.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name)
  values (
    new.id,
    left(coalesce(
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'name',
      ''
    ), 200)
  );
  return new;
end $$;

revoke execute on function public.handle_new_user() from public, anon, authenticated;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Preview for the registration screen. Callable by anon.
create function public.preview_invite(p_code text)
returns table (company_name text, inviter_name text, role public.member_role)
language sql stable
security definer
set search_path = ''
as $$
  select c.name, p.full_name, i.role
    from public.invites i
    join public.companies c on c.id = i.company_id
    join public.profiles  p on p.id = i.created_by
   where i.code = upper(btrim(p_code))
     and i.revoked_at is null
     and i.expires_at > now()
     and i.use_count < i.max_uses;
$$;

-- Redeem in one transaction. Failures are RETURNED (not raised) so the
-- failed-attempt row is committed. Rate limit: 10 invalid codes / hour / user.
create function public.redeem_invite(p_code text)
returns table (result public.redeem_invite_result, company_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_uid       uuid := (select auth.uid());
  v_inv       public.invites;
  v_existing  public.memberships;
  v_gid       text;
  c_max_fails constant int := 10;
  c_window    constant interval := interval '1 hour';
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  if (select count(*) from public.invite_failed_attempts f
       where f.user_id = v_uid and f.attempted_at > now() - c_window) >= c_max_fails then
    return query select 'rate_limited'::public.redeem_invite_result, null::uuid;
    return;
  end if;

  select * into v_inv from public.invites i
   where i.code = upper(btrim(p_code))
   for update;

  if not found then
    insert into public.invite_failed_attempts (user_id) values (v_uid);
    return query select 'invalid'::public.redeem_invite_result, null::uuid;
    return;
  end if;
  if v_inv.revoked_at is not null then
    return query select 'revoked'::public.redeem_invite_result, v_inv.company_id; return;
  end if;
  if v_inv.expires_at <= now() then
    return query select 'expired'::public.redeem_invite_result, v_inv.company_id; return;
  end if;
  if v_inv.use_count >= v_inv.max_uses then
    return query select 'exhausted'::public.redeem_invite_result, v_inv.company_id; return;
  end if;

  -- Same user redeeming the same invite twice is a no-op success.
  if exists (select 1 from public.invite_redemptions r
              where r.invite_id = v_inv.id and r.user_id = v_uid) then
    return query select 'ok'::public.redeem_invite_result, v_inv.company_id; return;
  end if;

  select * into v_existing from public.memberships m
   where m.company_id = v_inv.company_id and m.user_id = v_uid;

  if found and v_existing.role <> v_inv.role then
    return query select 'role_conflict'::public.redeem_invite_result, v_inv.company_id; return;
  end if;

  if not found then
    insert into public.memberships (company_id, user_id, role)
    values (v_inv.company_id, v_uid, v_inv.role);
  end if;

  if v_inv.role = 'student' then
    -- direct teacher link if the inviter teaches in this company
    if exists (select 1 from public.memberships m
                where m.company_id = v_inv.company_id
                  and m.user_id = v_inv.created_by and m.can_teach) then
      insert into public.teacher_students (company_id, teacher_id, student_id, is_direct)
      values (v_inv.company_id, v_inv.created_by, v_uid, true)
      on conflict (company_id, teacher_id, student_id) do update set is_direct = true;
    end if;

    -- groups from the DB row, never from the link
    for v_gid in select jsonb_array_elements_text(coalesce(v_inv.payload -> 'group_ids', '[]'::jsonb)) loop
      if exists (select 1 from public.groups g
                  where g.id = v_gid::uuid and g.company_id = v_inv.company_id) then
        insert into public.group_members (group_id, company_id, student_id)
        values (v_gid::uuid, v_inv.company_id, v_uid)
        on conflict do nothing;
      end if;
    end loop;
  end if;

  update public.invites set use_count = use_count + 1 where id = v_inv.id;
  insert into public.invite_redemptions (invite_id, user_id) values (v_inv.id, v_uid);

  return query select 'ok'::public.redeem_invite_result, v_inv.company_id;
end $$;

-- =============================================================================
-- 12. Function privileges
-- =============================================================================
revoke execute on all functions in schema private from public, anon;
grant  execute on all functions in schema private to authenticated, service_role;

revoke execute on function
  public.unlink_teacher_student(uuid, uuid, uuid),
  public.submit_assignment(uuid),
  public.review_assignment(uuid, public.submission_outcome),
  public.create_personal_workspace(text),
  public.create_lesson_series(uuid, uuid, text, text, interval, timestamptz[], jsonb, text, text, text, text, uuid),
  public.split_lesson_series(uuid, timestamptz, text, text, text, interval, timestamptz[], jsonb, uuid, text, text, text, text),
  public.preview_invite(text),
  public.redeem_invite(text)
from public, anon;

grant execute on function
  public.unlink_teacher_student(uuid, uuid, uuid),
  public.submit_assignment(uuid),
  public.review_assignment(uuid, public.submission_outcome),
  public.create_personal_workspace(text),
  public.create_lesson_series(uuid, uuid, text, text, interval, timestamptz[], jsonb, text, text, text, text, uuid),
  public.split_lesson_series(uuid, timestamptz, text, text, text, interval, timestamptz[], jsonb, uuid, text, text, text, text),
  public.redeem_invite(text)
to authenticated;

grant execute on function public.preview_invite(text) to anon, authenticated;

-- =============================================================================
-- 13. Row Level Security: enabled everywhere, policies in step 2
-- =============================================================================
do $$
declare t text;
begin
  for t in select tablename from pg_tables where schemaname = 'public' loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

-- =============================================================================
-- 14. Realtime (review list updates live; students see reviews)
-- =============================================================================
alter publication supabase_realtime add table
  public.assignments,
  public.assignment_submissions,
  public.answer_reviews;
