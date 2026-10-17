# Phase 1 review — baseline equivalence và error forensics

**Trạng thái:** đã được người dùng duyệt ngày 2026-10-15  
**Evidence:** development only  
**Algorithm label:** `phase1-offline-prototype`  
**Config fingerprint:** `fnv1a32-12b93cef`

## 1. Phạm vi đã thực hiện

Phase 1 chỉ thay đổi offline benchmark, artifact metadata và regression tests.
Không sửa EKF core, không tune tham số, không đổi DBSCAN và không nối live.

Các thay đổi:

- Đồng bộ cách tính `dt` của baseline replay với live engine ở precision
  millisecond.
- Thêm regression test đối chiếu benchmark với `WorkoutTrackingEngine` cho first
  fix, tiny segment, low accuracy, weak-signal recovery, speed spike và GPS gap.
- Giữ CLI pure Dart. Không import live engine vào CLI vì `geolocator` kéo
  `dart:ui`, làm `dart run tool/gps_benchmark.dart` không thể chạy.
- Field artifact dùng schema v2, evidence label
  `field_development_no_ground_truth`, algorithm version, config fingerprint,
  dataset ID và generated timestamp.
- Field CLI sinh thêm JSONL per-timestamp không có tọa độ.
- Latency đo sau một warm-up và 5 measured runs; báo median/P95.
- Synthetic artifact dùng schema v3 và evidence label `synthetic_development`.
- Báo cả signed và absolute distance error.

## 2. Baseline equivalence finding

Đã tái hiện một sai lệch thật ở biên gap:

```text
delta = 5.0005 s
benchmark cũ dùng microseconds → xem là > 5 s → break segment
live engine dùng milliseconds  → xem là 5.000 s → không break segment
```

Regression test đã đỏ trước khi sửa và xanh sau khi benchmark chuyển sang cùng
precision millisecond. Test equivalence mở rộng cũng xác nhận decision/reason và
segment boundary giống live engine trên các nhánh validation đại diện.

Benchmark vẫn có adapter pure-Dart riêng thay vì import live service trực tiếp.
Đây là chủ ý để CLI chạy được bằng `dart run`; equivalence được bảo vệ bằng test
đối chiếu live engine. Nếu live validation policy đổi, test này phải thất bại.

## 3. Synthetic development result

Scenario: urban cycling 30 phút, cùng input và validation cho baseline/candidate.

| Metric | Current baseline | EKF prototype | Thay đổi |
|---|---:|---:|---:|
| Availability | 59,411% | 59,411% | 0 điểm % |
| RMSE | 3,417 m | 3,172 m | giảm 7,16% |
| P95 | 5,884 m | 4,714 m | giảm 19,89% |
| Absolute distance error | 8,399% | 7,364% | giảm 12,32% |
| Turn P95 | 7,349 m | 5,630 m | giảm 23,39% |
| Turn RMSE | 3,723 m | 3,828 m | **tăng 2,81%** |
| Gap-recovery P95 | 4,776 m | 4,089 m | giảm 14,38% |

Kết luận ở Phase 1: prototype chưa đạt final gate vì RMSE chỉ giảm 7,16%, dưới
ngưỡng 10%. Turn P95 tốt hơn nhưng turn RMSE xấu hơn, nên chưa thể kết luận mô
hình rẽ đã đúng.

### Stationary 10 phút

| Metric | Current baseline | EKF prototype | Thay đổi |
|---|---:|---:|---:|
| RMSE | 1,384 m | 1,369 m | giảm 1,10% |
| P95 | 2,272 m | 2,361 m | **tăng 3,88%** |

P95 stationary vẫn nằm trong guardrail 5% nhưng đi sai hướng. Đây là bằng chứng
để giữ T-DBSCAN thành KPI riêng ở Phase 7, không cộng chung vào thành tích EKF.

## 4. Error forensics theo timestamp

Top 5% của EKF urban gồm 54 accepted timestamps:

- 43 timestamp được ground-truth tức thời gắn nhãn `straight`.
- 11 timestamp được gắn nhãn `turn`.
- 37/54 (68,5%) có `turnDetected = true` tại update EKF.
- 12/54 có position innovation lớn hơn 20 m.
- NIS chỉ down-weight 1/54 và reject 0/54.

Năm timestamp lỗi lớn nhất:

| Timestamp UTC | Phase | Error | Innovation | NIS | EKF turn |
|---|---|---:|---:|---:|---|
| 00:06:18 | straight | 13,849 m | 46,269 m | 12,102 | true |
| 00:02:11 | straight | 11,404 m | 33,295 m | 5,176 | true |
| 00:09:12 | straight | 11,391 m | 19,875 m | 1,742 | true |
| 00:17:01 | straight | 11,202 m | 27,346 m | 2,812 | true |
| 00:02:46 | straight | 11,085 m | 26,508 m | 5,591 | false |

### Root-cause evidence

1. Long-tail không chỉ nằm đúng tại timestamp ground-truth đổi hướng. Validation
   loại nhiều mẫu giữa hai EKF update, nên update kế tiếp có thể nhận course
   delta lớn dù nhãn tức thời đã trở lại `straight`.
