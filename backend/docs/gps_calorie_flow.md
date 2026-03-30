[Mobile App]
-> Collect GPS and step data during the workout
-> Compute distance, speed, and calories on device
-> Send the finished workout session to Backend

[Backend]
-> Validate payload
-> Persist workout session fields
-> Keep calories as provided by the client

[Database]
-> workout_sessions
-> gps_tracks

1. Scope

The current app flow is focused on:
- running
- walking
- cycling

Calories are distance-based and are calculated on the client, not on the backend.

2. Client-side metrics

2.1 Distance
distance = sum(haversine(point[i], point[i+1]))

2.2 Speed
speed_kmh = distance_km / duration_hours

2.3 Calories

Base coefficient `k`:
- running: 1.05
- walking/cycling: 0.92

Speed bonus:
- if speed_kmh > 10, add 0.05
- if speed_kmh > 15, add another 0.05

Formula:
calories = weight_kg * distance_km * k * gender_factor

Where:
- gender_factor = 0.95 for female
- gender_factor = 1.0 otherwise

3. Backend expectation

Input from mobile:
{
  id,
  user_id,
  activity_type,
  started_at,
  ended_at,
  duration_sec,
  distance_km,
  steps,
  avg_speed_kmh,
  calories_kcal,
  mode,
  lap_splits
}

Backend responsibility:
- store the final workout session
- preserve client-computed metrics
- avoid recalculating calories with MET or duration-only formulas
