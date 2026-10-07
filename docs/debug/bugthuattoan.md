# Thuật Toán GPS Record — Tài Liệu Đầy Đủ + So Sánh + Implement

Ngày: 06/10/2026 · Nguồn đọc: repo GitHub (27/09) + lib-3.zip (05/10, code hiện tại)

---

## 1. SO SÁNH: REPO vs CODE HIỆN TẠI

| File | Repo (27/09) | lib-3 (05/10) | Kết luận |
|---|---|---|---|
| `workout_tracking_engine.dart` (964 dòng) | ✅ | ✅ | **IDENTICAL** — thuật toán lõi không đổi |
| `workout_session_state.dart` | ✅ | ✅ | Giống nhau |
| `workout_session_finalizer.dart` | ✅ | ✅ | Giống nhau |
| `workout_environment_controller.dart` | ✅ | ✅ | Giống nhau |
| `record_providers.dart` | 1667 dòng | 1812 dòng | Khác — thêm crash-recovery, checkpoint, sync logic |

**Kết luận quan trọng:** Thuật toán GPS lõi **không thay đổi một dòng nào** từ 27/09 đến nay.
Mọi "plan sửa đổi" vừa qua chỉ động vào UI/sync/recovery, không động vào GPS.
Đây là lý do "không có gì được cải thiện" ở phần record GPS.

---

## 2. THUẬT TOÁN GPS RECORD (đọc từ `workout_tracking_engine.dart`)

### 2.1. Pipeline xử lý mỗi điểm GPS (`evaluateGpsUpdate`)

Mỗi fix GPS (~1Hz) đi qua 10 cửa lọc theo thứ tự:

```
Position (lat, lng, accuracy, speed, timestamp)
  │
  ├─[1] First-fix gate: nếu route rỗng và accuracy > ngưỡng
  │     (run 16m / walk 18m / cycle 20m) → SKIP, chờ fix tốt hơn
  │     → seed điểm đầu tiên khi đủ chính xác
  │
  ├─[2] Resume anchor reset: nếu vừa resume từ pause
  │     → reset anchor, không cộng khoảng nhảy
  │
  ├─[3] Tiny segment: quãng < ngưỡng (run 0.30m / walk 0.35m / cycle 1.5m)
  │     → SKIP (lọc nhiễu đứng yên)
  │
  ├─[4] Low accuracy: accuracy > ngưỡng (run 42m / walk 50m / cycle 32m)
  │     → SKIP + đánh dấu isGpsSignalWeak
  │
  ├─[5] GPS speed spike: position.speed > maxSpeedMs → HARD REJECT
  │
  ├─[6] Signal gap: timeDelta > 5s → ACCEPT nhưng break route (vẽ đứt nét),
  │     không cộng quãng, đánh dấu GpsGapSegment
  │
  ├─[7] Live route break: accuracy xấu + thời gian dài + nhảy xa
  │     → tương tự [6] (tránh vẽ đường thẳng xuyên qua vùng mất sóng)
  │
  ├─[8] Implied speed spike: quãng/thời gian > maxSpeed*1.2 → HARD REJECT
  │
  ├─[9] Heading spike: đổi hướng > 120° trong < 20m → HARD REJECT
  │     (lọc nhiễu "nhảy" khi đứng yên)
  │
  └─[10] ACCEPT → tính candidateSpeedKmh (ưu tiên quãng/thời gian,
          fallback sensor speed), cộng vào distanceMeters
```

### 2.2. Ba loại quãng đường (quan trọng!)

| Loại | Tính từ | Dùng ở đâu |
|---|---|---|
| `distanceMeters` | Cộng dồn segment đã lọc | Hiển thị live, summary |
| `validDistanceKm` | Phân tích lại sau khi xong (loại spike) | History, goal, home |
| `totalDistanceKm` (gpsAnalysis) | Tổng raw trước lọc spike | (đang dùng sai ở summary — bug đã báo) |

### 2.3. Smoothing & hiển thị

- `GpsSmoothingService.smoothAcceptedPoint`: làm mượt điểm vẽ lên map
- **Điểm cộng quãng = điểm raw đã lọc** (`routeCandidate = decision.livePoint`)
- **Điểm vẽ map = điểm smoothed** (`displayRoutePoint`)
- → Quãng đường chính xác, map mượt. Thiết kế này ĐÚNG.

### 2.4. Fallback khi mất GPS

```
GPS yếu kéo dài → trackingMode = indoor, recordingSource = 'step_fallback'
→ quãng đường tính từ bước chân × strideLength
→ GPS hồi phục → quay lại GPS, anchor reset (không nhảy quãng)
```

---

## 3. CHỨC NĂNG TỪNG NÚT BẤM (luồng Record)

### 3.1. Trước khi ghi (Activity tab)
| Nút | Chức năng |
|---|---|
| Chọn môn (Run/Walk/Cycle) | Đặt `activityType`, quyết định ngưỡng lọc GPS + có dùng GPS không |
| Chọn mục tiêu | Đặt `workoutTarget` (quãng/thời gian/calo) → hiện target HUD khi ghi |
| Bắt đầu | `_startWorkout()` → xin quyền → GPS lock (3s countdown, CÓ skip) → start |

