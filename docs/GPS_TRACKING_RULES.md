# GPS Tracking Rules & Validation Logic
**FlowFit — FitnessExerciseApplication**
_Tài liệu quy tắc xử lý GPS cho tính năng Outdoor Workout Recording_

---

## 1. GPS Sampling — Thu thập dữ liệu liên tục

### 1.1 Cấu hình Geolocator
```dart
LocationSettings(
  accuracy: LocationAccuracy.high,   // HIGH = GPS chip, không dùng network
  distanceFilter: 0,                 // Nhận MỌI điểm, lọc sau — không bỏ lỡ
  timeLimit: null,                   // Không timeout stream
)
```

### 1.2 Foreground persistence
- **Android**: Bật Foreground Service ngay khi user nhấn "Start Record". Gọi `wakelock_plus` TRƯỚC khi khởi động stream.
- **iOS**: Kích hoạt Background Modes > Location Updates trong `Info.plist`.
- Stream GPS **không được** dispose khi app vào background — chỉ dispose khi user nhấn Stop hoặc Pause.

### 1.3 Lưu điểm raw ngay lập tức
Mỗi điểm GPS nhận được → lưu vào local DB (SQLite) **ngay lập tức**, không batch, không đợi:

```dart
// Model mỗi điểm raw
GpsRawPoint {
  id            : UUID
  workoutId     : String
  latitude      : double
  longitude     : double
  altitude      : double?
  speed         : double          // m/s, từ geolocator
  accuracy      : double          // meters (horizontal error)
  timestamp     : DateTime
  confidence    : GpsConfidence   // HIGH / MEDIUM / LOW
}
```

**Confidence mapping:**
| accuracy (m) | confidence |
|---|---|
| ≤ 10m | HIGH |
| 11m – 30m | MEDIUM |
| > 30m | LOW |

---

## 2. Route Smoothing — Vẽ đường mềm mại

### 2.1 Lọc điểm nhiễu trước khi vẽ
Áp dụng **Weighted Moving Average (WMA, window W=5)** trên lat/lng:

```
lat_smooth[i] = Σ(w[j] × lat_raw[i-j]) / Σ(w[j])   với j = 0..4
weights       = [5, 4, 3, 2, 1]                        (gần nhất trọng số cao)
```

Ngoài ra áp dụng **speed gate**: bỏ qua điểm bất kỳ mà tốc độ tức thời so với điểm trước > 80 m/s (288 km/h) — đây là GPS glitch chắc chắn.

### 2.2 Xử lý mất tín hiệu GPS giữa chừng
Khi stream không nhận điểm mới trong **> 5 giây**:

1. **KHÔNG ngắt polyline** — giữ nguyên đường đã vẽ
2. Lưu `gpsGapStart = lastKnownTimestamp`
3. Hiển thị icon ⚡ nhỏ trên map tại vị trí cuối cùng
4. Bộ đếm thời gian workout **tiếp tục chạy** (không pause tự động)

Khi tín hiệu phục hồi:

1. Nối điểm mới vào điểm cuối cùng hợp lệ — **1 polyline duy nhất liên tục**
2. Đoạn nối được tô màu khác (ví dụ xám nhạt) để indicate gap
3. Lưu `gpsGapEnd`, tính `gapDuration`
4. Đoạn gap **không được tính vào distance** (chỉ tính time)

### 2.3 Bearing Consistency Check
Loại bỏ điểm "nhảy" khi bearing thay đổi đột ngột:
```
bearingDelta = |bearing(prev→curr) - bearing(curr→next)|
if bearingDelta > 120° AND distance(prev, curr) < 20m → discard điểm curr
```

---

## 3. Record Policy — Ghi nhận toàn bộ, xét sau

### Nguyên tắc cốt lõi
> **Thu thập TẤT CẢ, không từ chối live. Đánh giá chỉ khi FINISH.**

Lý do: Người dùng có thể di chuyển hợp lệ trong phần lớn workout nhưng lên xe một đoạn ngắn — không nên dừng ghi hay hủy session.

