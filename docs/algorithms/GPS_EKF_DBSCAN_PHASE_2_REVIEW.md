# Phase 2 review — correctness foundation của EKF

**Trạng thái:** chờ duyệt Phase 2  
**Evidence:** development only  
**Algorithm label:** `phase2-correctness-candidate`  
**Config fingerprint:** `fnv1a32-12b93cef`

## 1. Kết quả

Phase 2 đã hoàn tất phần sửa tính đúng toán học và numerical safety của EKF.
Không tune tham số, không đổi ngưỡng NIS, không sửa DBSCAN và chưa nối candidate
vào live pipeline.

Các lỗi được sửa:

- Heading tại lần seed đầu tiên từng được dùng dù speed chỉ là `0,1 m/s` hoặc
  heading nằm ngoài `[0, 360)`. Test đỏ đã tái hiện lỗi; hiện heading chỉ được
  seed khi speed hợp lệ và lớn hơn `0,6 m/s`.
- Speed `null` tại reseed từng bị đổi thành speed đo được bằng `0 m/s`, làm
  acceleration adaptation ở fix kế tiếp dùng một measurement không tồn tại.
  Hiện `null` và số `0` được giữ đúng nghĩa, kể cả trong diagnostics first-fix.
- Cấu hình noise trước đây chỉ dùng `assert`, nên có thể mất validation ở build
  release. Tất cả noise density, scale và threshold nay được kiểm tra runtime.
- Covariance stabilization trước đây âm thầm đổi NaN thành `0` hoặc `1e12`.
  Hiện non-finite covariance ném `StateError`; symmetrize/clamp hợp lệ được ghi
  bằng `covarianceCorrectionApplied`.
- Tọa độ NaN, infinity hoặc ngoài miền WGS84 bị từ chối trước khi filter được
  initialize hoặc mutate.
- `dt` NaN/âm/0 được fallback về 1 giây; `dt` ngoài `[0,05; 5]` được clamp và
  cả effective value lẫn cờ sanitize được ghi trong diagnostics.

## 2. Audit đơn vị Q/R

| Đại lượng | Cách tính | Đơn vị đầu ra |
|---|---|---|
| `Q_position` | `processPosStd² × dt` | m² |
| `Q_speed` | `processSpeedStd² × dt × scale` | (m/s)² |
| `Q_heading` | `processHeadingStd² × dt × scale` | rad² |
| `R_position` | effective accuracy² | m² |
| `R_speed` | `(sqrt(2) × accuracy / dt)²`, có clamp std | (m/s)² |
| `R_heading` | `atan2(sqrt(2) × accuracy, distance)²`, có clamp std | rad² |

Ba tham số process được mô tả đúng là continuous-time random-walk noise density:
`m/sqrt(s)`, `(m/s)/sqrt(s)` và `rad/sqrt(s)`. Diagnostics nay xuất cả ba phần
tử variance của Q để test và artifact có thể kiểm toán đơn vị.

## 3. Covariance update

Cả position update 2 chiều và scalar update speed/heading đều dùng Joseph form:

```text
P = (I - KH) P (I - KH)^T + K R K^T
```

Sau predict và mỗi measurement update, covariance được:

1. kiểm tra mọi phần tử finite;
2. symmetrize theo `(P + P^T) / 2`;
3. clamp diagonal vào `[1e-9, 1e12]`;
4. ghi diagnostics nếu correction vượt tolerance hoặc có clamp.

Stress test 2.000 update xác nhận mọi phần tử finite, ma trận đối xứng trong
`1e-9`, diagonal không âm và không cần covariance correction trên trace hợp lệ.

## 4. Validation và edge case

Đã có test cho:

- wrap heading `359° → 1°`;
- speed âm/null;
- heading NaN/ngoài miền;
- không dùng heading ở low speed;
- tọa độ NaN/infinity/ngoài miền;
- `dt` NaN và policy sanitize;
- runtime config validation;
- variance của Q, `R_speed` và `R_heading`;
- Joseph covariance qua 2.000 update;
- latency theo point.

Position accuracy không hợp lệ tiếp tục dùng fallback std 5 m theo policy cũ.
Đây là fallback bắt buộc vì position là measurement chính, không phải optional
measurement. Speed và heading không hợp lệ thì hoàn toàn không đi vào update.

## 5. Development benchmark trước/sau

Không có thay đổi tuning. Correctness fix phân biệt speed `null` với speed `0`
làm thay đổi nhỏ kết quả quanh gap/reseed; số âm là cải thiện, số dương là xấu
hơn so với Phase 1:

| Scenario / metric EKF | Phase 1 | Phase 2 | Delta |
|---|---:|---:|---:|
| Urban RMSE | 3,172050 m | 3,193923 m | +0,690% |
| Urban P95 | 4,714203 m | 4,714203 m | ~0,000% |
| Urban absolute distance error | 7,363730% | 7,347796% | -0,016 điểm % |
| Urban availability | 59,411438% | 59,411438% | 0 điểm % |
| Turn RMSE | 3,828154 m | 3,817356 m | -0,282% |
| Gap-recovery RMSE | 3,488110 m | 3,501310 m | +0,378% |
| Stationary RMSE | 1,368856 m | 1,368856 m | 0% |
| Stationary P95 | 2,360671 m | 2,360671 m | 0% |

