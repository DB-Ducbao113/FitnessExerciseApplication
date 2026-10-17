# Phase 5 Design Proposal — GPS Gap Recovery State Machine cho EKF 4-State

**Trạng thái tài liệu:** ĐỀ XUẤT KIẾN TRÚC THUẦN TÚY (DESIGN PROPOSAL ONLY) — **CHƯA ĐƯỢC ỦY QUYỀN TRIỂN KHAI (NOT AUTHORIZED)**<br>
**Nhánh Git:** `EKF+DBSCAN`<br>
**Tác giả:** Đội ngũ Nghiên cứu Thuật toán Aetron (AI Engineering Assistant & Core Team)<br>
**Mục tiêu:** Thiết lập cơ chế máy trạng thái phục hồi (State Machine) tất định, có nhận thức vật lý nhằm triệt tiêu hiện tượng "Khóa chết từ chối ngoại lai" (Latched Outlier Rejection Lockout) khi mất tín hiệu GPS hoặc mất góc hướng (heading dropout), bảo đảm an toàn hiệp phương sai và chống sốc quãng đường.<br>
**Ràng buộc tối cao:** 
- **KHÔNG** chỉnh sửa mã nguồn EKF core hay các tham số đã khóa của Phase 3 và Phase 4A.
- **KHÔNG** sửa đổi mã nguồn production (`lib/main.dart`, `GpsSmoothingService`, `LocalDB`).
- **KHÔNG** sửa đổi DBSCAN.
- **KHÔNG** sáp nhập (merge) hay triển khai (deploy).

---

## 1. Bối Cảnh Kỹ Thuật & Cơ Chế Lỗi Cần Khắc Phục (Root Cause Forensics)

### 1.1. Hiện Tượng Khóa Chết Từ Chối Ngoại Lai (Latched Rejection Lockout)
Trong quá trình nghiệm thu Phase 4A trên 108 kịch bản lập lịch toàn vẹn (Protocol 2 All-Scheduled Set), mô hình EKF 4-state `[east, north, speed, heading]` đạt kết quả xuất sắc trên 81 kịch bản có cảm biến hướng (RMSE $2.85 - 6.01\text{ m}$), nhưng ghi nhận sai số cực đại trên các kịch bản mất góc hướng (heading dropout, điển hình là Scenario 61 với All-Scheduled RMSE = $593.98\text{ m}$ và P95 = $1,128\text{ m}$).

Phân tích nguyên nhân gốc rễ đã xác định cơ chế lỗi toán học:
1. **Thiếu kênh quan trắc hướng độc lập:** Khi thiết bị di động không cung cấp góc la bàn (`headingDeg == null`), ma trận quan sát suy biến về vị trí $H = \begin{bmatrix} 1 & 0 & 0 & 0 \\ 0 & 1 & 0 & 0 \end{bmatrix}$. Góc hướng chỉ có thể được cập nhật gián tiếp thông qua độ lệch vị trí (innovation) $\tilde{y}$ nhờ hiệp phương sai chéo $P_{4, 1:2}$ trong ma trận độ lợi Kalman $K$.
2. **Loại bỏ đo lường tức thời tại khúc cua:** Khi xe thực hiện khúc cua gắt (ví dụ cua $160^\circ$ tại giây thứ 12 trong Kịch bản 61), vị trí đo thực tế của GPS rẽ sang hướng mới trong khi bộ lọc dự báo tiếp tục quán tính thẳng. Độ lệch vị trí $\tilde{y}$ vượt quá ngưỡng thống kê Chi-Square ($NIS = 18.5 \ge G_2 = 13.816$), khiến mẫu bị phân loại là `rejected`.
3. **Mất vòng lặp phản hồi (Feedback Loss):** Khi một mẫu bị từ chối, bộ lọc bỏ qua bước cập nhật (Update Step) và chỉ thực thi bước dự báo động học quán tính (Predict-only). Vị trí dự báo tiếp tục lao thẳng theo hướng cũ.
4. **Phân kỳ đơn điệu (Monotonic Divergence):** Ở chu kỳ lấy mẫu tiếp theo, khoảng cách giữa xe thực tế và vị trí dự báo quán tính càng xa hơn, dẫn đến $NIS$ tiếp tục bùng nổ ($33.2 \to 53.2 \to \dots$). EKF rơi vào trạng thái khóa chết vĩnh viễn (rejection lockout) suốt 294 mẫu liên tiếp (588 giây), trôi dạt ra xa $> 4.800\text{ m}$ trong khi xe đạp chạy vòng lặp trên thực tế.

