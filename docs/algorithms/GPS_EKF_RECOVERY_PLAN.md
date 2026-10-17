# Kế hoạch phục hồi EKF — phải vượt baseline trước khi bật live

## 1. Mục tiêu và nguyên tắc trung thực

Mục tiêu kỹ thuật là tạo một **Adaptive Robust EKF** cho `cycling` có kết quả
tốt hơn pipeline hiện tại. Đây là giả thuyết cần chứng minh, không phải kết quả
được điền trước.

Điều kiện để được gọi là “nâng cấp” trên final holdout có ground-truth:

- P95 horizontal error giảm ít nhất 15% so với pipeline hiện tại.
- RMSE horizontal error giảm ít nhất 10%.
- Absolute distance error không tăng.
- Operational availability không giảm quá 2 điểm phần trăm.
- Không scenario nào (đường thẳng, rẽ gấp, gap/recovery, dwell, degraded GPS)
  tăng P95 quá 5%.

Nếu chưa đạt đủ các điều kiện trên thì thuật toán vẫn là `experimental`, không
bật cho người dùng và không báo cáo là đã cải thiện độ chính xác thực địa.

## 2. Chẩn đoán nguyên nhân EKF hiện tại thua

Code hiện tại có bốn rủi ro cần kiểm chứng trước khi tune:

1. Mô hình giữ `speed + heading` gần như không đổi giữa hai mẫu, nên dễ trễ và
   cắt góc khi xe rẽ.
2. `R_heading` đang được tính từ một tỷ lệ nhưng đưa thẳng vào ma trận như
   variance; cần thống nhất đơn vị radian² và bình phương standard deviation.
3. `R_speed = 1.0` cố định, trong khi log chưa có `speedAccuracy`; filter có thể
   tin speed nhiều hơn chất lượng measurement thực tế.
4. Covariance update được chú thích là Joseph form nhưng implementation hiện
   chỉ dùng `(I-KH)P`; cần Joseph form đầy đủ để giữ covariance đối xứng và
   positive semi-definite tốt hơn.

Đây là giả thuyết chẩn đoán. Task đầu tiên phải xuất evidence theo timestamp để
xác nhận P95 xấu nằm ở góc cua, recovery sau gap hay measurement outlier.

## 3. Kiến trúc đề xuất

Pipeline candidate:

```text
raw GPS
  → validation hiện tại
  → signal-quality classification
  → adaptive robust EKF
      ├─ adaptive Q khi rẽ/gia tốc
      ├─ adaptive R từ reported accuracy + innovation
      ├─ NIS gate/down-weight outlier
      └─ reset + recovery warm-up sau gap
  → T-DBSCAN dwell post-process (chỉ khi đứng yên)
  → route output
```

Không chạy `DBSCAN → EKF`. Dwell collapse làm mất cadence, thay đổi `dt` và làm
mất speed/heading của các mẫu mà EKF realtime cần.

Pipeline hiện tại luôn được giữ làm control và rollback. Trong giai đoạn đầu,
candidate chỉ chạy offline/shadow; người dùng vẫn nhìn kết quả baseline.

## 4. Kế hoạch triển khai theo lát cắt

### Task 1 — Error forensics theo timestamp

**Mô tả:** mở rộng synthetic benchmark để xuất error, innovation, NIS, heading
delta, trạng thái turn/gap/recovery và rejection reason theo từng mẫu. Báo cáo
tổng hợp phải chia lỗi theo scenario thay vì chỉ một con số toàn tuyến.

**Acceptance criteria:**

- Xác định được top 5% mẫu tạo ra P95/RMSE của EKF.
- Có bảng `straight / turn / gap recovery / outlier / dwell` cho baseline và EKF.
- Detailed trace nằm ngoài Git và không chứa trong report công khai.

**Verification:** test metric segmentation; chạy lại synthetic 30 phút và 7
field journals mà không crash.

**Files dự kiến:** benchmark runner, synthetic factory, report CLI và tests.

### Task 2 — Sửa tính đúng của EKF trước khi tune

**Mô tả:** sửa measurement covariance theo đúng đơn vị; dùng Joseph covariance
update; ép đối xứng/giới hạn variance; không dùng heading khi speed thấp hoặc
heading không đáng tin; biến speed update thành optional thay vì luôn tin với
noise cố định.

**Acceptance criteria:**

- Covariance luôn finite, đối xứng và đường chéo không âm qua trace dài.
- Heading wrap `359° → 1°`, speed âm/null và `dt` bất thường đều có test.
- Không regression latency: dưới 1 ms/point trên máy test hiện tại.

**Verification:** TDD trong `extended_kalman_filter_test.dart`; benchmark cũ
phải chạy lại được trước khi sang Task 3.

**Files dự kiến:** EKF core, matrix helper, EKF tests.

