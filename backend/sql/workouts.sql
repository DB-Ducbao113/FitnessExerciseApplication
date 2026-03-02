create table workouts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references users(id) on delete cascade,

  activity_type text not null, -- walk / run
  started_at timestamp not null,
  ended_at timestamp,

  distance_km numeric,
  duration_min numeric,
  avg_speed_kmh numeric,
  calories numeric,

  created_at timestamp default now()
);
