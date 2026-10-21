# BÁO CÁO NGHIÊN CỨU THỰC NGHIỆM ĐỐI CHỨNG THUẬT TOÁN GPS AETRON TRÊN DỮ LIỆU THỰC TẾ
## (Real-World GPS Research Benchmark & Scientific Integrity Review)

**Mã đề tài / Repository:** `DB-Ducbao113/FitnessExerciseApplication`  
**Nhánh nghiên cứu:** `feat/rg-f4-dataset-export`  
**Tập dữ liệu kiểm toán:** `exports/historical/aetron_raw_gps_combined.csv`  
**Mã băm SHA-256 tập dữ liệu:** `4352aaf43356ab1e7b5e0f4acd3ca8f20259417bde2b3f5bfbabf9c956d2a9c5`  
**Phiên bản báo cáo:** 2.0.0 (Bản hiệu đính học thuật phục vụ bảo vệ & phản biện)  
**Trạng thái Quản trị (Governance Status):** **SECURITY HOLD** (Duy trì thuật toán sản xuất hiện tại; tạm dừng triển khai EKF + DBSCAN; hoàn thành khắc phục phơi nhiễm lịch sử git trước khi chuyển đổi trạng thái).

---

## 1. Cảnh báo An ninh & Tóm tắt Điều hành (Executive Summary & Security Incident)

> [!CAUTION]
> **SỰ CỐ AN NINH P0 — PHƠI NHIỄM DỮ LIỆU GPS THỰC TẾ CÁ NHÂN TRÊN REPOSITORY CÔNG KHAI**  
> Tệp `exports/historical/aetron_raw_gps_combined.csv` chứa tọa độ cá nhân thực tế (vĩ độ, kinh độ, mốc thời gian) đã được đưa vào theo dõi của Git tại commit `bdf5cea4177ff4d638bcf29c777fa53b93cfc240` và đẩy lên GitHub.  
> **Biện pháp khẩn cấp đã thực thi:**
> 1. Lưu trữ bản sao lưu ngoại tuyến an toàn tại `/Users/baobungbu/.aetron_secure_backup/` kèm xác minh SHA-256.
> 2. Gỡ bỏ hoàn toàn ngoại lệ whitelist trong `.gitignore` (`/exports/` hiện đã bị chặn toàn bộ).
> 3. Tách tệp ra khỏi chỉ mục theo dõi của Git (`git rm --cached`).
> 4. Chuyển đổi toàn bộ bộ kiểm thử tự động sang chế độ **Opt-in** (CI công khai chạy độc lập mà không yêu cầu tệp tọa độ cá nhân).
> 5. Lập kế hoạch thanh tẩy lịch sử Git theo quy trình chuẩn của GitHub (Mục 6), tuyệt đối không tự ý `force-push` khi chưa có phê duyệt của Chủ sở hữu.

### Tóm tắt Kết quả Nghiên cứu:
Mục tiêu của nghiên cứu là: **Xác định xem các thuật toán lọc GPS ứng viên (EKF, DBSCAN, EKF+DBSCAN, D+Opt) có cải thiện chất lượng bám vết và đo đạc quãng đường của Aetron so với thuật toán sản xuất hiện tại hay không.**

1. **Thuật toán sản xuất Aetron hiện tại (Fixed-Alpha Smoothing + Turn-Boost) hoạt động ổn định, tin cậy và có chi phí tài nguyên cực thấp (chưa có số đo hiệu năng tái lập để kết luận về pin).**
2. **DBSCAN** thu gọn hiệu quả các cụm dừng chân (Dwell Clusters) tại bài tập có nghỉ giữa chặng (giảm 24.01 m độ dài đường gấp khúc tại session `session_5`), tuy nhiên trên 91% rung lắc vi mô khi dừng đã được bộ lọc tiền kiểm định của Aetron loại bỏ từ trước.
3. **EKF-Only** cho quỹ đạo mượt mà hơn về mặt hình học nhưng xuất hiện độ trễ quán tính nhẹ tại các góc rẽ vuông 90°.
4. **Ứng viên D+Opt (Phase 5) THOÁI LUI NGHIÊM TRỌNG TRÊN THỰC ĐỊA:** Khi gặp môi trường thực tế có 61 khoảng mất sóng $>5\text{s}$ (Session `session_7`), máy trạng thái FSM bị kích hoạt chuyển trạng thái S2/S3/S5 liên tục; cơ chế bù trừ gián đoạn dẫn đến **thổi phồng quãng đường đo được lên tới +9.52% (+1,164.62 m trên tổng quãng đường 12.2 km)**. Quan sát replay này phù hợp với quyết định NO-GO cho D+Opt, nhưng không phải phép đo sai số thực địa vì không có ground truth độc lập.
5. **Quyết định Quản trị:** **HOLD**. Giữ nguyên thuật toán sản xuất hiện hành. Không triển khai EKF/DBSCAN vào sản xuất ở thời điểm này.

