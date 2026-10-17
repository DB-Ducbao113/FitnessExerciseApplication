# Phase 5 Design Proposal & Acceptance Plan — GPS Gap Recovery State Machine cho EKF 4-State

**Trạng thái tài liệu:** ĐỀ XUẤT KIẾN TRÚC & KẾ HOẠCH NGHIỆM THU (DESIGN PROPOSAL & ACCEPTANCE PLAN) — **CHƯA ĐƯỢC ỦY QUYỀN TRIỂN KHAI (NOT AUTHORIZED)**<br>
**Nhánh Git:** `EKF+DBSCAN`<br>
**Verified HEAD:** `040fcdfa87799c291470030c79f7e33045bff153`<br>
**Tác giả:** Đội ngũ Nghiên cứu Thuật toán Aetron (AI Engineering Assistant & Core Team)<br>
**Mục tiêu:** Thiết lập kiến trúc máy trạng thái phục hồi (FSM) toàn diện, bảng chuyển trạng thái tường minh (S0–S5), cơ chế tái bắt sóng an toàn đa tầng (chống cụm multipath & spoofing), quy tắc hạch toán quãng đường minh bạch (tách biệt overcount/undercount) và ma trận kiểm thử nghiệm thu tất định cho Phase 5.<br>
**Ràng buộc tối cao:** 
- **KHÔNG** chỉnh sửa mã nguồn EKF core hay các tham số đã khóa của Phase 3 và Phase 4A.
- **KHÔNG** sửa đổi mã nguồn production (`lib/main.dart`, `GpsSmoothingService`, `LocalDB`).
- **KHÔNG** sửa đổi DBSCAN.
- **KHÔNG** bắt đầu triển khai Phase 5 trước khi có phê chuẩn chính thức (GO/HOLD) từ Chủ dự án.

---

## 1. Bối Cảnh Kỹ Thuật & Cơ Chế Khóa Chết Cần Khắc Phục (Root Cause Isolation)

### 1.1. Bản Chất Toán Học của Hiện Tượng Khóa Chết (Latched Outlier Lockout)
Trong mô hình EKF 4-state vận tốc/góc hướng `[east, north, speed, heading]`, khi thiết bị di động không cung cấp góc la bàn (`headingDeg == null`), ma trận đo lường suy biến thành:
$$H = \begin{bmatrix} 1 & 0 & 0 & 0 \\ 0 & 1 & 0 & 0 \end{bmatrix}$$
Góc hướng ước lượng $\hat{\psi}$ chỉ có thể được cập nhật gián tiếp qua độ lệch vị trí (innovation) $\tilde{y} = z_{\text{pos}} - h(\hat{x})$ thông qua các phần tử hiệp phương sai chéo $P_{4, 1:2}$ trong ma trận Kalman gain:
$$K = P H^T S^{-1}$$

Khi xe đạp thực hiện khúc cua gắt trong lúc mất heading (điển hình: khúc cua $160^\circ$ tại giây 12 trong Kịch bản 61):
1. **Bùng nổ Innovation Tức Thời:** Vị trí GPS đo thực tế rẽ ngoặt trong khi EKF dự báo quán tính thẳng, đẩy độ lệch chuẩn hóa $NIS = \tilde{y}^T S^{-1} \tilde{y} = 18.5$ vượt quá ngưỡng Chi-Square loại bỏ ($G_2 = 13.816$).
2. **Cắt Đứt Vòng Phản Hồi (Feedback Severance):** Bộ lọc bỏ qua bước cập nhật vị trí và góc hướng, rơi vào chế độ dự báo quán tính thuần túy (predict-only).
3. **Phân Kỳ Đơn Điệu (Monotonic Lockout):** Ở các chu kỳ kế tiếp ($t = 14\text{s}, 16\text{s}, \dots$), xe đạp tiếp tục di chuyển trên đường mới, trong khi EKF quán tính thẳng theo hướng cũ. Khoảng cách giữa vị trí thực và vị trí ước lượng ngày càng mở rộng ($NIS = 33.2 \to 53.2 \to \dots$).
4. **Hậu Quả:** EKF bị khóa chết trong trạng thái từ chối suốt 294 bước liên tiếp (588 giây), dẫn đến sai số vị trí trôi dạt $> 4.887\text{ m}$ (All-Scheduled RMSE = $593.98\text{ m}$), dù Baseline sản xuất vẫn bám sát xe với sai số $< 18\text{ m}$.

---

## 2. Task 2 — Kiến Trúc & Bảng Chuyển Trạng Thái Tường Minh (S0 – S5)

Máy trạng thái phục hồi EKF Phase 5 gồm 6 trạng thái độc lập được kiểm soát bằng bộ đếm tất định, bộ đếm thời gian và cơ chế trễ (hysteresis).