### Checkpoint 1 — Correctness gate

- `flutter analyze` và tests xanh.
- Không tune tham số nếu covariance/math chưa qua gate.
- App live chưa thay đổi.

### Task 3 — NIS innovation gate và adaptive measurement noise

**Mô tả:** tính position innovation và innovation covariance; dùng NIS để phân
loại normal/suspicious/outlier. Measurement suspicious được tăng `R`; outlier
rất mạnh bị bỏ update position nhưng filter vẫn predict. `R` phải có min/max
để không collapse hoặc tăng vô hạn.

**Acceptance criteria:**

- Outlier 55 m không kéo estimate ra khỏi hành lang giới hạn đã test.
- Measurement tốt sau outlier kéo filter phục hồi trong số mẫu đã quy định.
- Report có tỷ lệ normal/down-weighted/skipped và NIS P50/P95.

**Verification:** test đỏ cho single spike, burst multipath và bias kéo dài;
chạy benchmark synthetic sau mỗi thay đổi.

**Files dự kiến:** EKF core, estimate diagnostics model, tests, benchmark report.

### Task 4 — Turn-aware process model

**Mô tả:** giữ state 4 chiều ở lần thử đầu nhưng làm `Q_heading` và `Q_speed`
thích nghi theo course delta/gia tốc quan sát được. Khi phát hiện rẽ hợp lệ,
tăng process noise hướng để filter quay nhanh; khi đi thẳng, giảm noise để làm
mượt. Nếu 4-state vẫn cắt góc, checkpoint mới cho phép nâng lên CTRV 5-state có
`yawRate`; không làm cả hai ngay từ đầu.

**Acceptance criteria:**

- P95 trong đoạn rẽ không cao hơn baseline quá 5% trên development scenarios.
- Không tạo shortcut/cắt góc vượt ngưỡng cross-track đã khóa.
- Straight-line jitter giảm mà turn retention không giảm.

**Verification:** synthetic 30°, 60°, 90°, hairpin; test tốc độ 10–30 km/h và
sampling 0,5–2 Hz.

**Files dự kiến:** EKF core/config, synthetic scenarios, tests.

### Task 5 — Gap/recovery state machine

**Mô tả:** reset sau gap dài như hiện tại, đồng thời thêm recovery warm-up 2–3
measurement: seed position trước, chỉ bật speed/heading update khi hai mẫu liên
tiếp hợp lý. Không nối quãng đường qua gap.

**Acceptance criteria:**

- Không xuất đường nối giả qua gap.
- P95 của 5 giây đầu sau recovery không cao hơn baseline quá 5%.
- Gap 3 s, 6 s, 15 s và recovery với first-fix xấu đều có test.

**Verification:** unit + replay test, không cần app/device.

**Files dự kiến:** benchmark EKF adapter/state, tests; tránh đưa policy recovery
vào matrix core nếu không cần.

### Checkpoint 2 — Candidate gate

Candidate chỉ đi tiếp nếu trên development synthetic:

- RMSE và P95 toàn tuyến đều tốt hơn baseline.
- Không scenario nào vi phạm regression guardrail.
- Kết quả không phụ thuộc một seed/noise pattern duy nhất.

Nếu không đạt, quay lại Task 3/4 tối đa ba vòng có ghi log thay đổi. Không chỉnh
tham số vô hạn cho tới khi một dataset cho ra con số đẹp.

### Task 6 — Deterministic parameter search trên development set

**Mô tả:** định nghĩa không gian nhỏ cho `Q_pos`, `Q_speed`, `Q_heading`, giới
hạn adaptive `R` và NIS thresholds. Chạy grid/random search có seed cố định.
Final score ưu tiên P95, sau đó RMSE, distance error và turn retention; mọi cấu
hình vi phạm availability/regression constraint bị loại.

**Acceptance criteria:**

- Lưu config, objective và toàn bộ candidate scores để tái tạo.
- Chọn đúng một config trước khi mở final holdout.
- Không dùng 7 field logs không ground-truth để tuyên bố positional accuracy.

**Verification:** chạy cùng input hai lần cho cùng config và cùng kết quả metric.

**Files dự kiến:** benchmark tuning tool/config model/tests; output ngoài Git.

### Task 7 — DBSCAN là KPI riêng cho dwell

**Mô tả:** chạy DBSCAN sau EKF chỉ cho đoạn có speed thấp đủ lâu. Chấm bằng
stationary drift removed, false dwell trên đoạn chuyển động và điểm collapse;
không cộng “điểm thưởng” DBSCAN vào accuracy khi xe đang chạy.

**Acceptance criteria:**

- Dwell drift giảm, không collapse góc cua/chạy chậm hợp lệ.
- False dwell bằng 0 trên moving-only synthetic scenarios.
- Nếu field data không có dwell, output phải giữ nguyên.

