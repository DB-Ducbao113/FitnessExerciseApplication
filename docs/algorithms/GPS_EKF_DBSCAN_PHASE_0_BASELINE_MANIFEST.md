# Phase 0 review package — baseline manifest và metric contract

**Trạng thái:** chờ duyệt Phase 0
**Ngày khóa manifest:** 2026-10-15 (Asia/Ho_Chi_Minh)
**Nhánh làm việc:** `EFK+DBSCAN`

## 1. Git baseline

| Thành phần | Giá trị |
|---|---|
| `HEAD` | `52b774a877fb0898836e82a51ec6a774a5af9246` |
| `main` | `52b774a877fb0898836e82a51ec6a774a5af9246` |
| merge-base `HEAD main` | `52b774a877fb0898836e82a51ec6a774a5af9246` |
| baseline commit | `feat: add Vercel Web Analytics` |
| baseline commit time | `2026-10-13T16:58:17+07:00` |

Nhánh `EFK+DBSCAN` hiện trỏ cùng commit với `main`. Candidate chỉ tồn tại trong
working tree, chưa có commit riêng. Do working tree đã có nhiều thay đổi của
người dùng từ trước, Phase 0 không tự động stage, commit, stash, reset hay xóa
bất kỳ file nào.

Điều này có nghĩa: `main` ref chưa đổi, nhưng thay đổi chưa commit vẫn có thể đi
theo working tree nếu switch branch. Không được switch branch trước khi tạo được
checkpoint sạch, có phạm vi và được người dùng duyệt.

## 2. Phạm vi candidate prototype cần audit

### 2.1 Core và test trực tiếp

- `lib/features/workout/domain/services/ekf/extended_kalman_filter.dart`
- `test/extended_kalman_filter_test.dart`

### 2.2 Offline benchmark/replay

- `lib/features/workout/domain/services/benchmark/field_gps_trace.dart`
- `lib/features/workout/domain/services/benchmark/field_gps_benchmark_runner.dart`
- `lib/features/workout/domain/services/benchmark/gps_benchmark_cli.dart`
- `lib/features/workout/domain/services/benchmark/synthetic_gps_trace_factory.dart`
- `lib/features/workout/domain/services/benchmark/synthetic_gps_benchmark_runner.dart`
- `test/field_gps_trace_parser_test.dart`
- `test/field_gps_benchmark_runner_test.dart`
- `test/gps_benchmark_cli_test.dart`
- `test/synthetic_gps_trace_factory_test.dart`
- `test/synthetic_gps_benchmark_runner_test.dart`
- `test/fixtures/gps/anonymized_raw_gps_trace.jsonl`
- `tool/gps_benchmark.dart`
- `tool/gps_synthetic_benchmark.dart`
- `tool/gps_ekf_parameter_search.dart`

### 2.3 Thuật toán DBSCAN hiện có, chỉ đọc cho tới Phase 7

- `lib/features/workout/domain/services/dbscan/gps_dbscan_service.dart`
- `lib/features/workout/domain/services/dbscan/dwell_route_simplifier.dart`
- `test/gps_dbscan_service_test.dart`
- `test/dwell_route_simplifier_test.dart`

### 2.4 Tài liệu thuộc nghiên cứu

- `docs/algorithms/GPS_EKF_DBSCAN_PHASE_GATE_MASTER_PLAN.md`
- `docs/algorithms/GPS_EKF_RECOVERY_PLAN.md`
- `docs/algorithms/GPS_CYCLING_EKF_DBSCAN_SPEC.md`
- `docs/algorithms/GPS_CYCLING_EKF_DBSCAN_IMPLEMENTATION_PLAN.md`
- `docs/algorithms/GPS_CYCLING_STAGE_A_REPORT.md`
- `docs/algorithms/GPS_ACCURACY_RECORDING_PROTOCOL.md`

Master plan là nguồn quy trình chuẩn. Các tài liệu còn lại là context/lịch sử và
không được phép tự động ghi đè gate trong master plan.

## 3. Live production boundary

Các file sau được coi là boundary và không sửa trong Phase 0–8:

- `lib/features/workout/domain/services/gps_smoothing_service.dart`
- `lib/features/workout/domain/services/gps_pipeline.dart`
- providers/coordinator của workout recording
- Isar/sqflite schema và backend payload

Baseline live hiện vẫn là validation + fixed-alpha/turn-boost trong
`GpsSmoothingService`. Khối EKF trong smoothing service vẫn bị comment. Việc
`GpsPipeline` giữ một instance EKF không có nghĩa EKF đang tạo output live.

Chỉ Phase 12, sau khi final gate `PASS` và có phê duyệt riêng, mới được sửa live
boundary bằng feature flag mặc định `false`.

## 4. Những thay đổi ngoài phạm vi phải giữ nguyên

Worktree hiện có các nhóm thay đổi không thuộc Phase 0–8 và không được stage hay
sửa cùng candidate:

