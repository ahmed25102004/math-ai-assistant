-- ==========================================
-- FILE: 001_initial_schema.sql
-- ==========================================
-- =====================================================
-- Sensei AI
-- Initial Database Schema
-- Migration 001
-- =====================================================

create extension if not exists vector;

-- =====================================================
-- ENUMS
-- =====================================================

create type app_role as enum (
    'student',
    'reviewer',
    'admin'
);

create type document_status as enum (
    'uploaded',
    'parsing',
    'embedding',
    'indexed',
    'failed'
);

create type generation_kind as enum (
    'question_bank',
    'flashcards',
    'study_plan',
    'revision_sheet',
    'test_help'
);

create type review_status as enum (
    'pending',
    'approved',
    'rejected',
    'needs_edit'
);

create type chat_kind as enum (
    'mentor',
    'concept'
);

-- =====================================================
-- PROFILES
-- =====================================================

create table public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,

    full_name text not null,
    initials text not null,
    avatar_url text,

    created_at timestamptz not null default now()
);

-- =====================================================
-- USER ROLES
-- =====================================================

create table public.user_roles (
    id uuid primary key default gen_random_uuid(),

    user_id uuid not null
        references public.profiles(id)
        on delete cascade,

    role app_role not null default 'student',

    created_at timestamptz not null default now(),

    unique(user_id, role)
);

-- =====================================================
-- WORKSPACES
-- =====================================================

create type workspace_accent as enum (
    'primary',
    'info',
    'success',
    'warning'
);

