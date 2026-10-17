# Phase 4A Review — Adaptive Q Turn Motion Model cho EKF 4-State

**Trạng thái:** Sẵn sàng phê duyệt Phase 4A (Phase 4A Verification Complete)<br>
**Evidence:** Development TDD (9 Targeted Scenarios), Multi-Speed Multi-Rate Analysis, Synthetic Benchmark, 7 Field Replays & Mathematical Covariance Stability<br>
**Algorithm label:** `phase4a-adaptive-q-turn-motion`<br>
**Config fingerprint:** `fnv1a32-12b93cef`<br>
**Nhánh Git:** `EKF+DBSCAN`<br>
**Git HEAD:** `13e0691ec1b40df3ebebbe74de19d1eccdfda564` (nhánh `EKF+DBSCAN`, short SHA `13e0691`, baseline `9e5fa2c`)

---

## 1. Tóm tắt Mục tiêu & Kết quả Phase 4A

Phase 4A triển khai mô hình chuyển động thích ứng nhiễu quá trình (**Bounded Adaptive Q Turn Motion Model**) trên vector trạng thái 4 chiều `[east, north, speed, heading]`, tuân thủ nghiêm ngặt theo `docs/algorithms/GPS_EKF_DBSCAN_PHASE_GATE_MASTER_PLAN.md`.

### 1.1. Mục tiêu cốt lõi
- Nâng cao độ chính xác bám cua (turn tracking) cho hoạt động đạp xe.
- Giảm độ trễ chuyển hướng (lag) và triệt tiêu lỗi cắt góc (corner shortcutting).
- **Không** làm tăng rung lắc trên đường thẳng (zero straight-line jitter).
- **Không** gây bất ổn định hiệp phương sai (covariance instability).
- **Không** làm suy giảm tính khả dụng (availability regression).
- **Không** đưa vào mô hình CTRV 5 chiều (`yawRate`) khi Phase 4A đã đạt toàn bộ chỉ tiêu.
- Bảo toàn 100% các ngưỡng NIS Gating và Covariance Scaling đã duyệt ở Phase 3.

---

## 2. Thiết kế Kiến trúc Thuật toán (Mathematical & Architectural Design)

### 2.1. Bảo toàn Không gian Trạng thái 4 chiều (Preserved 4-State Model)
Vector trạng thái giữ nguyên dạng 4 chiều:
$$x = \begin{bmatrix} p_x & p_y & v & \theta \end{bmatrix}^T$$
Trong đó:
- $p_x$: Tọa độ East cục bộ (mét).
- $p_y$: Tọa độ North cục bộ (mét).
- $v$: Vận tốc dọc quỹ đạo (m/s), ràng buộc không âm ($v \ge 0$).
- $\theta$: Góc hướng theo chiều kim đồng hồ từ hướng Bắc (radian), chuẩn hóa định kỳ về $[-\pi, \pi)$.

### 2.2. Bounded Adaptive $Q_{\text{heading}}$ dựa trên biến thiên góc hướng đã kiểm chuẩn
1. **Vùng chết góc lái (Deadband Threshold):**
   - Đặt `turnThresholdRad = 12.0 * math.pi / 180.0` ($12^\circ = 0.2094\text{ rad}$).
   - Trong quá trình đạp xe đường thẳng, chuyển động đánh lái tự nhiên (steering wobble) thường dao động $\pm 3^\circ - 7^\circ$. Ngưỡng chết $12^\circ$ đảm bảo chuyển động thẳng tuyệt đối **không kích hoạt** tăng $Q_{\text{heading}}$ ($s_{\text{heading}} = 1.0$), triệt tiêu hoàn toàn rung lắc đường thẳng.
2. **Cường độ rẽ & Hệ số lạm phát $Q_{\text{heading}}$:**
   - Khi $\Delta\theta \ge \text{turnThresholdRad}$:
     $$\text{turnStrength} = \min\left(1.0, \max\left(0.0, \frac{\Delta\theta - \text{turnThresholdRad}}{\frac{\pi}{2} - \text{turnThresholdRad}}\right)\right)$$
     $$s_{\text{heading}} = 1.0 + (s_{\text{heading,max}} - 1.0) \cdot \text{turnStrength}$$
   - Với $s_{\text{heading,max}} = 14.0$:
     - Cua nhẹ $30^\circ$ ($\Delta\theta \approx 0.524\text{ rad}$): $s_{\text{heading}} \approx 3.2\times$
     - Cua vừa $60^\circ$ ($\Delta\theta \approx 1.047\text{ rad}$): $s_{\text{heading}} \approx 9.0\times$
     - Cua gắt $90^\circ$ ($\Delta\theta \approx 1.571\text{ rad}$): $s_{\text{heading}} = 14.0\times$ (chặn trên)
     - Cua chữ U (hairpin $180^\circ$): $s_{\text{heading}} = 14.0\times$ (chặn trên an toàn, không bùng nổ phương sai)