### 3.2. Dialog lỗi khởi động (`record_screen.dart:315-380`)
| Nút | Chức năng |
|---|---|
| "Tập bằng bước chân" | Bỏ qua GPS, start ở chế độ indoor/step-only |
| "Hủy bỏ" | Đóng dialog + thoát màn hình record |
| Nút action chính | Thử lại khởi động sensor |

### 3.3. Khi đang ghi (Control Dock)
| Nút | Chức năng |
|---|---|
| Tạm dừng / Tiếp tục | `onPauseResume` → pause: đóng băng GPS, checkpoint recovery; resume: reset anchor, `_startGpsBackground` |
| Dừng (Stop) | `onStop` → dialog xác nhận → `stopWorkout()` → finalizer tính toán → summary |
| Khóa màn hình | `onToggleLock` → overlay chống chạm mồ hôi → "Chạm để mở khóa" |
| Toggle metrics (top bar) | Đổi hero metrics 46px ↔ 56px (large mode) |

### 3.4. Dialog xác nhận Stop (`record_screen.dart:403-416`)
| Nút | Chức năng |
|---|---|
| Cancel | Đóng dialog, tiếp tục ghi |
| Finish | Kết thúc → lưu (remote + local fallback) → summary |

### 3.5. Trên map
| Nút | Chức năng |
|---|---|
| 2D/3D toggle | Đổi góc nhìn map |
| Chọn kiểu map | Bottom sheet: vệ tinh 3D / đường phố |
| Locate (định vị) | `_onLocatePressed` → center map về vị trí hiện tại |

### 3.6. HUD phụ
| Nút | Chức năng |
|---|---|
| BỎ QUA (guided program) | Skip bước hiện tại của giáo án → sang bước tiếp |
| Kéo bottom sheet | Mở chi tiết: lap splits, biểu đồ, thông số phụ |

---

## 4. ĐÃ IMPLEMENT (06/10/2026) — file trong `aetron-gps-fix/`

### Fix 1: `record_providers.dart` — chặn string interpolation mỗi điểm GPS
- 2 chỗ `debugPrint` trong `_onPosition` và `_applyAcceptedGpsSegment`
- Bọc trong `if (kDebugMode)` — trước đây chuỗi `'lat=${...}, lng=${...}'`
  được build **mỗi fix GPS (~1Hz × hàng giờ)** ngay cả bản release
- `flutter/foundation.dart` đã import sẵn → `kDebugMode` dùng được ngay

### Fix 2: `workout_recording_coordinator.dart` — bỏ deep copy thừa
- `queueLiveRouteSnapshot`: deep copy toàn bộ route segments mỗi điểm GPS,
  trong khi `syncLiveRouteSnapshot` throttle 5s (bỏ qua 4/5 lần copy)
- Thêm early return: nếu chưa đủ 5s từ lần sync trước → return luôn,
  không copy. Lần tick đủ 5s sẽ copy fresh + sync
- An toàn: raw points vẫn được buffer riêng (`bufferRawGpsPoint`) làm
  source of truth cho finalizer; snapshot này chỉ là preview live

### Hiệu quả ước tính
- Buổi chạy 2h (~7200 fix): bớt ~7200 lần build chuỗi log + ~5760 lần
  deep copy route (mỗi lần O(n) với n tăng dần) → giảm CPU + pin đáng kể

---

## 5. CHƯA LÀM (cần quyết định của anh)

### 5.1. O(n²) trong `_applyAcceptedGpsSegment` — vấn đề lớn nhất còn lại
Mỗi điểm GPS accepted:
```dart
final updatedFilteredRoute = List<LatLng>.from(state.filteredRoutePoints)..add(...);
// + 4 list copy nữa + 2 deep copy segments
state = state.copyWith(...tất cả lists...); // rebuild toàn UI mỗi điểm
```
Buổi 2h = 7200 lần × copy list ~3600 phần tử trung bình ≈ **26 triệu** phần tử copy.
**Hướng fix đúng:** tách state — metrics nhẹ (distance/speed) update 1Hz,
route lists chỉ sync vào state mỗi 5s cho map vẽ. Nhưng đây là refactor
kiến trúc, không làm mù được (cần compiler + test). Anh quyết định có làm không.

### 5.2. Thuật toán lọc GPS hiện tại ĐÚNG, không cần sửa
10 cửa lọc + 3 loại quãng + smoothing tách bạch display/distance.
Nếu GPS vẫn sai số thực tế, nguyên nhân nằm ở: ngưỡng chưa hợp địa hình VN
(nhà cao tầng), hoặc GPS điện thoại — không phải logic code.

---

## 6. CÁCH ÁP DỤNG FIX

```bash
# Copy 2 file đã sửa đè vào lib-3 (backup trước)
cp ~/workspace/aetron-gps-fix/lib/features/workout/presentation/screens/record/record_providers.dart \
   <du-an>/lib/features/workout/presentation/screens/record/
cp ~/workspace/aetron-gps-fix/lib/features/workout/presentation/screens/record/workout_recording_coordinator.dart \
   <du-an>/lib/features/workout/presentation/screens/record/
flutter analyze
```
