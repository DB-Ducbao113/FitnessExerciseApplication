# Production monitoring and incident runbook

## Service-level objectives

- Frontend and Supabase Auth availability: 99.9% over 30 days.
- Edge Function error rate: below 1% over 5 minutes.
- Edge Function p95 latency: below 800 ms; p99 below 2 seconds.
- Workout processing queue: oldest queued job below 10 minutes.
- Offline sync: no pending operation older than 24 hours after connectivity returns.

The `Production availability monitor` GitHub workflow probes the public frontend,
Supabase Auth, and CORS preflight every 15 minutes. A failed run is a user-facing
availability signal and should page the on-call owner through GitHub Actions
notifications.

## Provider alerts to configure

Repository code cannot create account-level Vercel or Supabase alerts without
management credentials. Configure these once in the provider dashboards:

1. Supabase API/Edge 5xx rate above 1% for 5 minutes: page.
2. Supabase Edge p99 above 2 seconds for 5 minutes: page.
3. Database connections above 80% for 10 minutes: ticket; above 95%: page.
4. Database CPU above 85% for 15 minutes: ticket.
5. Vercel function 5xx above 1% for 5 minutes: page.
6. AI provider quota or spend above 80%: ticket; above 95%: page.

Do not use user IDs, emails, GPS coordinates, access tokens, or full request
bodies as metric labels or log fields.

## First response

1. Confirm the synthetic workflow failure and note endpoint/status/latency.
2. Search Edge logs by `request_id`; compare `duration_ms` and stable `event`.
3. Check Supabase database connections, CPU, Edge errors, and processing queue.
4. If a recent release correlates with the incident, redeploy the last known
   good Git ref through the manual Vercel or Supabase workflow.
5. Never roll back a database migration by renaming or deleting it. Add a new
   forward-fix migration.

## Workout processing queries

```sql
select status, job_type, count(*)
from public.workout_processing_jobs
group by status, job_type;

select min(created_at) as oldest_queued_at
from public.workout_processing_jobs
where status = 'queued';

select event_type, log_level, count(*)
from public.workout_processing_logs
where created_at >= now() - interval '15 minutes'
group by event_type, log_level;
```