create table public.workspaces (
    id uuid primary key default gen_random_uuid(),

    owner_id uuid not null
        references public.profiles(id)
        on delete cascade,

    name text not null,
    subject text not null,
    description text,

    accent workspace_accent,

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

-- =====================================================
-- DOCUMENTS
-- =====================================================

create table public.documents (
    id uuid primary key default gen_random_uuid(),

    workspace_id uuid not null
        references public.workspaces(id)
        on delete cascade,

    uploaded_by uuid not null
        references public.profiles(id)
        on delete cascade,

    title text not null,

    kind text not null,

    size_bytes bigint,

    pages integer,

    chunk_count integer not null default 0,

    status document_status not null default 'uploaded',

    storage_path text,

    notes text,

    topics text[] not null default '{}',

    coverage numeric(5,2),

    created_at timestamptz not null default now()
);

-- =====================================================
-- CHUNKS
-- =====================================================

create table public.chunks (
    id uuid primary key default gen_random_uuid(),

    document_id uuid not null
        references public.documents(id)
        on delete cascade,

    workspace_id uuid not null
        references public.workspaces(id)
        on delete cascade,

    chunk_index integer not null,

    page integer,

    content text not null,

    token_count integer,

    created_at timestamptz not null default now(),

    unique(document_id, chunk_index)
);

-- =====================================================
-- EMBEDDINGS
-- =====================================================

create table public.embeddings (
    id uuid primary key default gen_random_uuid(),

    chunk_id uuid not null
        references public.chunks(id)
        on delete cascade,

    embedding vector(1536) not null,

    model text not null,

    created_at timestamptz not null default now(),

    unique(chunk_id)
);

-- =====================================================
-- GENERATIONS
-- =====================================================

create table public.generations (
    id uuid primary key default gen_random_uuid(),

    workspace_id uuid not null
        references public.workspaces(id)
        on delete cascade,

    created_by uuid not null
        references public.profiles(id)
        on delete cascade,

    kind generation_kind not null,

    model text not null,

    title text not null,

    payload jsonb not null,

    document_ids uuid[] not null default '{}',

    grounding_score numeric(5,2),

    quality_score numeric(5,2),

    review_status review_status not null default 'pending',

    created_at timestamptz not null default now()
);

-- =====================================================
-- GENERATION VERSIONS
-- =====================================================

create table public.generation_versions (
    id uuid primary key default gen_random_uuid(),

    generation_id uuid not null
        references public.generations(id)
        on delete cascade,

    version integer not null,

    payload jsonb not null,

    edited_by uuid
        references public.profiles(id)
        on delete set null,

    created_at timestamptz not null default now(),

    unique(generation_id, version)
);

-- =====================================================
-- REVIEWS
-- =====================================================

create table public.reviews (
    id uuid primary key default gen_random_uuid(),

    generation_id uuid not null
        references public.generations(id)
        on delete cascade,

    workspace_id uuid not null
        references public.workspaces(id)
        on delete cascade,

    item_id text not null,

    reviewer_id uuid
        references public.profiles(id)
        on delete set null,

    status review_status not null default 'pending',

    comment text,

    created_at timestamptz not null default now()
);

-- =====================================================
-- CHATS
-- =====================================================

create table public.chats (
    id uuid primary key default gen_random_uuid(),

    workspace_id uuid not null
        references public.workspaces(id)
        on delete cascade,

    user_id uuid not null
        references public.profiles(id)
        on delete cascade,

    kind chat_kind not null,

    title text not null,

    model text not null,

    created_at timestamptz not null default now()
);

-- =====================================================
-- CHAT MESSAGES
-- =====================================================

create table public.chat_messages (
    id uuid primary key default gen_random_uuid(),

    chat_id uuid not null
        references public.chats(id)
        on delete cascade,

    role text not null
        check (role in ('user','assistant','system')),

    content text not null,

    citations jsonb,

    created_at timestamptz not null default now()
);

-- =====================================================
-- NOTIFICATIONS
-- =====================================================

create table public.notifications (
    id uuid primary key default gen_random_uuid(),

    user_id uuid
        references public.profiles(id)
        on delete cascade,

    workspace_id uuid
        references public.workspaces(id)
        on delete cascade,

    roles app_role[] not null default '{}',

    kind text not null,

    title text not null,

    body text not null,

    read boolean not null default false,

    created_at timestamptz not null default now()
);

-- =====================================================
-- HISTORY
-- =====================================================

create table public.history (
    id uuid primary key default gen_random_uuid(),

    workspace_id uuid not null
        references public.workspaces(id)
        on delete cascade,

    user_id uuid not null
        references public.profiles(id)
        on delete cascade,

    generation_id uuid
        references public.generations(id)
        on delete set null,

    kind generation_kind not null,

    title text not null,

    model text not null,

    review_status review_status not null,

    created_at timestamptz not null default now()
);

-- =====================================================
-- ANALYTICS
-- =====================================================

create table public.analytics (
    workspace_id uuid primary key
        references public.workspaces(id)
        on delete cascade,

    documents integer not null default 0,

    generations integer not null default 0,

    approvals integer not null default 0,

    rejections integer not null default 0,

    avg_grounding numeric(5,2) not null default 0,

    avg_quality numeric(5,2) not null default 0,

    captured_at timestamptz not null default now()
);

-- =====================================================
-- INDEXES
-- =====================================================

create index idx_workspaces_owner
on public.workspaces(owner_id);

create index idx_documents_workspace
on public.documents(workspace_id);

create index idx_chunks_document
on public.chunks(document_id);

create index idx_chunks_workspace
on public.chunks(workspace_id);

create index idx_embeddings_chunk
on public.embeddings(chunk_id);

create index idx_generations_workspace
on public.generations(workspace_id);

create index idx_reviews_generation
on public.reviews(generation_id);

create index idx_reviews_workspace
on public.reviews(workspace_id);

create index idx_chats_workspace
on public.chats(workspace_id);

create index idx_chat_messages_chat
on public.chat_messages(chat_id);

create index idx_notifications_user
on public.notifications(user_id);

create index idx_history_workspace
on public.history(workspace_id);

-- =====================================================
-- HELPER FUNCTIONS
-- =====================================================

drop function if exists public.has_role(uuid, app_role) cascade;

create or replace function public.has_role(
    user_id uuid,
    required app_role
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1
        from public.user_roles
        where user_id = has_role.user_id
          and role = has_role.required
    );
$$;

grant execute on function public.has_role(uuid, app_role)
to authenticated;

create or replace function public.update_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

-- =====================================================
-- TRIGGERS
-- =====================================================

create trigger trg_workspaces_updated_at
before update on public.workspaces
for each row
execute function public.update_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin

    insert into public.profiles (
        id,
        full_name,
        initials,
        avatar_url
    )

    values (

        new.id,

        coalesce(
            new.raw_user_meta_data->>'full_name',
            split_part(new.email, '@', 1)
        ),

        upper(
            left(
                coalesce(
                    new.raw_user_meta_data->>'full_name',
                    split_part(new.email, '@', 1)
                ),
                2
            )
        ),

        null

    );

    return new;

end;
$$;

create or replace function public.assign_default_role()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin

    insert into public.user_roles (

        user_id,
        role

    )

    values (

        new.id,
        'student'

    );

    return new;

end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_new_user();

create trigger on_profile_created
after insert on public.profiles
for each row
execute function public.assign_default_role();

-- =====================================================
-- ROW LEVEL SECURITY
-- =====================================================

alter table public.profiles enable row level security;
alter table public.user_roles enable row level security;
alter table public.workspaces enable row level security;
alter table public.documents enable row level security;
alter table public.chunks enable row level security;
alter table public.embeddings enable row level security;
alter table public.generations enable row level security;
alter table public.generation_versions enable row level security;
alter table public.reviews enable row level security;
alter table public.chats enable row level security;
alter table public.chat_messages enable row level security;
alter table public.notifications enable row level security;
alter table public.history enable row level security;
alter table public.analytics enable row level security;

create policy "Users can view their own profile"
on public.profiles
for select
to authenticated
using (id = auth.uid());

create policy "Users can update their own profile"
on public.profiles
for update
to authenticated
using (id = auth.uid());

create policy "Users can insert their own profile"
on public.profiles
for insert
to authenticated
with check (id = auth.uid());

create policy "Users manage their own workspaces"
on public.workspaces
for all
to authenticated
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

create policy "Workspace owners manage documents"
on public.documents
for all
to authenticated
using (
    exists (
        select 1
        from public.workspaces
        where workspaces.id = documents.workspace_id
        and workspaces.owner_id = auth.uid()
    )
)
with check (
    exists (
        select 1
        from public.workspaces
        where workspaces.id = documents.workspace_id
        and workspaces.owner_id = auth.uid()
    )
);

create policy "Workspace owners manage generations"
on public.generations
for all
to authenticated
using (
    exists (
        select 1
        from public.workspaces
        where workspaces.id = generations.workspace_id
        and workspaces.owner_id = auth.uid()
    )
)
with check (
    exists (
        select 1
        from public.workspaces
        where workspaces.id = generations.workspace_id
        and workspaces.owner_id = auth.uid()
    )
);

create policy "Reviewers can manage reviews"
on public.reviews
for all
to authenticated
using (
    public.has_role(auth.uid(), 'reviewer')
    or
    public.has_role(auth.uid(), 'admin')
)
with check (
    public.has_role(auth.uid(), 'reviewer')
    or
    public.has_role(auth.uid(), 'admin')
);

create policy "Users read their own notifications"
on public.notifications
for select
to authenticated
using (
    user_id = auth.uid()
);

-- =====================================================
-- REMAINING RLS POLICIES
-- =====================================================

-- -----------------------------------------------------
-- Chunks
-- -----------------------------------------------------

create policy "Workspace owners manage chunks"
on public.chunks
for all
to authenticated
using (
    exists (
        select 1
        from public.documents d
        join public.workspaces w
            on w.id = d.workspace_id
        where d.id = chunks.document_id
        and w.owner_id = auth.uid()
    )
)
with check (
    exists (
        select 1
        from public.documents d
        join public.workspaces w
            on w.id = d.workspace_id
        where d.id = chunks.document_id
        and w.owner_id = auth.uid()
    )
);

-- -----------------------------------------------------
-- Embeddings
-- -----------------------------------------------------

create policy "Workspace owners manage embeddings"
on public.embeddings
for all
to authenticated
using (
    exists (
        select 1
        from public.chunks c
        join public.documents d
            on d.id = c.document_id
        join public.workspaces w
            on w.id = d.workspace_id
        where c.id = embeddings.chunk_id
        and w.owner_id = auth.uid()
    )
)
with check (
    exists (
        select 1
        from public.chunks c
        join public.documents d
            on d.id = c.document_id
        join public.workspaces w
            on w.id = d.workspace_id
        where c.id = embeddings.chunk_id
        and w.owner_id = auth.uid()
    )
);

-- -----------------------------------------------------
-- Chats
-- -----------------------------------------------------

create policy "Users manage their chats"
on public.chats
for all
to authenticated
using (
    user_id = auth.uid()
)
with check (
    user_id = auth.uid()
);

-- -----------------------------------------------------
-- Chat Messages
-- -----------------------------------------------------

create policy "Users manage their chat messages"
on public.chat_messages
for all
to authenticated
using (
    exists (
        select 1
        from public.chats
        where chats.id = chat_messages.chat_id
        and chats.user_id = auth.uid()
    )
)
with check (
    exists (
        select 1
        from public.chats
        where chats.id = chat_messages.chat_id
        and chats.user_id = auth.uid()
    )
);

-- -----------------------------------------------------
-- History
-- -----------------------------------------------------

create policy "Users manage their history"
on public.history
for all
to authenticated
using (
    user_id = auth.uid()
)
with check (
    user_id = auth.uid()
);

-- -----------------------------------------------------
-- Analytics
-- -----------------------------------------------------

create policy "Workspace owners view analytics"
on public.analytics
for all
to authenticated
using (
    exists (
        select 1
        from public.workspaces
        where workspaces.id = analytics.workspace_id
        and workspaces.owner_id = auth.uid()
    )
)
with check (
    exists (
        select 1
        from public.workspaces
        where workspaces.id = analytics.workspace_id
        and workspaces.owner_id = auth.uid()
    )
);

-- -----------------------------------------------------
-- Generation Versions
-- -----------------------------------------------------

create policy "Workspace owners manage versions"
on public.generation_versions
for all
to authenticated
using (
    exists (
        select 1
        from public.generations g
        join public.workspaces w
            on w.id = g.workspace_id
        where g.id = generation_versions.generation_id
        and w.owner_id = auth.uid()
    )
)
with check (
    exists (
        select 1
        from public.generations g
        join public.workspaces w
            on w.id = g.workspace_id
        where g.id = generation_versions.generation_id
        and w.owner_id = auth.uid()
    )
);

-- ==========================================
-- FILE: 002_storage_policies.sql
-- ==========================================
-- =====================================================
-- Sensei AI
-- Storage Policies
-- Migration 002
-- =====================================================

create policy "Users can upload their own files"
on storage.objects
for insert
to authenticated
with check (
    bucket_id = 'documents'
);

create policy "Users can read their own files"
on storage.objects
for select
to authenticated
using (
    bucket_id = 'documents'
);

create policy "Users can delete their own files"
on storage.objects
for delete
to authenticated
using (
    bucket_id = 'documents'
);

-- ==========================================
-- FILE: 003_policy.sql
-- ==========================================
-- Enable RLS (safe to run multiple times)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- Profiles: user can read only their own profile
-- =====================================================

DROP POLICY IF EXISTS "Users can read their own profile"
ON public.profiles;

CREATE POLICY "Users can read their own profile"
ON public.profiles
FOR SELECT
TO authenticated
USING (auth.uid() = id);

-- =====================================================
-- User Roles: user can read only their own role
-- =====================================================

DROP POLICY IF EXISTS "Users can read their own role"
ON public.user_roles;

CREATE POLICY "Users can read their own role"
ON public.user_roles
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- ==========================================
-- FILE: 008_workspace_ownership.sql
-- ==========================================
-- ============================================================================
-- 008_workspace_ownership.sql
--
-- Phase 7.1 — Workspace ownership.
--
-- Exposes the workspace list the frontend renders (the `Workspace` domain model
-- in src/types/domain.ts) as a single denormalised read model so
-- src/api/workspace.api.ts can load workspaces together with the owner identity
-- and the review summary in one query.
--
-- Scope is deliberately Phase 7.1 ONLY:
--   * `workspace_with_owner` view  (owner-info joins + computed review fields)
--   * supporting indexes
--   * GRANTs
--
-- Deliberately NOT in this migration (land in Phase 7.2): RLS, policies,
-- the `app_role` enum and the `has_role()` helper, visibility filtering.
--
-- The base schema (workspaces, documents, generations, profiles and
-- auth.users) is created outside these migration files — see
-- docs/DATABASE_SCHEMA.md and src/types/database.types.ts.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- workspace_with_owner view
--
-- Joins workspaces -> profiles (owner full_name) and auth.users (owner email),
-- then adds per-workspace aggregates over documents and generations:
--   * document_count         total documents in the workspace
--   * generation_count       total generations in the workspace
--   * pending_review_count   generations still awaiting review
--   * review_status          review status of the workspace's most recent
--                            generation ('pending' when there are none)
--
-- A plain (security-definer) view runs with the view owner's privileges, so
-- the GRANTs below are the only access `authenticated` needs — it never reads
-- auth.users or the base tables directly.
--
-- CREATE OR REPLACE keeps the object idempotent and lets Phase 7.2 add its
-- visibility WHERE clause to the same view without recreating dependent
-- objects.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.workspace_with_owner AS
SELECT
    w.id,
    w.owner_id,
    w.name,
    w.subject,
    w.description,
    w.accent,
    w.created_at,
    w.updated_at,
    p.full_name AS owner_name,
    au.email    AS owner_email,
    (SELECT count(*) FROM public.documents d WHERE d.workspace_id = w.id)
        AS document_count,
    (SELECT count(*) FROM public.generations g WHERE g.workspace_id = w.id)
        AS generation_count,
    (SELECT count(*) FROM public.generations g
        WHERE g.workspace_id = w.id AND g.review_status = 'pending')
        AS pending_review_count,
    COALESCE((
        SELECT g.review_status
        FROM public.generations g
        WHERE g.workspace_id = w.id
        ORDER BY g.created_at DESC, g.id DESC
        LIMIT 1
    ), 'pending') AS review_status
FROM public.workspaces w
LEFT JOIN public.profiles p ON p.id = w.owner_id
LEFT JOIN auth.users   au ON au.id = w.owner_id;

COMMENT ON VIEW public.workspace_with_owner IS
    'Workspaces joined with owner identity and review summary (Phase 7.1).';
COMMENT ON COLUMN public.workspace_with_owner.owner_name IS
    'Owner display name from profiles.full_name.';
COMMENT ON COLUMN public.workspace_with_owner.owner_email IS
    'Owner email from auth.users (not directly readable by anon/authenticated).';
COMMENT ON COLUMN public.workspace_with_owner.document_count IS
    'Total documents in the workspace.';
COMMENT ON COLUMN public.workspace_with_owner.generation_count IS
    'Total generations in the workspace.';
COMMENT ON COLUMN public.workspace_with_owner.pending_review_count IS
    'Generations with review_status = ''pending''.';
COMMENT ON COLUMN public.workspace_with_owner.review_status IS
    'Review status of the workspace''s most recent generation; ''pending'' when the workspace has no generations.';

-- ---------------------------------------------------------------------------
-- Supporting indexes
--
-- Feed the view''s per-workspace aggregates. IF NOT EXISTS keeps the migration
-- idempotent against a base schema that may already carry these indexes.
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_documents_workspace_id
    ON public.documents (workspace_id);

CREATE INDEX IF NOT EXISTS idx_generations_workspace_id
    ON public.generations (workspace_id);

CREATE INDEX IF NOT EXISTS idx_generations_workspace_review_status
    ON public.generations (workspace_id, review_status);

CREATE INDEX IF NOT EXISTS idx_generations_workspace_created_at
    ON public.generations (workspace_id, created_at DESC);

-- ---------------------------------------------------------------------------
-- GRANTs
--
-- SELECT on the view is all `authenticated` gets — the view (not the base
-- tables) is the read path for the workspace list. service_role bypasses RLS
-- but is granted for symmetry with the rest of the schema.
-- ---------------------------------------------------------------------------
GRANT SELECT ON public.workspace_with_owner TO authenticated;
GRANT SELECT ON public.workspace_with_owner TO service_role;


-- ==========================================
-- FILE: 009_workspace_visibility.sql
-- ==========================================
-- ============================================================================
-- 009_workspace_visibility.sql
--
-- Phase 7.2 — RLS workspace visibility.
--
-- Makes workspace visibility a server-side decision:
--
--   * Student  → sees ONLY workspaces they own (owner_id = auth.uid()).
--   * Reviewer → sees their own plus every student workspace.
--   * Admin    → sees everything.
--
-- How it works:
--   * `workspace_with_owner` is a security-definer view (PostgREST lints it,
--     but the view's own WHERE clause now gates every row with the same
--     visibility predicate, so RLS-bypass by the view is not a leak). The
--     view keeps reading profiles/auth.users as its owner, so NO new grants
--     on base tables or auth.users are needed.
--   * The same predicate is ALSO expressed as RLS policies on `workspaces`
--     (defense in depth for direct table access, matching the workspace
--     visibility model).
--   * `has_role()` / `has_full_access()` are SECURITY DEFINER helpers so
--     policies and the view can read `user_roles` without RLS recursion.
--
-- Deliberately NOT in this migration (land in Phase 7.3): RLS on child
-- tables (documents, generations, reviews), storage buckets, realtime.
--
-- Idempotency: every object is created only if missing — the app_role enum
-- and functions are guarded by pg_type/to_regprocedure checks, the
-- user_roles table and indexes use IF NOT EXISTS, policies are created via a
-- pg_policies existence check, and the view uses CREATE OR REPLACE. Nothing
-- is DROPped and no existing definition is silently overwritten, so 009 is
-- safe to re-run in the Supabase SQL editor AND to keep as a single entry in
-- the migration history. Ordering 009 > 008.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. app_role enum + user_roles table (guarded — the base schema lives
--    outside the migration chain; these are Phase 7.2's only hard prereqs).
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE t.typname = 'app_role' AND n.nspname = 'public'
  ) THEN
    CREATE TYPE public.app_role AS ENUM ('student', 'reviewer', 'admin');
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.user_roles (
  id      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  role    public.app_role NOT NULL,
  UNIQUE (user_id, role)
);

-- ---------------------------------------------------------------------------
-- 2. Role helpers
--
-- Functions are created ONLY if missing (detect-and-create via
-- to_regprocedure), never dropped or blindly replaced. In a migration
-- history each migration runs once, but 009 also needs to be safe to re-run
-- in the SQL editor, so nothing here should delete or silently overwrite an
-- existing definition.
-- ---------------------------------------------------------------------------

-- SECURITY DEFINER so policies
-- and the security-definer view can read user_roles without RLS recursion.
DO $$
BEGIN
  IF to_regprocedure('public.has_role(uuid, public.app_role)') IS NULL THEN
    CREATE FUNCTION public.has_role(user_id uuid, required public.app_role)
    RETURNS boolean
    LANGUAGE sql
    STABLE
    SECURITY DEFINER
    SET search_path = public
    AS $fn$
      SELECT EXISTS (
        SELECT 1 FROM public.user_roles ur
        WHERE ur.user_id = has_role.user_id
          AND ur.role   = has_role.required
      );
    $fn$;
  END IF;
END $$;

-- True for admins and reviewers. A NULL uid (service_role / SQL editor / cron
-- requests have no JWT) is treated as full access so trusted contexts keep
-- reading; the anon role never reaches this function (no GRANT on the view).
DO $$
BEGIN
  IF to_regprocedure('public.has_full_access(uuid)') IS NULL THEN
    CREATE FUNCTION public.has_full_access(uid uuid)
    RETURNS boolean
    LANGUAGE sql
    STABLE
    AS $fn$
      SELECT uid IS NULL
          OR public.has_role(uid, 'admin')
          OR public.has_role(uid, 'reviewer');
    $fn$;
  END IF;
END $$;

GRANT EXECUTE ON FUNCTION public.has_role(uuid, public.app_role) TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_full_access(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- 3. RLS on workspaces (defense in depth + documented §5 behaviour)
-- ---------------------------------------------------------------------------
ALTER TABLE public.workspaces ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'workspaces'
      AND policyname = 'workspace_owner_access'
  ) THEN
    CREATE POLICY "workspace_owner_access"
      ON public.workspaces FOR ALL TO authenticated
      USING ((select auth.uid()) = owner_id)
      WITH CHECK ((select auth.uid()) = owner_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'workspaces'
      AND policyname = 'workspace_staff_read'
  ) THEN
    CREATE POLICY "workspace_staff_read"
      ON public.workspaces FOR SELECT TO authenticated
      USING (public.has_full_access((select auth.uid())));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'workspaces'
      AND policyname = 'workspace_staff_write'
  ) THEN
    CREATE POLICY "workspace_staff_write"
      ON public.workspaces FOR UPDATE TO authenticated
      USING (public.has_full_access((select auth.uid())));
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 4. Indexes for the policy / view predicates
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_workspaces_owner_id
  ON public.workspaces (owner_id);

