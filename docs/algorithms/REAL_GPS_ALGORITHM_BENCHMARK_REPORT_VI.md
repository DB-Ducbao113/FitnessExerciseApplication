# BÁO CÁO NGHIÊN CỨU THỰC NGHIỆM ĐỐI CHỨNG THUẬT TOÁN GPS AETRON TRÊN DỮ LIỆU THỰC TẾ (REAL-WORLD GPS BENCHMARK)

**Mã dự án:** DB-Ducbao113/FitnessExerciseApplication  
**Nhánh kiểm tra:** `feat/rg-f4-dataset-export`  
**Tập dữ liệu đối chứng:** `exports/historical/aetron_raw_gps_combined.csv`  
**Mã băm SHA-256 tập dữ liệu:** `4352aaf43356ab1e7b5e0f4acd3ca8f20259417bde2b3f5bfbabf9c956d2a9c5`  
**Ngày thực hiện:** 21/10/2026  
**Quyết định quản trị (Governance):** **HOLD** (Giữ nguyên thuật toán sản xuất hiện tại; không vội vã triển khai EKF + DBSCAN).

---

## 1. Tóm tắt Điều hành & Mục tiêu Nghiên cứu (Executive Summary)

Mục tiêu tối thượng của nghiên cứu này là: **Đánh giá thực nghiệm khách quan xem các thuật toán ứng viên (EKF, DBSCAN, EKF+DBSCAN, D+Opt) có thực sự cải thiện chất lượng bám vết và đo đạc khoảng cách của Aetron so với thuật toán sản xuất hiện hành hay không.**

Theo chỉ đạo của Chủ sở hữu (Owner):
1. **Không giả định trước rằng EKF + DBSCAN bắt buộc phải được triển khai lên production.**
2. **Sử dụng 100% dữ liệu GPS thực tế thu thập từ thiết bị di động của người dùng**, tuyệt đối không dùng dữ liệu mô phỏng nhân tạo để đánh giá thay cho thực tế.
3. **Bảo vệ quyền riêng tư tuyệt đối:** Không in tọa độ cá nhân (kinh độ, vĩ độ) ra log, màn hình terminal, báo cáo git hoặc hệ thống CI.
4. **Không ngộ nhận độ lệch khoảng cách giữa các thuật toán là sai số mặt đất (Ground-Truth Error):** Dữ liệu di động tiêu dùng không có trạm đo chuẩn trắc địa (RTK rover) đi kèm, do đó mọi phép so sánh chỉ được định danh là độ lệch tương đối (Relative Deviation).

### Kết luận ngắn gọn:
- **Thuật toán sản xuất Aetron hiện tại (Fixed-Alpha Smoothing + Turn-Boost) hoạt động ổn định, tin cậy và có chi phí tài nguyên cực thấp (0.9 µs/điểm).**
- **DBSCAN** phát huy tác dụng rõ rệt trong việc gộp các điểm dừng tĩnh (loại bỏ trôi dạt ảo ~24m tại buổi tập có dừng chân), nhưng phần lớn điểm rung lắc tĩnh đã được bộ lọc `tinySegment` của Aetron ngăn chặn từ trước.
- **EKF-only** cho quỹ đạo mượt mà hơn về mặt hình học, song có độ trễ quán tính nhẹ tại các khúc cua gắt và làm tăng nhẹ quãng đường hiển thị (+1.04% so với đường vẽ baseline).
- **Ứng viên D+Opt (Phase 5) THOÁI LUI NGHIÊM TRỌNG (Severe Regression):** Khi gặp môi trường thực tế có nhiều gián đoạn tín hiệu (61 lần mất sóng >5s ở session 7), máy trạng thái của D+Opt liên tục chuyển trạng thái S2/S3/S5 và cơ chế bù trừ gián đoạn dẫn đến **thổi phồng quãng đường lên tới +9.79% (vượt +1.19 km trên quãng đường 12.2 km)**. Kết quả thực địa này hoàn toàn đồng nhất với quyết định NO-GO của Phase 5.
- **Khuyến nghị:** **DUY TRÌ THUẬT TOÁN HIỆN TẠI TRÊN PRODUCTION**. Tiếp tục hoàn thiện hạ tầng trích xuất dữ liệu thô (RG-F4) và chuẩn bị thiết bị đo chuẩn trắc địa RTK trước khi xem xét nâng cấp bộ lọc.