```text
       ┌────────────────────────────────────────────────────────────────────────┐
       │                                                                        │
       ▼                                                                        │
┌──────────────┐          E01: N_rej >= 3 || dt >= 3.0s        ┌──────────────┐ │
│      S0      │ ────────────────────────────────────────────> │      S1      │ │
│    NORMAL    │ <──────────────────────────────────────────── │  SUSPECTED   │ │
│   TRACKING   │           E10: NIS < G1 (x2 clean fixes)      │   DEGRADED   │ │
└──────────────┘                                               └──────────────┘ │
                                                                      │         │
                                        E12: N_rej >= 5 || dt >= 5.0s │         │
                                        || dist_err > D_max           ▼         │
┌──────────────┐          E34: K >= 3 Valid Candidates         ┌──────────────┐ │
│      S4      │ <──────────────────────────────────────────── │      S2      │ │
│  VALIDATED   │                                               │   LOSS OF    │ │
│  RE-ANCHOR   │ ──┐                                           │     LOCK     │ │
└──────────────┘   │                                           └──────────────┘ │
                   │ E45: Kinematic Consistency Confirmed             │         │
                   ▼                                                  │         │
┌──────────────┐   │                                                  │         │
│      S5      │ ──┘                                                  │         │
│  SAFE RESET  │ ──> S0 (Success Reset & Return to Tracking) ─────────┘         │
└──────────────┘ ──> S2 (Post-Reset Probe Fails within 3 fixes) ────────────────┘
```

### 2.1. Bảng Chuyển Trạng Thái Chi Tiết (Explicit Transition Matrix)

| Trạng Thái Hiện Tại | Trạng Thái Đích | Mã Sự Kiện | Điều Kiện Kích Hoạt (Entry/Exit Conditions) | Hành Động Thực Thi (Actions) & Trạng Thái Hiệp Phương Sai ($P$) |
|:---:|:---:|:---:|---|---|
| **S0**<br>(Normal Tracking) | **S1**<br>(Suspected Degraded) | `E01` | **Điều kiện:** $N_{\text{reject}} \ge 3$ liên tiếp **HOẶC** khoảng cách thời gian giữa 2 mẫu hợp lệ $\Delta t_{\text{gap}} \ge 3.0\text{ s}$.<br>*Không chuyển nếu chỉ có 1 hoặc 2 mẫu bị từ chối.* | - Chuyển sang chế độ dự báo quán tính (Predict-only).<br>- Khởi động bộ đếm thời gian trôi dạt $t_{\text{degraded}}$.<br>- Hiệp phương sai $P$ tiếp tục lan truyền động học quán tính $P = F P F^T + Q$. |
| **S1**<br>(Suspected Degraded) | **S0**<br>(Normal Tracking) | `E10` | **Điều kiện trễ (Hysteresis):** Nhận được **2 mẫu GPS liên tiếp** đạt chuẩn:<br>- $NIS < G_1 = 5.991$.<br>- Reported accuracy $\le 12.0\text{ m}$.<br>- Vận tốc biến thiên $|v - \hat{v}| \le 3.0\text{ m/s}$. | - Reset bộ đếm từ chối $N_{\text{reject}} = 0$.<br>- Trở về quy trình cập nhật Kalman chuẩn.<br>- Cập nhật Joseph form bảo đảm PSD. |
| **S1**<br>(Suspected Degraded) | **S2**<br>(Loss of Lock) | `E12` | **Điều kiện:** $N_{\text{reject}} \ge 5$ liên tiếp **HOẶC** thời gian gián đoạn $\Delta t_{\text{gap}} \ge 5.0\text{ s}$ **HOẶC** khoảng cách lệch $\|\tilde{y}\| > D_{\max} = \max(30\text{ m}, \hat{v} \cdot \Delta t + 3\sigma_{\text{pos}})$. | - Khai báo mất khóa bám vết.<br>- Đóng băng góc hướng ước lượng hiện tại $\hat{\psi}$.<br>- Xóa rỗng và mở Bộ đệm Ứng viên (Candidate Buffer).<br>- Đình chỉ tích lũy quãng đường bài tập. |
| **S2**<br>(Loss of Lock) | **S3**<br>(Candidate Reacquisition) | `E23` | **Điều kiện:** Xuất hiện mẫu GPS thô $p_i$ có báo cáo sai số $\text{acc}_i \le 20.0\text{ m}$ và $0.4\text{ s} \le \Delta t \le 2.5\text{ s}$. | - Nạp $p_i$ vào Candidate Buffer.<br>- Khởi động đồng hồ sống của ứng viên: $T_{\text{buf\_life}} \le 6.0\text{ s}$.<br>- EKF tiếp tục đóng băng vị trí cuối cùng được chấp nhận. |
| **S3**<br>(Candidate Reacquisition) | **S2**<br>(Loss of Lock) | `E32` | **Điều kiện vi phạm ứng viên (Candidate Invalidation):**<br>- Mẫu kế tiếp có $v_{k, k-1} > 20.0\text{ m/s}$ ($72\text{ km/h}$).<br>- Hoặc gia tốc $a_k > 4.0\text{ m/s}^2$.<br>- Hoặc $T_{\text{buf\_life}} > 6.0\text{ s}$ mà chưa đủ $K=3$ điểm.<br>- Hoặc phát hiện cụm tĩnh tại nhiễu động. | - Hủy toàn bộ điểm trong Candidate Buffer (`buffer.clear()`).<br>- Trở về chờ đợi trong **S2**.<br>- Tuyệt đối không tái neo theo điểm ngoại lai. |
| **S3**<br>(Candidate Reacquisition) | **S4**<br>(Validated Re-Anchor) | `E34` | **Điều kiện:** Thu thập đủ **$K = 3$ mẫu liên tiếp** thỏa mãn đồng thời toàn bộ các tiêu chuẩn kiểm định động học (xem Mục 3). | - Đóng băng $3$ điểm ứng viên làm mốc tái neo.<br>- Tính toán vector vận tốc trung bình và góc hướng Course-Over-Ground (COG). |
| **S4**<br>(Validated Re-Anchor) | **S5**<br>(Safe Reset) | `E45` | **Điều kiện:** Không có mâu thuẫn cảm biến bổ trợ (sensor evidence không phủ định vị trí tái neo). | - Thực thi tái cấu trúc Vector Trạng Thái $x_{\text{new}}$.<br>- Thực thi Tái Khởi Tạo Hiệp Phương Sai $P_{\text{reset}}$ (Mục 2.2).<br>- Xử lý quãng đường gián đoạn (Mục 4). |
| **S5**<br>(Safe Reset) | **S0**<br>(Normal Tracking) | `E50` | **Điều kiện:** Điểm đo ngay sau Reset ($s = 1$) có $NIS < G_2 = 13.816$ và vận tốc nhất quán. | - Khôi phục hoàn toàn chế độ Normal Tracking.<br>- Đặt hệ số $Q_{\text{heading}} \times 4.0$ trong $5$ mẫu kế tiếp để bám vết nhanh. |
| **S5**<br>(Safe Reset) | **S2**<br>(Loss of Lock) | `E52` | **Điều kiện (Reset Thất Bại):** Mẫu kế tiếp ngay sau Reset bị loại bỏ ($NIS \ge G_2$), chứng tỏ Re-Anchor rơi vào cụm phản xạ cục bộ. | - Hủy trạng thái Re-Anchor.<br>- Quay trở lại **S2** để tìm kiếm chuỗi ứng viên mới.<br>- Không cho phép lặp lại Re-Anchor tại cùng vị trí trong vòng $10\text{ s}$. |