CREATE INDEX IF NOT EXISTS idx_user_roles_user_id
  ON public.user_roles (user_id);

-- ---------------------------------------------------------------------------
-- 5. Re-create workspace_with_owner with the visibility predicate.
--
-- The view stays security-definer so the owner-info joins keep working with
-- only the view-level GRANT — but every returned row is gated by the same
-- predicate the RLS policies use, so students never see other students'
-- workspaces through the app's read path.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.workspace_with_owner AS
SELECT
    w.id,
    w.owner_id,
    w.name,
    w.subject,
    w.description,
    w.accent,
    w.created_at,
    w.updated_at,
    p.full_name AS owner_name,
    au.email    AS owner_email,
    (SELECT count(*) FROM public.documents d WHERE d.workspace_id = w.id)
        AS document_count,
    (SELECT count(*) FROM public.generations g WHERE g.workspace_id = w.id)
        AS generation_count,
    (SELECT count(*) FROM public.generations g
        WHERE g.workspace_id = w.id AND g.review_status = 'pending')
        AS pending_review_count,
    COALESCE((
        SELECT g.review_status
        FROM public.generations g
        WHERE g.workspace_id = w.id
        ORDER BY g.created_at DESC, g.id DESC
        LIMIT 1
    ), 'pending') AS review_status
