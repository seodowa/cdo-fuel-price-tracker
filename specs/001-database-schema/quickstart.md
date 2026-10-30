# Quickstart: Database Schema

Proves SC-005 (one-step install), SC-001 to SC-004 (pgTAP) and SC-006 (advisor).

## Prerequisites

1. Docker Engine running (D18):
   ```sh
   sudo systemctl enable --now docker
   docker info --format '{{.ServerVersion}}'
   ```
2. Supabase CLI installed system-wide (D17). Pinned version: `2.122.0`.
   It must be a stable release with no `-beta` suffix (D23). Check with `supabase --version`. A different version is a mismatch to raise before Build.

## Run

From the repository root:

```sh
supabase start          # first run pulls images
supabase db reset       # applies supabase/migrations/* then supabase/seed.sql on an empty database
supabase test db        # runs supabase/tests/*.test.sql with pgTAP
supabase db lint        # schema lint
supabase db advisors --local --type security --level info --fail-on info   # SC-006
```

## Expected results

| Step | Expected |
|---|---|
| `supabase db reset` | finishes with no error (SC-005) |
| `supabase test db` | every file `ok`, no failures |
| `supabase db advisors` | exits 0, no issues listed (SC-006) |

## Spot checks (psql against the local database)

```sh
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres"
```

- `select count(*) from barangay b join city c on c.id = b.city_id where c.name = 'Cagayan de Oro';` returns 80.
- `select name from fuel_category order by name;` returns diesel, gasoline, kerosene.
- `set role anon; select submitted_by from price_report;` fails with 42501 (`contracts/data-api.md`). Then `reset role;`.

## First admin

Admins are set only with the service role (research R2). After a user signs in once locally:

```sql
update public.profile set is_admin = true where id = '<auth user uuid>';
```

Run it in the Studio SQL editor. Never through the app.

## Stop

```sh
supabase stop
```
