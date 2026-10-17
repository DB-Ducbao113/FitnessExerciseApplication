# Master plan phase-gate: Adaptive Robust EKF + T-DBSCAN

## 1. Mục đích của tài liệu

Tài liệu này là kế hoạch chuẩn duy nhất để nâng cấp thuật toán GPS cho `cycling`
trên nhánh `EFK+DBSCAN`. Công việc được chia thành các phase nhỏ, có artifact,
test và điều kiện duyệt rõ ràng. Không bắt đầu phase kế tiếp trước khi người phụ
trách trả lời rõ `Duyệt Phase N`.

Quy trình tổng quát:

```text
Khóa phạm vi
  → đo baseline và truy vết lỗi
  → sửa tính đúng toán học
  → robust/adaptive measurement
  → mô hình rẽ
  → recovery sau GPS gap
  → tuning có giới hạn
  → T-DBSCAN cho dwell
  → đóng gói candidate offline
  → khóa code/config/protocol
  → record dữ liệu mới
  → final holdout evaluation
  → shadow mode và rollout có kiểm soát
```

## 2. Nguyên tắc làm việc và duyệt phase

Mỗi phase phải kết thúc bằng một gói review gồm:

1. Mục tiêu và những gì thực tế đã làm.
2. Danh sách file thay đổi và diff có phạm vi.
3. Test đã chạy, kết quả và thời gian xử lý nếu liên quan.
4. Metric trước/sau trên đúng cùng tập dữ liệu.
5. Các lỗi hoặc gate chưa đạt, không che giấu kết quả âm.
6. Đề nghị một trong ba quyết định: `Duyệt`, `Sửa trong phase`, hoặc `Dừng`.

Quy tắc chuyển phase:

- Chỉ chuyển tiếp sau câu trả lời `Duyệt Phase N`.
- Nếu phase bị từ chối, chỉ sửa phạm vi phase đó rồi trình lại.
- Mỗi phase có commit/checkpoint riêng sau khi đã tách được thay đổi khỏi dirty
  worktree. Không gom file không liên quan vào commit thuật toán.
- `main` và live pipeline giữ nguyên cho tới Phase 12.
- Không dùng final holdout để tune. Nếu sửa thuật toán sau khi xem holdout, bộ
  holdout đó trở thành development data và phải thu một bộ final mới.

## 3. Phạm vi và định nghĩa thành công

### 3.1 Phạm vi ban đầu

- Chỉ áp dụng cho workout `cycling`.
- Input: GPS position, timestamp, reported horizontal accuracy, speed và heading.
- Không gọi là GNSS/INS vì chưa sử dụng accelerometer/gyroscope đồng bộ.
- Adaptive Robust EKF là causal filter.
- T-DBSCAN chỉ là post-process cho dwell/đứng yên, không lọc cua đang di chuyển.
- Pipeline hiện tại là control, fallback và rollback path.

### 3.2 Final acceptance gate

Candidate chỉ được gọi là “nâng cấp” nếu đồng thời đạt trên final holdout:

- P95 horizontal error giảm ít nhất 15% so với baseline.
- RMSE horizontal error giảm ít nhất 10%.
- Absolute distance error không tăng.
- Availability không giảm quá 2 điểm phần trăm.
- P95 của từng nhóm `straight`, `turn`, `gap recovery`, `dwell`, `degraded GPS`
  không xấu hơn baseline quá 5%.
- Không xuất hiện lỗi covariance, crash hoặc latency vượt ngân sách.

Nếu final field data không có positional ground-truth đủ tin cậy, không công bố
RMSE/P95 vị trí thực địa. Khi đó chỉ công bố distance error, cross-track proxy,
availability và diagnostics; RMSE/P95 chỉ được ghi là kết quả synthetic.

### 3.3 Thứ tự ưu tiên metric

Không cộng các metric thành một “điểm đẹp” duy nhất. Dùng thứ tự:

1. Loại candidate vi phạm safety, availability hoặc scenario regression.
2. Trong số còn lại, tối ưu P95.
3. Sau đó tối ưu RMSE.
4. Sau đó tối ưu absolute distance error.
5. Nếu vẫn hòa, chọn cấu hình đơn giản và ít nhạy tham số hơn.

## 4. Phân tách dữ liệu để chống overfit