2. 68,5% top-tail kích hoạt turn adaptation. Mô hình heading/turn vẫn là vùng
   cần xử lý chính ở Phase 4.
3. Innovation 20–46 m vẫn thường có NIS dưới ngưỡng vì innovation covariance
   lớn. NIS prototype hiện chưa đủ để chặn phần lớn long-tail; Phase 3 phải audit
   cách tạo `S`, adaptive `R` và recovery sau chuỗi measurement bị validation bỏ.
4. Synthetic validation loại 721/1.791 point (40,26%), trong đó 689 là
   `headingSpike`. Đây là interaction mạnh giữa synthetic route và live
   validation, không đại diện trực tiếp cho field data. Candidate vẫn được so
   công bằng vì dùng cùng accepted timestamps, nhưng Phase 4 cần scenario turn
   chuyên biệt thay vì chỉ dựa vào aggregate urban này.

## 5. Replay 7 field development journals

Field journals không có positional ground-truth, vì vậy bảng này không chứa
RMSE/P95 vị trí.

Tổng hợp:

- 7/7 journal replay thành công, không crash.
- 10.730 timestamp duy nhất từ 10.779 source lines.
- 49 duplicate timestamp.
- 89 gap lớn hơn 5 giây; max gap 17,007 giây.
- Baseline accepted 8.135 và rejected 2.595 point.
- Rejection: 2.369 tiny segment, 128 low accuracy, 96 heading spike và 2 bad
  initial fix.
- EKF display distance so với baseline app distance dao động từ -2,789% đến
  +0,036%. Đây chỉ là pipeline difference, không phải accuracy.
- EKF latency P95 cao nhất trong 7 journal là 5,804 µs/point, thấp hơn budget
  1.000 µs/point với khoảng cách rất lớn.

Field data cho thấy `headingSpike` chỉ chiếm 96/2.595 rejection, khác rõ synthetic
urban (689/721). Vì vậy không được tune validation theo synthetic để làm đẹp
availability trong phase này.

## 6. Determinism và artifact

Synthetic benchmark được chạy hai lần:

- Summary sau khi bỏ `generated_at_utc` có cùng SHA-256:
  `ea6bf6a85e9eb746f2dc5886926e129c3fa8634c2027e392d15912e1903d76d1`.
- Detailed trace có cùng SHA-256:
  `56d9ea3a3b5f04a2fd20de0f375ab999e2f9dd5df0c0f015c11b18a626d504d3`.

Artifacts ngoài Git:

- `/tmp/aetron-phase1-synthetic.json`
- `/tmp/aetron-phase1-synthetic.json.trace.jsonl`
- `/tmp/aetron-phase1-raw-gps-<workout-id>.json`
- `/tmp/aetron-phase1-raw-gps-<workout-id>.json.trace.jsonl`

Trace field chứa timestamp, rejection reason và diagnostics nhưng không chứa
latitude/longitude.

## 7. Vấn đề gặp trong phase và cách xử lý

Một thử nghiệm cho benchmark import trực tiếp `WorkoutTrackingEngine` đã làm CLI
pure Dart fail vì dependency `geolocator` dẫn tới `dart:ui`. Công việc được dừng,
root cause được xác nhận, rồi adapter pure-Dart được phục hồi. Regression tests
Flutter đối chiếu adapter với live engine thay cho runtime import. Không sửa live
engine hoặc dependency graph ngoài phạm vi Phase 1.

## 8. File thay đổi trong Phase 1

- `lib/features/workout/domain/services/benchmark/field_gps_benchmark_runner.dart`
- `lib/features/workout/domain/services/benchmark/gps_benchmark_cli.dart`
- `test/field_gps_benchmark_runner_test.dart`
- `test/gps_benchmark_cli_test.dart`
- `tool/gps_synthetic_benchmark.dart`
- Tài liệu review này.

Không thay đổi:

- `extended_kalman_filter.dart` trong Phase 1.
- `GpsSmoothingService`, `WorkoutTrackingEngine` và live providers.
- DBSCAN core.
- Database/backend.

## 9. Phase 1 acceptance checklist

- [x] Baseline replay có equivalence regression test với live decisions.
- [x] Xác định top 5% timestamp tạo long-tail.
- [x] Có metric theo straight/turn/gap-recovery/dwell.
- [x] Có innovation, NIS, turn state và rejection reason theo timestamp.
- [x] Artifact chi tiết nằm ngoài Git và field trace không chứa tọa độ.
- [x] Replay 7 field journals không crash.
- [x] Synthetic output deterministic.
- [x] `flutter analyze`: không có issue.
- [x] `flutter test`: 357 test pass, 1 test skip.
- [x] Người dùng duyệt Phase 1.

## 10. Đề nghị quyết định

Đề nghị **Duyệt Phase 1** và chuyển sang Phase 2 — correctness foundation của
EKF. Phase 2 sẽ audit covariance, đơn vị `Q/R`, Joseph form, measurement validity
và numerical stability; chưa tune để đạt metric.