FROM public.workspaces w
LEFT JOIN public.profiles p ON p.id = w.owner_id
LEFT JOIN auth.users   au ON au.id = w.owner_id
WHERE public.has_full_access((select auth.uid()))
   OR w.owner_id = (select auth.uid());

COMMENT ON VIEW public.workspace_with_owner IS
    'Workspaces joined with owner identity and review summary, filtered to the caller''s visibility (Phase 7.1 + 7.2).';

-- ---------------------------------------------------------------------------
-- 6. GRANTs (re-issued; idempotent)
-- ---------------------------------------------------------------------------
GRANT SELECT ON public.workspace_with_owner TO authenticated;
GRANT SELECT ON public.workspace_with_owner TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.workspaces TO authenticated;
GRANT ALL ON public.workspaces TO service_role;


-- ==========================================
-- FILE: 010_workspace_visibility_hard_fix.sql
-- ==========================================
-- ============================================================================
-- 010_workspace_visibility_hard_fix.sql
--
-- Phase 7.2 root-cause fix for workspace visibility.
--
-- Problem: 009's detect-and-create guards skipped replacing the OLD
-- `public.has_role(uuid, app_role)` that 001_initial_schema.sql already
-- created (create or replace). `has_full_access` therefore stays bound to the
-- OLD function and the live `user_roles` rows it reads; in the live DB those
-- rows resolve the "student" account as staff, so the view's
-- `WHERE has_full_access(...)` passes for every row and the student sees every
-- workspace.
--
-- Fix: CREATE OR REPLACE is non-destructive — it swaps the function bodies in
-- place, keeps the same OIDs, and does NOT break the view or RLS policies that
-- reference these functions. No DROP, no tables/enums/triggers touched.
-- 010 is idempotent and safe to re-run in the Supabase SQL editor.
--
-- Ordering: 010 > 009 > 008. Requires the objects from 001 and 009 to exist.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Force the intended role helpers to be the live ones.
--
-- CREATE OR REPLACE replaces the existing 001 definition in place (same OID),
-- so `workspace_with_owner` and the `workspace_*` policies keep their valid
-- references — no dependency breakage, no DROP ... CASCADE.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.has_role(user_id uuid, required public.app_role)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles ur
    WHERE ur.user_id = has_role.user_id
      AND ur.role   = has_role.required
  );
$fn$;

CREATE OR REPLACE FUNCTION public.has_full_access(uid uuid)
RETURNS boolean
LANGUAGE sql
STABLE
AS $fn$
  SELECT uid IS NULL
      OR public.has_role(uid, 'admin')
      OR public.has_role(uid, 'reviewer');
$fn$;