---

## 2. Ma trận Phân định Bằng chứng Khoa học (Scientific Evidence Matrix)

Để đảm bảo tính khách quan và liêm chính học thuật, toàn bộ các phát hiện trong báo cáo được phân định rõ ràng theo 3 cấp độ bằng chứng:

| Khía cạnh Đánh giá | Tầng 1: Quan sát Trực tiếp (Observed / Empirically Measured) | Tầng 2: Suy diễn Kỹ thuật (Inferred / Mechanistically Deduceable) | Tầng 3: Chưa thể Chứng minh (Unproven / Requires Further Data) |
|---|---|---|---|
| **Sai số Quãng đường** | Đo đạc được độ lệch số học tuyệt đối và % giữa các thuật toán đối chứng trên cùng một chuỗi điểm thô. | Thuật toán có bước làm mượt (chord shortening) sẽ cho chiều dài đường vẽ ngắn hơn tổng các đoạn thẳng thô. | **Không thể tuyên bố đây là Sai số Thực địa (Ground-Truth Error)** vì tập dữ liệu điện thoại tiêu dùng không có trạm trắc địa RTK-GNSS đo chuẩn. |
| **Thu gọn Cụm dừng DBSCAN** | Chiều dài chuỗi điểm giảm đúng 24.01 m tại session `session_5` sau khi gộp 10 điểm trong 2 cụm ($\epsilon=12\text{m}, \text{minPts}=15\text{s}$). | Thuật toán phân cụm mật độ đã thành công trong việc gom các điểm dao động xung quanh một trọng tâm khi vận tốc thấp. | **Chưa thể chứng minh 24.01 m đó hoàn toàn là trôi dạt GPS (drift)**; người dùng có thể đã đi bộ qua lại trong phạm vi 12 mét của quán nước/chỗ nghỉ. |
| **Bộ lọc Bước nhảy Nhỏ (tinySegment)** | 2,366 / 2,593 điểm bị loại (91.25%) có khoảng cách giữa 2 điểm liên tiếp $< 1.5\text{ m}$. | Ngăn chặn hiện tượng cộng dồn vi sai tọa độ khi thiết bị đứng yên một chỗ. | **Không thể khẳng định 100% các điểm này là nhiễu cảm biến**; chúng có thể bao gồm di chuyển rất chậm, dắt xe bộ hoặc leo dốc gắt ($< 5.4\text{ km/h}$). |
| **Sự cố Phình Quãng đường D+Opt** | Quãng đường của D+Opt tăng vọt +1,164.62 m (+9.52%) tại session `session_7` kèm 44 lần rơi vào S2, 44 lần S3, 48 lần S5. | Sự kết hợp giữa bù thiếu hụt góc rẽ và bắc cầu quán tính trong môi trường mất sóng dày đặc gây tích lũy sai số dương. | **Chưa thể quy kết nguyên nhân duy nhất cho một cờ tính năng cụ thể** nếu không thực hiện thử nghiệm bóc tách cô lập (ablation study) trên từng cờ. |
| **Chi phí Tính toán & Pin** | Thời gian chạy thay đổi theo thiết bị và điều kiện đo; số đo chẩn đoán được tách khỏi artifact có hash. | Cần benchmark hiệu năng riêng có kiểm soát. | Không thể suy ra mức tiêu thụ pin từ số vi-giây CPU. |

