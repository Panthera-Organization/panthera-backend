# panthera-backend

Local development uses the Supabase CLI and Docker.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started) 2.120.0

## Local database

Start the local stack, then rebuild the database from the migrations in `supabase/migrations`:

```bash
supabase start
supabase db reset
```

`supabase db reset` applies every migration and then loads `supabase/seed.sql`. That seed file is empty until [PB-53](https://linear.app/pantheraapp/issue/PB-53/seed-a-tutoring-center-and-a-personal-workspace).

Studio is at http://127.0.0.1:54323. `supabase status` prints the local URLs and keys.

## Checks

```bash
supabase db lint --local --fail-on error
supabase test db --local
supabase gen types typescript --local > /tmp/database.types.ts
diff -u supabase/functions/_shared/db/database.types.ts /tmp/database.types.ts
```

The last command must print nothing. Commit the regenerated file when a migration changes the schema.

Edge Functions are TypeScript and run on Deno 2:

```bash
supabase functions serve
```

There are no function entrypoints yet. `supabase functions serve` still starts the local functions runtime.

## Staging

A push to `main` runs the same checks, then applies migrations to the staging project with `supabase db push`. It does not load seed data. Edge Functions deploy with `--use-api` once a function entrypoint exists.

Staging can pause after a week of inactivity. Restore the project in the Supabase dashboard, then re-run the deploy. The workflow does not restore it.