| Tập dữ liệu | Dùng cho | Không được dùng cho |
|---|---|---|
| Unit synthetic | Chứng minh công thức, edge case | Công bố độ chính xác thực tế |
| Development synthetic | Phát triển, tuning có giới hạn | Final claim |
| 7 field journals hiện có | Diagnostics, replay, độ ổn định | Positional RMSE khi không có ground-truth |
| Pre-freeze field route | Rehearsal protocol nếu cần | Final claim |
| Final holdout mới | Đánh giá duy nhất sau freeze | Tuning hoặc sửa config |

Synthetic development phải deterministic và có nhiều seed/noise profile. Final
synthetic holdout chỉ được tạo/mở sau khi code và config đã freeze. Raw field
GPS không commit vào Git; fixture test phải được làm mờ tọa độ.

## 5. Các phase triển khai

## Phase 0 — Khóa phạm vi, trạng thái Git và protocol duyệt

**Mục tiêu:** tạo điểm xuất phát có thể audit trước khi sửa thêm thuật toán.

**Công việc:**

- Xác nhận nhánh làm việc là `EFK+DBSCAN`, `main` không đổi.
- Lập inventory chính xác file prototype thuật toán, file có sẵn của người dùng
  và thay đổi không liên quan trong dirty worktree.
- Chốt danh sách metric, đơn vị, baseline và quy tắc duyệt phase.
- Đánh dấu code Adaptive EKF hiện có là `prototype/unapproved`; không dùng kết
  quả prototype làm final claim.
- Chốt budget latency: dưới 1 ms cho một GPS point trên máy test hiện tại.

**Deliverable:** baseline manifest, danh sách file trong phạm vi, Git diff plan
và bảng metric contract.

**Acceptance:**

- Không mất hoặc ghi đè thay đổi có sẵn của người dùng.
- Có thể chỉ ra chính xác baseline commit và candidate working state.
- Mọi metric đều có định nghĩa và đơn vị không mơ hồ.

**Verification:** `git status`, `git diff --check`, review manifest thủ công.

**Điểm duyệt:** chờ `Duyệt Phase 0`.

## Phase 1 — Baseline replay và error forensics theo timestamp

**Mục tiêu:** biết EKF sai ở đâu trước khi thay đổi mô hình.

**Công việc:**

- Chuẩn hóa parser/runner để cùng một trace chạy qua baseline và candidate.
- Xuất per-timestamp: validation decision, error, innovation, NIS, heading
  delta, gap state và rejection reason.
- Phân loại phase: `straight`, `turn`, `gapRecovery`, `outlier`, `dwell`.
- Xuất top 5% timestamp gây long-tail và metric theo từng phase.
- Sửa lỗi generator/metric nếu phát hiện contract sai; không tune EKF ở phase này.

**Deliverable:** JSON summary, JSONL trace chi tiết ngoài Git và báo cáo root
cause baseline.

**Acceptance:**

- Metric deterministic khi chạy lặp lại.
- Top 5% lỗi truy ngược được về timestamp và phase.
- Synthetic ground-truth và field-no-ground-truth không bị trộn khái niệm.

**Verification:** parser/runner/metric tests; replay development synthetic và 7
field journals không crash.

**Điểm duyệt:** chờ `Duyệt Phase 1` sau khi xem báo cáo timestamp.

## Phase 2 — Correctness foundation của EKF

**Mục tiêu:** sửa toán trước khi tune.

**Công việc:**

- Kiểm tra đơn vị của mọi phần tử `Q` và `R`.
- `R_heading` phải là variance radian².
- Speed/heading measurement trở thành optional và được validate thống nhất.
- Triển khai Joseph covariance update đầy đủ.
- Symmetrize/clamp covariance với diagnostics, không âm thầm che NaN.
- Kiểm tra angle wrapping, `dt`, speed âm/null, heading ngoài miền và low-speed.

**Deliverable:** EKF core đã sửa và unit test toán học.

**Acceptance:**

- Covariance finite, đối xứng, diagonal không âm qua trace dài.
- Wrap `359° → 1°` đúng.
- Invalid measurement không đi vào update.
- Latency dưới 1 ms/point.

**Verification:** targeted EKF tests, stress test tối thiểu 2.000 update,
`flutter analyze`, `flutter test`.

