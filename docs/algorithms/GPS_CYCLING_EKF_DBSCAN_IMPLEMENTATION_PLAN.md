# Kế hoạch triển khai: EKF/DBSCAN cho đạp xe

## Tổng quan

Triển khai theo hai chặng. Chặng A xây offline replay và kiểm chứng thuật toán mà không thay đổi app live. Chặng B chỉ tích hợp sau khi report Chặng A được review. Đây là risk-first slicing vì repository đã có lõi EKF/T-DBSCAN nhưng chưa có bằng chứng trên raw field logs.

## Quyết định kiến trúc

- Raw JSONL được parse thành model benchmark riêng, không phụ thuộc database hay UI.
- Mỗi pipeline variant tuân theo cùng contract input/output để so sánh công bằng.
- Validation/outlier gate chạy trước bộ lọc trạng thái; T-DBSCAN là post-processing cần cửa sổ thời gian.
- Feature flag cho live integration mặc định `false`.
- Không nhúng dataset vị trí thật vào test fixtures.

## Chặng A — Offline benchmark

### Task 1: Model và parser raw JSONL

**Acceptance:**

- Parse đủ timestamp, latitude, longitude, accuracy, speed, heading và metadata cần thiết.
- Sort ổn định, phát hiện duplicate và báo lỗi input không hợp lệ.
- Không cần database/network.

**Verify:** test parser fixture nhỏ, bao gồm duplicate và invalid numeric values.

**Files dự kiến:** model/parser trong `benchmark/`, một test và fixture làm mờ.

### Task 2: Contract runner và baseline hiện tại

**Acceptance:**

- Variant `current` replay đúng validation + fixed-alpha đang chạy trong app.
- Report point count, distance, gaps, rejection reasons và timing.
- Kết quả deterministic.

**Verify:** regression test với synthetic trace và fixture parser.

**Dependencies:** Task 1.

### Task 3: Variant EKF

**Acceptance:**

- Viết test đỏ cho gap/reset, heading invalid, measurement noise cao và rẽ gấp.
- Sửa lõi EKF tối thiểu để các test qua; không bật live.
- Runner xuất variant EKF và synthetic ground-truth metrics.

**Verify:** `flutter test test/extended_kalman_filter_test.dart` và benchmark tests.

**Dependencies:** Task 2.

### Task 4: Variant T-DBSCAN và EKF → T-DBSCAN

**Acceptance:**

- T-DBSCAN collapse dwell, giữ nguyên đoạn chuyển động bình thường.
- Có variant DBSCAN-only và EKF→DBSCAN.
- Không có DBSCAN→EKF vì dwell collapse phá nhịp mẫu cần cho EKF realtime.
- Report cluster count, collapsed points và phantom drift.

**Verify:** unit test dwell/outlier/gap và synthetic cycling comparison.

**Dependencies:** Tasks 2–3.

### Checkpoint A1

- Relevant tests xanh.
- Bốn variant chạy được trên synthetic trace.
- Pipeline app live chưa thay đổi.

### Task 5: CLI local-only và export report

**Acceptance:**

- CLI nhận input/output tuyệt đối và trả exit code khác 0 khi input lỗi.
- JSON report tự mô tả dataset type (`synthetic` hoặc `field_no_ground_truth`).
- Không in toàn bộ tọa độ vào console/report summary.

**Verify:** CLI test với fixture tạm và kiểm tra exit/output.

**Dependencies:** Tasks 1–4.

### Task 6: Chạy bảy workout development

**Acceptance:**

- Sinh report riêng từng workout và aggregate.
- Ghi rõ field data không có ground-truth.
- Ghi nhận bất thường của hai workout mới, đặc biệt duplicate/gap/accuracy cực đại.

**Verify:** kiểm tra count input trong report khớp JSONL và không có tọa độ trong Git.

**Dependencies:** Task 5.

### Checkpoint A2 — Review kết quả

- `flutter analyze` xanh.
- `flutter test` xanh.
- Có bảng so sánh bốn variant.
- Chọn pipeline và tham số dựa trên synthetic + field diagnostics.
- Người phát triển duyệt trước khi bật live.

## Chặng B — Tích hợp có kiểm soát

### Task 7: Feature flag EKF cho cycling

**Acceptance:**

- Flag tắt: output/behavior hiện tại không đổi.
- Flag bật: cycling dùng EKF đã chọn; walking/running không đổi.
- Reset đúng khi bắt đầu/kết thúc workout và sau gap theo đặc tả.

**Verify:** provider/pipeline tests và manual replay.

**Dependencies:** Checkpoint A2 được duyệt.

### Task 8: Post-process T-DBSCAN đã chọn

**Acceptance:**

- Chỉ tích hợp nếu report chứng minh có ích cho dwell drift.
- Không giảm availability quá 2% và không cắt mất các góc cua thực.
- Raw GPS luôn được giữ nguyên để audit/rollback.

**Verify:** integration tests trên workout finalize và comparison report.

**Dependencies:** Task 7 và quyết định tại A2.

### Checkpoint hoàn tất

- Full analyze/test xanh.
- Pipeline có rollback bằng feature flag.
- Record final test set mới sau khi khóa tham số.
- Chỉ final test set có ground-truth mới được dùng để kết luận độ chính xác thực địa.

## Rủi ro và giảm thiểu

| Rủi ro | Mức | Giảm thiểu |
|---|---:|---|
| Tune theo cùng dataset rồi báo kết quả | Cao | Tách development và final test set mới |
| DBSCAN bị hiểu là bộ lọc mọi outlier | Cao | Giới hạn contract vào dwell; validation gate xử lý spike |
| EKF cắt góc khi xe rẽ | Cao | Synthetic turn test + turn-retention metric |
| Gap dài làm prediction trôi | Cao | Test reset/reseed và giới hạn `dt` rõ ràng |
| Raw GPS cá nhân bị commit | Cao | Dataset chỉ ở Downloads; fixtures làm mờ |
| Dirty worktree ghi đè thay đổi hiện có | Trung bình | Chỉ sửa file đã liệt kê, xem diff trước mỗi lát cắt |

## Trạng thái khởi đầu đã xác nhận

- 4 nhóm test hiện tại: 10 test đều xanh.
- Lõi `ExtendedKalmanFilter` tồn tại nhưng đang comment khỏi `GpsSmoothingService`.
- `GpsDbscanService`/`DwellRouteSimplifier` tồn tại nhưng chưa nối vào record pipeline.
- Hai workout mới đã tải thành công và giữ ngoài repository.