### 1.2. Tại Sao Không Thể Đơn Thuần Nới Ngưỡng NIS?
Nếu chỉ đơn giản mở rộng ngưỡng $G_2$ hoặc ép buộc chấp nhận mẫu sau $N$ lần từ chối, bộ lọc sẽ lập tức bị kéo sập bởi các xung nhiễu đa đường (multipath spike 50–100 m) hoặc vị trí phản xạ khi xe vừa ra khỏi hầm. Việc tiếp nhận một điểm đột biến cô lập sẽ:
- Bẻ gãy tính chất nửa xác định dương (PSD) của ma trận hiệp phương sai $P$.
- Tạo ra bước nhảy vận tốc phi vật lý ($> 100\text{ km/h}$).
- Làm phình to quãng đường tích lũy của bài tập (phantom workout distance).

**Kết luận:** Cần một máy trạng thái phục hồi đa điểm đo (Multi-Fix Gap Recovery State Machine) hoạt động nhân quả, có trễ (hysteresis) và có kiểm chứng động học chặt chẽ.

---

## 2. Kiến Trúc Máy Trạng Thái 6 Cấp Độ (The 6-State Recovery Machine)

Hệ thống phục hồi EKF Phase 5 được thiết kế dưới dạng máy trạng thái hữu hạn (FSM) gồm 6 trạng thái độc lập:

```text
       ┌────────────────────────────────────────────────────────┐
       │                                                        │
       ▼                                                        │
┌──────────────┐     N_reject >= 3      ┌──────────────────┐    │
│      S0      │ ─────────────────────> │        S1        │    │
│    NORMAL    │ <───────────────────── │    SUSPECTED     │    │
│   TRACKING   │      NIS < G1 (x1)     │     DEGRADED     │    │
└──────────────┘                        └──────────────────┘    │
                                                  │             │
                                    N_reject >= 5 │ dt >= 5s    │
                                                  ▼             │
┌──────────────┐   K >= 3 Valid Fixes   ┌──────────────────┐    │
│      S4      │ <───────────────────── │        S2        │    │
│  VALIDATED   │                        │     LOSS OF      │    │
│   RE-ANCHOR  │                        │       LOCK       │    │
└──────────────┘                        └──────────────────┘    │
       │                                          ▲             │
       │ Re-anchor                              │ Validation    │
       │ Execution                              │ Fails         │
       ▼                                          │             │
┌──────────────┐     Single Outlier               │             │
│      S5      │ ─────────────────────────────────┴─────────────┘
│  SAFE RESET  │
│  & RET-TRACK │ ───────────────────────────────────────────────┘
└──────────────┘             Success Return to Tracking
```

### 2.1. Chi tiết Định nghĩa Các Trạng thái (State Definitions)

| Mã | Tên Trạng Thái | Ý Nghĩa Vận Hành | Hành Vi Toán Học của EKF |
|:---:|---|---|---|
| **S0** | **Normal Tracking** | GPS khóa tốt, độ chính xác cao, chuyển động ổn định. | Thực hiện chu trình EKF chuẩn: Predict $\to$ NIS Gating $\to$ Measurement Update ($R$ thích ứng). |
| **S1** | **Suspected Degraded GPS** | Xuất hiện từ chối ngoại lai cục bộ hoặc độ chính xác suy giảm ngắn hạn. | Thực thi Predict-Only. Bật bộ đếm từ chối $N_{\text{reject}}$. Nếu mẫu kế tiếp có $NIS < G_1$ ($5.991$), quay về **S0** ngay lập tức. |
| **S2** | **Loss of Lock** | Mất tín hiệu hoàn toàn hoặc bộ lọc đã phân kỳ khỏi quỹ đạo thực tế. | Đình chỉ cập nhật Kalman thông thường. Đóng băng góc hướng ước lượng. Kích hoạt bộ đệm ứng viên tái bắt sóng (Candidate Buffer). |
| **S3** | **Candidate Reacquisition** | Thu thập chuỗi điểm đo GPS thô liên tiếp để kiểm chứng tính nhất quán. | Điểm đo không đưa vào EKF state mà nạp vào bộ đệm trượt $K$-điểm ($K \ge 3$). Kiểm tra ràng buộc vận tốc và gia tốc liên điểm. |
| **S4** | **Validated Re-Anchor** | Chuỗi $K$ điểm đo vượt qua toàn bộ các kiểm định động học vật lý. | Xác nhận điểm neo tái định vị hợp lệ. Xác định vector vận tốc và góc hướng Course-Over-Ground (COG) từ chuỗi ứng viên. |
| **S5** | **Safe Reset & Return to Tracking** | Tái khởi tạo trạng thái và ma trận hiệp phương sai an toàn. | Đặt lại vị trí, tốc độ, góc hướng; khởi tạo lại ma trận $P$ theo chuẩn PSD; triệt tiêu cross-covariance; chuyển về **S0**. |