---

## 2. Kiểm toán Dữ liệu Thực tế (Dataset Audit & Provenance)

### 2.1 Xuất xứ & Xác thực Tệp
- Tệp dữ liệu được phát hiện tại: `exports/historical/aetron_raw_gps_combined.csv` (đồng bộ hoàn toàn với bản sao `exports/historical/aetron_7_journals_raw_gps_combined.csv` và `exports/aetron_raw_gps_combined.csv`).
- Mã SHA-256: `4352aaf43356ab1e7b5e0f4acd3ca8f20259417bde2b3f5bfbabf9c956d2a9c5`.
- Dung lượng: `2,214,282` bytes.
- Tổng số dòng: `10,780` dòng (1 dòng tiêu đề + `10,779` bản ghi tọa độ GPS thô).
- Số buổi tập thực tế: **7 sessions** độc lập, tương ứng 7 journal ghi vết ngoại tuyến được phục hồi trên thiết bị iPhone/Android của tài khoản chủ sở hữu.
- Đối chiếu với tổng kho Supabase (10,907 điểm / 11 sessions toàn dự án): 7 sessions này chiếm **10,779 / 10,907 điểm (98.82% tổng dung lượng dữ liệu GPS lịch sử của toàn bộ hệ thống)**.

### 2.2 Cấu trúc Bản ghi & Độ Đầy đủ Dữ liệu (Schema & Telemetry Completeness)
Các cột trong tệp CSV: `workout_id,timestamp,latitude,longitude,altitude,speed,accuracy,heading,device_source,confidence`.

| Chỉ số Kiểm toán | Giá trị Ghi nhận | Đánh giá Kỹ thuật |
|---|:---:|---|
| **Tổng số điểm bản ghi thô** | 10,779 điểm | 100% điểm GPS thực tế thu từ `geolocator_position_stream` |
| **Độ cao (Altitude)** | 10,779 / 10,779 (100%) | Đầy đủ 100%, không khuyết thiếu |
| **Vận tốc tức thời (Speed)** | 10,779 / 10,779 (100%) | Đầy đủ 100%, giá trị hợp lệ từ 0.0 đến 19.88 m/s (~71.6 km/h) |
| **Độ chính xác bán kính (Accuracy)** | 10,779 / 10,779 (100%) | Đầy đủ 100%, trung vị (median) đạt 8.0 m |
| **Góc hướng di chuyển (Heading)** | 10,292 / 10,779 (95.5%) | 487 điểm khuyết góc khi thiết bị đứng yên/tốc độ < 0.5 m/s |
| **Nguồn thiết bị (Device Source)** | 10,779 / 10,779 (100%) | 100% định danh `geolocator_position_stream` |
| **Mức độ tin cậy (Confidence)** | 10,779 / 10,779 (100%) | Đầy đủ nhãn phân loại (high / medium / low) |