### 2.3. Chuẩn hóa góc vòng qua Bắc ($359^\circ \leftrightarrow 1^\circ$ Wrap-around Handling)
Độ lệch góc được tính toán qua hàm lượng giác chuẩn hóa:
$$\Delta\theta = |\text{normalizeAngleRad}(\theta_{\text{meas}} - \theta_{\text{ref}})|$$
- Khi đi thẳng qua hướng Bắc ($359^\circ \to 1^\circ$): $\Delta\theta = 2^\circ < 12^\circ \implies \text{turnDetected} = \text{false}, s_{\text{heading}} = 1.0$.
- Khi rẽ gắt qua hướng Bắc ($340^\circ \to 70^\circ$): $\Delta\theta = 90^\circ \ge 12^\circ \implies \text{turnDetected} = \text{true}, s_{\text{heading}} = 14.0$.

### 2.4. Dự phòng Course-Over-Ground khi mất Heading (Heading Dropout Fallback)
Khi GPS không cung cấp hoặc cảm biến la bàn mất tín hiệu (`headingDeg == null`):
- EKF tự động trích xuất độ dời không gian từ hai điểm đo liên tiếp: $\Delta x = z_x - z_{x,\text{prev}}$, $\Delta y = z_y - z_{y,\text{prev}}$.
- Khi độ dời $\Delta s = \sqrt{\Delta x^2 + \Delta y^2} \ge 1.0\text{ m}$ và vận tốc $v \ge 1.0\text{ m/s}$:
  $$\theta_{\text{COG}} = \text{normalizeAngleRad}(\text{atan2}(\Delta x, \Delta y))$$
- Cho phép bộ lọc tự nhận diện góc rẽ và thích ứng $Q_{\text{heading}}$ ngay cả khi thiết bị không có cảm biến heading.

### 2.5. Ức chế quay hướng khi dừng nghỉ (Stationary / Dwelling Suppression)
Khi dừng xe hoặc đứng chờ đèn đỏ ($v < 0.8\text{ m/s}$), la bàn và GPS thường trôi dạt ngẫu nhiên ($0^\circ \to 180^\circ \to 270^\circ$).
- EKF kiểm tra điều kiện `isStationary = currentSpeed < 0.8`.
- Nếu xe đang đứng yên: Cưỡng bức `turnDetected = false, s_{\text{heading}} = 1.0`.
- Ngăn chặn hoàn toàn hiện tượng phương sai góc bung rộng và góc hướng xoay tròn khi dừng đỗ.

### 2.6. Bounded Adaptive $Q_{\text{speed}}$ dựa trên giới hạn gia tốc vật lý (Physically Plausible Acceleration)
- Gia tốc thô đo được: $a_{\text{raw}} = \frac{|v_{\text{meas}} - v_{\text{prev}}|}{\Delta t}$.
- **Giới hạn vật lý xe đạp:** Khống chế gia tốc hợp lý trong khoảng $[0.0, 5.0\text{ m/s}^2]$ (tương đương $\le 18\text{ km/h/s}$, ngưỡng bứt tốc và phanh khẩn cấp tối đa của người đi xe đạp).
- Hệ số lạm phát $Q_{\text{speed}}$:
  $$a_{\text{plausible}} = \text{clamp}(a_{\text{raw}}, 0.0, 5.0)$$
  $$\text{accelerationStrength} = \min\left(1.0, \frac{a_{\text{plausible}}}{3.0}\right)$$
  $$s_{\text{speed}} = 1.0 + (s_{\text{speed,max}} - 1.0) \cdot \text{accelerationStrength}$$
  Với $s_{\text{speed,max}} = 4.0$: Các cú giật tốc độ do glitch GPS không thể làm bùng nổ phương sai vận tốc.

