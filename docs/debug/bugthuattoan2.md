# Aetron GPS Record — Tổng Hợp Lỗi & Kế Hoạch Sửa Chữa
### (Hướng tới EKF + DBSCAN)

Ngày: 06/10/2026 · Người lập: Muse · Người implement: Bảo
Nguồn đối chiếu: repo GitHub (27/09/2026, 170 files) vs lib-3.zip (05/10/2026, 466 files)

---

## PHẦN 1 — KẾT QUẢ ĐỐI CHIẾU

| File | Repo 27/09 | lib-3 05/10 | Kết luận |
|---|---|---|---|
| `workout_tracking_engine.dart` (964 dòng, 10 cửa lọc) | ✅ | ✅ | **IDENTICAL — 0 dòng thay đổi** |
| `workout_session_state.dart` (215 dòng) | ✅ | ✅ | Giống nhau |
| `workout_session_finalizer.dart` (113 dòng) | ✅ | ✅ | Giống nhau |
| `workout_environment_controller.dart` (33 dòng) | ✅ | ✅ | Giống nhau |
| `record_providers.dart` | 1667 dòng | 1812 dòng | Khác: thêm crash-recovery, checkpoint, sync — **không động GPS** |
| `workout_tracking_engine.dart` ở repo | `domain/services/` | `domain/services/` | Cùng vị trí |

**Kết luận:** Mọi plan sửa đổi từ 27/09 đến nay chỉ động vào UI/sync/recovery.
Thuật toán GPS lõi đứng yên — đây là nguyên nhân "không có gì được cải thiện".

---

## PHẦN 2 — TỔNG HỢP LỖI CHÍNH (theo mức độ nghiêm trọng)

### 🔴 LỖI 1: O(n²) + rebuild toàn UI mỗi điểm GPS
- **File:** `record_providers.dart:1361-1374` (`_applyAcceptedGpsSegment`)
- **Hiện tượng:** Mỗi điểm GPS accepted (~1Hz):
  1. Copy toàn bộ 6 danh sách (`filteredRoutePoints`, `smoothedRoutePoints`, `routePoints`, `routeSegments` deep, `smoothedRouteSegments` deep, `gpsGapSegments`) rồi mới add 1 điểm
  2. `state.copyWith(...)` → Riverpod rebuild **toàn màn hình record** (HUD + map vẽ lại polyline + top bar)
- **Con số:** Buổi 2h = 7200 điểm → ≈ **130 triệu** phần tử copy + 7200 lần rebuild UI
- **User cảm nhận:** map giật khi route dài, máy nóng, pin tụt — càng tập lâu càng lag
- **Nguyên nhân gốc:** pattern immutable state của Riverpod bị lạm dụng cho dữ liệu update 1Hz

### 🟡 LỖI 2: Deep copy thừa trong `queueLiveRouteSnapshot`
- **File:** `workout_recording_coordinator.dart:196-208`
- **Hiện tượng:** Deep copy toàn bộ route segments mỗi điểm GPS, nhưng `syncLiveRouteSnapshot` throttle 5s → 4/5 lần copy bị vứt đi
- **Fix:** early return nếu chưa đủ 5s từ lần sync trước (chi tiết ở Phần 4, Bước 0)

### 🟡 LỖI 3: String interpolation mỗi điểm GPS (kể cả bản release)
- **File:** `record_providers.dart` — `debugPrint` trong `_onPosition` (~dòng 930) và `_applyAcceptedGpsSegment` (~dòng 1471)
- **Hiện tượng:** Chuỗi `'lat=${...}, lng=${...}, acc=...'` được build mỗi fix GPS ngay cả bản release (debugPrint chỉ bỏ qua việc in, không bỏ qua việc build chuỗi)
- **Fix:** bọc trong `if (kDebugMode)` — `flutter/foundation.dart` đã import sẵn

### 🟢 QUAN SÁT 4: Thuật toán lọc GPS hiện tại là ĐÚNG, không cần sửa logic
- 10 cửa lọc (first-fix gate, anchor reset, tiny segment, accuracy, speed spike, signal gap, route break, implied speed, heading spike) hoạt động đúng
- Tách bạch 3 loại quãng đường: `distanceMeters` (live) / `validDistanceKm` (sau lọc) / `totalDistanceKm` (raw)
- Tách bạch điểm cộng quãng (raw đã lọc) vs điểm vẽ map (smoothed) — thiết kế đúng
- Nếu GPS thực tế vẫn sai số: do ngưỡng chưa hợp địa hình VN (nhà cao tầng, hẻm) hoặc phần cứng điện thoại — không phải bug logic