---

## 3. Quy Tắc Kỹ Thuật Chi Tiết (Technical Specifications)

### 3.1. Tiêu Chí Chuyển Trạng Thái & Hạn Thời Gian (Transition Triggers & Timeout Rules)

1. **Chuyển từ S0 (Normal) sang S1 (Suspected Degraded):**
   - Kích hoạt khi: Số lần bị NIS Gating từ chối liên tiếp $N_{\text{reject}} \ge 3$ HOẶC khoảng cách thời gian giữa hai mẫu hợp lệ $\Delta t \ge 3.0\text{ s}$.
   - Trễ phục hồi (Hysteresis): Chỉ cần duy nhất $1$ mẫu có $NIS < G_1 = 5.991$ với độ chính xác $\text{acc} \le 12.0\text{ m}$ là quay về **S0**.

2. **Chuyển từ S1 (Suspected Degraded) sang S2 (Loss of Lock):**
   - Kích hoạt khi: $N_{\text{reject}} \ge 5$ liên tiếp HOẶC thời gian gián đoạn tín hiệu $\Delta t \ge 5.0\text{ s}$ HOẶC độ lệch vị trí tức thời $||\tilde{y}|| > D_{\max} = \max(30\text{ m}, v_{\text{est}} \cdot \Delta t + 3\sigma_{\text{pos}})$.
   - Tại thời điểm vào **S2**: Xác nhận mất khóa bám vết; xóa rỗng bộ đệm ứng viên (`candidate_buffer.clear()`).

### 3.2. Cửa Sổ Xác Thực Đa Điểm Đo (Multi-Fix Validation Window, $K \ge 3$)

Khi ở trạng thái **S2 (Loss of Lock)**, hệ thống tuyệt đối không tái neo ngay tại điểm GPS đầu tiên nhận được. Thay vào đó, kích hoạt quy trình xác thực đa điểm:

1. **Kích thước bộ đệm:** $K = 3$ mẫu GPS thô liên tiếp $(p_1, t_1), (p_2, t_2), (p_3, t_3)$.
2. **Tiêu chuẩn gia nhập bộ đệm (Admission Criteria):**
   - Báo cáo sai số bán kính: $\text{acc}_i \le 20.0\text{ m}$.
   - Khoảng cách thời gian hợp lý: $0.4\text{ s} \le \Delta t_{i, i-1} \le 2.5\text{ s}$.
3. **Kiểm tra Tính Hợp Lý Động Học Cặp Điểm (Pairwise Kinematic Plausibility):**
   - **Giới hạn vận tốc từng đoạn:**
     $$v_{i, i-1} = \frac{\text{HaversineDistance}(p_i, p_{i-1})}{\Delta t_{i, i-1}} \le V_{\max}$$
     Với xe đạp (cycling): $V_{\max} = 20.0\text{ m/s}$ ($72.0\text{ km/h}$). Nếu $v_{i, i-1} > V_{\max}$, loại bỏ mẫu vi phạm và xóa bộ đệm.
   - **Giới hạn gia tốc chuyển tiếp:**
     $$a_{i} = \frac{|v_{i, i-1} - v_{i-1, i-2}|}{\Delta t_{i, i-1}} \le A_{\max} = 4.0\text{ m/s}^2$$
4. **Kiểm tra Tính Đồng Hướng Không Gian (Spatial Collinearity & Directional Consistency):**
   - Độ dịch chuyển tổng thể của chuỗi 3 điểm: $D_{\text{span}} = \text{Distance}(p_1, p_3)$.
   - Nếu xe đang di chuyển ($v \ge 2.0\text{ m/s}$), góc Course-Over-Ground giữa vector $(p_1 \to p_2)$ và $(p_2 \to p_3)$ không được quay ngược $180^\circ$ đột ngột trong khoảng thời gian $< 2\text{ s}$ trừ khi vận tốc cực thấp ($< 1.0\text{ m/s}$).