---

### 2.2. Chi Tiết Toán Học Cho S5 (Safe Reset & Covariance Reinitialization)

Khi tiến hành Safe Reset tại **S5**, toàn bộ trạng thái và ma trận hiệp phương sai được cấu trúc lại nhằm loại bỏ hoàn toàn các tương quan chéo sai lệch tích tụ trong giai đoạn trôi dạt:

1. **Tái thiết Vector Trạng Thái $x_{\text{reset}} \in \mathbb{R}^4$:**
   $$x_{\text{reset}} = \begin{bmatrix} \text{East}(p_3) \\ \text{North}(p_3) \\ v_{\text{cand}} \\ \psi_{\text{cand}} \end{bmatrix}$$
   Trong đó:
   - $p_3$ là điểm đo thứ 3 trong chuỗi ứng viên đã xác thực.
   - $v_{\text{cand}} = \text{clamp}\left(\frac{\text{Haversine}(p_1, p_3)}{t_3 - t_1}, 0.0, 20.0\right)\text{ m/s}$.
   - Góc hướng $\psi_{\text{cand}}$:
     $$\psi_{\text{cand}} = \begin{cases} \text{Bearing}(p_1, p_3) & \text{nếu } \text{Haversine}(p_1, p_3) \ge 3.0\text{ m} \text{ (xe đang di chuyển)} \\ \text{heading}_{\text{raw}} & \text{nếu xe đứng yên nhưng có la bàn} \\ \hat{\psi}_{\text{frozen}} & \text{nếu xe đứng yên và mất la bàn} \end{cases}$$