---

## 3. Kiểm toán Dữ liệu Thực tế (Dataset Audit & Verification)

### 3.1 Xuất xứ & Tính Toàn vẹn Tệp
- **Tệp nguồn:** `exports/historical/aetron_raw_gps_combined.csv`
- **Mã băm SHA-256:** `4352aaf43356ab1e7b5e0f4acd3ca8f20259417bde2b3f5bfbabf9c956d2a9c5`
- **Dung lượng:** `2,214,282` bytes (`10,780` dòng = 1 header + `10,779` bản ghi tọa độ thô).
- **Tập trung:** Thu thập từ 7 session journal ghi nhận hoạt động đạp xe thực địa của người dùng thiết bị di động, chiếm **98.82%** tổng dung lượng dữ liệu GPS lịch sử trên Supabase (`10,779 / 10,907` điểm).

### 3.2 Kiểm toán Thứ tự Mốc Thời gian Nguyên bản (Original Sequence Integrity)
- **Thứ tự nguyên bản trước khi sắp xếp:** Đã thực hiện quét kiểm tra tính đơn điệu trên từng buổi tập ngay khi đọc từ tệp CSV thô: **Ghi nhận 0 điểm nghịch đảo thời gian** ($\Delta t < 0$). Toàn bộ 7 buổi tập đều được ghi tuần tự thời gian tuyệt đối.
- **Điểm trùng lặp thời gian:** Phát hiện 49 điểm có timestamp giống hệt điểm liền trước ($\Delta t = 0\text{ s}$, chiếm 0.45%), xuất hiện khi cảm biến GPS phát nhiều bản ghi trong cùng một mili-giây. Cơ chế khử trùng lặp (deduplication) đưa tập điểm làm việc về **10,730 điểm duy nhất**.
- **Tần số lấy mẫu:** Chuẩn danh định **1.000 Hz** (Trung vị $\text{median} = 1.000\text{ s}$, Phân vị $\text{P95} = 1.000\text{ s}$).
- **Độ đầy đủ trường viễn thám:** Độ cao (Altitude), Vận tốc (Speed), Độ chính xác (Accuracy) đạt **100% đầy đủ** (0 giá trị null). Góc hướng di chuyển (Heading) đạt **95.48%** (khuyết khi tốc độ $\le 0.4\text{ m/s}$).

### 3.3 Phân bố Gián đoạn Tín hiệu (Outage & Gap Distribution)
- Gián đoạn ngắn ($\Delta t > 2\text{ s}$): 149 lần.
- Gián đoạn trung bình ($\Delta t > 5\text{ s}$): 89 lần. Trong đó, riêng session `session_7` chiếm **61 lần** (tổng thời gian mất sóng lên đến 410.7 giây) do di chuyển trong hẻm sâu đô thị.
- Gián đoạn nghiêm trọng ($\Delta t > 15\text{ s}$): Đúng 1 lần duy nhất ($17.0\text{ s}$ tại session `session_2`).
- Mất sóng hoàn toàn ($\Delta t > 30\text{ s}$): **0 lần**.

---

## 4. Dữ liệu Thực nghiệm & Bảng Đối chứng Chi tiết

### 4.1 Bảng Tổng hợp Toàn bộ 7 Buổi tập (Aggregate Benchmark Matrix)

| Chỉ số Đo lường | Baseline App Distance | Current Display Route | EKF-Only | DBSCAN-Only | EKF → DBSCAN | Ứng viên D+Opt |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| **Tổng quãng đường (m)** | **58,036.58 m** | **57,068.79 m** | **57,662.43 m** | **57,881.95 m** | **57,655.22 m** | **58,695.91 m** |
| **Độ lệch vs Baseline App (%)** | *Chuẩn tham chiếu (0.00%)* | **-1.67%** | **-0.64%** | **-0.27%** | **-0.66%** | **+1.14%** |
| **Độ lệch vs Current Display (%)** | *+1.70%* | *Chuẩn hiển thị (0.00%)* | **+1.04%** | **+1.42%** | **+1.03%** | **+2.85%** |
| **Điểm hợp lệ / Điểm thô** | 8,137 / 10,730 (75.83%) | 8,137 / 10,730 (75.83%) | 8,137 / 10,730 (75.83%) | 8,137 / 10,730 (75.83%) | 8,137 / 10,730 (75.83%) | 8,137 / 10,730 (75.83%) |