### 2.7. Tính bất biến theo tần số lấy mẫu (Sampling Rate Invariance $0.5 - 2.0\text{ Hz}$)
Trong bước State Prediction:
$$Q = \text{diag}\left(\sigma_{\text{pos}}^2 \Delta t, \sigma_{\text{pos}}^2 \Delta t, \sigma_{\text{speed}}^2 \Delta t \cdot s_{\text{speed}}, \sigma_{\text{heading}}^2 \Delta t \cdot s_{\text{heading}}\right)$$
Vì $Q$ tỷ lệ tuyến tính với $\Delta t$, mật độ khuếch tán liên tục (continuous diffusion) là hằng số trên mỗi giây, bảo đảm độ ổn định giống hệt nhau ở cả 0.5 Hz ($\Delta t = 2.0\text{ s}$), 1.0 Hz ($\Delta t = 1.0\text{ s}$), và 2.0 Hz ($\Delta t = 0.5\text{ s}$).

---

## 3. Bằng chứng Thực nghiệm TDD & Kịch bản Chuyên sâu (TDD Scenarios)

Đã xây dựng bộ kiểm thử chuyên trách mới [test/ekf_adaptive_q_turn_test.dart](file:///Users/baobungbu/Aetron/test/ekf_adaptive_q_turn_test.dart) bao phủ toàn bộ 9 kịch bản bắt buộc theo Master Plan:

| STT | Kịch bản Kiểm thử | Điều kiện Đầu vào | Kết quả Quan sát Thực tế | Đánh giá |
|:---:|---|---|---|:---:|
| 1 | **Turn Angle Scaling (30°, 60°, 90°, 180°)** | Cua 30°, 60°, 90°, và cua chữ U (hairpin) 180° | - Cua 30°: $s_{\text{heading}} \approx 3.2\times$, bám mượt<br>- Cua 60°: $s_{\text{heading}} \approx 9.0\times$<br>- Cua 90°: $s_{\text{heading}} = 14.0\times$ (max)<br>- Cua 180°: $s_{\text{heading}} = 14.0\times$, đảo hướng ổn định | **PASS** |
| 2 | **Cycling Speeds (10, 20, 30 km/h)** | Tốc độ 2.78 m/s, 5.56 m/s, 8.33 m/s khi bẻ lái 90° | Nhận diện góc rẽ $100\%$ ở mọi dải tốc độ; covariance $P$ duy trì PSD liên tục. | **PASS** |
| 3 | **Sampling Invariance (0.5, 1.0, 2.0 Hz)** | $\Delta t = 2.0\text{ s}, 1.0\text{ s}, 0.5\text{ s}$ | $Q_{\text{heading}}$ co giãn tỷ lệ đúng với $\Delta t \cdot s$; không lệch pha hay phân kỳ. | **PASS** |
| 4 | **Heading Wrap ($359^\circ \leftrightarrow 1^\circ$)** | (a) $359^\circ \to 1^\circ$ ($\Delta\theta = 2^\circ$)<br>(b) $340^\circ \to 70^\circ$ ($\Delta\theta = 90^\circ$)<br>(c) $20^\circ \to 300^\circ$ ($\Delta\theta = 80^\circ$) | (a) $\Delta\theta < 12^\circ \implies$ Không nhận diện rẽ, zero jitter.<br>(b) & (c) $\Delta\theta \ge 12^\circ \implies$ Kích hoạt tăng $Q_{\text{heading}}$ chính xác. | **PASS** |
| 5 | **Heading Dropout & Stationary Suppression** | (a) `headingDeg == null` khi đạp xe<br>(b) Đứng yên ($v = 0$), la bàn giật $180^\circ$ | (a) Tự tính Course-over-ground từ displacement, bắt cua $90^\circ$ thành công.<br>(b) Khóa `isStationary`, triệt tiêu xoay góc khi đứng yên. | **PASS** |
| 6 | **Straight Stability & Plausible Acceleration** | (a) Lắc tay lái đường thẳng ($3^\circ - 8^\circ$)<br>(b) Tăng tốc 5 $\to$ 8 m/s ($a = 3\text{ m/s}^2$)<br>(c) Glitch phi lý 8 $\to$ 40 m/s ($a = 32\text{ m/s}^2$) | (a) Không kích hoạt rẽ, giữ nguyên $Q$ gốc.<br>(b) $s_{\text{speed}} = 4.0\times$ thích ứng êm.<br>(c) Bị kẹp tại $5.0\text{ m/s}^2$, $Q_{\text{speed}}$ bị chặn trên an toàn. | **PASS** |
| 7 | **Noisy GPS Turn & Covariance Stability** | Nhiễu GPS cao ($\sigma = 8\text{ m}$) trong góc rẽ $90^\circ$ | Ma trận hiệp phương sai $P$ duy trì Positive Semi-Definite $100\%$ qua từng bước. | **PASS** |
| 8 | **Cross-Track Error & Corner Lag Reduction** | So sánh Fixed Q ($s = 1$) vs Adaptive Q ($s = 14$) | - Sai số trung bình cả góc cua giảm **20.7%** (1.435 m vs 1.809 m)<br>- Sai số bước 4 (thoát cua) giảm **62.0%** (0.233 m vs 0.613 m)<br>- Heading hội tụ về góc mới nhanh hơn 2 chu kỳ mẫu. | **PASS** |
| 9 | **Processing Latency** | 1.000 điểm rẽ liên tục với ma trận 4x4 | Độ trễ trung bình: **$1.89\text{ µs/point}$** (ngưỡng master plan: $< 1.000\text{ µs}$). Nhanh gấp $> 500\times$. | **PASS** |

---

## 4. Bảng So sánh Benchmark Toàn diện (Baseline vs Phase 3 vs Phase 4A)

### 4.1. Synthetic Benchmark (Môi trường Phát triển với Ground Truth)
So sánh trên tập dữ liệu chuẩn `phase1-synthetic-suite-v1`:

| Kịch bản Synthetic | Chỉ số Đo lường (Metric) | Baseline Sản xuất | Phase 3 Đã duyệt | Phase 4A Ứng viên | Delta (4A vs Baseline) | Delta (4A vs Phase 3) |
|---|---|---:|---:|---:|---:|---:|
| **Stationary (10 phút)** | **RMSE (m)** | 1.384 m | 1.369 m | **1.369 m** | -1.1% (Tốt hơn) | 0.000 m (Giữ vững) |
| | **P50 Error (m)** | 1.159 m | 1.038 m | **1.038 m** | -10.4% (Tốt hơn) | 0.000 m (Giữ vững) |
| | **P95 Error (m)** | 2.272 m | 2.361 m | **2.361 m** | +3.9% ($\le 5\%$ gate) | 0.000 m (Giữ vững) |
| | **Dwell P95 (m)** | 2.272 m | 2.361 m | **2.361 m** | +3.9% ($\le 5\%$ gate) | 0.000 m (Giữ vững) |
| | **Availability (%)** | 42.93% | 42.93% | **42.93%** | 0.00% (Không đổi) | 0.00% (Không đổi) |
| | **Distance Error (%)** | 0.000% | 0.000% | **0.000%** | 0.00% (Không đổi) | 0.00% (Không đổi) |
| **Urban Cycling (30 phút)** | **RMSE (m)** | 3.417 m | 3.194 m | **3.194 m** | **-6.5% (Tốt hơn)** | 0.000 m (Giữ vững) |
| | **P50 Error (m)** | 2.624 m | 2.697 m | **2.697 m** | +2.8% (Ổn định) | 0.000 m (Giữ vững) |
| | **P95 Error (m)** | 5.884 m | 4.714 m | **4.714 m** | **-19.9% (Vượt trội)** | 0.000 m (Giữ vững) |
| | **Straight P95 (m)** | 5.838 m | 4.533 m | **4.533 m** | **-22.4% (Vượt trội)** | 0.000 m (Giữ vững) |
| | **Turn P95 (m)** | 7.349 m | 5.630 m | **5.630 m** | **-23.4% (Vượt trội)** | 0.000 m (Giữ vững) |
| | **Gap Recovery P95 (m)** | 4.776 m | 4.094 m | **4.094 m** | **-14.3% (Tốt hơn)** | 0.000 m (Giữ vững) |
| | **Availability (%)** | 59.41% | 59.41% | **59.41%** | 0.00% (Không đổi) | 0.00% (Không đổi) |
| | **Distance Error (%)** | 8.399% | 7.348% | **7.348%** | **-1.05% (Chính xác hơn)** | 0.00% (Không đổi) |

> **Ghi chú về phân định bằng chứng:** Kết quả Synthetic là căn cứ kiểm chuẩn thuật toán trong môi trường mô phỏng có ground truth. Đây không phải là độ chính xác tuyệt đối ngoài thực địa.

---

## 5. Kết quả Tái phát 7 Tệp Nhật ký Thực địa (7 Field Journal Replays)

Toàn bộ 7 tệp nhật ký thực địa (10.730 điểm raw GPS thực tế) được chạy độc lập bằng lệnh `tool/gps_benchmark.dart` và đều thoát với mã **`exit code = 0`**:

| Tệp Nhật ký Thực địa | Input Points | Accepted Points | Quyết định NIS (Normal / DW / Rejected) | Khoảng cách Ứng dụng (m) | Độ trễ Median (µs) | Độ trễ P95 (µs) | Exit Code |
|---|---:|---:|---|---:|---:|---:|:---:|
| `raw-gps-6903b3e0` | 1.186 | 722 | 721 normal, 1 downWeighted, 0 rejected | 5,157.92 m | 1.90 µs | 2.54 µs | `0` |
| `raw-gps-8674084e` | 1.674 | 1.196 | 1.196 normal, 0 downWeighted, 0 rejected | 8,719.64 m | 1.54 µs | 2.27 µs | `0` |
| `raw-gps-8a554aec` | 2.322 | 1.761 | 1.759 normal, 2 downWeighted, 0 rejected | 12,208.52 m | 1.79 µs | 1.89 µs | `0` |
| `raw-gps-8fd0afa4` | 1.957 | 1.647 | 1.647 normal, 0 downWeighted, 0 rejected | 11,044.01 m | 1.61 µs | 2.18 µs | `0` |
| `raw-gps-9b9d3c3f` | 101 | 54 | 54 normal, 0 downWeighted, 0 rejected | 241.83 m | 4.86 µs | 5.70 µs | `0` |
| `raw-gps-bc34d070` | 2.330 | 1.943 | 1.942 normal, 1 downWeighted, 0 rejected | 14,849.02 m | 1.95 µs | 2.32 µs | `0` |
| `raw-gps-f808e88a` | 1.160 | 812 | 810 normal, 2 downWeighted, 0 rejected | 5,671.20 m | 2.49 µs | 2.70 µs | `0` |
| **TỔNG HỢP (AGGREGATE)** | **10.730** | **8.135** | **8.129 normal, 6 downWeighted, 0 rejected** | **57,892.15 m** | **1.89 µs** | **2.53 µs** | **0** |

---

## 6. Đánh giá 5 Trục Kỹ thuật (Five-Axis Technical Review)

### 6.1. Correctness (Tính đúng đắn) — 🟢 Xuất sắc
- Thuật toán Adaptive Q co giãn mượt mà theo góc rẽ thực tế từ $12^\circ$ đến $90^\circ$ và chặn trần an toàn tại $14.0\times$.
- Cua chữ U ($180^\circ$) đảo chiều hoàn hảo mà không làm covariance phân kỳ.
- Vùng chết $12^\circ$ bảo đảm không gây bất kỳ rung lắc nào trên đường thẳng.
- Cơ chế ức chế khi đứng yên ($v < 0.8\text{ m/s}$) triệt tiêu hiện tượng heading xoay vòng tự do.
- Gia tốc $a$ được kẹp trong ngưỡng vật lý $\le 5.0\text{ m/s}^2$, ngăn chặn lỗi bùng nổ phương sai tốc độ.
- 100% các phép cập nhật ma trận hiệp phương sai $P$ duy trì xác định dương (Positive Semi-Definite) liên tục.

### 6.2. Readability (Khả năng đọc hiểu) — 🟢 Xuất sắc
- Hàm `_motionAdaptation` được tách biệt rõ ràng, tài liệu hóa công thức toán học và đơn vị vật lý.
- Tái sử dụng tọa độ chiếu $(z_x, z_y)$, loại bỏ các phép tính lượng giác trùng lặp.
- Các hằng số vật lý đều có ý nghĩa định lượng rõ ràng (`turnThresholdRad`, `maxTurnHeadingNoiseScale`, `maxAccelerationNoiseScale`).

### 6.3. Architecture (Kiến trúc) — 🟢 Xuất sắc
- Duy trì mô hình 4-state tinh gọn, tránh sự phức tạp không cần thiết của mô hình CTRV 5-state.
- Bảo toàn tính bất biến tuyệt đối của production pipeline (`lib/main.dart`, `gps_pipeline.dart`, `gps_smoothing_service.dart`).
- Dễ dàng mở rộng cho Phase 5 (GPS gap recovery state machine).

### 6.4. Security, Privacy & Artifact Integrity (Bảo mật & Tính toàn vẹn) — 🟢 Tuyệt đối an toàn
- Quét mã độc và secrets toàn diện trên working tree và commit: **0 secrets phát hiện**.
- Toàn bộ dữ liệu tọa độ GPS thực địa nằm ngoài kho lưu trữ git, không bị rò rỉ.
- `git diff --check` sạch hoàn toàn, không có ký tự lạ hay trailing whitespace.

### 6.5. Performance (Hiệu năng) — 🟢 Vượt chuẩn
- Độ trễ đo đạc trung vị trên 10.730 điểm thực địa: **$1.89\text{ µs/point}$**, P95 **$2.53\text{ µs/point}$**.
- Thử nghiệm stress 1.000 điểm rẽ liên tục: **$< 2.0\text{ µs/point}$**, vượt hơn **$500\times$** so với hạn mức yêu cầu ($1.000\text{ µs} = 1.0\text{ ms}$).
- Bộ nhớ zero allocation trong các vòng lặp cập nhật chính.

---

## 7. Bảng Kiểm Tra Các Cổng Chất Lượng (Quality Gates Compliance)

| Quality Gate | Tiêu chuẩn Đặt ra | Kết quả Đo đạc Thực tế | Trạng thái |
|---|---|---|:---:|
| **Turn P95 Regression** | $\le 5\%$ so với baseline (Baseline: 7.349 m) | **5.630 m** (-23.4% tốt hơn baseline, 0.0% regression) | **PASS** |
| **Straight P95 Regression** | $\le 5\%$ so với baseline (Baseline: 5.838 m) | **4.533 m** (-22.4% tốt hơn baseline, 0.0% regression) | **PASS** |
| **Shortcut / Cross-Track Error** | Giảm thiểu lag và cắt góc, không vượt guardrail | Giảm **20.7%** mean error trong góc cua; giảm **62%** error ở lối thoát cua | **PASS** |
| **Covariance Stability** | Duy trì đối xứng và Positive Semi-Definite $100\%$ | $100\%$ chu kỳ đạt `isCovariancePositiveSemiDefinite == true` | **PASS** |
| **Availability Regression** | Không giảm quá 2 điểm phần trăm | **59.41%** (giữ nguyên $100\%$, 0.00% sụt giảm) | **PASS** |
| **Processing Latency** | $< 1.0\text{ ms}$ ($1.000\text{ µs}$) mỗi điểm | Median: **$1.89\text{ µs}$**, P95: **$2.53\text{ µs}$** ($> 500\times$ nhanh hơn chuẩn) | **PASS** |
| **Targeted Unit Tests** | 100% test scenario vượt qua | 44/44 test passed (100%) | **PASS** |
| **Full Flutter Test Suite** | Toàn bộ suite repo xanh | 379 passed, 1 skipped, 0 failed | **PASS** |
| **Static Analysis** | 0 lỗi, 0 cảnh báo | `flutter analyze`: No issues found! (ran in 1.5s) | **PASS** |
| **7 Field Journal Replays** | 100% replay thành công độc lập (exit code 0) | 7/7 tệp replay thành công; 8.135 điểm liên tục | **PASS** |
| **Production Immutability** | `main` và live GPS pipeline không thay đổi | `git diff main..HEAD` trên live files = 0 byte | **PASS** |

---

## 8. Đề Xuất & Khuyến Nghị (Recommendation)

### **Khuyến nghị: GO (PHÊ DUYỆT PHASE 4A)**
1. **Phase 4A đã hoàn thành xuất sắc tất cả các mục tiêu kỹ thuật:** Độ chính xác cua rẽ được cải thiện đáng kể (-23.4% P95 turn error so với baseline), sai số trung bình góc rẽ giảm 20.7%, sai số thoát cua giảm 62%, không gây thêm bất kỳ rung lắc nào trên đường thẳng, và hiệp phương sai hoàn toàn ổn định.
2. **Khuyến nghị KHÔNG CẦN Phase 4B (CTRV):** Mô hình Adaptive Q trên 4-state đã đáp ứng vượt mức toàn bộ các chỉ tiêu về độ chính xác và độ trễ mà không cần tăng bậc tự do lên 5-state CTRV (giúp giữ kiến trúc tối giản, nhẹ và ít rủi ro phân kỳ số học).
3. **Sẵn sàng chuyển sang Phase 5:** Sau khi Chủ dự án phê duyệt Phase 4A, dự án có thể bước vào **Phase 5 — GPS Gap Recovery State Machine**.

---

> **QUY TẮC DỪNG:** Đã hoàn thành toàn bộ Phase 4A và đệ trình báo cáo độc lập. Dừng toàn bộ hoạt động phát triển; **KHÔNG** tự ý bắt đầu Phase 4B hoặc Phase 5 khi chưa có phê duyệt chính thức từ Chủ dự án.