GRANT EXECUTE ON FUNCTION public.has_role(uuid, public.app_role) TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_full_access(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- 2. Re-assert the gate (same shape as 009; CREATE OR REPLACE is idempotent).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.workspace_with_owner AS
SELECT
    w.id,
    w.owner_id,
    w.name,
    w.subject,
    w.description,
    w.accent,
    w.created_at,
    w.updated_at,
    p.full_name AS owner_name,
    au.email    AS owner_email,
    (SELECT count(*) FROM public.documents d WHERE d.workspace_id = w.id)
        AS document_count,
    (SELECT count(*) FROM public.generations g WHERE g.workspace_id = w.id)
        AS generation_count,
    (SELECT count(*) FROM public.generations g
        WHERE g.workspace_id = w.id AND g.review_status = 'pending')
        AS pending_review_count,
    COALESCE((
        SELECT g.review_status
        FROM public.generations g
        WHERE g.workspace_id = w.id
        ORDER BY g.created_at DESC, g.id DESC
        LIMIT 1
    ), 'pending') AS review_status
FROM public.workspaces w
LEFT JOIN public.profiles p ON p.id = w.owner_id
LEFT JOIN auth.users   au ON au.id = w.owner_id
WHERE public.has_full_access((select auth.uid()))
   OR w.owner_id = (select auth.uid());

COMMENT ON VIEW public.workspace_with_owner IS
    'Workspaces joined with owner identity and review summary, filtered to the caller''s visibility (Phase 7.1 + 7.2).';

-- ---------------------------------------------------------------------------
-- 3. GRANTs (re-issued; idempotent)
-- ---------------------------------------------------------------------------
GRANT SELECT ON public.workspace_with_owner TO authenticated;
GRANT SELECT ON public.workspace_with_owner TO service_role;

-- ---------------------------------------------------------------------------
-- 4. DATA CLEANUP (the actual staff grant lives in the data, not the code).
--
-- 010 fixes the function binding; if the "student" account still holds
-- 'reviewer'/'admin' rows in public.user_roles, remove them so the account
-- resolves as a pure student. Run this ONCE after 010, replacing
-- <student_auth_uid> with the student's auth.users id.
-- ---------------------------------------------------------------------------
-- DELETE FROM public.user_roles
-- WHERE user_id = '<student_auth_uid>' AND role IN ('reviewer', 'admin');
--
-- Confirm: select * from public.user_roles where user_id = '<student_auth_uid>';
-- should show only the ('student') row.
-- Then sign in as the student and run:
--   select id, owner_id, name from public.workspace_with_owner;
-- non-owned workspaces must no longer appear.


-- ==========================================
-- FILE: 011_document_security.sql
-- ==========================================
-- ============================================================================
-- 011_document_security.sql
--
-- Phase 7.3 — Document / Generation / Review security (RLS ownership model).
--
-- Requirement (Phase 7.3 security model — RLS ownership by workspace):
--   * Student   → full CRUD on the documents, generations and reviews that
--                 belong to workspaces they own. Read-only access to nothing
--                 owned by another student.
--   * Reviewer  → read-only access to documents/generations across ALL
--                 workspaces, plus write access to the review trail.
--   * Admin     → same read-everything model as reviewers (has_full_access).
--
-- 001 already creates owner-scoped policies (documents, generations, chunks,
-- embeddings, generation_versions) and a reviewer/admin policy on reviews.
-- This migration ADDS the missing read paths for staff (documents/generations/
-- chunks/embeddings/versions) and the owner read path for reviews so the Data
-- API enforces the full Phase 7.3 ownership model. Nothing existing is dropped
-- or rewritten.
--
-- Idempotency: every policy is created inside a pg_policies existence check
-- (same pattern as 009) and grants are unconditional — safe to re-run in the
-- SQL editor. Ordering: 011 > 010 > 009 > 008 > 001.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. GRANTs so the Data API can serve these tables to `authenticated`
--    (the coarse layer — RLS below is the actual gate). service_role is
--    granted for symmetry with the rest of the schema and bypasses RLS.
-- ---------------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE, DELETE ON public.documents TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.chunks TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.embeddings TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.generations TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.generation_versions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.reviews TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.history TO authenticated;

GRANT ALL ON public.documents TO service_role;
GRANT ALL ON public.chunks TO service_role;
GRANT ALL ON public.embeddings TO service_role;
GRANT ALL ON public.generations TO service_role;
GRANT ALL ON public.generation_versions TO service_role;
GRANT ALL ON public.reviews TO service_role;
GRANT ALL ON public.history TO service_role;

-- ---------------------------------------------------------------------------
-- 2. RLS policies
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  -- Documents ------------------------------------------------------------
  -- Staff (reviewer/admin, per has_full_access) read documents in every
  -- workspace. Owners already have full CRUD via 001's policy.
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'documents'
      AND policyname = 'Workspace staff can read documents'
  ) THEN
    CREATE POLICY "Workspace staff can read documents"
      ON public.documents FOR SELECT TO authenticated
      USING (public.has_full_access((select auth.uid())));
  END IF;

  -- Generations ----------------------------------------------------------
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'generations'
      AND policyname = 'Workspace staff can read generations'
  ) THEN
    CREATE POLICY "Workspace staff can read generations"
      ON public.generations FOR SELECT TO authenticated
      USING (public.has_full_access((select auth.uid())));
  END IF;

  -- Reviews --------------------------------------------------------------
  -- Owners may read the review trail of their own workspace (review status,
  -- comments). Reviewers/admins already have FOR ALL via 001's policy.
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'reviews'
      AND policyname = 'Workspace owners can read reviews'
  ) THEN
    CREATE POLICY "Workspace owners can read reviews"
      ON public.reviews FOR SELECT TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM public.workspaces w
          WHERE w.id = reviews.workspace_id
            AND w.owner_id = (select auth.uid())
        )
      );
  END IF;

  -- Chunks (document children) ------------------------------------------
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'chunks'
      AND policyname = 'Workspace staff can read chunks'
  ) THEN
    CREATE POLICY "Workspace staff can read chunks"
      ON public.chunks FOR SELECT TO authenticated
      USING (public.has_full_access((select auth.uid())));
  END IF;

  -- Embeddings (chunk children) -----------------------------------------
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'embeddings'
      AND policyname = 'Workspace staff can read embeddings'
  ) THEN
    CREATE POLICY "Workspace staff can read embeddings"
      ON public.embeddings FOR SELECT TO authenticated
      USING (public.has_full_access((select auth.uid())));
  END IF;

  -- Generation versions (generation children) ---------------------------
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'generation_versions'
      AND policyname = 'Workspace staff can read versions'
  ) THEN
    CREATE POLICY "Workspace staff can read versions"
      ON public.generation_versions FOR SELECT TO authenticated
      USING (public.has_full_access((select auth.uid())));
  END IF;

  -- History --------------------------------------------------------------
  -- Owners keep managing their own history (001); staff read all history so
  -- the review/audit surfaces can render workspace activity.
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'history'
      AND policyname = 'Staff can read history'
  ) THEN
    CREATE POLICY "Staff can read history"
      ON public.history FOR SELECT TO authenticated
      USING (public.has_full_access((select auth.uid())));
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- Verification (run in the SQL editor after applying):
--
--   -- Policies per table:
--   select tablename, policyname, cmd from pg_policies
--   where schemaname = 'public'
--     and tablename in ('documents','generations','reviews','chunks',
--                       'embeddings','generation_versions','history')
--   order by tablename, policyname;
--
--   -- As a student:      set request.jwt.claims = '{"sub":"<student_uid>","role":"authenticated"}'::jsonb;
--   --   select count(*) from documents;  -- only own workspace's rows
--   -- As a reviewer:     set request.jwt.claims = '{"sub":"<reviewer_uid>","role":"authenticated"}'::jsonb;
--   --   select count(*) from documents;  -- ALL documents
-- ---------------------------------------------------------------------------


-- ==========================================
-- FILE: 012_storage_security.sql
-- ==========================================
-- ============================================================================
-- 012_storage_security.sql
--
-- Phase 7.3 — Secure Supabase Storage.
--
-- The `documents` bucket holds uploaded lecture files at
--   <workspaceId>/<documentId>/<fileName>
-- so the workspace id is always the first path segment.
--
-- 002 created three very lax storage policies (ANY authenticated user could
-- upload/read/delete ANY file in the bucket). This migration:
--   1. ensures the private `documents` bucket exists (100 MB limit, non-public),
--   2. REPLACES the lax policies with ownership-aware ones:
--        * upload/update/delete  → workspace owner only
--        * download (select)     → workspace owner OR staff (has_full_access)
--   3. adds a security-definer signed-URL helper for the backend so files are
--      served with expiring signed URLs, never through public access.
--
-- Idempotency: bucket upsert + DROP POLICY IF EXISTS + pg_policies guards for
-- the new policies + CREATE OR REPLACE on helpers. Safe to re-run.
-- Ordering: 012 > 011 > 010 > 002.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Private `documents` bucket (create if missing, keep it private, 100 MB).
-- ---------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('documents', 'documents', false, 104857600, NULL)
ON CONFLICT (id) DO UPDATE
  SET public = false,
      file_size_limit = 104857600;

-- ---------------------------------------------------------------------------
-- 2. Path helper: extract the workspace uuid from a storage path, or NULL when
--    the first segment is not a valid uuid (prevents ::uuid errors in policies
--    for malformed paths).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.storage_workspace_id(p_path text)
RETURNS uuid
LANGUAGE sql
STABLE
AS $$
  SELECT CASE
    WHEN (storage.foldername(p_path))[1] ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    THEN (storage.foldername(p_path))[1]::uuid
    ELSE NULL
  END;
$$;

GRANT EXECUTE ON FUNCTION public.storage_workspace_id(text) TO authenticated;

-- ---------------------------------------------------------------------------
-- 3. Drop the lax 002 policies (idempotent) and re-create ownership-aware ones.
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "Users can upload their own files" ON storage.objects;
DROP POLICY IF EXISTS "Users can read their own files" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own files" ON storage.objects;