DBSCAN-only phát hiện **3 cụm trong 2/7 phiên**: 2 cụm tại `session_5` (giảm 24.01 m độ dài đường gấp khúc) và 1 cụm tại `session_7` (giảm 4.72 m), tổng cộng **28.73 m**. Đây là thay đổi đầu ra, chưa phải mức cải thiện độ chính xác được xác nhận bằng ground truth.

---

### 4.2 Bảng Chi tiết 7 Buổi tập Thực tế (Per-Session Performance)

| Workout ID | Điểm Thô (Dedupe) | Điểm Hợp lệ (%) | Baseline App (m) | Current Display (m) | EKF-Only (m) | DBSCAN (m) | EKF+DBSCAN (m) | D+Opt (m) | Độ lệch D+Opt vs Baseline |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| `session_1` | 1,186 | 722 (60.9%) | 5,168.26 | 5,081.85 | 5,142.93 | 5,157.92 | 5,142.93 | 5,087.57 | -1.56% |
| `session_2` | 1,160 | 812 (70.0%) | 5,686.56 | 5,597.13 | 5,666.27 | 5,671.20 | 5,666.27 | 5,682.51 | -0.07% |
| `session_3` | 101 | 54 (53.5%) | 242.90 | 233.87 | 235.09 | 241.83 | 235.09 | 226.96 | -6.57% |
| `session_4` | 2,330 | 1,943 (83.4%) | 14,880.30 | 14,689.91 | 14,853.38 | 14,849.01 | 14,853.38 | 14,784.38 | -0.64% |
| `session_5` | 1,957 | 1,648 (84.2%) | 11,086.59 | 10,899.15 | 11,043.31 | 11,035.69 | 11,037.37 | 10,938.19 | -1.34% |
| `session_6` | 1,674 | 1,196 (71.5%) | 8,738.45 | 8,624.47 | 8,664.81 | 8,719.64 | 8,664.81 | 8,578.17 | -1.83% |
| `session_7` | 2,322 | 1,762 (75.9%) | 12,233.51 | 11,942.40 | 12,056.65 | 12,206.65 | 12,055.38 | 13,398.13 | +9.52% |
---

### 4.3 Phân tích Nguyên nhân Lọc Điểm (Rejection Root-Cause Breakdown)
Trong 10,730 điểm GPS thô đã khử trùng lặp, bộ lọc kiểm định sản xuất của Aetron đã loại bỏ 2,593 điểm (tỷ lệ chấp nhận đạt 75.83%):
- **`tinySegment` ($< 1.5\text{ m}$): 2,366 điểm (91.25%)**: Chiếm đại đa số. Lọc bỏ các bước dịch chuyển vi mô khi người dùng đứng chờ đèn đỏ hoặc di chuyển cực chậm ($< 5.4\text{ km/h}$).
- **`lowAccuracy` ($> 32\text{ m}$): 128 điểm (4.94%)**: Lọc bỏ các điểm suy giảm chất lượng tín hiệu nặng (multipath).
- **`headingSpike` ($> 120^\circ$ trong $< 20\text{ m}$): 97 điểm (3.74%)**: Lọc bỏ hiện tượng giật lùi vô lý.
- **`waitingForBetterFirstFix` ($> 20\text{ m}$ ở điểm đầu): 2 điểm (0.08%)**: Chờ khóa vị trí ban đầu ổn định.

---

## 5. Trả lời Trực diện 4 Câu hỏi Nghiên cứu