2. **Tái khởi tạo Ma Trận Hiệp Phương Sai $P_{\text{reset}} \in \mathbb{R}^{4 \times 4}$:**
   Triệt tiêu toàn bộ các phần tử ngoài đường chéo về $0$ để đảm bảo tính độc lập và chống suy biến:
   $$P_{\text{reset}} = \begin{bmatrix} \sigma_{\text{pos}}^2 & 0 & 0 & 0 \\ 0 & \sigma_{\text{pos}}^2 & 0 & 0 \\ 0 & 0 & \sigma_{\text{speed}}^2 & 0 \\ 0 & 0 & 0 & \sigma_{\text{heading}}^2 \end{bmatrix}$$
   Với:
   - $\sigma_{\text{pos}}^2 = \max(25.0\text{ m}^2, \text{acc}_3^2)$ (cho phép bán kính không gian tối thiểu $5\text{ m}$ để dung nạp các mẫu tiếp theo).
   - $\sigma_{\text{speed}}^2 = 4.0\text{ m}^2/\text{s}^2$ (độ lệch chuẩn $2.0\text{ m/s}$).
   - $\sigma_{\text{heading}}^2 = \begin{cases} (15^\circ \cdot \frac{\pi}{180})^2 \approx 0.068\text{ rad}^2 & \text{khi COG $\ge 3\text{ m}$ rõ ràng} \\ (60^\circ \cdot \frac{\pi}{180})^2 \approx 1.096\text{ rad}^2 & \text{khi di chuyển chậm / mất góc hướng} \end{cases}$
   - **Bảo đảm PSD:** Kiểm tra $P = \frac{1}{2}(P + P^T)$ và $\lambda_{\min}(P) > 0$. Ma trận đối xứng và xác định dương $100\%$.

---

## 3. Task 3 — Tái Bắt Sóng An Toàn Đa Tầng (Safe Reacquisition Under Adversarial Conditions)

### 3.1. Phân Tích Rủi Ro: Tại Sao 3 Điểm Nội Bộ Nhất Quán Chưa Đủ Đảm Bảo Tính Xác Thực?
Một giả định ngây thơ cho rằng: *"Nếu có 3 điểm GPS liên tiếp có khoảng cách hợp lý thì đó là vị trí thật"* là **SAI LẦM VÀ NGUY HIỂM**. Trong thực tế đo đạc di động, các tình huống sau có thể tạo ra chuỗi 3 điểm giả mạo nhưng nhất quán nội bộ:
1. **Cụm Đa Đường Đô Thị (Sustained Multipath Cluster):** Đi qua tòa nhà kính cao tầng phản xạ tín hiệu, máy thu GPS nhận chùm sóng dội tạo ra chuỗi 3–5 điểm dịch chuyển song song cách đường thật $40 - 60\text{ m}$ với vận tốc nhìn bề ngoài hoàn toàn "hợp lệ".
2. **Nhiễu Tĩnh Tại Dưới Tán Cây / Đèn Đỏ (Noisy Stationary Fixes):** Xe đạp dừng đèn đỏ ($v = 0$), nhưng GPS nhảy ngẫu nhiên vòng quanh bán kính $15\text{ m}$. Ba điểm liên tiếp có thể tình cờ tạo thành một đoạn thẳng có độ dài $10\text{ m}$ ($v \approx 3\text{ m/s}$) đánh lừa bộ lọc rằng xe đang di chuyển.
3. **Cửa Hầm Đường Bộ (Tunnel Exit Shock):** Sau 60 giây mất tín hiệu hoàn toàn trong hầm, máy thu bắt lại sóng vệ tinh nhưng hình học vệ tinh (GDOP) chưa hội tụ, sinh ra cụm 3 điểm có sai số hệ thống (systematic bias) trôi dần về vị trí thật.
4. **Giả Mạo Vị Trí (Position-Offset Spoofing):** Tín hiệu giả mạo dịch chuyển tức thời vị trí của xe sang tọa độ khác nhưng vẫn duy trì chuỗi xung nhịp 1 Hz đều đặn.
5. **Vận Chuyển Thực Tế Trên Phương Tiện Khác (Genuine Relocation):** Người dùng dừng xe đạp, đưa xe lên tàu điện ngầm hoặc xe bán tải đi qua khoảng mù GPS, sau đó bắt lại tín hiệu ở vị trí cách xa hàng kilomet.

### 3.2. Hệ Thống Kiểm Chứng Đa Tầng Cho Reacquisition (Multi-Layer Verification Safeguards)

Để ngăn chặn tuyệt đối việc tái neo vào các cụm giả mạo, chuỗi ứng viên tại **S3** phải vượt qua **4 lớp phòng thủ độc lập**:

```text
[ Raw GPS Fix Candidate ]
           │
           ▼
┌───────────────────────────────────────────────┐
│ LỚP 1: BỘ LỌC CHẤT LƯỢNG ĐO ĐẠC ĐẦU VÀO      │
│  - acc <= 20m, 0.4s <= dt <= 2.5s             │
│  - Loại bỏ spike đơn lẻ                       │
└───────────────────────────────────────────────┘
           │ Thỏa mãn
           ▼
┌───────────────────────────────────────────────┐
│ LỚP 2: RÀNG BUỘC ĐỘNG HỌC CẶP ĐIỂM LIÊN TIẾP  │
│  - v_pair <= 20 m/s (72 km/h)                 │
│  - a_pair <= 4.0 m/s^2                        │
│  - Loại bỏ bước nhảy tức thời                 │
└───────────────────────────────────────────────┘
           │ Thỏa mãn (Đủ K = 3 điểm)
           ▼
┌───────────────────────────────────────────────┐
│ LỚP 3: KIỂM TRA ĐỒNG BỘ CẢM BIẾN & DI CHUYỂN  │
│  - Nếu v_raw < 1.0 m/s: Cấm tạo COG giả       │
│  - Kiểm tra độ dịch chuyển tổng thể D_span    │
│  - Kiểm định góc đổi hướng liên tiếp          │
└───────────────────────────────────────────────┘
           │ Thỏa mãn
           ▼
┌───────────────────────────────────────────────┐
│ LỚP 4: THỜI GIAN THỬ THÁCH HẬU RE-ANCHOR      │
│  - Probationary Tracking (3 mẫu tiếp theo)    │
│  - Nếu NIS bùng nổ -> Lập tức thu hồi về S2   │
└───────────────────────────────────────────────┘
           │ Vượt qua
           ▼
[ Re-Anchor Được Phê Chuẩn & Trở Về S0 ]
```

#### Chi Tiết Các Tiêu Chuẩn Phòng Thủ:

1. **Phòng Thủ Chống Cụm Tĩnh Tại Nhiễu Động (Stationary Noise Defense):**
   - Nếu cảm biến tốc độ của thiết bị báo cáo $v_{\text{raw}} < 0.8\text{ m/s}$ (hoặc gia tốc kế tích hợp cho thấy thiết bị đứng yên):
   - Chuỗi $K=3$ điểm đo KHÔNG ĐƯỢC PHÉP gán góc hướng di chuyển mới.
   - Trạng thái tốc độ gán $v = 0.0\text{ m/s}$, góc hướng giữ nguyên góc cũ $\hat{\psi}_{\text{prev}}$.
   - Ngưỡng độ lệch tối thiểu: Khoảng cách giữa điểm đầu và điểm cuối $D_{\text{span}} = \text{Haversine}(p_1, p_3)$ phải đạt $\ge 3.0\text{ m}$ thì mới được công nhận là xe có di chuyển thực tế.

2. **Phòng Thủ Chống Cụm Đa Đường Đô Thị (Multipath Cluster Defense):**
   - Đánh giá tính đồng nhất góc (Directional Coherence):
     $$\Delta \theta = |\text{Bearing}(p_1, p_2) - \text{Bearing}(p_2, p_3)|$$
   - Nếu $v \ge 2.0\text{ m/s}$, góc $\Delta \theta$ không được vượt quá $90^\circ$ trong vòng $1.0\text{ s}$ trừ khi tốc độ thấp. Cụm đa đường thường có xu hướng nhảy zic-zac ngược chiều ($\Delta \theta \approx 140^\circ - 180^\circ$) để cố gắng bù trừ sai số; hiện tượng này lập tức làm vô hiệu hóa Candidate Buffer.

3. **Phòng Thủ Chống Bước Nhảy Di Dời Thực Tế (Relocation / Transit Defense):**
   - Khoảng cách từ vị trí ước lượng cuối cùng của EKF đến điểm ứng viên $p_1$ là $\Delta R = \text{Haversine}(\hat{x}_{\text{last}}, p_1)$.
   - Nếu $\Delta R > 150.0\text{ m}$ (khoảng cách dịch chuyển vượt quá phạm vi di chuyển vật lý của xe đạp trong thời gian gián đoạn $\Delta t_{\text{gap}} \cdot V_{\max}$):
     - Xác định đây là hiện tượng di dời bằng phương tiện khác (teleportation/transit).
     - Đánh dấu phân đoạn là `DiscontinuousTransit`.
     - **TUYỆT ĐỐI KHÔNG** cộng khoảng cách $\Delta R$ vào bài tập.
     - Khởi tạo lại toàn bộ phiên bài tập như một chặng đạp mới (Cold Re-Seed).

---

## 4. Task 4 — Quy Tắc Hạch Toán Quãng Đường Toàn Vẹn (Distance Accounting & Integrity)