DO $$
BEGIN
  -- Owner may upload (INSERT) into their own workspace's folder.
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND policyname = 'Documents: workspace owner can upload'
  ) THEN
    CREATE POLICY "Documents: workspace owner can upload"
      ON storage.objects FOR INSERT TO authenticated
      WITH CHECK (
        bucket_id = 'documents'
        AND public.storage_workspace_id(name) IS NOT NULL
        AND EXISTS (
          SELECT 1 FROM public.workspaces w
          WHERE w.id = public.storage_workspace_id(name)
            AND w.owner_id = (select auth.uid())
        )
      );
  END IF;

  -- Owner or staff (reviewer/admin) may download (SELECT).
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND policyname = 'Documents: workspace owner or staff can download'
  ) THEN
    CREATE POLICY "Documents: workspace owner or staff can download"
      ON storage.objects FOR SELECT TO authenticated
      USING (
        bucket_id = 'documents'
        AND public.storage_workspace_id(name) IS NOT NULL
        AND (
          EXISTS (
            SELECT 1 FROM public.workspaces w
            WHERE w.id = public.storage_workspace_id(name)
              AND w.owner_id = (select auth.uid())
          )
          OR public.has_full_access((select auth.uid()))
        )
      );
  END IF;

  -- Owner may update (overwrite) their own files.
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND policyname = 'Documents: workspace owner can update'
  ) THEN
    CREATE POLICY "Documents: workspace owner can update"
      ON storage.objects FOR UPDATE TO authenticated
      USING (
        bucket_id = 'documents'
        AND public.storage_workspace_id(name) IS NOT NULL
        AND EXISTS (
          SELECT 1 FROM public.workspaces w
          WHERE w.id = public.storage_workspace_id(name)
            AND w.owner_id = (select auth.uid())
        )
      )
      WITH CHECK (
        bucket_id = 'documents'
        AND public.storage_workspace_id(name) IS NOT NULL
        AND EXISTS (
          SELECT 1 FROM public.workspaces w
          WHERE w.id = public.storage_workspace_id(name)
            AND w.owner_id = (select auth.uid())
        )
      );
  END IF;

  -- Owner may delete their own files.
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND policyname = 'Documents: workspace owner can delete'
  ) THEN
    CREATE POLICY "Documents: workspace owner can delete"
      ON storage.objects FOR DELETE TO authenticated
      USING (
        bucket_id = 'documents'
        AND public.storage_workspace_id(name) IS NOT NULL
        AND EXISTS (
          SELECT 1 FROM public.workspaces w
          WHERE w.id = public.storage_workspace_id(name)
            AND w.owner_id = (select auth.uid())
        )
      );
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 4. Signed-URL helper (backend storage support):
--
-- Returns a short-lived signed URL for a document path, but only when the
-- caller is the workspace owner or staff. The bucket itself is private, so the
-- signed URL is the ONLY way a browser/backend can fetch file bytes.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_document_signed_url(
  p_path text,
  p_expires int DEFAULT 3600
)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = storage, public
AS $$
DECLARE
  v_workspace uuid;
  v_signed    text;
BEGIN
  v_workspace := public.storage_workspace_id(p_path);
  IF v_workspace IS NULL THEN
    RAISE EXCEPTION 'invalid storage path';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.workspaces w
    WHERE w.id = v_workspace
      AND (w.owner_id = auth.uid() OR public.has_full_access(auth.uid()))
  ) THEN
    RAISE EXCEPTION 'access denied to document storage';
  END IF;

  SELECT (storage.create_signed_url('documents', p_path, p_expires)).signed_url
    INTO v_signed;

  RETURN v_signed;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_document_signed_url(text, int) TO authenticated;

-- ---------------------------------------------------------------------------
-- Verification (run in the SQL editor after applying):
--
--   select id, name, public from storage.buckets where id = 'documents';
--   select policyname, cmd from pg_policies
--   where schemaname = 'storage' and tablename = 'objects';
--
--   -- As a workspace owner:
--   --   select public.get_document_signed_url('<workspaceId>/<docId>/a.pdf', 300);
--   -- returns a https://...storage.../documents/... signed URL.
--   -- As another student, the same call raises 'access denied to document storage'.
-- ---------------------------------------------------------------------------


-- ==========================================
-- FILE: 013_realtime_and_notifications.sql
-- ==========================================
-- ============================================================================
-- 013_realtime_and_notifications.sql
--
-- Phase 7.4 — Realtime + lightweight notification model (backend support).
--
-- Realtime:
--   * Adds workspaces, documents, generations, reviews and notifications to
--     the `supabase_realtime` publication so Postgres Changes can be consumed
--     by the frontend (RLS still filters every delivered change to what the
--     subscribed user may see).
--   * The frontend subscribes to `workspaces` and invalidates ONLY the
--     `["workspace-bootstrap"]` React Query cache (see WorkspaceContext.tsx).
--
-- Notifications:
--   * A lightweight model built on the existing `notifications` table.
--   * SECURITY DEFINER triggers write notifications when:
--       - a generation is created        ("Generation completed")
--       - a review row is inserted/updated ("Review finished")
--       - a document is uploaded          ("Document uploaded")
--     Notifications target the workspace OWNER (user_id = owner id), so they
--     are readable through the existing "Users read their own notifications"
--     policy.
--   * Adds a role-targeted read policy so reviewers/admins can receive
--     broadcast notifications via the `roles` array. No notification UI is
--     added — this is backend/service support only.
--
-- Idempotency: publication membership is guarded by pg_publication_tables;
-- triggers are re-created via DROP IF EXISTS + CREATE; functions use
-- CREATE OR REPLACE; the policy uses a pg_policies guard.
-- Ordering: 013 > 012 > 011 > 010.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Realtime publication membership (idempotent).
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['workspaces', 'documents', 'generations', 'reviews', 'notifications']
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = t
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    END IF;
  END LOOP;
END $$;

-- ---------------------------------------------------------------------------
-- 2. Notification helper + triggers.
-- ---------------------------------------------------------------------------

