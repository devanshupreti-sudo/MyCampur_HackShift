# MyCampus

A student event-planning app built with Next.js, TypeScript, Tailwind, Supabase, and `ical.js`.

## Current implementation

- Responsive marketing page and event workspace with clearly labeled demo mode.
- Create, search, and delete events; complete existing milestones; detect overlapping event sessions.
- ICS preview/import with duplicate checks.
- Travel plans per event, including origin, destination, mode, estimate, arrival buffer, notes, and calculated departure time. Plans persist in local demo storage or Supabase for a signed-in account.
- Create teams and generate private, seven-day invitation links for signed-in users. Invitees must sign in with the invited email. Links are copied for the inviter to share manually; the app does not send email.
- Local demo teams are browser-only and are explicitly not shared with other users.
- Email/password signup, sign-in, sign-out, password reset request, and Supabase RLS schema.

This is still a development foundation, not a complete production service. Team rosters, invitation revocation, full milestone CRUD, server-side protection for all private pages, account export/deletion, scheduled reminders, and verified event discovery remain incomplete. The demo Discover listings are illustrative. ICS import is a file import, not a calendar sync.

## Requirements

- Node.js 20.9 or later
- A Supabase project for account-backed data and real team invitations (optional for local demo use)

## Local development

1. Install dependencies with `npm install`.
2. Copy `.env.example` to `.env.local`.
3. Run `npm run dev` and open `http://localhost:3000`.
4. Without Supabase values, the event and travel demo saves in this browser. Demo teams are local-only; sign-in and real invitations need Supabase.

## Supabase setup

1. Create a Supabase project.
2. In the SQL editor, run `supabase/migrations/202610140001_initial_schema.sql`.
3. Set `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY` in `.env.local` using the project's URL and publishable/anon key. Never place a service-role key in a browser variable.
4. In Supabase Auth URL configuration, set the local site URL to `http://localhost:3000` and add your deployed URL and dashboard redirect URL.
5. Configure email confirmation and a production email provider in Supabase Auth.
6. To enable secure invitation acceptance, set `SUPABASE_SERVICE_ROLE_KEY` in `.env.local` and in Vercel's server environment settings. Keep this key server-only; do not use a `NEXT_PUBLIC_` prefix.

Invitation acceptance checks the token, expiration, and signed-in user's email before adding membership. No invitation email is sent automatically; share the generated link yourself.

## Vercel deployment

1. Push the project to GitHub and import it in Vercel.
2. Add the public Supabase URL and anon/publishable key to Preview and Production environments.
3. Apply the SQL migration to the matching Supabase project.
4. Add the deployed domain to Supabase Auth URL configuration.
5. Add the server-only service-role key only if enabling team invite acceptance.
6. Deploy with the Vercel production build.

## Checks

- `npm run test`
- `npm run lint`
- `npm run typecheck`
- `npx next build --webpack`

## Data and privacy

Unauthenticated demo events, travel plans, and teams are stored in this browser. Clear this site's browser storage to remove them. Authenticated events, travel plans, and teams use Supabase with row-level access policies. Travel estimates are user-entered and are not live route calculations. Demo listings are not verified. This preview does not provide complete user data export or account deletion, and it does not send email or push reminders.