### 📌 LỖI LIÊN QUAN ĐÃ BÁO TRƯỚC (không lặp lại chi tiết, chỉ liệt kê để không sót)
- Summary dùng `totalDistanceKm` vs list dùng `validDistanceKm` → lệch số (bug #2 báo cáo 05/10)
- i18n thiếu: dialog Stop, snackbar GPS, goal validation (7 dòng tiếng Anh hardcode)
- Màu/font cũ trong map widget, HUDs, trophy wall (139 chỗ `AetronColors`)

---

## PHẦN 3 — KIẾN TRÚC MỤC TIÊU (chuẩn bị cho EKF + DBSCAN)

```
┌─────────────────────────────────────────────────────────┐
│  _onPosition (record_providers.dart) — giữ nguyên        │
│  → 10 cửa lọc (workout_tracking_engine) — giữ nguyên    │
└──────────────────────┬──────────────────────────────────┘
                       │ điểm accepted
                       ▼
┌─────────────────────────────────────────────────────────┐
│  GpsPipeline (class mới, stateful, mutable)             │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────┐  │
│  │ EKF state   │  │ Mutable      │  │ Anchor, thời   │  │
│  │ x, P (4x4)  │  │ buffers      │  │ gian, speed    │  │
│  │ [tương lai] │  │ (route lists)│  │ samples        │  │
│  └─────────────┘  └──────────────┘  └────────────────┘  │
│  • processPoint(): O(1) append + EKF predict/update      │
│  • snapshot(): trả bản copy cho state (mỗi 5s)          │
│  • flush(): ép snapshot (pause/stop/resume)             │
└──────┬──────────────────────────────────┬───────────────┘
       │ metrics nhẹ (1Hz)                │ route snapshot (0.2Hz)
       ▼                                  ▼
  state.copyWith(                    state.copyWith(
    distanceMeters,                     routePoints,
    speedKmh,                           routeSegments,
    caloriesBurned,                     smoothedRoute...,
    currentLatLng,                      gapSegments,
    lapSplits, ...)                     ...)
       │                                  │
       ▼                                  ▼
  HUD rebuild (rẻ)                  Map rebuild (đắt, ít lần)
```

**Nguyên tắc:**
1. Hot path (mỗi điểm GPS) chỉ làm việc O(1): append buffer + update số
2. Việc đắt (copy list, rebuild map) gom lại mỗi 5s
3. `GpsPipeline` là nhà tương lai của EKF state (ma trận x, P cần sống qua từng điểm — không thể nhét vào immutable state mà không copy mỗi lần)
4. Finalizer không đổi: nó đọc từ state **sau khi flush** — dữ liệu đầy đủ như cũ

---

## PHẦN 4 — PLAN A CHI TIẾT (từng bước implement)

### Bước 0: Fix nhanh 2 lỗi nhỏ (LỖI 2, LỖI 3) — 15 phút
- [ ] `record_providers.dart`: bọc 2 `debugPrint` hot-path trong `if (kDebugMode)`
- [ ] `workout_recording_coordinator.dart` → `queueLiveRouteSnapshot`: thêm early return khi `now.difference(_lastLiveRouteSnapshotSyncAt) < _kLiveRouteSnapshotInterval`
- [ ] `flutter analyze` pass

### Bước 1: Tạo `GpsPipeline` class — file mới
`lib/features/workout/domain/services/gps_pipeline.dart`
- [ ] Fields mutable: `routePoints`, `filteredRoutePoints`, `smoothedRoutePoints` (List<LatLng> growable), `routeSegments`, `smoothedRouteSegments` (List<List<LatLng>>), `gapSegments`
- [ ] Fields pipeline: `_distanceAnchorPoint`, `_lastAcceptedPositionTime`, `_shouldResetAnchorOnResume` (chuyển từ notifier sang đây)
- [ ] **Chỗ cho tương lai:** `EkfState? ekf` (null cho đến khi implement EKF)
- [ ] Methods:
  - `processAcceptedPoint({...})` — append O(1) vào buffers, cập nhật anchor/thời gian, trả về metrics (distanceDelta, smoothedPoint, confidence...)
  - `snapshot()` — trả về bản copy unmodifiable của tất cả lists (dùng cho state)
  - `flush()` — alias của snapshot, gọi khi pause/stop
  - `reset()` / `seed(LatLng)` — cho start/resume
- [ ] Không đụng đến `workout_tracking_engine.dart` — 10 cửa lọc giữ nguyên

### Bước 2: Sửa `_applyAcceptedGpsSegment` — `record_providers.dart:1344`
- [ ] Xóa 6 dòng `List.from` / `.map(...from...)` (dòng 1361-1374)
- [ ] Gọi `pipeline.processAcceptedPoint(...)` thay thế
- [ ] `state.copyWith` **chỉ** chứa metrics nhẹ: `distanceMeters`, `speedKmh`, `caloriesBurned`, `currentLatLng`, `smoothedCurrentLatLng`, `lapSplits`, `gpsConfidence`, `isStationaryByGps`, `isGpsSignalWeak`, `lastGpsGapDurationSec`, `gpsGapMarker`
- [ ] **Không** đưa route lists vào copyWith ở đây nữa

### Bước 3: Thêm cơ chế snapshot định kỳ
- [ ] Trong notifier: biến đếm `_pointsSinceSnapshot`; mỗi 5 điểm accepted HOẶC 5 giây (lấy điều kiện nào đến trước):
  ```dart
  final snap = pipeline.snapshot();
  state = state.copyWith(
    routePoints: snap.routePoints,
    filteredRoutePoints: snap.filteredRoutePoints,
    smoothedRoutePoints: snap.smoothedRoutePoints,
    routeSegments: snap.routeSegments,
    smoothedRouteSegments: snap.smoothedRouteSegments,
    gpsGapSegments: snap.gapSegments,
  );
  ```
- [ ] Map vẫn "live" với mắt người (5s không phân biệt được trên đường route)

### Bước 4: Đảm bảo flush ở các điểm chuyển trạng thái
- [ ] `pauseWorkout`: flush pipeline → state **trước** khi đổi status
- [ ] `stopWorkout`: flush pipeline → state **trước** khi gọi finalizer
- [ ] `resumeWorkout`: `pipeline.resetAnchor()` (thay cho `_shouldResetGpsAnchorOnResume`)
- [ ] `seedRoute` (điểm đầu): `pipeline.seed(decision.livePoint)`
- [ ] Lý do: finalizer và màn hình summary đọc từ state — sau flush, state đầy đủ 100% như cũ

### Bước 5: Dọn biến thừa trong notifier
- [ ] Xóa `_distanceAnchorPoint`, `_lastAcceptedPositionTime`, `_shouldResetGpsAnchorOnResume` khỏi `record_providers.dart` (đã chuyển vào pipeline)
- [ ] Giữ `_recordingCoordinator`, `_environmentController`, `_gpsSmoothingService` nguyên

### Bước 6: Checklist test sau implement
- [ ] `flutter analyze` — 0 error
- [ ] Record thử 5 phút ngoài trời: quãng đường khớp với trước (so với Google Maps đo tay)
- [ ] Pause → resume: route không nhảy, quãng không tăng đột biến
- [ ] Stop: summary hiện đủ route, số liệu khớp live
- [ ] Bật/tắt màn hình, lock/unlock: không mất điểm
- [ ] Test với `kDebugLocationMode` nếu có
- [ ] So sánh pin: buổi 30 phút trước/sau (cảm quan + battery stats nếu có)

---

## PHẦN 5 — TÍCH HỢP EKF (sau khi Plan A xong)

### Vị trí
Thay thế `GpsSmoothingService.smoothAcceptedPoint` trong live path.
10 cửa lọc giữ nguyên đứng trước EKF.

### Thiết kế
- **State:** `x = [lat, lng, vLat, vLng]`, `P` (4x4) — sống trong `GpsPipeline` (đây là lý do Plan A là nền móng bắt buộc)
- **Predict:** constant-velocity model mỗi điểm accepted
- **Update:** measurement = điểm GPS đã qua 10 cửa lọc
- **R (measurement noise) adaptive:** `R = position.accuracy²` — tận dụng dữ liệu điện thoại cho sẵn, không tune cứng
- **Q (process noise):** tune theo activity (run/walk/cycle khác nhau)

### ⚠️ NGUYÊN TẮC BẮT BUỘC
> **EKF chỉ dùng cho HIỂN THỊ + PACE. KHÔNG dùng cho QUÃNG ĐƯỜNG.**
> EKF với constant-velocity model sẽ cắt cua → đường ziczac bị nắn thẳng → quãng đo ngắn hơn thực tế.
> Kiến trúc hiện tại đã tách đúng: điểm raw (đã lọc) cộng quãng, điểm smoothed vẽ map.
> EKF chỉ thay phía smoothed.

### Output của EKF dùng cho
- `smoothedCurrentLatLng` / `displayRoutePoint` (vẽ map)
- `speedKmh` tức thì (từ velocity state — ổn định hơn pace hiện tại)
- `gpsConfidence` (từ covariance P — biết khi nào GPS đáng tin)

### Validate (không tune mù)
- [ ] App đã có `bufferRawGpsPoint` → dùng raw traces thật để replay test
- [ ] Chạy cùng 1 trace qua pipeline cũ vs +EKF, so quãng đường với thực tế
- [ ] Tiêu chí pass: pace tức thì ít nhảy hơn, quãng đường sai số không tăng

---

## PHẦN 6 — TÍCH HỢP DBSCAN (sau EKF, độc lập)

### Vị trí
Post-processing trong `workout_session_finalizer.dart` — chạy **1 lần khi bấm Stop**, không bao giờ chạy live.

### Thiết kế
- **Input:** full route từ state (sau flush) — `routePoints` + timestamps
- **Chạy trên isolate** (compute): với 7200 điểm, DBSCAN naive ≈ 26M phép haversine → 1-3s trên điện thoại, không được block UI lúc lưu workout
- **Tham số gợi ý:** `eps` ≈ 15-25m (bán kính drift GPS), `minPts` quy theo thời gian (điểm trong ~30s)
- **Output:**
  - Danh sách đoạn dừng nghỉ → hiện ở summary ("Nghỉ 2 lần · 3p20s")
  - Route đã loại nhiễu drift → lưu làm route chính thức
  - Ghi vào `gpsAnalysis` (cùng chỗ với `validDistanceKm`)

### Giá trị thật của DBSCAN
Không phải "làm đẹp route" — mà là **phát hiện dừng nghỉ có ý nghĩa** (phân biệt "dừng đèn đỏ" vs "GPS drift khi đứng yên", điều mà auto-pause hiện tại làm chưa tốt).

### Validate
- [ ] Test với buổi tập có dừng nghỉ thật (đi bộ dừng mua nước...)
- [ ] So số lần dừng phát hiện vs thực tế

---

## PHẦN 7 — THỨ TỰ THỰC HIỆN & MỐC

```
Tuần 1: Plan A (Bước 0 → 6)
  └─ Fix O(n²), dọn nền cho EKF. Mỗi bước test được riêng.
Tuần 2: EKF (Phần 5)
  └─ Chỉ live path (display + pace). Quãng đường không đổi.
Tuần 3: DBSCAN (Phần 6)
  └─ Chỉ finalizer. Chạy isolate. Thêm mục "dừng nghỉ" ở summary.
```

**Không làm song song 3 thứ** — mỗi tầng phụ thuộc tầng trước, và mỗi tầng cần số liệu validate riêng.

### Ghi chú về UI
Trước đây UI từng ghi "EKF/DBSCAN" nhưng chưa implement (đã gỡ).
Khi nào implement xong và validate pass, hãy đưa badge đó trở lại — lúc đó mới là thật.

---

## PHẦN 8 — RỦI RO & CÁCH PHÒNG

| Rủi ro | Phòng ngừa |
|---|---|
| Quên flush → finalizer thiếu điểm cuối | Bước 4 bắt buộc flush ở pause/stop; checklist test có case stop đột ngột |
| Snapshot 5s làm map "giật cục" | 5s trên route line mắt thường không phân biệt được; nếu thấy, giảm xuống 3s |
| EKF cắt cua làm pace sai | Nguyên tắc Phần 5: EKF không động vào quãng đường |
| DBSCAN chậm trên máy yếu | Isolate + timeout fallback (quá 5s → dùng route chưa clean) |
| Không có compiler để verify | Mỗi bước đều có checklist test tay trên thiết bị thật |