- `.vscode/settings.json`.
- Các file bị xóa trong `docs/debug/`, `docs/stitch_aetron_fitness_redesign/`
  và `docs/ui/`.
- Raw tracking/local DB/recovery journal và các test tương ứng.
- Workout providers, record providers và recording coordinator.
- `web/index.html`.
- `package.json`, `package-lock.json`, `node_modules/`.
- `docs/benchmarks/`, `docs/operations/`, `docs/report/`.

Nếu một phase sau thật sự cần chạm một file trong nhóm này, phải bổ sung scope
trước khi code và chờ duyệt; không mặc nhiên mở rộng phạm vi.

## 5. Checksum của prototype tại Phase 0

Checksum dùng SHA-256 để phát hiện thay đổi ngoài phase, không phải chữ ký bảo mật.

| File | SHA-256 |
|---|---|
| `extended_kalman_filter.dart` | `b3799858e1c2cb8404c3b7a20aeabec1008143a71b857040963640abc5449d6c` |
| `extended_kalman_filter_test.dart` | `1aa1f5a90c98718af7ae4dac6a591f611eca71e2df446e4527bce3d47c97ffb7` |
| `field_gps_benchmark_runner.dart` | `96a5b30937868ac8dadefc083c08ce1fe4859c2b129d46c80d9fb28162582da0` |
| `field_gps_trace.dart` | `81aa37f08635043aa13cdd05bc11cbd41370d6c6eeba324313fa6fad1eba8989` |
| `gps_benchmark_cli.dart` | `9c401e25ccff5ff1b078422f6bbc52ac225853725fce663555aa318fad55fd9c` |
| `synthetic_gps_benchmark_runner.dart` | `84a068a383d4709d34edc5f2ef6490e6ee909b6b2a342fe6833d668a47e4200a` |
| `synthetic_gps_trace_factory.dart` | `80dc3b82a75ef0be0b68109c61b1a10fe79575faaca17271ad5c0d6e38ddc8a2` |
| `gps_benchmark.dart` | `a3b456f716c94e8d7ac16c65947bf5ba7607b0c7345166a7d138f5d0cefa1dac` |
| `gps_ekf_parameter_search.dart` | `29c51404acd7b1a23e3ebe90572eccfb7d1811e23139c2cf09697c436e7c0a18` |
| `gps_synthetic_benchmark.dart` | `f682aabe15f4c7e879286f54a22ef266a9e92d086c01ff358ce23f18447ac5fb` |

Checksum sẽ được cập nhật trong review package của phase có quyền sửa file đó.

## 6. Baseline và candidate contract

### Baseline/control

`current = cycling validation hiện tại → fixed-alpha smoothing + turn boost`

Baseline runner phải chứng minh tương đương live policy bằng regression test.
Nếu phát hiện runner khác live, Phase 1 phải sửa runner trước khi so sánh EKF.

### Candidate

```text
cycling validation giống baseline
  → Adaptive Robust EKF
  → conditional T-DBSCAN dwell post-process
```

- Validation input phải giống nhau giữa baseline và candidate.
- EKF không được nhận một tập point thuận lợi hơn baseline.
- DBSCAN không được chạy trước EKF.
- `DBSCAN-only` chỉ là ablation/comparison, không phải kiến trúc đề xuất.

## 7. Metric contract đã khóa

### 7.1 Positional error — chỉ khi có ground-truth

Với output tại timestamp `i` và ground-truth cùng timestamp:

```text
e_i = geodesic_distance(output_i, truth_i), đơn vị mét
RMSE = sqrt(mean(e_i²))
P50/P95 = percentile tuyến tính tại vị trí (n - 1) × p
```

- Timestamp phải match chính xác sau khi normalize UTC.
- Không nội suy truth âm thầm.
- Missing output ảnh hưởng availability; không được tự động bỏ khỏi mẫu số rồi
  tuyên bố positional error đẹp hơn.

### 7.2 Distance error

Distance chỉ cộng trong cùng continuous segment, không nối qua `startsNewSegment`.

```text
signed_distance_error_m = estimated_distance_m - truth_distance_m
absolute_distance_error_m = abs(signed_distance_error_m)
absolute_distance_error_percent = absolute_distance_error_m / truth_distance_m × 100
```

Final gate dùng **absolute** distance error. Signed error vẫn được báo cáo để biết
over-count hay under-count nhưng không dùng để lách gate.

### 7.3 Availability

```text
expected_count = span_seconds_floor + 1       // contract 1 Hz hiện tại
availability_percent = output_count / expected_count × 100
```

- Báo riêng raw sampling availability, accepted availability và display count.
- So sánh candidate với baseline trên cùng trace và cùng validation.
- Final gate: candidate không thấp hơn baseline quá 2 điểm phần trăm.

Nếu recording cadence khác 1 Hz, protocol phải khai báo cadence trước khi record
và expected count phải được cập nhật trong một schema version mới, không sửa âm thầm.

### 7.4 Bias

