create table users (
  id uuid primary key default gen_random_uuid(),
  name text,
  gender text,
  age int,
  weight_kg numeric,
  height_cm numeric,
  created_at timestamp default now()
);