-- Single write point for app notifications. SECURITY DEFINER so triggers can
-- insert on behalf of the target user regardless of the invoking role.
CREATE OR REPLACE FUNCTION public.create_notification(
  p_user_id uuid,
  p_workspace_id uuid,
  p_roles public.app_role[],
  p_kind text,
  p_title text,
  p_body text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.notifications (user_id, workspace_id, roles, kind, title, body)
  VALUES (p_user_id, p_workspace_id, p_roles, p_kind, p_title, p_body);
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_notification(uuid, uuid, public.app_role[], text, text, text)
  TO authenticated;

-- Generation created → notify the workspace owner.
CREATE OR REPLACE FUNCTION public.notify_generation_created()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.create_notification(
    (SELECT w.owner_id FROM public.workspaces w WHERE w.id = NEW.workspace_id),
    NEW.workspace_id,
    ARRAY['student']::public.app_role[],
    'done',
    'Generation completed',
    format('%s is ready to review', NEW.title)
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_generation_created_notify ON public.generations;
CREATE TRIGGER trg_generation_created_notify
AFTER INSERT ON public.generations
FOR EACH ROW
EXECUTE FUNCTION public.notify_generation_created();

-- Review row inserted/updated → notify the workspace owner.
CREATE OR REPLACE FUNCTION public.notify_review_finished()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.create_notification(
    (SELECT w.owner_id FROM public.workspaces w WHERE w.id = NEW.workspace_id),
    NEW.workspace_id,
    ARRAY['student']::public.app_role[],
    'review',
    'Review finished',
    format('A review on this workspace is now %s', NEW.status)
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_review_finished_notify ON public.reviews;
CREATE TRIGGER trg_review_finished_notify
AFTER INSERT OR UPDATE ON public.reviews
FOR EACH ROW
EXECUTE FUNCTION public.notify_review_finished();

-- Document uploaded → notify the workspace owner.
CREATE OR REPLACE FUNCTION public.notify_document_uploaded()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.create_notification(
    (SELECT w.owner_id FROM public.workspaces w WHERE w.id = NEW.workspace_id),
    NEW.workspace_id,
    ARRAY['student']::public.app_role[],
    'validation',
    'Document uploaded',
    format('%s is queued for parsing', NEW.title)
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_document_uploaded_notify ON public.documents;
CREATE TRIGGER trg_document_uploaded_notify
AFTER INSERT ON public.documents
FOR EACH ROW
EXECUTE FUNCTION public.notify_document_uploaded();

-- ---------------------------------------------------------------------------
-- 3. Role-targeted notification read policy (for broadcast notifications).
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'notifications'
      AND policyname = 'Staff can read role notifications'
  ) THEN
    CREATE POLICY "Staff can read role notifications"
      ON public.notifications FOR SELECT TO authenticated
      USING (
        public.has_full_access((select auth.uid()))
        AND ('reviewer' = ANY(roles) OR 'admin' = ANY(roles))
      );
  END IF;
END $$;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.notifications TO authenticated;
GRANT ALL ON public.notifications TO service_role;

-- ---------------------------------------------------------------------------
-- Verification (run in the SQL editor after applying):
--
--   select schemaname, pubname, tablename from pg_publication_tables
--   where pubname = 'supabase_realtime';
--
--   -- Insert a generation as service_role, then:
--   select title, body, read from public.notifications order by created_at desc;
--   -- the workspace owner sees one "Generation completed" row.
-- ---------------------------------------------------------------------------


-- ==========================================
-- FILE: 014_performance_indexes.sql
-- ==========================================
-- ============================================================================
-- 014_performance_indexes.sql
--
-- Phase 7.5 — Database optimization.
--
-- 008 already added the composite indexes that feed the `workspace_with_owner`
-- aggregates (documents/generations by workspace_id, review status and
-- created_at). This migration adds the remaining feed/queue/workload indexes:
--
--   * reviews(workspace_id, created_at DESC)   — review queues + audit trail
--   * notifications(user_id, read)             — unread badge counts
--   * generations(created_by)                  — "my generations" lists
--   * documents(workspace_id, created_at DESC) — document explorer feeds
--   * history(workspace_id, created_at DESC)   — history feeds
--   * chats(workspace_id, created_at DESC)     — conversation lists
--
-- All are CREATE INDEX IF NOT EXISTS → fully idempotent, no DROP, safe to
-- re-run. Ordering: 014 > 013.
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_reviews_workspace_created
  ON public.reviews (workspace_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_user_read
  ON public.notifications (user_id, read);

CREATE INDEX IF NOT EXISTS idx_generations_created_by
  ON public.generations (created_by);

CREATE INDEX IF NOT EXISTS idx_documents_workspace_created
  ON public.documents (workspace_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_history_workspace_created
  ON public.history (workspace_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_chats_workspace_created
  ON public.chats (workspace_id, created_at DESC);


-- ==========================================
-- FILE: 016_reviewer_workflow_and_favorites.sql
-- ==========================================
-- ============================================================================
-- 016_reviewer_workflow_and_favorites.sql
--
-- Phase 8 — Reviewer workflow (staff writes) + Supabase flashcard favorites.
--
-- Generations:
--   * Staff (reviewer/admin) may UPDATE the review status of any generation so
--     the review queue can advance rows from 'pending' -> 'approved' etc. This
--     complements 011's read-only staff access. (Owners keep full CRUD via 001.)
--   * A new SECURITY DEFINER trigger notifies the reviewer/admin roles whenever
--     a reviewable generation is created, so the staff notification feed shows
--     "New output awaiting review" with the workspace name. The owner is already
--     notified by 013's `notify_generation_created`.
--
-- Favorites:
--   * `flashcard_favorites` — per-user favorites for generated flashcards,
--     keyed by the card's front text (stable across regenerations). RLS limits
--     every row to its owner.
--
-- Idempotency: policies use a pg_policies existence check, triggers are
-- re-created via DROP IF EXISTS + CREATE, functions use CREATE OR REPLACE,
-- tables use IF NOT EXISTS. Safe to re-run in the SQL editor.
-- Ordering: 016 > 013 > 011 > 009 > 008 > 001.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Staff may advance a generation's review status.
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'generations'
      AND policyname = 'Workspace staff can update review status'
  ) THEN
    CREATE POLICY "Workspace staff can update review status"
      ON public.generations FOR UPDATE TO authenticated
      USING (public.has_full_access((select auth.uid())))
      WITH CHECK (public.has_full_access((select auth.uid())));
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 2. Staff pending-review notifications.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notify_staff_pending_review()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  wname text;
BEGIN
  IF NEW.kind IN ('question_bank', 'flashcards', 'test_help', 'study_plan', 'revision_sheet') THEN
    SELECT w.name INTO wname FROM public.workspaces w WHERE w.id = NEW.workspace_id;
    PERFORM public.create_notification(
      NULL,
      NEW.workspace_id,
      ARRAY['reviewer', 'admin']::public.app_role[],
      'review',
      'New output awaiting review',
      format('%s · %s', COALESCE(wname, 'A workspace'), NEW.title)
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_staff_pending_review_notify ON public.generations;
CREATE TRIGGER trg_staff_pending_review_notify
AFTER INSERT ON public.generations
FOR EACH ROW
EXECUTE FUNCTION public.notify_staff_pending_review();

-- ---------------------------------------------------------------------------
-- 3. Flashcard favorites.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.flashcard_favorites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  generation_id uuid REFERENCES public.generations(id) ON DELETE SET NULL,
  front text NOT NULL,
  back text,
  topic text,
  format text,
  source_chunk_id text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, front)
);

ALTER TABLE public.flashcard_favorites ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'flashcard_favorites'
      AND policyname = 'Users manage their flashcard favorites'
  ) THEN
    CREATE POLICY "Users manage their flashcard favorites"
      ON public.flashcard_favorites FOR ALL TO authenticated
      USING (user_id = auth.uid())
      WITH CHECK (user_id = auth.uid());
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_flashcard_favorites_user
  ON public.flashcard_favorites (user_id);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.flashcard_favorites TO authenticated;
GRANT ALL ON public.flashcard_favorites TO service_role;

-- ---------------------------------------------------------------------------
-- Verification (run in the SQL editor after applying):
--
--   select policyname, cmd from pg_policies
--   where tablename in ('generations', 'flashcard_favorites');
--
--   -- Insert a generation as a student, then (as reviewer):
--   select title, body from public.notifications
--   where 'reviewer' = ANY(roles) order by created_at desc;
-- ---------------------------------------------------------------------------


-- ==========================================
-- FILE: 017_review_and_favorites_fixes.sql
-- ==========================================
-- ============================================================================
-- 017_review_and_favorites_fixes.sql
--
-- Phase 8.1 — Two fixes on top of 016:
--
-- 1. Reviews upsert key.
--    `ReviewService.decideItem` upserts reviews with
--    `onConflict: 'generation_id,item_id'`, but 001 created no unique
--    constraint on those columns. The upsert therefore failed with "no unique
--    or exclusion constraint matching the ON CONFLICT specification", which
--    surfaced as "Could not persist the decision" when a reviewer approved or
--    rejected an item. This adds the missing unique index (and constraint).
--
-- 2. Per-workspace favorites.
--    `flashcard_favorites` had no workspace link, so favorites leaked across
--    workspaces. This adds a nullable `workspace_id` (NULL keeps legacy rows
--    visible; new favorites always carry one), an index for the owner+workspace
--    query, and a foreign key so deleting a workspace removes its favorites.
--
-- Idempotency: ALTER TABLE ... ADD COLUMN IF NOT EXISTS, unique index guarded
-- by IF NOT EXISTS, constraint added only when absent. Safe to re-run in the
-- Supabase SQL editor. Ordering: 017 > 016 > 013 > 011 > 009 > 008 > 001.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. reviews: unique key for the app's upsert.
-- ---------------------------------------------------------------------------
CREATE UNIQUE INDEX IF NOT EXISTS reviews_generation_item_key
  ON public.reviews (generation_id, item_id);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'reviews_generation_item_key'
  ) THEN
    ALTER TABLE public.reviews
      ADD CONSTRAINT reviews_generation_item_key
      UNIQUE USING INDEX reviews_generation_item_key;
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 2. flashcard_favorites: scope favorites to the workspace they came from.
-- ---------------------------------------------------------------------------
ALTER TABLE public.flashcard_favorites
  ADD COLUMN IF NOT EXISTS workspace_id uuid REFERENCES public.workspaces(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_flashcard_favorites_workspace
  ON public.flashcard_favorites (user_id, workspace_id);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.flashcard_favorites TO authenticated;

-- ---------------------------------------------------------------------------
-- Verification (run in the SQL editor after applying):
--
--   select conname, conrelid::regclass from pg_constraint
--   where conname = 'reviews_generation_item_key';
--
--   select column_name from information_schema.columns
--   where table_name = 'flashcard_favorites' and column_name = 'workspace_id';
-- ---------------------------------------------------------------------------


-- ==========================================
-- FILE: 018_generation_with_creator.sql
-- ==========================================
-- ============================================================================
-- 018_generation_with_creator.sql
--
-- Phase 8.2 — Human review provenance.
--
-- The reviewer page shows, per queued item, which account created it and from
-- which workspace it came. Generation rows carry `created_by` + `workspace_id`
-- but:
--   * `profiles` RLS only lets a user read their OWN profile, so a reviewer
--     cannot resolve a creator's display name/email directly;
--   * workspace names need the join used by `workspace_with_owner`.
--
-- This adds `generation_with_creator`, the same shape PostgREST already treats
-- as a security-definer view (see `workspace_with_owner` in 009/010): the
-- predicate keeps the app's existing visibility model — staff
-- (`has_full_access`) see every generation with provenance, owners see their
-- own — while the join to `profiles` / `auth.users` / `workspaces` runs as the
-- view owner so names resolve for staff.
--
-- Idempotent (CREATE OR REPLACE VIEW + re-issued GRANTs). Safe to re-run.
-- Ordering: 018 > 016 > 013 > 011 > 009 > 008 > 001.
-- ============================================================================

CREATE OR REPLACE VIEW public.generation_with_creator AS
SELECT
    g.id,
    g.workspace_id,
    g.created_by,
    g.kind,
    g.model,
    g.title,
    g.payload,
    g.document_ids,
    g.grounding_score,
    g.quality_score,
    g.review_status,
    g.created_at,
    p.full_name    AS creator_name,
    au.email       AS creator_email,
    w.name         AS workspace_name
FROM public.generations g
LEFT JOIN public.profiles p  ON p.id = g.created_by
LEFT JOIN auth.users   au   ON au.id = g.created_by
LEFT JOIN public.workspaces w ON w.id = g.workspace_id
WHERE public.has_full_access((select auth.uid()))
   OR g.workspace_id IN (
        SELECT w2.id FROM public.workspaces w2 WHERE w2.owner_id = (select auth.uid())
      );

COMMENT ON VIEW public.generation_with_creator IS
    'Generations joined with creator identity and workspace name, filtered to the caller''s visibility (staff: all; owner: own).';

GRANT SELECT ON public.generation_with_creator TO authenticated;
GRANT SELECT ON public.generation_with_creator TO service_role;

-- ---------------------------------------------------------------------------
-- Verification (run in the SQL editor after applying):
--
--   -- As a reviewer/admin: every generation with creator + workspace names.
--   select title, creator_name, creator_email, workspace_name
--   from public.generation_with_creator order by created_at desc limit 10;
--
--   -- As a student: only generations from workspaces you own.
-- ---------------------------------------------------------------------------


-- ==========================================
-- FILE: 019_pipeline_telemetry.sql
-- ==========================================
-- ============================================================================
-- 019_pipeline_telemetry.sql
--
-- Phase 8.3 — Live RAG pipeline telemetry.
--
-- The RAG Pipeline page (and admin surfaces) show six headline numbers:
--   * Chunks indexed          → computed LIVE from public.chunks
--   * Avg. retrieval latency  → measured value, stored here (updated by the
--                               backend / admins as measurements come in)
--   * Top-k                   → config value (hybrid retrieval k)
--   * Embedding model         → config value
--   * Validation pass rate    → measured value (schema validation)
--   * Support checked         → measured value (% outputs checked)
--
-- `pipeline_telemetry` is a single-row (id = 1) table that holds the
-- config/measured values. `pipeline_stats` is a security-definer view that
-- joins them with the live chunks count and gates reads to staff
-- (has_full_access), exactly like `workspace_with_owner`.
--
-- Nothing in this migration touches localStorage or reads client state; the
-- frontend reads the view through the Data API, so every number reflects the
-- live database.
--
-- Idempotency: table uses IF NOT EXISTS, the seed uses ON CONFLICT, policies
-- use a pg_policies existence check, and the view uses CREATE OR REPLACE —
-- safe to re-run in the Supabase SQL editor.
-- Ordering: 019 > 016 > 011 > 009 > 008 > 001.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Telemetry table (single row, id = 1).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.pipeline_telemetry (
  id                    integer PRIMARY KEY CHECK (id = 1),
  avg_retrieval_ms      numeric,
  top_k                 integer,
  embedding_model       text,
  validation_pass_rate  numeric,          -- % of outputs passing schema validation
  support_checked_pct   numeric,          -- % of outputs whose answers are verified
  updated_at            timestamptz NOT NULL DEFAULT now()
);

-- Seed with the current platform values so the page is never empty. The seed
-- row is what the backend will UPDATE as real measurements arrive.
INSERT INTO public.pipeline_telemetry
  (id, avg_retrieval_ms, top_k, embedding_model, validation_pass_rate, support_checked_pct)
VALUES
  (1, 184, 8, 'gemini-embedding-001', 97.2, 100)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2. RLS — only staff (reviewer/admin) may read or update telemetry.
-- ---------------------------------------------------------------------------
ALTER TABLE public.pipeline_telemetry ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'pipeline_telemetry'
      AND policyname = 'Staff can read pipeline telemetry'
  ) THEN
    CREATE POLICY "Staff can read pipeline telemetry"
      ON public.pipeline_telemetry FOR SELECT TO authenticated
      USING (public.has_full_access((select auth.uid())));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'pipeline_telemetry'
      AND policyname = 'Staff can update pipeline telemetry'
  ) THEN
    CREATE POLICY "Staff can update pipeline telemetry"
      ON public.pipeline_telemetry FOR UPDATE TO authenticated
      USING (public.has_full_access((select auth.uid())))
      WITH CHECK (public.has_full_access((select auth.uid())));
  END IF;
END $$;

GRANT SELECT, UPDATE ON public.pipeline_telemetry TO authenticated;
GRANT ALL ON public.pipeline_telemetry TO service_role;

-- ---------------------------------------------------------------------------
-- 3. pipeline_stats view — live chunks count + telemetry, staff-gated.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.pipeline_stats AS
SELECT
  (SELECT count(*) FROM public.chunks)::bigint                AS chunks_indexed,
  t.avg_retrieval_ms,
  t.top_k,
  t.embedding_model,
  t.validation_pass_rate,
  t.support_checked_pct,
  t.updated_at
FROM public.pipeline_telemetry t
WHERE t.id = 1
  AND public.has_full_access((select auth.uid()));

COMMENT ON VIEW public.pipeline_stats IS
  'Live RAG pipeline telemetry: chunks indexed (computed) plus config/measured values, visible to staff only (Phase 8.3).';

GRANT SELECT ON public.pipeline_stats TO authenticated;
GRANT SELECT ON public.pipeline_stats TO service_role;

-- ---------------------------------------------------------------------------
-- Verification (run in the SQL editor after applying):
--
--   -- As the admin/reviewer account:
--   select * from public.pipeline_stats;
--   -- chunks_indexed reflects the live count of public.chunks.
--
--   -- As the student account: the same query returns no rows (staff-gated).
--
--   -- Update measurements as they arrive (backend or admin):
--   update public.pipeline_telemetry
--   set avg_retrieval_ms = 152, validation_pass_rate = 97.8, updated_at = now()
--   where id = 1;
-- ---------------------------------------------------------------------------


