create table gps_tracks (
  id uuid primary key default gen_random_uuid(),
  workout_id uuid references workouts(id) on delete cascade,

  latitude double precision not null,
  longitude double precision not null,
  recorded_at timestamp not null,

  created_at timestamp default now()
);
