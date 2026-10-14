create extension if not exists pgcrypto;
create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 display_name text, institution text, interests text[] not null default '{}', preferred_categories text[] not null default '{}',
 arrival_buffer_minutes int not null default 30 check(arrival_buffer_minutes between 0 and 720), timezone text not null default 'Asia/Kolkata', created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.events (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 title text not null check(length(title) between 1 and 240), description text, category text, organizer text, event_url text, registration_url text, source_reference text,
 venue text, city text, format text not null default 'in_person' check(format in ('in_person','online','hybrid')),
 starts_at timestamptz not null, ends_at timestamptz, timezone text not null default 'Asia/Kolkata',
 registration_status text not null default 'interested' check(registration_status in ('interested','registered','submitted','shortlisted','confirmed','waitlisted','rejected','completed','cancelled')),
 notes text, archived_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 check(ends_at is null or ends_at > starts_at)
);
create index if not exists events_user_starts_idx on public.events(user_id,starts_at) where archived_at is null;
create table if not exists public.milestones (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade, event_id uuid not null references public.events(id) on delete cascade,
 title text not null check(length(title) between 1 and 240), description text, due_at timestamptz not null, type text not null default 'custom', completed boolean not null default false,
 external_url text, reminder_preference text, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index if not exists milestones_user_due_idx on public.milestones(user_id,due_at) where completed=false;
create table if not exists public.travel_plans (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade, event_id uuid not null unique references public.events(id) on delete cascade,
 origin text, destination text, mode text, duration_minutes int check(duration_minutes is null or duration_minutes>=0), arrival_buffer_minutes int not null default 30 check(arrival_buffer_minutes>=0), notes text, estimate_source text, checked_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.event_logistics (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade, event_id uuid not null unique references public.events(id) on delete cascade,
 accommodation text not null default 'needs_confirmation' check(accommodation in ('confirmed','not_offered','needs_confirmation')),
 meals text not null default 'needs_confirmation' check(meals in ('confirmed','not_offered','needs_confirmation')),
 reimbursement text not null default 'needs_confirmation' check(reimbursement in ('confirmed','not_offered','needs_confirmation')),
 eligibility text not null default 'needs_confirmation' check(eligibility in ('confirmed_eligible','not_eligible','needs_confirmation')),
 reimbursement_cap numeric, claim_deadline timestamptz, eligibility_conditions text, accommodation_instructions text, meal_arrangements text, organizer_contact text, source_url text, verified_at timestamptz, private_notes text,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.teams (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id) on delete cascade, name text not null check(length(name) between 1 and 100), created_at timestamptz not null default now()
);
create table if not exists public.team_members (
 team_id uuid not null references public.teams(id) on delete cascade, user_id uuid not null references auth.users(id) on delete cascade,
 role text not null default 'member' check(role in ('owner','member')), created_at timestamptz not null default now(), primary key(team_id,user_id)
);
create table if not exists public.team_invitations (
 id uuid primary key default gen_random_uuid(), team_id uuid not null references public.teams(id) on delete cascade, invited_email text not null,
 token_hash text not null unique, expires_at timestamptz not null, accepted_at timestamptz, revoked_at timestamptz, created_at timestamptz not null default now()
);
create table if not exists public.event_team_associations (
 event_id uuid not null references public.events(id) on delete cascade, team_id uuid not null references public.teams(id) on delete cascade,
 owner_id uuid not null references auth.users(id) on delete cascade, attendance text not null default 'unsure' check(attendance in ('planning','confirmed','not_attending','unsure')),
 share_details boolean not null default false, created_at timestamptz not null default now(), primary key(event_id,team_id)
);
create table if not exists public.notifications (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade, type text not null, title text not null, body text, event_id uuid references public.events(id) on delete cascade, milestone_id uuid references public.milestones(id) on delete cascade, read_at timestamptz, created_at timestamptz not null default now()
);
create table if not exists public.user_preferences (
 user_id uuid primary key references auth.users(id) on delete cascade, theme text not null default 'system' check(theme in ('system','light','dark')), comparison_weights jsonb not null default '{"goal":25,"commitment":25,"urgency":20,"travel":15,"team":15}', updated_at timestamptz not null default now()
);
-- Identity bootstrap. SECURITY DEFINER function writes only the new auth user's profile.
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$ begin insert into public.profiles(id,display_name) values(new.id,coalesce(new.raw_user_meta_data->>'display_name','')); return new; end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();
-- RLS: private records are always owned by the authenticated subject.
do $$ declare t text; begin foreach t in array array['profiles','events','milestones','travel_plans','event_logistics','teams','team_members','team_invitations','event_team_associations','notifications','user_preferences'] loop execute format('alter table public.%I enable row level security',t); end loop; end $$;
create policy "profiles own row" on public.profiles for all using(id=auth.uid()) with check(id=auth.uid());
create policy "events own rows" on public.events for all using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "milestones own rows" on public.milestones for all using(user_id=auth.uid() and exists(select 1 from public.events e where e.id=event_id and e.user_id=auth.uid())) with check(user_id=auth.uid() and exists(select 1 from public.events e where e.id=event_id and e.user_id=auth.uid()));
create policy "travel own rows" on public.travel_plans for all using(user_id=auth.uid() and exists(select 1 from public.events e where e.id=event_id and e.user_id=auth.uid())) with check(user_id=auth.uid() and exists(select 1 from public.events e where e.id=event_id and e.user_id=auth.uid()));
create policy "logistics own rows" on public.event_logistics for all using(user_id=auth.uid() and exists(select 1 from public.events e where e.id=event_id and e.user_id=auth.uid())) with check(user_id=auth.uid() and exists(select 1 from public.events e where e.id=event_id and e.user_id=auth.uid()));
create policy "teams member read" on public.teams for select using(exists(select 1 from public.team_members tm where tm.team_id=id and tm.user_id=auth.uid()));
create policy "teams owner manage" on public.teams for all using(owner_id=auth.uid()) with check(owner_id=auth.uid());
create policy "team members see own row" on public.team_members for select using(user_id=auth.uid());
create policy "team member self insert" on public.team_members for insert with check(user_id=auth.uid() and exists(select 1 from public.teams t where t.id=team_id and t.owner_id=auth.uid()));
create policy "team owner member delete" on public.team_members for delete using(exists(select 1 from public.teams t where t.id=team_id and t.owner_id=auth.uid()) or user_id=auth.uid());
create policy "invites owner read" on public.team_invitations for select using(exists(select 1 from public.teams t where t.id=team_id and t.owner_id=auth.uid()));
create policy "invites owner manage" on public.team_invitations for all using(exists(select 1 from public.teams t where t.id=team_id and t.owner_id=auth.uid())) with check(exists(select 1 from public.teams t where t.id=team_id and t.owner_id=auth.uid()));
create policy "association owner manage" on public.event_team_associations for all using(owner_id=auth.uid() and exists(select 1 from public.events e where e.id=event_id and e.user_id=auth.uid())) with check(owner_id=auth.uid() and exists(select 1 from public.events e where e.id=event_id and e.user_id=auth.uid()));
create policy "notifications own" on public.notifications for all using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "preferences own" on public.user_preferences for all using(user_id=auth.uid()) with check(user_id=auth.uid());