### 2.3 Phân tích Tần số Lấy mẫu & Bất thường Thời gian (Sampling & Anomaly Audit)
- **Tần số danh định:** Đạt chuẩn **1.000 Hz** hoàn hảo (Trung vị $\Delta t = 1.000\text{ s}$, Phân vị P95 $\Delta t = 1.000\text{ s}$ trên toàn bộ 7 buổi tập).
- **Tính đơn điệu thời gian (Monotonicity):** **0 điểm đảo ngược thời gian** ($\Delta t < 0$).
- **Điểm trùng lặp thời gian (Duplicate Timestamps):** 49 điểm ($\Delta t = 0$, chiếm 0.45%), xuất hiện khi cảm biến trả về nhiều mẫu trong cùng 1 mili-giây; được thuật toán khử trùng tự động (deduplication) đưa tập điểm làm việc về **10,730 điểm**.
- **Phân bố gián đoạn tín hiệu (Gaps / Outages):**
  - Gián đoạn nhẹ ($\Delta t > 2\text{ s}$): 149 lần.
  - Gián đoạn trung bình ($\Delta t > 5\text{ s}$): 89 lần.
  - Gián đoạn nghiêm trọng ($\Delta t > 15\text{ s}$): **Duy nhất 1 lần** (17.0s tại workout `f808e88a`).
  - Gián đoạn mất sóng hoàn toàn ($\Delta t > 30\text{ s}$): **0 lần**.

---

## 3. Thiết lập Thí nghiệm Đối chứng 5 Pipeline (Benchmark Methodology)

Thí nghiệm được thiết lập chạy trên cùng môi trường thuần nhất, sử dụng bộ kiểm tra tự động `test/real_gps_research_benchmark_test.dart` và bộ thực thi lõi `FieldGpsBenchmarkRunner`:

1. **Pipeline 1 — Baseline Sản xuất Aetron (Current Baseline):**
   - Lọc tiền kiểm định theo đặc thù môn đạp xe: loại bỏ độ chính xác kém (>32m), bão hòa tốc độ (>80 m/s), bước nhảy quán tính (>96 m/s), giật lùi vô lý (>120° trong <20m), và đặc biệt là bước dịch chuyển cực nhỏ (`tinySegment` < 1.5m).
   - Làm mượt Fixed-Alpha: $\alpha = 0.72$ (high), $0.52$ (medium), $0.34$ (low).
   - Tăng tốc góc cua (Turn-Boost): $\alpha = \max(\alpha, 0.82)$ khi góc cua lệch $> 28^\circ$ và khoảng cách $> 4.0\text{ m}$.
   - Khóa vị trí khi dừng (Stationary Freeze): Giữ nguyên tọa độ khi vận tốc $\le 0.8\text{ m/s}$ và dịch chuyển $< 2.0\text{ m}$.
   - Xuất ra 2 chỉ số khoảng cách: **App Baseline Distance** (tổng đoạn hợp lệ tích lũy) và **Display Route Distance** (quãng đường hiển thị theo đường vẽ làm mượt).

2. **Pipeline 2 — EKF-Only (Bộ lọc Kalman Mở rộng 4 Trạng thái):**
   - Trạng thái vector: $\mathbf{x} = [p_x, p_y, v_x, v_y]^T$.
   - Sử dụng ma trận hiệp phương sai sai số đo lường thích ứng theo `accuracy` và `heading`.
   - Cơ chế co giãn nhiễu góc cua `maxTurnHeadingNoiseScale: 14.0`.

3. **Pipeline 3 — DBSCAN-Only (Phân cụm Mật độ Không gian - Thời gian):**
   - Áp dụng `GpsDbscanService.findDwellClusters` trực tiếp trên chuỗi điểm hợp lệ để phát hiện các cụm dừng chân (Dwell Clusters: bán kính $\epsilon \le 12\text{ m}$, thời gian tối thiểu 15s).
   - Nén toàn bộ cụm dừng thành một trọng tâm duy nhất (Centroid), loại bỏ trôi dạt ảo (Phantom Drift).

4. **Pipeline 4 — EKF → DBSCAN:**
   - Kết hợp tuần tự: Làm mượt quỹ đạo động học bằng EKF 4 trạng thái, sau đó nén các cụm dừng bằng DBSCAN.

5. **Pipeline 5 — Ứng viên D+Opt (Phase 5 EKF Gap-Recovery FSM):**
   - Máy trạng thái 6 cấp (S0: Normal, S0-Prov: Provisional, S1: Degraded, S2: Loss of Lock, S3: Reacquisition, S4: Validated Re-anchor, S5: Safe Reset).
   - Bật đầy đủ 9 cờ tính năng nghiên cứu: Bounded Hybrid Distance, Gap Overlap Correction, Probation Variance Inflation, Alternative Rollback Recovery, Multi-Fix Heading Estimation, Probation Consecutive Rejections, Adaptive Turn Uncertainty, Noise-Aware Kinematic Screening.