Không che giấu regression: aggregate RMSE tăng 0,690% và gap-recovery RMSE tăng
0,378%. Cả hai đến từ correctness fix có test, không phải tuning. P95,
availability và stationary không đổi đáng kể; distance error và turn RMSE tốt
hơn nhẹ. Các biến động này chưa phải final claim và vẫn trong guardrail 5%.

Replay field development:

- 7/7 journal hoàn tất, không crash.
- 8.135 accepted point; 10.730 trace row.
- 0 covariance correction trên dữ liệu field hợp lệ.
- 0 `dt` sanitize trong accepted update (gap được runner reset/reseed).
- EKF latency P95 lớn nhất: `5,729 µs/point`, thấp hơn budget `1.000 µs/point`.
- Display-distance delta so với current baseline nằm trong khoảng `-2,786%`
  đến `+0,033%`; không diễn giải đây là positional accuracy.

Artifacts ngoài Git:

- `/tmp/aetron-phase2-synthetic.json`
- `/tmp/aetron-phase2-synthetic.json.trace.jsonl`
- `/tmp/aetron-phase2-raw-gps-<workout-id>.json`
- `/tmp/aetron-phase2-raw-gps-<workout-id>.json.trace.jsonl`

## 6. File thay đổi trong Phase 2

- `lib/features/workout/domain/services/ekf/extended_kalman_filter.dart`
- `test/extended_kalman_filter_test.dart`
- `lib/features/workout/domain/services/benchmark/gps_benchmark_cli.dart`
- `test/gps_benchmark_cli_test.dart`
- `tool/gps_synthetic_benchmark.dart`
- Tài liệu review này; đồng thời ghi nhận Phase 1 đã được duyệt.

`main` vẫn ở commit `52b774a877fb0898836e82a51ec6a774a5af9246` và live pipeline
không được chuyển sang candidate. SHA-256 EKF core đổi từ Phase 1
`b3799858e1c2cb8404c3b7a20aeabec1008143a71b857040963640abc5449d6c`
sang Phase 2
`ee5304aeb446ea6174ef5c102df3f2d6486d66329626012e67e33eae68345cc9`.

## 7. Verification

- Targeted EKF + matrix: 25/25 pass.
- Full `flutter analyze`: 0 issue.
- Full `flutter test`: 362 pass, 1 skip.
- `git diff --check`: pass.
- Synthetic replay: pass; correctness deltas được công bố ở mục 5.
- 7 field journal replay: pass.

## 8. Review năm trục

- **Correctness:** không còn finding mở trong phạm vi Phase 2; test bao phủ
  unit, invalid input, angle wrap, Joseph covariance, stress và replay.
- **Readability:** đơn vị Q/R được ghi ngay tại field và report; diagnostics có
  tên kèm đơn vị.
- **Architecture:** thay đổi nằm trong offline candidate/benchmark; live path và
  rollback baseline chưa bị đổi.
- **Security/privacy:** field trace tiếp tục không xuất tọa độ; artifact raw nằm
  ngoài Git.
- **Performance:** không thêm allocation theo điểm ngoài diagnostics đã có;
  latency field còn cách budget khoảng 175 lần.

Không có 🔴 Critical hoặc 🟡 Important finding còn mở. NIS thresholds, adaptive
R behavior và outlier recovery vẫn là phạm vi Phase 3, không được coi là đã duyệt
chỉ vì prototype code hiện hữu.

Self-review từng phát hiện diagnostics first-fix báo sai việc dùng speed/heading.
Regression test mở rộng sau đó phát hiện thêm việc speed `null` bị đồng nhất với
`0`. Cả hai đã được sửa và full suite được chạy lại đến khi xanh.

## 9. Phase 2 acceptance checklist

- [x] Q/R có contract đơn vị rõ và được test.
- [x] `R_heading` là variance rad².
- [x] Speed/heading optional và validation thống nhất cả initialization/update.
- [x] Joseph form đầy đủ cho position, speed và heading.
- [x] Covariance finite/đối xứng/diagonal không âm qua 2.000 update.
- [x] Covariance correction có diagnostics; NaN không bị che giấu.
- [x] Heading wrap và invalid measurement có regression test.
- [x] Latency dưới 1 ms/point.
- [x] Analyze, full test, synthetic và 7 field replay đều pass.
- [ ] Người dùng duyệt Phase 2.

## 10. Đề nghị quyết định

Đề nghị **Duyệt Phase 2** và chuyển sang Phase 3 — NIS gating và adaptive
measurement covariance. Nếu chưa duyệt, chỉ sửa trong phạm vi Phase 2; không mở
Phase 3.