- East bias dương khi estimate nằm phía Đông truth, âm khi phía Tây.
- North bias dương khi estimate nằm phía Bắc truth, âm khi phía Nam.
- Báo mean theo mét; bias không thay thế RMSE/P95.

### 7.5 Phase segmentation

Thứ tự ưu tiên nhãn cho một timestamp:

```text
outlier → dwell → gapRecovery → turn → straight
```

- `outlier`: do generator đánh dấu, không suy ngược từ output của filter.
- `dwell`: ground-truth speed `<= 0.8 m/s` trong development synthetic hiện tại.
- `gapRecovery`: từ first fix sau gap `> 5 s` đến hết 5 giây tiếp theo.
- `turn`: absolute wrapped heading delta `>= 12°` nếu không thuộc nhãn trên.
- `straight`: phần còn lại.

Phase 1 phải kiểm tra lại threshold bằng scenario contract; thay đổi threshold
cần review vì nó làm thay đổi metric phân nhóm.

### 7.6 NIS/innovation diagnostics

- Position innovation: Euclidean norm trong local tangent plane, mét.
- Position NIS: `yᵀ S⁻¹ y`, dimensionless, 2 degree-of-freedom.
- Decision counts: `normal`, `downWeighted`, `rejected`.
- Heading innovation: wrapped radians trong `[-π, π)`.
- Heading covariance/noise: radian².
- Speed innovation: m/s; speed covariance/noise: `(m/s)²`.

Prototype thresholds `5.991` và `13.816` chưa được coi là final config; Phase 3
phải giải thích và test chúng trước khi duyệt.

### 7.7 Turn và gap guardrail

- Báo RMSE/P95 riêng từng phase.
- Final guardrail: phase P95 không xấu hơn baseline quá 5%.
- Phase 4 bổ sung cross-track/shortcut error; công thức phải được khóa trước khi
  dùng để chọn 4-state hay CTRV.
- Gap distance không được nối qua segment, kể cả khi hình vẽ UI nối được.

### 7.8 Dwell/DBSCAN

- `stationary_drift_m`: tổng quãng đường giả trong dwell ground-truth.
- `phantom_drift_removed_m`: drift trước collapse trừ drift sau collapse.
- `false_dwell_count`: cluster được phát hiện trong moving-only ground-truth.
- `collapsed_point_count`: input point count trừ output point count.

DBSCAN không được cộng điểm vào positional RMSE khi đang di chuyển và không được
dùng để che EKF turn error.

### 7.9 Latency

- Đơn vị: microseconds/accepted point.
- Đo whole-trace ít nhất 5 lần sau một warm-up; báo median và P95 giữa các lần.
- Gate core EKF: dưới 1.000 microseconds/point trên máy test được ghi trong report.
- Debug/report serialization không tính vào core filter latency nhưng phải báo
  riêng nếu chạy trong CLI.

Runner hiện mới đo một lần bằng `Stopwatch`; Phase 1 phải nâng measurement protocol
trước khi dùng latency làm bằng chứng.

## 8. Evidence labels

Mọi report phải có đúng một nhãn:

- `synthetic_development`
- `field_development_no_ground_truth`
- `synthetic_final_holdout`
- `field_final_holdout`

Không được dùng `accuracy`, `RMSE` hoặc `P95 position error` cho field report
không có ground-truth. Report phải chứa schema version, algorithm version,
config hash, dataset ID và generated timestamp.

## 9. Final gates đã khóa

| Gate | Điều kiện |
|---|---|
| P95 | Giảm ít nhất 15% |
| RMSE | Giảm ít nhất 10% |
| Absolute distance error | Không tăng |
| Availability | Không giảm quá 2 điểm phần trăm |
| Per-phase P95 | Không phase nào xấu hơn quá 5% |
| Stability | Không NaN/Inf/covariance âm/crash |
| EKF latency | `< 1 ms/point` theo protocol Mục 7.9 |

Tất cả gate là đồng thời. Không dùng weighted score để bù một gate thất bại.

## 10. Phase 0 acceptance checklist

- [x] Nhánh, `HEAD`, `main` và merge-base đã được ghi lại.
- [x] Candidate scope và live boundary đã được tách rõ.
- [x] Dirty worktree ngoài phạm vi đã được ghi nhận và không bị sửa.
- [x] Prototype có checksum để audit thay đổi.
- [x] Công thức metric, đơn vị và final gates đã được khóa.
- [x] Raw/field evidence không bị gọi nhầm là ground-truth accuracy.
- [x] `git diff --check` cho hai tài liệu phase-gate không có lỗi whitespace.
- [x] `flutter analyze`: không có issue.
- [x] `flutter test`: 355 test pass, 1 test skip.
- [ ] Người dùng duyệt Phase 0.

Sau khi duyệt, Phase 1 được phép sửa **benchmark/diagnostics mà thôi** để chứng minh
baseline equivalence và xuất error forensics. Phase 1 chưa được tune hoặc sửa
EKF core.