Sai số quãng đường trong các hệ thống tracking GPS thường bị bóp méo bởi hai thái cực:
- **Overcount (Đếm dư / Quãng đường ma):** Xung nhiễu kéo tọa độ đi xa, hoặc bước nhảy Re-Anchor giữa điểm trôi dạt và điểm thật bị cộng gộp vào tổng quãng đường.
- **Undercount (Đếm thiếu / Cắt góc):** Mất tín hiệu trong hầm hoặc cua gắt khiến quãng đường thực tế bị bỏ quên hoàn toàn.

Phase 5 thiết lập công thức hạch toán phân đoạn minh bạch:

```text
Tổng Quãng Đường Tích Lũy: D_total = D_tracked + D_bridged
```

### 4.1. Hạch Toán Chi Tiết Theo Từng Trạng Thái FSM

| Trạng Thái FSM | Quy Tắc Cộng Quãng Đường ($\Delta d$) | Cơ Chế Chống Quãng Đường Ma (Anti-Phantom) |
|---|---|---|
| **S0 (Normal Tracking)** | $\Delta d_k = \text{Haversine}(\hat{x}_{k-1}, \hat{x}_k)$ dọc theo quỹ đạo đã làm mượt của EKF. | Tốc độ tức thời bị chặn trên $V_{\max} = 20\text{ m/s}$. Nếu $\Delta d_k > V_{\max} \cdot \Delta t$, phần vượt bị cắt bỏ. |
| **S1 (Suspected Degraded)** | $\Delta d_k = \text{clamp}(\hat{v} \cdot \Delta t, 0.0, 1.2 \times v_{\text{last}} \cdot \Delta t)$ dọc theo vector quán tính thẳng. | Giới hạn tối đa $3.0\text{ s}$. Không cho phép tăng tốc trong lúc nghi ngờ suy thoái. |
| **S2 (Loss of Lock)** | **$\Delta d = 0.0\text{ m}$ (ĐÓNG BĂNG HOÀN TOÀN)** | Quãng đường dự báo quán tính trôi dạt ra khoảng không **KHÔNG ĐƯỢC PHÉP CỘNG VÀO BÀI TẬP**. |
| **S3 (Candidate Reacquisition)** | $\Delta d$ được giữ trong **Bộ Đệm Tạm Thời (Escrow Buffer)**. | Chưa cộng vào tổng quãng đường chính thức cho tới khi Re-Anchor được xác thực thành công. |
| **S4 / S5 (Re-Anchor Jump)** | **QUY TẮC CỐT LÕI:** Khoảng cách Euclid giữa điểm trôi dạt cuối cùng của EKF $\hat{x}_{\text{drift}}$ và điểm tái neo $p_{\text{anchor}}$ **TUYỆT ĐỐI KHÔNG CỘNG VÀO QUÃNG ĐƯỜNG**. | Bẻ gãy bước nhảy không gian. Triệt tiêu hoàn toàn $4.800\text{ m}$ quãng đường ma trong Scenario 61. |

### 4.2. Xử Lý Quãng Đường Qua Khe Hở Thời Gian (Bridging Policy for Short vs Long Gaps)

Khi Re-Anchor thành công tại $t_{\text{anchor}}$ sau một khoảng thời gian gián đoạn $\Delta t_{\text{gap}} = t_{\text{anchor}} - t_{\text{last\_valid}}$:

1. **Khe hở ngắn ($\Delta t_{\text{gap}} \le 10.0\text{ s}$):**
   - Khoảng cách đường thẳng: $D_{\text{chord}} = \text{Haversine}(p_{\text{last\_valid}}, p_{\text{anchor}})$.
   - Vận tốc tương đương: $v_{\text{equiv}} = \frac{D_{\text{chord}}}{\Delta t_{\text{gap}}}$.
   - Nếu $v_{\text{equiv}} \le V_{\max} = 20.0\text{ m/s}$:
     $$D_{\text{bridged}} = D_{\text{chord}}$$
     Bù đắp quãng đường dây cung hợp lý, triệt tiêu hiện tượng Undercount khi cua ngắn hoặc chui qua cầu vượt.

2. **Khe hở dài ($\Delta t_{\text{gap}} > 10.0\text{ s}$):**
   - Tuyến đường di chuyển thực tế của người dùng qua khe hở dài không thể nội suy bằng đường thẳng mà không có rủi ro tạo quãng đường ảo xuyên qua nhà dân.
   - Nếu $v_{\text{equiv}} > 20.0\text{ m/s}$: Đánh dấu phân đoạn `DiscontinuousTransit`, $D_{\text{bridged}} = 0.0\text{ m}$.
   - Nếu $v_{\text{equiv}} \le 20.0\text{ m/s}$ (người dùng đạp xe đều trong hầm dài):
     $$D_{\text{bridged}} = \min(D_{\text{chord}}, v_{\text{last\_valid}} \cdot \Delta t_{\text{gap}})$$
     Chỉ ghi nhận tối đa theo vận tốc hợp lý trước khi mất tín hiệu.