### Segment hóa dữ liệu
Chia toàn bộ route thành các **segment 100m** (hoặc 30 giây nếu < 100m):
```
Segment {
  startPoint    : GpsRawPoint
  endPoint      : GpsRawPoint
  distanceM     : double
  durationSec   : double
  paceSecPerKm  : double        // = durationSec / (distanceM / 1000)
  avgSpeed      : double        // m/s
  status        : SegmentStatus // VALID | SUSPICIOUS | INVALID
}
```

---

## 4. Pace Anomaly Detection — Ngưỡng hợp lý theo activity

### 4.1 Bảng ngưỡng pace

| Activity | Pace MIN (quá nhanh → nghi xe) | Pace MAX (quá chậm → không hợp lệ) |
|---|---|---|
| **Walking** | < 5:00 /km (> 3.3 m/s) | > 30:00 /km (< 0.55 m/s) |
| **Running** | < 2:30 /km (> 6.7 m/s) | > 12:00 /km (< 1.4 m/s) |
| **Cycling** | < 0:45 /km (> 22 m/s) | > 10:00 /km (< 1.7 m/s) |
| **Hiking** | < 4:00 /km (> 4.2 m/s) | > 40:00 /km (< 0.4 m/s) |

> Các ngưỡng trên dựa trên giới hạn sinh lý học và kỷ lục thể thao thế giới. Running world record ≈ 2:51/km; pace đi bộ bình thường 8–12 min/km.

### 4.2 Phân loại segment

```
VALID       : pace nằm trong [MIN, MAX] của activity
SUSPICIOUS  : pace vi phạm ngưỡng MIN (quá nhanh)
INVALID     : pace vi phạm ngưỡng MAX (quá chậm) HOẶC accuracy > 50m toàn đoạn
```

### 4.3 Logic đánh dấu từng segment
```dart
SegmentStatus classifySegment(Segment seg, ActivityType activity) {
  final pace = seg.paceSecPerKm;
  final threshold = PaceThreshold.forActivity(activity);

  if (seg.avgAccuracy > 50.0) return SegmentStatus.invalid;
  if (pace < threshold.minPaceSec) return SegmentStatus.suspicious;
  if (pace > threshold.maxPaceSec) return SegmentStatus.invalid;
  return SegmentStatus.valid;
}
```

---

## 5. Summary Calculation — Tổng kết sau khi Finish

### 5.1 Tính các metric từ segment đã phân loại

```
totalDistance       = Σ distance(ALL segments)
validDistance       = Σ distance(VALID segments)
suspiciousDistance  = Σ distance(SUSPICIOUS segments)
invalidDistance     = Σ distance(INVALID segments)

effectivePace       = totalDuration / (validDistance / 1000)  // tính trên valid only
suspiciousRatio     = suspiciousDistance / totalDistance       // %
```

### 5.2 Workout Validity Flag

| Điều kiện | Flag | Hiển thị |
|---|---|---|
| suspiciousRatio ≤ 10% | `VERIFIED` | ✅ Xanh |
| 10% < suspiciousRatio ≤ 30% | `PARTIAL` | 🟡 Vàng — cảnh báo nhẹ |
| suspiciousRatio > 30% | `UNVERIFIED` | 🔴 Đỏ — không công nhận goal |

### 5.3 Hiển thị Summary Screen
```
┌─────────────────────────────────────┐
│  Tổng quãng đường:    8.42 km       │
│  Quãng đường hợp lệ:  7.80 km  ✅  │
│  Đoạn bị gắn cờ:      0.62 km  ⚠️  │
│                                     │
│  Thời gian:           52:14         │
│  Pace hiệu quả:       6:42 /km      │
│                                     │
│  ┌─────────────────────────────┐    │
│  │ ⚠️  Phát hiện 2 đoạn có    │    │
│  │ tốc độ bất thường (pace    │    │
│  │ < 2:30/km với Running).    │    │
│  │ Workout KHÔNG được tính    │    │
│  │ vào Goal tháng này.        │    │
│  └─────────────────────────────┘    │
└─────────────────────────────────────┘
```