**Điểm duyệt:** chờ `Duyệt Phase 2`; chưa đánh giá tuning ở phase này.

## Phase 3 — NIS gating và adaptive measurement covariance

**Mục tiêu:** giảm ảnh hưởng spike/multipath mà không bỏ measurement tốt.

**Công việc:**

- Tính innovation covariance và position NIS.
- Phân loại `normal`, `downWeighted`, `rejected` bằng ngưỡng khóa trước.
- Tăng `R` có min/max cho measurement đáng ngờ.
- Adaptive `R_speed` từ reported accuracy, `dt` và tính hợp lệ của speed.
- Ghi diagnostics: innovation, NIS, decision, effective variance.

**Deliverable:** robust measurement update và report decision distribution.

**Acceptance:**

- Spike đơn 55 m không kéo state vượt hành lang test.
- Có test burst multipath và bias kéo dài, không chỉ single spike.
- Measurement tốt sau outlier phục hồi trong số mẫu đã định trước.
- Không giảm availability quá 2 điểm phần trăm trên development set.

**Verification:** TDD cho spike/burst/bias/recovery; benchmark cùng baseline.

**Điểm duyệt:** chờ `Duyệt Phase 3`.

## Phase 4 — Mô hình chuyển động khi rẽ

**Mục tiêu:** giảm lag/cắt góc mà không làm đường thẳng rung hơn.

Phase này có hai bước tuần tự, không triển khai đồng thời:

### Phase 4A — Adaptive Q trên state 4 chiều

- Tăng `Q_heading` theo course delta đã validate.
- Tăng `Q_speed` theo acceleration hợp lý.
- Giới hạn scale để covariance không bùng nổ.

### Phase 4B — CTRV/yaw-rate chỉ khi 4A không đạt

- Nếu 4A vẫn không đạt RMSE/turn guardrail, lập decision record rồi nâng state
  thành `[east, north, speed, heading, yawRate]`.
- So sánh 4-state và CTRV bằng đúng cùng scenario; không mặc định mô hình phức
  tạp hơn là tốt hơn.

**Scenario bắt buộc:** cua 30°, 60°, 90°, hairpin; tốc độ 10–30 km/h; sampling
0,5–2 Hz; heading wrap và heading dropout.

**Acceptance:**

- Turn P95 không xấu hơn baseline quá 5%.
- Cross-track/shortcut error không vượt guardrail đã khóa ở Phase 1.
- Straight-line P95 không xấu hơn baseline quá 5%.
- Nếu dùng CTRV, lợi ích phải vượt độ phức tạp bằng metric, không bằng hình nhìn mượt.

**Verification:** scenario unit tests và development benchmark đa seed.

**Điểm duyệt:** duyệt riêng `Phase 4A`; chỉ mở `Phase 4B` nếu báo cáo 4A đề nghị.

## Phase 5 — GPS gap recovery state machine

**Mục tiêu:** recovery ổn định sau mất tín hiệu mà không tạo quãng đường giả.

**Công việc:**

- Reset/reseed sau gap dài theo policy đã khóa.
- First fix chỉ seed position; chỉ bật speed/heading sau chuỗi fix hợp lý.
- Không cộng distance xuyên qua segment gap.
- Diagnostics ghi `normal`, `gap`, `warmup`, `recovered`.

**Scenario bắt buộc:** gap 3 s, 6 s, 15 s; first fix tốt; first fix xấu;
heading sai sau gap; nhiều gap liên tiếp.

**Acceptance:**

- Không có đường nối hoặc distance giả xuyên gap.
- P95 trong 5 giây đầu recovery không xấu hơn baseline quá 5%.
- State machine deterministic và reset hoàn toàn giữa workouts.

**Verification:** unit test state machine và replay test.

**Điểm duyệt:** chờ `Duyệt Phase 5`.

## Phase 6 — Bounded parameter search trên development set

**Mục tiêu:** chọn một config tái tạo được, không tune vô hạn.

**Công việc:**

- Khóa trước search space, seed, objective và số candidate tối đa.
- Search `Q`, scale của reported accuracy, NIS thresholds và adaptive caps.
- Chạy nhiều development scenarios/seeds.
- Lưu toàn bộ candidate scores, không chỉ cấu hình thắng.
- Sensitivity check quanh cấu hình thắng để tránh điểm tối ưu mong manh.