### 4.3. Định Lượng Riêng Biệt Overcount và Undercount

Trong các bài kiểm tra đo kiểm Phase 5, sai số quãng đường sẽ được đo lường phân tách rõ ràng thành hai metric độc lập:
$$\text{Overcount Error (\%)} = \frac{\sum \max(0, d_{\text{est}} - d_{\text{truth}})}{D_{\text{truth}}} \times 100\%$$
$$\text{Undercount Error (\%)} = \frac{\sum \max(0, d_{\text{truth}} - d_{\text{est}})}{D_{\text{truth}}} \times 100\%$$
- **Chỉ tiêu Phase 5:**
  - $\text{Overcount Error} \le 1.0\%$ (Triệt tiêu hoàn toàn quãng đường ma từ re-anchor).
  - $\text{Undercount Error} \le 3.0\%$ trên các đoạn gián đoạn $< 10\text{ s}$.

---

## 5. Task 5 — Ma Trận Đo Kiểm Nghiệm Thu Tất Định (Phase 5 Deterministic Acceptance Matrix)

Bảng ma trận kiểm thử bắt buộc phải đạt $100\%$ trước khi Phase 5 được xem xét đề xuất phê chuẩn:

| Mã Kiểm Thử | Tên Kịch Bản Đo Kiểm | Dữ Liệu Đầu Vào & Nhiễu Mô Phỏng | Kỳ Vọng Kỹ Thuật Bắt Buộc (Acceptance Criteria) | Cấu Hình Đối Soát |
|---|---|---|---|---|
| **TC-01** | **Scenario 61 Recovery** | Lộ trình chuẩn 108 kịch bản, Seed 61: Cua gắt $160^\circ$ tại $t=12\text{s}$, mất hoàn toàn heading (`headingDeg == null`). | - Phát hiện mất khóa tại bước $s \le 9$ ($N_{\text{rej}} \ge 3$).<br>- Tái neo thành công tại bước $s \le 12$ ($K=3$ candidate fixes).<br>- **Max Error giảm từ $4.887\text{ m}$ xuống $< 12.0\text{ m}$**.<br>- Quãng đường tích lũy không phình to. | Config C (Phase 4A) vs Config D (Phase 5) |
| **TC-02** | **Multi-Angle Turns with Heading Dropout** | Cua $30^\circ$, $60^\circ$, $90^\circ$, và Hairpin ($180^\circ$) ở tốc độ $15 - 25\text{ km/h}$, toàn bộ không có la bàn. | - Bắt vết thành công toàn bộ 4 góc cua.<br>- Không bị rơi vào khóa chết từ chối.<br>- Turn P95 error $\le 8.0\text{ m}$. | So sánh với Phase 3 B1 và Baseline A |
| **TC-03** | **Isolated Single Spike (55m & 100m)** | Xe đạp đang chạy $5\text{ m/s}$ ổn định tại S0; tiêm 1 mẫu ngoại lai lệch $55\text{ m}$ hoặc $100\text{ m}$. | - Mẫu bị loại bỏ tại S0 bởi NIS Gating.<br>- Bộ lọc KHÔNG chuyển trạng thái sang S1 hay S2.<br>- Quỹ đạo không bị giật; quãng đường tăng đúng $5.0\text{ m}$. | Baseline A vs Phase 5 |
| **TC-04** | **Multi-Point False Multipath Cluster** | Trong lúc đang mất tín hiệu tại S2; tiêm cụm 3 điểm giả mạo cách vị trí thật $60\text{ m}$ nhưng có $v > 25\text{ m/s}$ hoặc nhảy zic-zac. | - Lớp phòng thủ Động học loại bỏ cụm giả mạo.<br>- FSM giữ nguyên S2, xóa Candidate Buffer.<br>- **TUYỆT ĐỐI KHÔNG TÁI NEO theo cụm giả**. | So sánh với mô hình Re-Anchor ngây thơ |
| **TC-05** | **GPS Blackout Sweep (1s, 5s, 10s, 30s, 60s)** | Xe đạp chạy thẳng và rẽ cua qua các đường hầm mất sóng hoàn toàn với các độ dài thời gian khác nhau. | - $1\text{ s}$: Giữ S0, predict chính xác.<br>- $5\text{ s}$: Chuyển S1 $\to$ S2; phục hồi ngay khi ra hầm.<br>- $10\text{ s}, 30\text{ s}, 60\text{ s}$: Tái neo trong $\le 3$ mẫu hợp lệ sau hầm.<br>- Quãng đường gián đoạn hạch toán đúng chính sách (Mục 4.2). | Baseline A vs Phase 5 |
| **TC-06** | **Stationary Noise & Dwell at Traffic Light** | Xe dừng hẳn $v = 0.0\text{ m/s}$ trong $60\text{ s}$; GPS dao động ngẫu nhiên bán kính $15\text{ m}$. | - FSM không sinh ra vận tốc ảo hay góc hướng giả mạo.<br>- Quãng đường tích lũy trong 60 giây đứng yên $\le 1.0\text{ m}$. | T-DBSCAN Post-Process vs Phase 5 |
| **TC-07** | **Slow Cycling Creep (0.8 – 1.5 m/s)** | Xe di chuyển cực chậm gần ngưỡng đứng yên. | - Không nhầm lẫn giữa bò chậm và đứng yên.<br>- Covariance duy trì PSD $100\%$, không suy biến ma trận. | Phase 4A vs Phase 5 |
| **TC-08** | **Covariance PSD & Numerical Stability** | Stress test 5.000 chu kỳ bao gồm liên tục chuyển trạng thái S0 $\leftrightarrow$ S2 $\to$ S5. | - $100\%$ các bước kiểm tra trị riêng $\lambda_{\min}(P) > 0$.<br>- Ma trận đối xứng hoàn hảo, $0$ giá trị NaN hoặc Inf. | MatrixMath4x4 Jacobi |
| **TC-09** | **No Phantom Distance Assertions** | Đo kiểm chênh lệch khoảng cách trước và sau bước Re-Anchor tại S5. | - Assert: $\text{dist}_{\text{est}}(t_{\text{anchor}}) - \text{dist}_{\text{est}}(t_{\text{anchor}}^-) \le V_{\max} \cdot \Delta t$.<br>- Không có đột biến quãng đường dạng bậc thang (step jump). | Ground-Truth Polyline |
| **TC-10** | **All-Scheduled 108-Scenario Benchmark Gate** | Chạy toàn bộ 75.600 điểm lập lịch của bộ kiểm tra chuẩn. | - **Protocol 2 All-Scheduled RMSE giảm từ $593.98\text{ m}$ xuống $< 8.0\text{ m}$**.<br>- **Protocol 2 All-Scheduled P95 giảm từ $1.128\text{ m}$ xuống $< 15.0\text{ m}$**.<br>- Operational Availability $\ge 98.5\%$. | Config A, B1, B2, C, D |

