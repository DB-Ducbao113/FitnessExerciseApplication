[Mobile App]
→ Collect GPS (lat, lon, timestamp)
→ Send GPS batch to Backend

[Backend]
→ Validate GPS data
→ Calculate distance between points
→ Calculate speed (km/h)
→ Classify activity (walking / running)
→ Calculate calories
→ Store result

[Database]
→ gps_tracks
→ workouts (type, duration, calories)

2.1 Distance
distance = sum(haversine(point[i], point[i+1]))

2.2 Speed
speed (km/h) = distance (km) / duration (hours)

2.3 Activity classification
if speed < 6.0 → walking
else → running

2.4 Calories
MET_walking = 3.5
MET_running = 7.0

calories = MET × weight_kg × duration_hours

Input from mobile
{
  workout_id,
  latitude,
  longitude,
  timestamp
}

Output backend return
{
  total_distance_km,
  avg_speed_kmh,
  activity_type,
  calories
}
