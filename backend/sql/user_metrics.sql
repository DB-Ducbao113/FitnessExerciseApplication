create table user_metrics (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references users(id),
  height_cm int,
  weight_kg float,
  age int,
  gender text,
  updated_at timestamp default now()
);