### 3.3. Bảo Vệ Chống Điểm Đột Biến Cô Lập & Tấn Công Giả Mạo (Anti-Spike & Spoofing Protection)

- **Nguyên tắc "Spike Cô Lập Bị Hủy":** Nếu một xung nhiễu đa đường $100\text{ m}$ xuất hiện (mẫu $p_1$), nó được lưu tạm vào vị trí đầu tiên của bộ đệm. Mẫu kế tiếp $p_2$ (quay về vị trí thực) sẽ tạo ra vận tốc ảo $v_{1,2} = \frac{100\text{ m}}{1\text{ s}} = 100\text{ m/s} > 20\text{ m/s}$. Ngay lập tức, kiểm định vận tốc kích hoạt: xóa $p_1$, đặt $p_2$ làm ứng viên số 1 mới. Điểm đột biến bị triệt tiêu hoàn toàn, không thể gây ảnh hưởng đến bộ lọc.
- **Nguyên tắc "Không Nhảy Quãng Đường Ảo" (No Phantom Distance Accumulation):**
  - Trong quá trình trôi dạt quán tính ở **S2**, bộ lọc KHÔNG ghi nhận khoảng cách trôi dạt này vào tổng quãng đường bài tập (`accumulated_distance`).
  - Khi thực hiện Re-Anchor tại **S5**, khoảng cách Euclid giữa tọa độ ước lượng phân kỳ cuối cùng của EKF và tọa độ tái neo $p_{\text{anchor}}$ **TUYỆT ĐỐI KHÔNG ĐƯỢC CỘNG VÀO BÀI TẬP**.
  - Đoạn gián đoạn được đánh dấu là `GapSegment`. Nếu $\Delta t_{\text{gap}} \le 10\text{ s}$ và vận tốc hợp lý, quãng đường bù đắp được nội suy bằng đường thẳng dây cung giữa điểm khóa cuối cùng và điểm tái neo; nếu $\Delta t_{\text{gap}} > 10\text{ s}$, quãng đường gián đoạn bằng $0$.

### 3.4. Xử Lý Tái Khởi Tạo Hiệp Phương Sai An Toàn (Covariance Reset & PSD Enforcement)

Khi chuyển từ **S4 (Validated Re-Anchor)** sang **S5 (Safe Reset)**, trạng thái $x$ và hiệp phương sai $P$ được cấu trúc lại như sau:

1. **Vector Trạng Thái $x \in \mathbb{R}^4$:**
   - $x[0] = \text{East}_{\text{anchor}}$ (tính từ điểm $p_3$ của chuỗi ứng viên).
   - $x[1] = \text{North}_{\text{anchor}}$.
   - $x[2] = v_{\text{anchor}} = \text{clamp}\left(\frac{\text{Distance}(p_1, p_3)}{t_3 - t_1}, 0.0, V_{\max}\right)$.
   - $x[3] = \psi_{\text{anchor}} = \begin{cases} \text{Bearing}(p_1, p_3) & \text{nếu } \text{Distance}(p_1, p_3) \ge 3.0\text{ m} \\ \text{heading}_{\text{raw}} & \text{nếu có sensor heading} \\ x_{\text{prev}}[3] & \text{nếu đứng yên} \end{cases}$

2. **Ma Trận Hiệp Phương Sai $P \in \mathbb{R}^{4 \times 4}$:**
   - Để ngăn chặn việc ma trận hiệp phương sai mang theo tương quan chéo sai lệch từ giai đoạn phân kỳ, toàn bộ các phần tử ngoài đường chéo bị triệt tiêu về $0$:
     $$P_{\text{reset}} = \begin{bmatrix} \sigma_{\text{pos}}^2 & 0 & 0 & 0 \\ 0 & \sigma_{\text{pos}}^2 & 0 & 0 \\ 0 & 0 & \sigma_{\text{speed}}^2 & 0 \\ 0 & 0 & 0 & \sigma_{\text{heading}}^2 \end{bmatrix}$$
   - Trong đó:
     - $\sigma_{\text{pos}}^2 = \max(25.0\text{ m}^2, \text{acc}_3^2)$ (đảm bảo độ bất định vị trí đủ rộng để dung nạp mẫu tiếp theo).
     - $\sigma_{\text{speed}}^2 = 4.0\text{ m}^2/\text{s}^2$ (độ lệch chuẩn $2\text{ m/s}$).
     - $\sigma_{\text{heading}}^2 = \begin{cases} (15^\circ \cdot \frac{\pi}{180})^2 \approx 0.068\text{ rad}^2 & \text{nếu COG hợp lệ} \\ (60^\circ \cdot \frac{\pi}{180})^2 \approx 1.096\text{ rad}^2 & \text{nếu mất hướng / đứng yên} \end{cases}$
   - Kiểm tra điều kiện xác định dương: $P = \frac{1}{2}(P + P^T)$, kiểm tra trị riêng $\lambda_{\min}(P) > 0$. Điều này bảo đảm $100\%$ PSD, không bao giờ sinh ra ma trận suy biến hay NaN.

