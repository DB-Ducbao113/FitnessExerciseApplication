(A) CREATE WORKOUT
POST /workouts/start


Request

{
  "user_id": "uuid"
}


Response

{
  "workout_id": "uuid",
  "started_at": "timestamp"
}

(B) SEND GPS POINT
POST /gps/track


Request

{
  "workout_id": "uuid",
  "latitude": 10.762622,
  "longitude": 106.660172,
  "timestamp": "2026-02-04T10:20:30Z"
}


Response

{
  "status": "stored"
}

(C) END WORKOUT
POST /workouts/end


Request

{
  "workout_id": "uuid"
}


Response

{
  "total_distance_km": 4.2,
  "avg_speed_kmh": 8.1,
  "activity_type": "running",
  "calories": 312
}

Notes

- Current mobile app scope: `running`, `walking`, `cycling`
- `calories` is a distance-based estimate persisted from the client workout flow
- The backend should not recalculate calories using MET or duration-only formulas

(D) GET HISTORY
GET /workouts/{user_id}


Response

[
  {
    "workout_id": "uuid",
    "type": "walking",
    "distance_km": 2.1,
    "calories": 120,
    "created_at": "timestamp"
  }
]
