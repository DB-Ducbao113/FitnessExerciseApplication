alter table public.user_profiles
  add column if not exists height_cm numeric(5,1),
  add column if not exists date_of_birth date;

update public.user_profiles
set height_cm = round((height_m * 100.0)::numeric, 1)
where height_cm is null
  and height_m is not null;

do $$ begin
  alter table public.user_profiles
    add constraint user_profiles_weight_kg_positive
      check (weight_kg is null or weight_kg > 0);
exception
  when duplicate_object then null;
end $$;

do $$ begin
  alter table public.user_profiles
    add constraint user_profiles_height_cm_positive
      check (height_cm is null or height_cm > 0);
exception
  when duplicate_object then null;
end $$;

create index if not exists idx_user_profiles_date_of_birth
  on public.user_profiles (date_of_birth);