### 3.5. Xử Lý Khuyết Tật Mất Góc Hướng (Heading Dropout Handling)

- Khi cảm biến la bàn bị mất hoàn toàn (`headingDeg == null`), hệ thống kích hoạt chế độ **Kinematic Heading Observer**:
  - Tận dụng vector dịch chuyển giữa $p_1 \to p_3$ trong bộ đệm ứng viên để khởi tạo góc hướng ban đầu cho EKF.
  - Sau khi Safe Reset, hệ thống tạm thời tăng nhiễu quá trình góc hướng $Q_{\text{heading}}$ trong $5$ mẫu đầu tiên ($Q_{\text{heading}} \times 4.0$) để thuật toán thích ứng nhanh với các góc rẽ tiếp theo mà không bị bẫy trong ngưỡng NIS Gating.

---

## 4. Kế Hoạch Đo Kiểm & Tiêu Chí Nghiệm Thu Cho Phase 5 (Khi Được Phê Chuẩn)

Khi Chủ dự án chính thức ban hành lệnh bắt đầu triển khai Phase 5, bộ tiêu chuẩn nghiệm thu độc lập sau đây sẽ được áp dụng:

1. **Khắc Phục Hoàn Toàn Kịch Bản Khóa Chết Scenario 61:**
   - Trên cùng dữ liệu đầu vào của Kịch bản 61, hệ thống phải phát hiện mất khóa tại bước $s = 8$ ($N_{\text{reject}} = 3$), hoàn tất tái neo tại bước $s = 11$ ($K = 3$ fixes hợp lệ).
   - Sai số vị trí cực đại giảm từ **$4.887\text{ m}$ xuống $< 15.0\text{ m}$**.
   - Ma trận hiệp phương sai duy trì $100\%$ hữu hạn và PSD.
2. **Kháng Nhiễu Đột Biến (Adversarial Robustness):**
   - Kịch bản tiêm nhiễu xung cô lập $100\text{ m}$ trong lúc đang mất tín hiệu: FSM phải giữ nguyên trạng thái hoặc hủy bộ đệm ứng viên, tuyệt đối không được kích hoạt Re-Anchor theo điểm nhiễu.
3. **Cổng Chất Lượng Toàn Tuyến (108 Scenarios Benchmark):**
   - **All-Scheduled Protocol 2 RMSE:** Giảm từ **$593.98\text{ m}$ xuống $< 8.0\text{ m}$** (tương đương hoặc vượt trội so với Production Baseline $6.26\text{ m}$).
   - **All-Scheduled Protocol 2 P95:** Giảm từ **$1,128.00\text{ m}$ xuống $< 15.0\text{ m}$**.
   - **Operational Availability:** Đạt $\ge 98.5\%$.
   - **Phantom Distance:** Tuyệt đối không có hiện tượng sai số quãng đường vọt lên do bước nhảy tái neo.

---

## 5. Kết Luận & Dừng Hoạt Động Chờ Phê Duyệt (Stop for Owner Approval)

- Tài liệu đề xuất thiết kế Phase 5 này hoàn tất việc định nghĩa kiến trúc lý thuyết giải quyết triệt để vấn đề "Khóa chết từ chối ngoại lai khi mất heading" được phát hiện trong đợt điều tra nguyên nhân gốc rễ Phase 4A.
- **Tuân thủ kỷ luật dự án:**
  - Không có bất kỳ dòng code thuật toán nào của Phase 5 được cài đặt vào hệ thống.
  - Mã nguồn production và DBSCAN hoàn toàn giữ nguyên 100%.
  - Tiến trình dừng tại đây và chờ phê duyệt chính thức từ Chủ dự án trước khi có bất kỳ hành động tiếp theo nào.