**Giới hạn:** tối đa ba vòng search. Thay đổi search space phải được ghi lý do
trước khi chạy vòng mới.

**Acceptance:**

- Kết quả lặp lại giống nhau với cùng input/config.
- Chọn đúng một config hoặc kết luận chưa có config đạt.
- Không mở final holdout.
- Candidate phải tốt hơn baseline về RMSE và P95 trước khi đi tiếp.

**Verification:** deterministic search test và report toàn bộ candidates.

**Điểm duyệt:** chờ `Duyệt Phase 6` và khóa config development.

## Phase 7 — T-DBSCAN chỉ cho dwell

**Mục tiêu:** giảm drift khi đứng yên mà không làm mất cua/chạy chậm hợp lệ.

**Công việc:**

- Chạy sau EKF và chỉ kích hoạt khi low-speed đủ lâu.
- Đánh giá riêng stationary drift, false dwell và collapsed point count.
- Không dùng DBSCAN để xử lý spike khi đang di chuyển.
- So sánh `baseline`, `EKF`, `DBSCAN-only`, `EKF→DBSCAN`.

**Scenario bắt buộc:** đứng đèn đỏ, dừng ngắn, slow turn, leo dốc chậm,
moving-only và GPS jitter khi đứng yên.

**Acceptance:**

- Dwell drift giảm.
- False dwell bằng 0 trên moving-only scenarios.
- Không collapse slow turn hoặc góc cua hợp lệ.
- Trace không có dwell giữ nguyên output ngoài sai số số học cho phép.

**Verification:** DBSCAN unit tests và synthetic dwell report.

**Điểm duyệt:** chờ `Duyệt Phase 7`.

## Phase 8 — Candidate pipeline offline hoàn chỉnh

**Mục tiêu:** ghép các thành phần đã duyệt thành pipeline có thể replay end-to-end.

**Công việc:**

- Pipeline: validation → Adaptive Robust EKF → conditional T-DBSCAN.
- CLI chạy cùng trace qua baseline và candidate.
- Tổng hợp metric toàn tuyến, theo phase và per timestamp.
- Chạy full development synthetic và 7 field journals.
- Review năm trục: correctness, readability, architecture, security/privacy,
  performance.

**Acceptance:**

- Không crash trên toàn bộ development corpus.
- Không regression scenario guardrail.
- Raw tọa độ không lọt vào Git hoặc public report.
- `flutter analyze` và toàn bộ `flutter test` xanh.

**Điểm duyệt:** chờ `Duyệt Phase 8`. Candidate vẫn chưa nối live.

## Phase 9 — Freeze code, config và recording protocol

**Mục tiêu:** tạo candidate bất biến trước khi thu dữ liệu đánh giá.

**Công việc:**

- Gắn version/hash cho baseline, candidate, config và benchmark schema.
- Khóa metric/gate, không thay đổi sau khi record.
- Chuẩn bị checklist record: thiết bị, cách gắn điện thoại, app build, timezone,
  thời tiết, start/stop, route reference và kiểm tra raw journal.
- Chọn ground-truth method và ghi giới hạn của nó.
- Dry-run bằng dữ liệu rehearsal; rehearsal không thuộc final holdout.

**Acceptance:**

- Có thể tái tạo candidate từ commit + config.
- Protocol đủ chi tiết để hai lần record độc lập thực hiện giống nhau.
- Final dataset chưa được mở/chạy trước freeze.

**Điểm duyệt:** chờ `Duyệt Phase 9` rồi mới hẹn record.

## Phase 10 — Record dữ liệu thực tế cùng người dùng

**Mục tiêu:** thu final holdout mới, chưa từng dùng để tune.

**Bộ record tối thiểu:**

- 3 tuyến: open sky, cây che, đô thị.
- Mỗi tuyến ít nhất 3 lần lặp.
- Có đường thẳng, cua 30°/60°/90°, dừng đèn đỏ và một đoạn degraded/recovery.
- Cùng thiết bị, cách gắn và app build đã freeze.
- Thu raw GPS đầy đủ; không chỉ lưu polyline đã lọc.

**Phân vai:**

- Người dùng thực hiện record theo checklist và cung cấp raw journals/reference.
- Agent kiểm tra integrity, count, timestamp, duplicate, gap và metadata; không
  xem metric candidate để quyết định loại một trial trừ lỗi protocol đã định trước.