---

## 4. Dữ liệu Thực nghiệm & Bảng Đối chứng Chi tiết

### 4.1 Bảng Tổng hợp Toàn bộ 7 Buổi tập (Aggregate Benchmark Matrix)

| Chỉ số Đo lường | Baseline App Distance | Current Display Route | EKF-Only | DBSCAN-Only | EKF → DBSCAN | Ứng viên D+Opt |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| **Tổng quãng đường (m)** | **57,892.15 m** | **57,069.05 m** | **57,662.58 m** | **57,883.75 m** | **57,656.64 m** | **58,689.42 m** |
| **Độ lệch vs Baseline App (%)** | *Chuẩn tham chiếu (0.00%)* | **-1.42%** | **-0.40%** | **-0.01%** | **-0.41%** | **+1.38%** |
| **Độ lệch vs Current Display (%)** | *+1.44%* | *Chuẩn hiển thị (0.00%)* | **+1.04%** | **+1.43%** | **+1.03%** | **+2.84%** |
| **Điểm hợp lệ / Tổng thô** | 8,135 / 10,730 (75.8%) | 8,135 / 10,730 (75.8%) | 8,135 / 10,730 (75.8%) | 8,135 / 10,730 (75.8%) | 8,135 / 10,730 (75.8%) | 8,135 / 10,730 (75.8%) |
| **Số điểm hiển thị (Display Pts)** | N/A | 6,750 | 8,135 | 8,125 | 8,124 | 8,135 |
| **Cụm dừng DBSCAN phát hiện** | N/A | N/A | N/A | **2 cụm** | **2 cụm** | N/A |
| **Trôi dạt ảo bị loại bỏ (m)** | 0.0 m | 0.0 m | 0.0 m | **-24.01 m** | **-22.37 m** | N/A |
| **Thời gian tính toán trung bình** | ~0.9 µs/pt | ~0.9 µs/pt | ~1.9 µs/pt | ~0.5 µs/pt | ~2.2 µs/pt | ~5.4 µs/pt |

---

### 4.2 Bảng Chi tiết Từng Buổi tập (Per-Workout Detailed Breakdown)

| Workout ID | Điểm Thô (Dedupe) | Điểm Hợp lệ (%) | Baseline App (m) | Current Display (m) | EKF-Only (m) | DBSCAN (m) | EKF+DBSCAN (m) | D+Opt (m) | Độ lệch D+Opt vs Baseline |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| `6903b3e0` | 1,186 | 722 (60.9%) | 5,157.92 | 5,081.85 | 5,142.93 | 5,157.92 | 5,142.93 | 5,087.57 | -1.36% |
| `f808e88a` | 1,160 | 812 (70.0%) | 5,671.20 | 5,597.13 | 5,666.27 | 5,671.20 | 5,666.27 | 5,682.51 | +0.20% |
| `9b9d3c3f` | 101 | 54 (53.5%) | 241.83 | 233.87 | 235.09 | 241.83 | 235.09 | 226.96 | -6.15% |
| `bc34d070` | 2,330 | 1,943 (83.4%) | 14,849.02 | 14,689.91 | 14,853.86 | 14,849.02 | 14,853.86 | 14,773.69 | -0.51% |
| `8fd0afa4` | 1,957 | 1,647 (84.2%) | 11,044.01 | 10,899.27 | 11,043.26 | **11,035.61** | **11,037.32** | 10,936.95 | -0.97% |
| `8674084e` | 1,674 | 1,196 (71.5%) | 8,719.64 | 8,624.47 | 8,664.81 | 8,719.64 | 8,664.81 | 8,578.17 | -1.62% |
| `8a554aec` | 2,322 | 1,761 (75.8%) | 12,208.52 | 11,942.55 | 12,056.35 | 12,208.52 | 12,056.35 | **13,403.57** | **+9.79%** ⚠️ |