**Verification:** stationary/red-light/slow-turn tests.

**Files dự kiến:** DBSCAN adapter/config và tests.

### Checkpoint 3 — Freeze trước final test

- Freeze code, config, metric và acceptance thresholds.
- Tạo hash/version cho candidate và baseline.
- Không sửa tham số sau khi xem final holdout; nếu sửa thì holdout cũ trở thành
  development và phải thu final set mới.

### Task 8 — Final holdout thực tế

**Mô tả:** thu dữ liệu mới chưa từng dùng để tune. Lý tưởng là RTK ground-truth.
Nếu chưa có RTK, dùng tuyến tham chiếu độc lập để đánh giá distance error và
cross-track proxy, nhưng không gọi đó là absolute positional RMSE.

**Bộ test tối thiểu:**

- 3 tuyến × 3 lần lặp, gồm open sky, cây che và đô thị.
- Có đường thẳng, nhiều góc cua, ít nhất một lần dừng đèn đỏ và một đoạn GPS
  degraded/recovery.
- Cùng cách gắn iPhone; ghi rõ device/iOS/thời gian/thời tiết.

**Acceptance criteria:** áp dụng nguyên văn các điều kiện “nâng cấp” ở Mục 1,
kèm bootstrap confidence interval cho chênh lệch P95/RMSE khi đủ mẫu.

**Verification:** report baseline và candidate chạy trên đúng cùng timestamp.

### Task 9 — Shadow integration và rollout

**Mô tả:** tích hợp candidate sau feature flag. Shadow mode tính cả baseline và
candidate nhưng UI/database chính vẫn dùng baseline; chỉ log metric chẩn đoán
không chứa route. Sau soak test mới cho phép flag nội bộ dùng candidate.

**Acceptance criteria:**

- Flag off cho output hiện tại không đổi.
- Có rollback tức thời về baseline.
- Raw GPS luôn được giữ để audit.

**Verification:** integration tests, `flutter analyze`, toàn bộ `flutter test`,
manual ride nội bộ.

## 5. Thứ tự sửa cụ thể

```text
Error forensics
  → covariance/unit correctness
  → NIS + adaptive R
  → turn-aware Q
  → gap recovery
  → parameter search
  → DBSCAN dwell validation
  → freeze
  → final holdout
  → shadow integration
```

Không nên bắt đầu bằng việc nối EKF vào `GpsSmoothingService`. Làm vậy sẽ đưa
một candidate đang thua baseline vào app trước khi biết lỗi nằm ở đâu.

## 6. Cách trình bày với giảng viên

Phát biểu bảo vệ được:

> Đề tài đề xuất một pipeline Adaptive Robust EKF kết hợp T-DBSCAN. Bản EKF
> ban đầu là baseline nghiên cứu và bộc lộ lỗi long-tail tại góc cua/recovery.
> Vì vậy nhóm bổ sung innovation gating, adaptive covariance và turn-aware
> process noise, sau đó khóa tham số và đánh giá trên holdout độc lập.

Chỉ sau Task 8, nếu đạt gate, mới thay câu cuối bằng kết quả phần trăm thực tế.
Nếu chưa đạt, phải báo cáo đây là kết quả âm và giữ pipeline production cũ;
không đổi nhãn dữ liệu mô phỏng thành dữ liệu thực.

## 7. Dự kiến phạm vi

- Tasks 1–2: chẩn đoán và correctness foundation.
- Tasks 3–5: candidate algorithm.
- Tasks 6–7: tuning và DBSCAN validation.
- Task 8: phụ thuộc việc thu final dataset.
- Task 9: chỉ thực hiện sau khi final gate đạt.

Mỗi task là một lát cắt TDD riêng và phải để repository ở trạng thái xanh.

## 8. Cơ sở nghiên cứu cho hướng sửa

- Innovation adaptive filtering dùng chi-squared test để nhận biết measurement
  bất thường và điều chỉnh measurement covariance thay vì luôn tin `R` cố định:
  [Wang et al., 2022](https://doi.org/10.3390/su141811230).
- Innovation-based adaptive estimation được dùng vì process/measurement noise
  thực tế thay đổi theo môi trường và prior sai có thể làm filter giảm chất
  lượng hoặc divergence:
  [Kim et al., 2019](https://doi.org/10.3390/s19051142).
- Robust adaptive EKF cho GNSS/INS cũng tập trung vào việc sửa measurement-noise
  covariance khi có disturbance bất thường:
  [Wang et al., 2023](https://doi.org/10.3390/rs15174125).

Các bài trên cung cấp cơ sở cho adaptive covariance/innovation gating, nhưng
không được dùng để suy ra rằng app điện thoại này chắc chắn đạt cùng mức cải
thiện; kết quả của Aetron vẫn phải đến từ final holdout riêng.