**Acceptance:**

- Mọi trial có ID, metadata và pass/fail protocol rõ ràng.
- Không loại trial vì kết quả thuật toán xấu.
- Dataset được đánh dấu read-only/final trước evaluation.

**Điểm duyệt:** chờ `Duyệt Phase 10` sau data-integrity report.

## Phase 11 — Chạy mô phỏng và final holdout evaluation

**Mục tiêu:** đưa ra kết luận đạt hoặc không đạt mà không tune lại.

**Công việc:**

- Chạy baseline và candidate trên đúng cùng timestamp.
- Chạy final synthetic holdout mới và field holdout.
- Báo cáo overall, per-route, per-phase và worst-case timestamps.
- Tính confidence interval/bootstrap khi cỡ mẫu phù hợp.
- Áp dụng nguyên văn gate ở Mục 3.2.

**Kết luận chỉ có ba dạng:**

1. `PASS`: đạt tất cả gate, đủ điều kiện sang shadow mode.
2. `FAIL`: không đạt; production giữ baseline.
3. `INCONCLUSIVE`: ground-truth/cỡ mẫu không đủ; phải thu thêm dữ liệu, không tune.

**Acceptance:** report chứa cả kết quả thuận lợi và bất lợi; không thay threshold
sau khi xem kết quả.

**Điểm duyệt:** chờ `Duyệt Phase 11`.

## Phase 12 — Feature flag, shadow mode và rollout

**Điều kiện mở phase:** Phase 11 phải `PASS` và người dùng cho phép tích hợp live.

**Công việc:**

- Feature flag mặc định `false`.
- Shadow mode tính baseline và candidate nhưng UI/distance chính vẫn dùng baseline.
- Log diagnostics tổng hợp, không log route nhạy cảm.
- Soak test nội bộ, kiểm tra latency/battery/crash.
- Rollout nội bộ trước; rollback tức thời về baseline.

**Acceptance:**

- Flag off cho hành vi hiện tại không đổi.
- Có integration test và rollback test.
- Không ghi đè raw GPS; audit path còn nguyên.
- Chỉ đổi output chính sau một checkpoint duyệt riêng.

**Verification:** integration tests, `flutter analyze`, `flutter test`, manual ride.

**Điểm duyệt:** chờ `Duyệt Phase 12` trước mọi rollout thực tế.

## 6. Dependency graph

```text
Phase 0
  └─ Phase 1
      └─ Phase 2
          └─ Phase 3
              └─ Phase 4A
                  ├─ đạt → Phase 5
                  └─ chưa đạt → duyệt Phase 4B → Phase 5
                      └─ Phase 6
                          └─ Phase 7
                              └─ Phase 8
                                  └─ Phase 9
                                      └─ Phase 10
                                          └─ Phase 11
                                              └─ PASS → Phase 12
```

## 7. Trạng thái tại thời điểm lập master plan

- Nhánh hiện tại: `EFK+DBSCAN`.
- `main` chưa được tích hợp candidate.
- Đã tồn tại prototype cho Joseph update, adaptive covariance, NIS gating,
  turn-aware Q, gap warm-up, diagnostics và parameter search.
- Prototype đã chạy test, nhưng theo quy trình mới sẽ được audit lần lượt trong
  các Phase 0–6; sự tồn tại của code không đồng nghĩa phase đã được duyệt.
- Kết quả development prototype hiện chưa đạt RMSE gate 10%, nên tuyệt đối chưa
  mở final holdout và chưa bật live.

## 8. Việc không làm trước khi được duyệt

- Không sửa thêm thuật toán sau khi master plan được trình duyệt.
- Không record final data trước Phase 9.
- Không gọi synthetic result là kết quả thực tế.
- Không bật EKF/T-DBSCAN trong live pipeline.
- Không commit raw GPS, tọa độ cá nhân hoặc secrets.
- Không hạ acceptance threshold để hợp thức hóa candidate hiện có.

## 9. Điểm duyệt đầu tiên

Sau khi duyệt tài liệu này, bước thực thi duy nhất tiếp theo là **Phase 0**.
Phase 0 chỉ khóa scope, Git state và metric contract; chưa sửa thêm code thuật toán.