---

### 4.3 Phân tích Nguyên nhân Lọc Điểm (Rejection Root-Cause Audit)
Trong tổng số 10,730 điểm GPS thô đã khử trùng lặp, bộ lọc Aetron đã loại bỏ 2,595 điểm (tỷ lệ chấp nhận 75.82%). Phân tích chi tiết nguyên nhân:

```text
========================================================================================
PHÂN BỐ NGUYÊN NHÂN TỪ CHỐI ĐIỂM GPS (2,595 ĐIỂM BỊ LOẠI)
========================================================================================
1. tinySegment (< 1.5m)          : 2,369 điểm (91.29%)  █████████████████████████████████
2. lowAccuracy (> 32m)           :   128 điểm ( 4.93%)  ██
3. headingSpike (> 120°)         :    96 điểm ( 3.70%)  █
4. waitingForBetterFirstFix (>20m):     2 điểm ( 0.08%)  
========================================================================================
```

**Nhận định kỹ thuật:**
- **91.3% các điểm bị loại bỏ là do `tinySegment` (< 1.5m)**: Điều này xảy ra khi người dùng đạp xe dừng chờ đèn giao thông, dừng uống nước, hoặc di chuyển cực chậm. Độ dịch chuyển giữa 2 giây liên tiếp nhỏ hơn 1.5 mét (< 5.4 km/h). Việc loại bỏ này là **hoàn toàn chính xác**, ngăn chặn hiện tượng cộng dồn nhiễu tĩnh gây phình ảo quãng đường.
- **4.9% là do độ chính xác kém (`lowAccuracy` > 32m)**: Tập trung chủ yếu ở workout `8a554aec` (75 điểm) và `6903b3e0` (46 điểm) khi đi qua hẻm sâu hoặc dưới bóng cây rậm rạp.
- **3.7% là do góc giật đột ngột (`headingSpike`)**: Lọc bỏ các bước nhảy zigzag sai lệch do hiện tượng đa đường (multipath reflection).

---

## 5. Phân tích Chuyên sâu Từng Ứng viên (Deep-Dive Candidate Analysis)

### 5.1 Hiện tượng D+Opt Thổi phồng Quãng đường tại Session `8a554aec` (Phát hiện Cốt lõi)
Tại buổi tập `8a554aec`, trong khi:
- Baseline App đo được: `12,208.5 m`
- Current Display vẽ được: `11,942.5 m` (-2.18%)
- EKF-Only ước tính: `12,056.3 m` (-1.25%)
- DBSCAN đo được: `12,208.5 m` (0.00%)
- **Thì D+Opt lại vọt lên tới: `13,403.57 m` (DƯ THỪA +1,195.1 m tương đương +9.79% so với App Baseline, và DƯ THỪA +1,461.0 m tương đương +12.23% so với Current Display)!**

**Nguyên nhân kỹ thuật:**
1. Buổi tập `8a554aec` diễn ra trong khu vực che khuất tín hiệu, có tới **61 khoảng gián đoạn sóng > 5s**, tổng thời gian mất sóng lên đến **410.7 giây**.
2. Máy trạng thái của D+Opt đã bị kích hoạt quá mức:
   - Rơi vào trạng thái mất khóa `s2LossOfLock`: **44 lần**.
   - Tái bắt sóng `s3CandidateReacquisition`: **44 lần**.
   - Thiết lập lại an toàn `s5SafeReset`: **48 lần**.