### 1. Thuật toán Aetron hiện tại đang hoạt động tốt ở đâu?
- **Tính ổn định và chặn biên an toàn:** Không bao giờ bị hiện tượng phóng đại quãng đường khi gặp gián đoạn sóng liên tục.
- **Hiệu năng:** Cần đo riêng trên thiết bị vật lý trước khi kết luận về CPU hoặc pin.
- **Bảo tồn góc cua tốt:** Cơ chế Turn-Boost ($\alpha$ tăng lên $0.82$ khi góc lệch $> 28^\circ$) phản ứng nhanh, ôm sát góc cua thực tế.

### 2. Các ứng viên cải thiện hành vi trong điều kiện nào?
- **DBSCAN:** Hữu ích trong việc gộp các điểm dừng chân kéo dài. Khi áp dụng tại session `session_5`, DBSCAN phát hiện 2 cụm dừng chân và thu gọn 24.01 m dao động đường vẽ.
- **EKF-Only:** Tạo ra vector vận tốc liên tục, mượt mà hơn về mặt hình học dọc theo các đoạn đường thẳng.

### 3. Những ứng viên nào bị thoái lui (Regression) và thoái lui ở khía cạnh nào?
- **ỨNG VIÊN D+Opt THOÁI LUI NGHIÊM TRỌNG:**
  - Tại session `session_7` (có 61 lần mất sóng $>5\text{s}$), máy trạng thái FSM chuyển trạng thái quá mức (44 lần S2, 44 lần S3, 48 lần S5).
  - Cơ chế bắc cầu khoảng trống (gap bridging) và bù thiếu hụt góc rẽ đã khuếch đại nhiễu, dẫn đến **thổi phồng quãng đường lên thêm +1,164.62 m (+9.52% so với App Baseline, và +12.19% so với Current Display)**!
  - Quan sát replay này là tín hiệu cảnh báo; quyết định NO-GO Phase 5 dựa trên holdout synthetic độc lập.
- **EKF-Only có độ trễ quán tính (Inertial Lag):** Do duy trì trạng thái vận tốc $(v_x, v_y)$, EKF có xu hướng văng nhẹ ra ngoài tại các góc rẽ vuông $90^\circ$ tốc độ cao trước khi hội tụ về hướng mới.

### 4. Cần những bằng chứng nào trước khi quyết định thay đổi thuật toán?
1. **Đường chuẩn Trắc địa Độc lập (Survey-Grade Ground Truth):** Cần tối thiểu 3 bài chạy thực nghiệm với thiết bị định vị vệ tinh 2 tần số RTK-GNSS (sai số $< 2\text{ cm}$) để đo đạc sai số RMSE thực tế.
2. **Đo đạc Tiêu thụ Pin Ngoại vi (Hardware Battery Drain):** Thử nghiệm tiêu hao năng lượng liên tục 2 giờ trên thiết bị vật lý iOS và Android.
3. **Thử nghiệm Đa thiết bị Song song:** Chạy đồng thời 2 thiết bị trên cùng một hành trình để so sánh đối đầu trực tiếp.

---

## 6. Quy trình Thanh tẩy Lịch sử Git Khỏi Dữ liệu Nhạy cảm (Remediation Plan)

Xem [runbook RG-F4](../operations/rg_f4_sensitive_history_remediation_runbook.md). SHA baseline an toàn là `3644e8a866a4e86a4f7e9cf1dd1c4cca7f489284`. Bản chạy thử chỉ thực hiện trong clone tạm; GitHub vẫn giữ PR refs và cache. Phải dừng ở cổng phê duyệt Chủ sở hữu trước mọi cập nhật remote.

---

## 7. Khuyến nghị Quản trị Kỹ thuật (Governance Recommendation)

- **Trạng thái Quản trị:** **SECURITY HOLD**.
- **Quy tắc Vận hành:**
  1. **DUY TRÌ NGUYÊN TRẠNG THUẬT TOÁN SẢN XUẤT HIỆN TẠI (Fixed-Alpha + Turn-Boost).** Không thay đổi thuật toán trên production.
  2. **BÁC BỎ HOÀN TOÀN D+Opt** cho môi trường sản xuất.
  3. Giữ PR #11 ở trạng thái **DRAFT**. Tuyệt đối không merge vào `main`.
  4. Thực hiện quy trình thanh tẩy lịch sử Git khi Chủ sở hữu cho phép.