---

## 6. Bảo Vệ Pipeline Sản Xuất & Tính Bất Biến (Pipeline Immutability)

- Toàn bộ các file phục vụ người dùng cuối tiếp tục được bảo vệ nghiêm ngặt:
  - `lib/main.dart`
  - `lib/features/workout/domain/services/gps_data_stream_service.dart`
  - `lib/features/workout/domain/services/gps_smoothing_service.dart`
  - `lib/features/workout/domain/services/gps_signal_monitor.dart`
  - `lib/features/workout/domain/services/dbscan/*`
- Độ sai biệt so với nhánh `main`: **Chính xác 0 byte**.
- Mọi nghiên cứu của Phase 5 khi được phê duyệt chỉ được phép thực hiện trên các file dịch vụ EKF độc lập thuộc `lib/features/workout/domain/services/ekf/`.

---

## 7. Khuyến Nghị & Dừng Hoạt Động (Recommendation & Stop Protocol)

### 7.1. Khuyến Nghị Chính Thức (Official Recommendation)
1. **Phê chuẩn Báo cáo Thiết kế Phase 5 (Approve Phase 5 Design Proposal):** Đề xuất kiến trúc FSM 6 trạng thái, cơ chế tái neo phòng thủ 4 lớp, bảng hạch toán quãng đường và ma trận 10 tiêu chí nghiệm thu đã giải quyết toàn diện các lỗ hổng của Phase 4A.
2. **Duy trì HOLD Cổng Phát Hành Phase 4A (Hold Phase 4A Release):** Giữ nguyên quyết định HOLD đối với mã nguồn Phase 4A hiện tại vì chưa có cơ chế phục hồi FSM.
3. **Chờ Ủy Quyền Cho Phase 5 (Await Phase 5 Implementation Authorization):** Giữ nguyên lệnh cấm triển khai code; không bắt đầu viết code Phase 5 cho đến khi Chủ dự án chính thức ký lệnh `Duyệt Kế hoạch Phase 5 & Bắt đầu Triển khai`.

**AGENT ĐÃ HOÀN TẤT TOÀN BỘ CÁC MỤC YÊU CẦU VÀ DỪNG LẠI CHỜ CHỈ ĐẠO TIẾP THEO TỪ CHỦ DỰ ÁN.**