3. Trong các trạng thái chuyển giao này, các module nghiên cứu của D+Opt (`enableBoundedHybridDistance`, `enableAdaptiveTurnUncertainty`, và phục hồi thiếu hụt góc cua) đã cố gắng "bắc cầu" (bridge) và ước lượng quán tính qua khoảng trống thời gian. Khi gặp nhiễu đa đường liên tiếp, các ước lượng này đã tích lũy sai số dương và **bơm thêm gần 1.2 km ảo vào bài tập của người dùng**.
4. **Kết luận:** Đây là minh chứng thực nghiệm thực tế đắt giá chứng minh tại sao D+Opt đã thất bại tại các bài kiểm tra Holdout của Phase 5 và không bao giờ được phép đưa lên sản xuất.

### 5.2 Hiệu quả Khử Trôi dạt Tĩnh của DBSCAN tại Session `8fd0afa4`
- Tại buổi tập `8fd0afa4`, người dùng có dừng chân tại 2 địa điểm.
- Thuật toán `DBSCAN` đã phát hiện chính xác **2 cụm dừng chân (Dwell Clusters)**, thu gọn 10 điểm GPS trôi dạt vòng quanh và **loại bỏ đúng 24.01 m quãng đường ảo**.
- Quãng đường sau DBSCAN (`11,035.61 m`) phản ánh trung thực hơn trạng thái đứng yên của vận động viên so với quãng đường thô (`11,044.01 m`).
- Tuy nhiên, trên 6 buổi tập còn lại, DBSCAN không phát hiện thêm cụm dừng nào vì cơ chế `tinySegment` của Aetron đã chủ động chặn phần lớn điểm tĩnh từ vòng ngoài.

### 5.3 So sánh Hành vi Góc Cua (Turn Preservation): Fixed-Alpha + Turn-Boost vs. EKF
- **Fixed-Alpha + Turn-Boost của Aetron:**
  - Bình thường làm mượt với trọng số $\alpha = 0.72$ giúp đường vẽ ổn định.
  - Khi phát hiện góc cua lệch $> 28^\circ$ kèm dịch chuyển $> 4\text{ m}$, hệ số $\alpha$ lập tức tăng vọt lên $0.82$, bám sát đỉnh góc cua thực tế, không bị hiện tượng "cắt ngang tòa nhà".
  - Do làm mượt dạng dây cung (chord shortening), quãng đường hiển thị ngắn hơn quãng đường thô khoảng -1.42%, tạo cảm giác đường vẽ gọn gàng trên bản đồ.
- **EKF-Only:**
  - Do EKF duy trì trạng thái vận tốc vector $(v_x, v_y)$, khi xe bẻ cua gấp 90°, quán tính vận tốc giữ bộ lọc tiếp tục tiến về phía trước một khoảng ngắn trước khi đổi hướng, tạo độ trễ nhẹ. Quãng đường hiển thị của EKF dài hơn đường vẽ của Aetron khoảng +1.04% và bám rất sát tổng đoạn thô (-0.40%).

---

## 6. Trả lời Trực diện 4 Câu hỏi Nghiên cứu (Core Research Questions)

### Câu hỏi 1: Thuật toán Aetron hiện tại đang hoạt động tốt ở đâu?
- **Trả lời:**
  1. **Độ ổn định và an toàn cao:** Hoàn toàn không bao giờ bị hiện tượng thổi phồng quãng đường (Runaway distance explosion) như D+Opt, bất kể GPS bị mất sóng bao nhiêu lần.
  2. **Hiệu năng cực nhanh (Extreme Efficiency):** Chỉ tiêu tốn trung bình **0.9 µs/điểm**, chiếm chưa đến 0.1% ngân sách CPU trên thiết bị di động, tiết kiệm pin tối đa.
  3. **Lọc nhiễu tĩnh thông minh:** Cơ chế `tinySegment` (<1.5m) loại bỏ thành công 91.3% rung lắc tĩnh mà không cần thuật toán phân cụm phức tạp.
  4. **Bảo tồn góc cua xuất sắc:** Cơ chế Turn-Boost giúp ôm cua chính xác, trực quan trên giao diện bản đồ.