### 5.4 Chi tiết đoạn bị flag (expandable)
Người dùng có thể tap vào cảnh báo để xem:
- Danh sách segment SUSPICIOUS/INVALID
- Thời điểm xảy ra (timestamp)
- Tốc độ thực tế vs ngưỡng cho phép
- Vị trí trên map (highlight đỏ trên route)

---

## 6. Workout History — Hiển thị lịch sử

### 6.1 Badge trạng thái
Mỗi workout trong history list hiển thị badge:

```
✅  VERIFIED    — Tất cả hợp lý, tính vào goal
🟡  PARTIAL     — Một phần bất thường, tính một phần vào goal
🔴  UNVERIFIED  — Không hợp lý, KHÔNG tính vào goal
```

### 6.2 Distance & Pace hiển thị
- History card hiển thị `validDistance` (không phải `totalDistance`) làm số chính
- Nếu workout là `UNVERIFIED`: gạch ngang số liệu và thêm badge đỏ
- Tooltip khi tap: "Quãng đường gốc: X km | Đã loại: Y km do bất thường"

### 6.3 Goal contribution
```dart
// Chỉ cộng vào goal nếu workout VERIFIED hoặc PARTIAL
if (workout.validityFlag != WorkoutValidity.unverified) {
  goal.addProgress(workout.validDistance);
}
```

---

## 7. Edge Cases đặc biệt

### 7.1 Người dùng dừng lại lâu (đứng chờ đèn đỏ, nghỉ giữa chừng)
- Speed ≈ 0 kéo dài → segment bị `INVALID` (pace vô cực)
- **Xử lý**: Nếu khoảng thời gian đứng yên > 60s liên tục → tự động đánh dấu là `REST_PERIOD`, không tính vào pace, không tính vào distance
- Hiển thị trong summary: "Thời gian nghỉ: 3:20"

### 7.2 GPS glitch nhảy vọt
- Điểm GPS đột ngột cách điểm trước > 500m trong < 2s → loại bỏ điểm này khỏi route và distance
- Flag: `GPS_SPIKE`, không ảnh hưởng validity flag của workout

### 7.3 Indoor → Outdoor transition (dùng khi EnvironmentClassifier active)
- Khi classifier chuyển trạng thái INDOOR → OUTDOOR: đặt lại buffer WMA
- Các điểm trong 5s đầu sau transition có accuracy thường kém → weight giảm 50%

### 7.4 Tunnel / hầm ngầm
- Mất GPS > 30s → hiển thị banner "GPS yếu — đang ước tính bằng PDR"
- Nếu có pedometer: dùng bước chân + stride length để estimate distance trong khoảng gap
- Điểm ước tính được đánh dấu `ESTIMATED`, không ảnh hưởng validity

---

## 8. Tóm tắt luồng xử lý

```
START RECORD
    │
    ▼
[GPS Stream] ──────────────────────────────────────────┐
    │  mỗi điểm                                        │
    ▼                                                   │
[Speed Gate] → glitch? → discard                       │
    │                                                   │
    ▼                                                   │
[WMA Smoother] → lat/lng smoothed                      │
    │                                                   │
    ▼                                                   │
[Save GpsRawPoint to SQLite] (immediate)               │
    │                                                   │
    ▼                                                   │
[Update polyline on map] (real-time)                   │
    │                                                   │
    │  GPS gap > 5s?                                    │
    └──→ hold last point, mark gap, show ⚡ icon ───────┘
    
FINISH RECORD
    │
    ▼
[Segment Builder] → chia route thành segments 100m
    │
    ▼
[Pace Anomaly Detector] → classify VALID/SUSPICIOUS/INVALID
    │
    ▼
[suspiciousRatio calculator] → VERIFIED / PARTIAL / UNVERIFIED
    │
    ▼
[Summary Screen] → hiển thị kết quả + cảnh báo nếu có
    │
    ▼
[Save WorkoutRecord to DB] → sync lên Supabase
    │
    ▼
[Goal updater] → chỉ cộng nếu VERIFIED hoặc PARTIAL
```

---

_Tài liệu này là spec cho implementation. Mọi thay đổi ngưỡng pace cần review lại bảng Section 4.1 và cập nhật unit tests tương ứng._