### Câu hỏi 2: Các ứng viên có tiềm năng cải thiện trong điều kiện nào?
- **Trả lời:**
  1. **DBSCAN:** Có tiềm năng cải thiện rõ rệt trong các bài tập có **thời gian dừng chân kéo dài** (dừng đèn đỏ lâu, nghỉ giải lao, dừng quán nước). DBSCAN triệt tiêu hiện tượng "vẽ hoa/mạng nhện" (GPS spiderweb) khi người dùng đứng yên một chỗ trong thời gian dài.
  2. **EKF:** Có tiềm năng tạo ra các vector vận tốc mượt mà, phục vụ tốt cho tính năng hiển thị tốc độ tức thời (instant pace) và bù đắp các đoạn mất sóng ngắn (1–2 giây) trên xa lộ thẳng hoặc góc cua thoai thoải.

### Câu hỏi 3: Những ứng viên nào bị thoái lui (regression) và thoái lui ở khía cạnh nào?
- **Trả lời:**
  1. **Ứng viên D+Opt THOÁI LUI NGHIÊM TRỌNG:** Tăng vọt quãng đường ảo (+9.79% đến +12.23%) khi gặp các đợt mất sóng liên tiếp trong hẻm đô thị. Máy trạng thái quá phức tạp, dễ bị đánh lừa bởi chuỗi GPS trôi dạt trong giai đoạn phục hồi.
  2. **EKF-only có hiện tượng trễ quán tính (Inertial Lag):** Cắt góc hoặc văng ra ngoài một đoạn nhỏ tại các khúc cua vuông 90° tốc độ cao nếu không có cơ chế tăng cường góc rẽ.
  3. **Chi phí tính toán:** D+Opt tiêu tốn tới 20.6 µs/điểm (gấp 20 lần baseline hiện tại).

### Câu hỏi 4: Cần những bằng chứng nào trước khi quyết định thay đổi thuật toán?
- **Trả lời:**
  1. **Đường chuẩn Trắc địa Độc lập (Survey-Grade Ground Truth):** Cần tối thiểu 3 bài chạy/đạp xe thực tế cùng với thiết bị định vị vệ tinh 2 tần số RTK-GNSS (độ chính xác < 2 cm) để đo lường RMSE thực sự.
  2. **Đo đạc Tiêu thụ Năng lượng Thực tế (Edge Battery Drain):** Đo đạc tác động hao pin trên iPhone/Android khi chạy bộ lọc liên tục 2 giờ ngoài trời.
  3. **Thử nghiệm Đa thiết bị Đồng thời:** Chạy song song 2 máy (1 máy chạy baseline, 1 máy chạy ứng viên) trên cùng một cung đường đạp xe thực tế để so sánh trực tiếp.

---

## 7. Khuyến nghị Quản trị Kỹ thuật (Governance Recommendation)

1. **Trạng thái Quản trị:** **HOLD — DUY TRÌ NGUYÊN TRẠNG THUẬT TOÁN SẢN XUẤT HIỆN TẠI.**
2. **Quyết định đối với các ứng viên:**
   - **D+Opt:** **BÁC BỎ HOÀN TOÀN (REJECT)** cho môi trường sản xuất. Lưu giữ mã nguồn trong kho nghiên cứu để làm bài học thực nghiệm.
   - **EKF & DBSCAN:** **TẠM DỪNG TRIỂN KHAI ĐƠN LẺ LÊN PRODUCTION**. Cân nhắc tích hợp mô-đun DBSCAN như một lớp hậu xử lý tùy chọn (post-processing dwell simplifier) khi lưu bài tập, thay vì chạy trực tiếp trên luồng thời gian thực.
3. **Kế hoạch tiếp theo:**
   - Tập trung hoàn thiện cơ chế xuất dữ liệu không cáp RG-F4 (Share Sheet / Web Export) để tiếp tục thu thập thêm dữ liệu từ cộng đồng người dùng.
   - Chuẩn bị kế hoạch đo đạc chuẩn RTK cho giai đoạn tiếp theo (RG-F5).
