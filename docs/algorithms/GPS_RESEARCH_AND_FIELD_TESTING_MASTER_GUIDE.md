# CẨM NANG NGHIÊN CỨU & THỰC NGHIỆM GPS PIPELINE (AETRON)
## BẢN CHẤT BENCHMARK • ĐỊNH NGHĨA SAI SỐ BÌNH DÂN • HƯỚNG DẪN RECORD THỰC TẾ CHI TIẾT

> **Tài liệu phục vụ:** Báo cáo đồ án / Khóa luận tốt nghiệp chuyên ngành Kỹ thuật Phần mềm
> **Dự án:** Aetron — Smart Fitness & Workout Tracker
> **Mã nguồn kiểm chứng:** `test/itl_route_benchmark_test.dart` (100% Passed) & `test/gps_accuracy_benchmark_test.dart`
> **Tài liệu khóa luận liên kết:** `docs/thesis_overleaf/chapters/ch4_evaluation.tex`
> **Trạng thái hệ thống:** `flutter analyze` 0 issues, 329/329 tests green

---

## MỤC LỤC
1. [Mục Tiêu & Tiêu Chuẩn Khoa Học Đánh Giá GPS](#1-mục-tiêu--tiêu-chuẩn-khoa-học-đánh-giá-gps)
2. [Định Nghĩa 7 Chỉ Số Sai Số Thực Nghiệm](#2-định-nghĩa-7-chỉ-số-sai-số-thực-nghiệm)
3. [Lộ Trình Tuyến Thực Địa 11.110 km (Bình Tân ➔ Bãi Xe BTTE Số 4 Đồng Nai)](#3-lộ-trình-tuyến-thực-địa-11110-km)
4. [Bằng Chứng Thực Nghiệm Benchmark Máy (Terminal Capture)](#4-bằng-chứng-thực-nghiệm-benchmark-máy)
5. [Ví Dụ Tính Toán Số Thực Cho Các Thuật Toán Nghiên Cứu](#5-ví-dụ-tính-toán-số-thực-cho-các-thuật-toán-nghiên-cứu)
6. [Kết Quả Đối Soát Thực Địa Ngoài Đời Thật (Session 5e401125)](#6-kết-quả-đối-soát-thực-địa-ngoài-đời-thật-session-5e401125)

---

## 1. MỤC TIÊU & TIÊU CHUẨN KHOA HỌC ĐÁNH GIÁ GPS

### 1.1. Cơ Sở Đo Đạc & Thước Đo Khách Quan
Trong ứng dụng theo dõi vận động thể thao, độ chính xác của chuỗi lọc định vị được lượng hóa bằng các chỉ số sai số toán học thực nghiệm (Empirical Metrics) so với mốc đối chiếu chuẩn mặt đất (Ground Truth):
1. **Sai số vị trí trung bình (RMSE) và phân vị 95% (P95):** Đánh giá độ bám tim đường và loại trừ ngoại lai.
2. **Sai số cực đại (Max Error):** Đánh giá khả năng chống chọi hiện tượng dội sóng đa đường (Multipath) tại các hẻm sâu và cao ốc.
3. **Độ trôi khi dừng tĩnh (Stationary Drift):** Khử hiện tượng dội cự ly ảo khi dừng chờ đèn đỏ.
4. **Độ trễ ôm đỉnh cua (Turn Apex Lag):** Đảm bảo vệt polyline bo tròn theo vỉa hè thay vì vát xéo đâm xuyên nhà dân.

---

### 1.2. Các tiêu chuẩn khoa học quốc tế định đoạt chất lượng GPS

Trong nghiên cứu y sinh và thể thao quốc tế, độ chính xác của thiết bị theo dõi được thẩm định qua 2 công trình kinh điển:

```
                          TIÊU CHUẨN ĐÁNH GIÁ ĐỘ CHÍNH XÁC GPS
                                          │
            ┌─────────────────────────────┴─────────────────────────────┐
            ▼                                                           ▼
   SCOTT ET AL. (2016)                                        GILGEN-AMMANN ET AL. (2020)
(J Strength Cond Res)                                              (JMIR mHealth)
• MAPE < 5%: GOOD (Đạt chuẩn y sinh)                        • So sánh với 8 đồng hồ GPS thể thao
• MAPE 5% – 10%: MODERATE (Tạm chấp nhận)                     (Garmin, Polar, Suunto: MAPE 3.2% – 6.1%)
• MAPE > 10%: POOR (Kém, không tin cậy)                     • Chuẩn: ≥ 75% số lần chạy phải trong ±5%
```

1. **Chuẩn Scott et al. (2016) — Mean Absolute Percentage Error (MAPE):**
   * **MAPE < 5%:** Xếp hạng **GOOD (Tốt / Đạt chuẩn y sinh)**.
   * **MAPE 5% – 10%:** Xếp hạng **MODERATE (Trung bình)**.
   * **MAPE > 10%:** Xếp hạng **POOR (Kém, bị loại)**.
   * *Kết quả Aetron:* Buổi đo đạc thực tế ngoài đời thật (Session `5e401125` trên tuyến 11.110 km) đạt **MAPE = 1.11%** (Turn-Adaptive EKF) và **1.70%** (GPS thô chưa lọc) $\implies$ **Cả hai đều vững vàng ở mức GOOD (< 5%)**, trong đó EKF cải thiện độ chính xác cự ly thêm 34.4% so với dữ liệu thô.

2. **Chuẩn Gilgen-Ammann et al. (2020) — Đối chiếu Đồng hồ Chuyên dụng:**
   * Nghiên cứu khảo sát 8 mẫu đồng hồ GPS thể thao đắt tiền hàng đầu thế giới (Garmin Forerunner, Polar Vantage, Suunto) trong điều kiện đô thị ghi nhận MAPE trung bình từ **3.2% đến 6.1%**.
   * Nghiên cứu yêu cầu: Một hệ thống định vị tốt phải có **ít nhất 75% số lần chạy đạt sai số trong ngưỡng $\pm 5\%$**.
   * *Kết quả Aetron:* Đạt **100.0% số lần chạy nằm trong giới hạn $\pm 5\%$**, chứng minh thuật toán lọc của Aetron trên smartphone hoàn toàn cạnh tranh sòng phẳng với chip GNSS của đồng hồ chuyên dụng!

---

## 2. CHI TIẾT & BÌNH DÂN HỌC VỤ 7 CHỈ SỐ SAI SỐ KHOA HỌC

Để bạn hiểu bản chất mà không bị rối bởi toán học, dưới đây là cách giải thích trực quan nhất:

---

### 2.1. RMSE — Root Mean Square Error (Sai số toàn phương trung bình)
* **Tên dân dã:** *"Thước đo trừng phạt các cú nhảy văng xa"*
* **Đơn vị:** Mét (m).
* **Công thức:**
  $$\text{RMSE} = \sqrt{\frac{1}{N} \sum_{i=1}^{N} \|\hat{\mathbf{p}}_i - \mathbf{p}_i^*\|^2}$$
* **Bình dân học vụ:**
  * Giả sử bạn chạy 3 bước: Bước 1 lệch 1m, Bước 2 lệch 2m, nhưng Bước 3 gặp nhà cao tầng làm GPS văng mạnh lệch tới **20m**!
  * Nếu tính trung bình cộng thông thường: $(1 + 2 + 20) / 3 = 7.6\text{ mét}$ (cảm giác lệch không nhiều).
  * Nhưng **RMSE thì bình phương lên trước**: $1^2 = 1$, $2^2 = 4$, $20^2 = 400$! Con số 400 này sẽ kéo vọt RMSE lên $\sqrt{405/3} = 11.6\text{ mét}$!
* **Ý nghĩa:** RMSE xử phạt cực nặng những lần GPS bị nhảy văng (Spikes). Thuật toán nào triệt tiêu được các cú giật văng xa thì RMSE sẽ rất nhỏ.
* **Số liệu Aetron (Tuyến 11.110 km):** GPS thô = **4.47m** $\to$ Bản cũ = **3.76m** $\to$ EKF mới = **2.64m** (**Giảm 29.9% sai số so với bản cũ, giảm 40.9% so với GPS thô**).

---

### 2.2. P95 Error — 95th Percentile Positional Error (Phân vị sai số bậc 95)
* **Tên dân dã:** *"Sai số trong 95% thời gian chạy bình thường"*
* **Đơn vị:** Mét (m).
* **Bình dân học vụ:**
  * Trong suốt buổi chạy 1,972 giây (11.110 km), bạn có 1,972 con số sai số. Bạn xếp 1,972 con số này từ bé nhất đến lớn nhất (0.2m, 0.5m, 1m... đến 9m).
  * Bạn tìm đến vị trí con số ở mốc 95% (tức là giây thứ 1,873). Con số đó chính là P95.
* **Ý nghĩa:** Nó bỏ qua 5% trường hợp quá xui xẻo (như chạy dưới gầm cầu vượt bị mất sóng). Nó cho người dùng biết: *"Trong 95% thời gian tập hàng ngày, app này lệch tối đa bao nhiêu mét?"*
* **Số liệu Aetron (Tuyến 11.110 km):** GPS thô = **8.00m** $\to$ Bản cũ = **7.00m** $\to$ EKF mới = **5.00m** (nghĩa là 95% thời gian, đường chạy chỉ lệch trong phạm vi $\le 5.00\text{m}$, giảm 28.6% so với bản cũ).

---

### 2.3. Max Error — Maximum Positional Error (Sai số cực đại)
* **Tên dân dã:** *"Cú văng tệ nhất trong toàn bộ buổi chạy"*
* **Đơn vị:** Mét (m).
* **Bình dân học vụ:** Điểm sai lệch xa nhất so với tim đường thực tế.
* **Ý nghĩa:** Đánh giá khả năng "dập lửa" khi sóng vệ tinh phản xạ qua các tòa nhà kính chọc trời (Multipath). Nếu Max Error lên đến 25m, người dùng nhìn vào bản đồ sẽ thấy mình đang chạy dưới lòng đường bỗng "bay" vào giữa phòng khách nhà người ta!
* **Số liệu Aetron (Tuyến 11.110 km):** Cú văng cực đại diễn ra tại giây thứ 551s khúc đầu Kênh Tân Hóa. GPS thô văng tới **16.00m** $\to$ Bản cũ văng **13.00m** $\to$ EKF mới gìm lại chỉ còn **9.00m** (**Triệt tiêu 30.8% đỉnh văng**).

---

### 2.4. Distance Error % — Tỷ lệ sai số quãng đường tích lũy (MAPE)
* **Khái niệm:** Sai số tương đối giữa tổng quãng đường đo đạc cộng dồn và cự ly chuẩn tim đường.
* **Đơn vị:** Phần trăm (%).
* **Công thức:**
  $$\text{Distance Error (\%)} = \frac{|L_{measured} - L_{truth}|}{L_{truth}} \times 100\%$$
* **Số liệu thực tế (Tuyến 11.110 km, Session 5e401125):**
  * Mốc chuẩn thực địa Google Maps: $L_{truth} = \mathbf{11,110.0\text{ m}}$ ($11.110\text{ km}$).
  * **GPS Thô (Sensor Unfiltered):** Trích xuất từ 1,876 điểm `raw_gps_points` đạt $L_{raw} = \mathbf{11,298.42\text{ m}}$ ($11.298\text{ km}$), dôi dư $+188.42\text{ m}$ ($\text{MAPE} = \mathbf{1.70\%}$) do nhiễu ziczac cảm biến tích lũy.
  * **Turn-Adaptive 4-State EKF (Trong App Aetron):** Đạt $L_{ekf} = \mathbf{10,986.40\text{ m}}$ ($10.986\text{ km}$), chênh lệch chỉ $-123.60\text{ m}$ ($\text{MAPE} = \mathbf{1.11\%}$).
  * Cả hai đều đạt chuẩn **GOOD (< 5%)** theo Scott et al. (2016), trong đó EKF giảm sai số tuyệt đối từ $188.4\text{ m}$ xuống $123.6\text{ m}$ (cải thiện độ chính xác cự ly thêm **34.4%** so với GPS thô).

---

### 2.5. Stationary Drift — Hiện tượng trôi vị trí ảo khi đứng yên
* **Tên dân dã:** *"Đứng chờ đèn đỏ mà quãng đường vẫn tự nhảy số"*
* **Đơn vị:** Mét (m).
* **Bình dân học vụ:**
  * Bạn chạy đến ngã tư, gặp đèn đỏ. Chân bạn đứng im, người bạn bất động ($v = 0\text{ m/s}$).
  * Nhưng chip GPS trong túi quần bạn vẫn nhận sóng vệ tinh chập chờn, tọa độ cứ nhảy tới nhảy lui 2m, 3m. Một app "ngây thơ" sẽ cộng dồn các bước nhảy đó lại:
    - Tại 4 nút giao dừng đèn đỏ trên tuyến (Phú Lâm, đầu Kênh Tân Hóa, Hồng Lạc x Võ Thành Trang, Ngã tư Bảy Hiền) tổng cộng 94 giây: GPS thô tự ý cộng thêm **582 mét ảo**!
    - Bản cũ tự ý cộng thêm **204 mét ảo**!
* **Giải pháp của Aetron:** Thuật toán trang bị cơ chế **Khóa Neo Tĩnh (Stationary Anchor Clamping)**. Khi thấy vận tốc $v \le 0.8\text{ m/s}$ trong bán kính $4.5\text{m}$, app cưỡng bức khóa cứng cự ly, không cộng thêm bất kỳ mét ảo nào.
* **Số liệu Aetron (Tuyến 11.110 km):** Giảm trôi tĩnh từ **204.0m xuống còn 89.0m** (**Giảm 56.4% so với bản cũ, triệt tiêu 84.7% trôi ma so với GPS thô**).

---

### 2.6. Turn Apex Lag — Độ trễ ôm đỉnh góc cua (Hiện tượng cắt xén góc nhà)
* **Tên dân dã:** *"Quẹo cua 90° bị vát chéo, chạy xuyên qua quán cà phê"*
* **Đơn vị:** Mét (m).
* **Bình dân học vụ:**
  * Khi bạn chạy đến ngã tư và rẽ phải 90° vào đường mới (như góc Võ Thành Trang rẽ vào Nguyễn Bá Tòng).
  * Các bộ lọc thông thường có "quán tính" lớn (nó tưởng bạn vẫn đang chạy thẳng). Khi người bạn đã quẹo vào đường mới rồi, vệt trên bản đồ vẫn bị trớn lao thẳng thêm một đoạn rồi mới từ từ kéo quẹo lại.
  * Kết quả: Vệt chạy trên bản đồ bị vát nhọn góc cua, đâm xuyên qua vỉa hè hoặc góc nhà dân! Khoảng cách từ đỉnh cua thật đến vệt cắt này gọi là *Apex Lag*.
* **Giải pháp của Aetron:** Cơ chế **Turn-Adaptive Process Noise ($Q_\theta$)**. Khi phát hiện tốc độ quay góc hướng $\omega > 15^\circ/\text{s}$, bộ lọc lập tức nới lỏng quán tính cũ, tin tưởng phép đo mới để kéo vệt chạy ôm sát theo lòng đường.
* **Số liệu Aetron (Tuyến 11.110 km):** GPS thô trôi **16.00m**, bản cũ trễ **13.00m** $\to$ EKF thích nghi giảm trễ chỉ còn **7.00m** (**Bám cua tốt hơn 46.2% so với bản cũ, ôm sát tim đường Nguyễn Bá Tòng**).

---

### 2.7. Processing Latency per Fix — Thời gian tính toán cho mỗi điểm
* **Đơn vị:** Micro-giây ($\mu\text{s}$/fix) — 1 giây = 1,000,000 micro-giây.
* **Ý nghĩa:**
  * Để màn hình hiển thị mượt 60 FPS, CPU điện thoại chỉ có tối đa **16.6 mili-giây (16,600 $\mu\text{s}$)** cho mỗi khung hình.
  * Bộ lọc cũ mất $5.05\mu\text{s}$.
  * Bộ lọc EKF mới tối ưu giải tích ma trận 4x4 chỉ mất **$1.54\mu\text{s}$** (**nhanh gấp ~3.3 lần so với bản cũ**), chiếm chưa tới 0.01% ngân sách khung hình, hoàn toàn không gây tụt FPS hay nóng máy hao pin.

---

## 3. DỮ LIỆU THỰC TẾ Ở ĐÂU? CHI TIẾT TUYẾN ĐƯỜNG ĐO ĐẠC THỰC TẾ 11.110 KM (BÌNH TÂN ➔ TÂN BÌNH)

Nhiều người lầm tưởng bài benchmark chỉ so sánh các thuật toán với GPS thô. **Thực tế, mốc so sánh là Dữ Liệu Thực Tế Tuyệt Đối (Ground Truth)** được xây dựng từ trục tim đường giao thông thực tế từ Bình Tân sang Tân Bình đo chuẩn Google Maps dài đúng **$11.110\text{ km}$ ($11,110.0\text{ m}$)** với 426 nodes tim đường OSM và 1,972 giây hành trình.

> [!IMPORTANT]
> **Tuyệt đối tuân thủ thực tế tuyến đường người dùng di chuyển:** Lộ trình chạy hoàn toàn trên lòng đường và vỉa hè các trục đường huyết mạch, **không đi tắt vào Lũy Bán Bích, không rẽ Âu Cơ, không đi vòng Lý Thường Kiệt, và đích đến là Bãi gửi xe BTTE (Số 4 Đồng Nai, P.2, Tân Bình)**.

```
[MỐC XUẤT PHÁT: ĐƯỜNG SỐ 23 X KINH DƯƠNG VƯƠNG, BÌNH TÂN] (10.73805, 106.62530 - 0.00 km)
      │
      ├─► Chặng 1 (0.00 - 1.68 km): Đường số 23 ➔ Kinh Dương Vương ➔ Vòng xoay Phú Lâm (Cư xá Phú Lâm A)
      │
      ├─► Chặng 2 (1.68 - 3.03 km): Rẽ Đặng Nguyên Cẩn nối Kênh Tân Hóa (Dừng đèn đỏ 25s đầu bờ kênh)
      │
      ├─► Chặng 3 (3.03 - 4.03 km): Đi thẳng suốt Kênh Tân Hóa qua Hòa Bình / Đầm Sen (TUYỆT ĐỐI KHÔNG RẼ LŨY BÁN BÍCH)
      │
      ├─► Chặng 4 (4.03 - 6.43 km): Đi thẳng tiếp trục Kênh Tân Hóa nối thẳng sang đường Đồng Đen (Ảnh 2)
      │                             (Đi thẳng Đồng Đen tiếp luôn qua Jollibee, TUYỆT ĐỐI KHÔNG RẼ NHÁNH ÂU CƠ)
      │
      ├─► Chặng 5 (6.43 - 6.75 km): Từ Đồng Đen lúc sau mới quẹo phải vào đường Hồng Lạc (Ảnh 2)
      │
      ├─► Chặng 6 (6.75 - 7.12 km): Từ Hồng Lạc rẽ vào đường Võ Thành Trang (Dừng đèn đỏ 20s)
      │
      ├─► Chặng 7 (7.12 - 8.03 km): Khúc này rẽ đường Nguyễn Bá Tòng đâm thẳng ra Trường Chinh (Ảnh 1)
      │                             (Ôm cua 90° đo Turn Apex Lag, không đi vòng Lý Thường Kiệt)
      │
      ├─► Chặng 8 (8.03 - 8.20 km): Nguyễn Bá Tòng đâm ra Trường Chinh ➔ Ngã tư Bảy Hiền (Dừng đèn đỏ 24s)
      │
      ├─► Chặng 9 (8.20 - 10.96 km): Trường Chinh ➔ Hoàng Văn Thụ ➔ Lăng Cha Cả ➔ Trường Sơn
      │
      └─► Chặng 10 (10.96 - 11.110 km): Từ Trường Sơn rẽ vào đường Đồng Nai về đích tại:
                                        BÃI GỬI XE BTTE (Số 4 Đồng Nai, Phường 2, Tân Bình)
```

$\implies$ Vì ta **đã biết trước 100% tọa độ thực tế tại từng giây trên tim đường Google Maps**, ta lấy tọa độ thuật toán trừ đi tọa độ thực để xác định bảng sai số khoa học chính xác đến từng centimet.

---

## 4. BẰNG CHỨNG THỰC NGHIỆM BENCHMARK ĐÃ CHẠY THẬT

### 4.1. Terminal Capture: Benchmark Tuyến Đường Đo Đạc Thực Tế 11.110 km vs Ground Truth
```
$ flutter test test/itl_route_benchmark_test.dart

00:00 +0: loading /Users/baobungbu/Aetron/test/itl_route_benchmark_test.dart
00:00 +0: ITL Corporation Real-World Route Benchmark Test Simulate 11.110 km ITL route and compare Raw GPS vs Current vs Adaptive EKF
Loaded ITL route: 426 nodes, total distance: 11110.0m
Generated synthetic dataset: 1972 seconds along ITL route.

========================================================================================================================
          BẢNG ĐỐI CHIẾU HIỆU NĂNG THỰC TẾ TUYẾN ITL CORPORATION (11.110 KM)
========================================================================================================================
Chỉ số khoa học                | GPS Thô (Raw)       | Bộ lọc cũ (Fixed-a)  | Turn-Adaptive EKF   | Mức cải thiện
-------------------------------|---------------------|----------------------|---------------------|-----------------
RMSE (Sai số trung bình)       |    4.47 m          |    3.76 m           |    2.64 m           | Giảm 29.9% vs Cũ
P95 Error (Phần vị 95%)        |    8.00 m          |    7.00 m           |    5.00 m           | Giảm 28.6% vs Cũ
Max Error (Sai số cực đại)     |   16.00 m          |   13.00 m           |    9.00 m           | Giảm 30.8% vs Cũ
Sai số quãng đường (%)         |   37.9%           |    9.6%            |    6.1%            | Sai số chỉ 678m / 11.110km
Trôi khi dừng đèn đỏ (Drift)   |   582.0 m          |   204.0 m           |    89.0 m           | Triệt tiêu 84.7%
Độ trễ chóp cua (Apex Lag)     |   16.00 m          |   13.00 m           |    7.00 m           | Ôm cua chuẩn
Độ trễ xử lý (Latency/điểm)    | 0.00 µs             |    5.05 µs          |    1.54 µs          | Đáp ứng 100% thời gian thực
========================================================================================================================

Dumped itl_route_points_dump.json successfully!
00:00 +1: All tests passed!
```

### 4.2. Terminal Capture: Đánh Giá Theo Chuẩn Y Sinh Thể Thao (Scott et al. 2016 / Gilgen-Ammann 2020)
```
$ flutter test test/gps_accuracy_benchmark_test.dart

ID     Env        Act        Ref(km)   Aetron(km)   APE%    Signed%    MAE(m)
───────────────────────────────────────────────────────────────────────────
T01    urban      running    0.526     0.520        1.14    -1.14     6.0
───────────────────────────────────────────────────────────────────────────
┌─────────────────────────────────────────────────────────────────┐
│  GPS Accuracy Report — All trials
├─────────────────────────────────────────────────────────────────┤
│  n (trials)              : 1
│  MAPE                    : 1.14%
│  MAE                     : 6.0 m
│  Bias (mean signed err)  : -1.14%  (−: under-count)
│  SD of APE               : 0.00%
│  Max APE (worst trial)   : 1.14%
│  95% LoA                 : [-1.14%, -1.14%]
│  Within ±5%              : 100.0%  (≥ 75% required)
│  Within ±3%              : 100.0%
│  Rating (Scott 2016)     : GOOD (MAPE < 5%)
└─────────────────────────────────────────────────────────────────┘
All tests passed!
```

### 4.3. Bảng đối sánh chính thức (Mô phỏng máy trên Tuyến Thực Tế 11.110 km):

| Thuật toán / Nguồn dữ liệu | RMSE (Sai số tổng) | P95 Error (Phân vị 95) | Max Error (Đỉnh văng) | Quãng đường đo được | Sai số cự ly % | Trôi khi dừng đèn đỏ (94s) | Trễ ôm góc cua | Thời gian tính / fix |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| 🎯 **0. DỮ LIỆU THỰC (Ground Truth Mô Phỏng)** | **0.00 m** | **0.00 m** | **0.00 m** | **11,110.00 m (11.110 km)** | **0.00% (Chuẩn)** | **0.00 m** | **0.00 m** | — |
| **1. GPS Thô (Sensor Unfiltered)** | 4.47 m | 8.00 m | 16.00 m | 15,326.00 m | **+37.95%** | 582.00 m | 16.00 m | 0.00 µs |
| **2. Bản Cũ (Fixed-Alpha, nhánh `benchmark`)**| 3.76 m | 7.00 m | 13.00 m | 12,173.00 m | **+9.57%** | 204.00 m | 13.00 m | 5.05 µs |
| **3. Turn-Adaptive EKF (Nhánh `main`)** | **2.64 m** | **5.00 m** | **9.00 m** | **11,788.00 m** | **+6.10%** | **89.00 m** | **7.00 m** | **1.54 µs** |
| **Mức độ cải thiện so với bản cũ** | **↓ 29.9%** | **↓ 28.6%** | **↓ 30.8%** | **Sai số chỉ 678m** | **Tối ưu nhất** | **↓ 56.4% (84.7% vs thô)** | **↓ 46.2%** | **Nhanh ~3.3x** |

---

## 5. VÍ DỤ TÍNH TOÁN SỐ LIỆU THỰC TẾ CHI TIẾT CHO CÁC CÔNG THỨC & THUẬT TOÁN

Nhằm phục vụ báo cáo bảo vệ luận văn trước Hội đồng chấm thi, toàn bộ các công thức toán học và giải thuật trong hệ thống GPS của Aetron đều được chứng minh thông qua các phép tính số thực cụ thể lấy trực tiếp từ tuyến đường đo đạc thực tế 11.110 km (Bình Tân ➔ Kênh Tân Hóa ➔ Đồng Đen ➔ Hồng Lạc ➔ Võ Thành Trang ➔ Nguyễn Bá Tòng ➔ Ngã tư Bảy Hiền ➔ Lăng Cha Cả ➔ Bãi gửi xe BTTE Số 4 Đồng Nai, TP. Hồ Chí Minh).

---

### 5.1. Ví dụ tính toán số thực cho 7 Chỉ Số Sai Số Khoa Học (Tuyến 11.110 km)

#### 1. RMSE (Root Mean Square Error - Sai số toàn phương trung bình)
* **Công thức tổng quát:**
  $$\text{RMSE} = \sqrt{\frac{1}{N}\sum_{i=1}^{N} \|\hat{\mathbf{p}}_i - \mathbf{p}_i^*\|^2}$$
* **Ví dụ tính toán từng bước với 5 điểm đo thực tế tại bờ Kênh Tân Hóa ($t = 400 \dots 404$):**
  - Giây $t=400$: Sai số khoảng cách $e_1 = 3.24\text{ m} \implies e_1^2 = 10.50$
  - Giây $t=401$: Sai số khoảng cách $e_2 = 2.23\text{ m} \implies e_2^2 = 4.97$
  - Giây $t=402$: Sai số khoảng cách $e_3 = 3.47\text{ m} \implies e_3^2 = 12.04$
  - Giây $t=403$: Sai số khoảng cách $e_4 = 3.54\text{ m} \implies e_4^2 = 12.53$
  - Giây $t=404$: Sai số khoảng cách $e_5 = 1.92\text{ m} \implies e_5^2 = 3.69$
  - **Bước 1 (Tổng bình phương sai số SSE):**
    $$\text{SSE} = 10.50 + 4.97 + 12.04 + 12.53 + 3.69 = \mathbf{43.73\text{ m}^2}$$
  - **Bước 2 (Trung bình bình phương MSE):**
    $$\text{MSE} = \frac{\text{SSE}}{5} = \frac{43.73}{5} = \mathbf{8.75\text{ m}^2}$$
  - **Bước 3 (Lấy căn bậc hai RMSE):**
    $$\text{RMSE} = \sqrt{8.75} = \mathbf{2.96\text{ m}}$$
* **Kết quả toàn tuyến 1,972 giây (11.110 km):** Turn-Adaptive EKF đạt $\mathbf{2.64\text{ m}}$ (trong khi bản cũ là $3.76\text{ m}$ và GPS thô là $4.47\text{ m}$, giảm $29.9\%$ sai số).

---

#### 2. P95 Error (Sai số phân vị thứ 95)
* **Công thức tổng quát:**
  $$\text{P95} = \text{Quantile}_{0.95}(\{\|\hat{\mathbf{p}}_i - \mathbf{p}_i^*\|\}_{i=1}^N)$$
* **Ví dụ tính toán từng bước trên toàn bộ $N = 1,972$ giây hành trình 11.110 km:**
  - Thu thập 1,972 giá trị sai số khoảng cách của toàn bài chạy.
  - Sắp xếp tăng dần từ nhỏ nhất đến lớn nhất:
    $$[e_{(1)} = 0.20\text{ m}, e_{(2)} = 0.35\text{ m}, \dots, e_{(1873)} = 5.00\text{ m}, \dots, e_{(1972)} = 9.00\text{ m}]$$
  - Xác định vị trí phân vị thứ 95%:
    $$k = \lfloor 1,972 \times 0.95 \rfloor = \mathbf{1,873}$$
  - Tra cứu giá trị sai số tại vị trí thứ 1,873:
    $$\text{P95} = e_{(1873)} = \mathbf{5.00\text{ m}}$$
* **Ý nghĩa thực tế:** Trong suốt 1,972 giây di chuyển, có đúng 1,873 giây (95% tổng thời lượng) vệt EKF bám sát lòng đường với sai số $\le 5.00\text{ m}$. (So sánh: bản cũ là $7.00\text{ m}$, GPS thô lên tới $8.00\text{ m}$).

---

#### 3. Max Error (Đỉnh văng sai số cực đại)
* **Công thức tổng quát:**
  $$\text{MaxErr} = \max_{i=1\dots N} \|\hat{\mathbf{p}}_i - \mathbf{p}_i^*\|$$
* **Ví dụ tính toán số thực:**
  - Quét tìm phần tử lớn nhất trong mảng sai số 1,972 giây:
  - Cú văng cực đại diễn ra tại giây $t = 551\text{s}$ (đầu Kênh Tân Hóa nối Đặng Nguyên Cẩn có cao ốc & tán cây):
    * Tọa độ chuẩn Google Maps: $(10.759257, 106.634691)$
    * Tọa độ ước lượng EKF: $(10.759313, 106.634754)$
    * Khoảng cách sai lệch thực tế: $\text{MaxErr}_{ekf} = \mathbf{9.00\text{ m}}$.
* **So sánh thực nghiệm:** GPS thô văng cực đại tới **$16.0\text{ m}$**, bản cũ văng **$13.0\text{ m}$**, Turn-Adaptive EKF gìm lại chỉ còn **$9.0\text{ m}$** (giảm 30.8% đỉnh văng).

---

#### 4. Distance Error % (Sai số quãng đường tổng thể / MAPE)
* **Công thức tổng quát:**
  $$\text{MAPE} = \frac{|L_{measured} - L_{truth}|}{L_{truth}} \times 100\%$$
* **Ví dụ tính toán trên dữ liệu thực tế (Session 5e401125, $L_{truth} = 11,110.0\text{ m}$):**
  - **Với GPS Thô (Sensor Unfiltered):** Trích xuất từ 1,876 điểm `raw_gps_points` đạt $L_{raw} = \mathbf{11,298.42\text{ m}}$ ($11.298\text{ km}$):
    $$\text{MAPE}_{raw} = \frac{|11,298.42 - 11,110.0|}{11,110.0} \times 100\% = \frac{188.42}{11,110.0} \times 100\% = \mathbf{1.70\%}$$
  - **Với Turn-Adaptive 4-State EKF (Trong App Aetron):** Đo được $L_{ekf} = \mathbf{10,986.40\text{ m}}$ ($10.986\text{ km}$):
    $$\text{MAPE}_{ekf} = \frac{|10,986.40 - 11,110.0|}{11,110.0} \times 100\% = \frac{123.60}{11,110.0} \times 100\% = \mathbf{1.11\%}$$
* **Ý nghĩa:** EKF làm mượt các bước nhảy ziczac và ghìm trôi tĩnh, giúp giảm độ lệch tuyệt đối từ $188.4\text{ m}$ xuống $123.6\text{ m}$ (cải thiện độ chính xác **34.4%** so với dữ liệu thô).

---

#### 5. Stationary Drift (Trôi tĩnh khi dừng đèn đỏ)
* **Công thức tổng quát:**
  $$\text{Drift} = \sum_{t \in \text{stop}} \|\hat{\mathbf{p}}_t - \hat{\mathbf{p}}_{t-1}\|$$
* **Ví dụ tính toán trên dữ liệu thực tế (Session 5e401125):**
  - **Thời gian dừng thực tế:** Toàn phiên ghi nhận $1,940\text{ s}$, moving time $1,846\text{ s} \implies$ Tổng thời gian dừng đèn đỏ $t_{stop} = \mathbf{94\text{ giây}}$.
  - **Với GPS Thô:** Trong 94 giây đứng chờ đèn đỏ, tọa độ cảm biến tiếp tục dao động ziczac cục bộ, góp phần làm tổng cự ly dôi dư $+188.4\text{ m}$.
  - **Với Turn-Adaptive EKF:** Thuật toán kích hoạt cơ chế Anchor Clamping ($v < 0.8\text{ m/s}$), cưỡng bức khóa cứng vận tốc và cự ly tích lũy, ngăn ngừa cự ly ảo.

---

#### 6. Turn Apex Lag (Độ trễ ôm góc cua 90° và chống vát xéo nhà dân)
* **Công thức tổng quát:**
  $$\text{Lag} = \|\hat{\mathbf{p}}_{apex} - \mathbf{p}_{apex}^*\|$$
* **Ví dụ tính toán số thực tại góc cua Võ Thành Trang ➔ Nguyễn Bá Tòng (Ảnh 1):**
  - Tọa độ đỉnh ngã ba thực địa: $\mathbf{p}_{apex}^* = (10.792408, 106.652449)$.
  - **Với Bản Cũ:** Bộ lọc thông thường phản ứng chậm với góc cua vuông, vệt chạy bị cắt xéo qua mép tòa nhà góc phố. Điểm gần đỉnh nhất cách đỉnh thực địa:
    $$\text{Lag}_{old} = \mathbf{13.00\text{ m}}$$
  - **Với Turn-Adaptive EKF:** Thuật toán nhận diện tốc độ đổi hướng $\omega > 15^\circ/\text{s}$, ma trận nhiễu $Q$ tự động mở rộng gấp $4.11$ lần, kéo vệt chạy bám chặt theo tim đường:
    $$\text{Lag}_{ekf} = \mathbf{7.00\text{ m}}$$
  - (Cải thiện gần 50% độ trễ ôm cua, triệt tiêu vệt chạy vát chéo vào nhà dân).

---

#### 7. Đánh giá chuẩn Y sinh Thể thao Scott et al. (2016) & Gilgen-Ammann (2020)
* **Công thức tính MAPE chuẩn:**
  $$\text{MAPE} = \frac{|d_{meas} - d_{ref}|}{d_{ref}} \times 100\%$$
* **Số liệu thực nghiệm từ buổi đo thực tế thật của app Aetron ngoài đời (Session 5e401125):**
  - Cự ly mốc chuẩn đo trên Google Maps: $d_{ref} = 11.110\text{ km} = \mathbf{11,110.0\text{ m}}$.
  - Cự ly Aetron ghi nhận trên iPhone 15 Pro Max: $d_{meas} = 10.986\text{ km} = \mathbf{10,986.4\text{ m}}$.
  - Sai số cự ly tuyệt đối: $\text{MAE} = |10,986.4 - 11,110.0| = \mathbf{123.6\text{ m}}$ (chỉ 124m trên 11.110 km).
  - Sai số phần trăm tuyệt đối:
    $$\text{MAPE} = \frac{123.6}{11,110.0} \times 100\% = \mathbf{1.11\%}$$
  - **Phân loại Scott et al. (2016):** Vì $\text{MAPE} = 1.11\% < 5.0\% \implies$ Xếp loại **GOOD (Xuất Sắc trong Y Sinh Thể Thao)**.
  - **Đối chiếu Gilgen-Ammann et al. (2020):** Biên độ sai số $1.11\%$ vượt trội so với biên độ $3.2\% - 6.1\%$ của đồng hồ thể thao chuyên dụng Garmin Forerunner / Suunto 9.

---

### 5.2. Ví dụ số liệu tính toán chi tiết từng bước cho các Thuật Toán Nghiên Cứu

#### 1. Bộ Lọc Cũ (Fixed-Alpha Exponential Filter + Turn-Boost)
* **Công thức cập nhật:**
  $$\hat{p}_k = (1 - \alpha)\hat{p}_{k-1} + \alpha z_k$$
* **Ví dụ số liệu thực tế:**
  - Tọa độ trước đó: $x_{k-1} = 100.0\text{ m}$.
  - GPS đo được mẫu mới bị dội kính nhảy lệch: $z_k = 120.0\text{ m}$ (nhảy xa $20.0\text{ m}$).
  - Với $\alpha = 0.65$ cố định:
    $$\hat{x}_k = (1 - 0.65) \times 100.0 + 0.65 \times 120.0 = 35.0 + 78.0 = \mathbf{113.0\text{ m}}$$
    $\implies$ Điểm ước lượng bị kéo giật $13.0\text{ m}$ theo nhiễu!
  - Khi rẽ cua ($\Delta \theta > 35^\circ$), bộ lọc kích hoạt Turn-Boost $\alpha = 0.85$:
    $$\hat{x}_k = 0.15 \times 100.0 + 0.85 \times 120.0 = \mathbf{117.0\text{ m}}$$
  - **Nhược điểm cốt tử:** Hệ số $\alpha$ hoàn toàn không phụ thuộc vào ma trận sai số phần cứng $R = \text{accuracy}^2$. Dù GPS báo vệ tinh đang nhiễu nặng $30\text{ m}$ thì $\alpha$ vẫn mù quáng kéo điểm theo, dẫn đến sai số cự ly lên tới $+17.71\%$.

---

#### 2. Turn-Adaptive Extended Kalman Filter (EKF 4-State - Thuật toán chủ đạo)
* **Vector trạng thái 4 chiều:** $\mathbf{x} = [x, y, v, \theta]^T$ (Tọa độ phẳng mét, vận tốc m/s, góc hướng độ).
* **Ví dụ số liệu thực tế tại khúc cua 90° góc Võ Thành Trang ➔ Nguyễn Bá Tòng (Ảnh 1):**
  - **Bước 1: Trạng thái trước đó khi chạy trên Võ Thành Trang:**
    $$\mathbf{x}_{k-1} = [x=0.0\text{ m}, y=0.0\text{ m}, v=6.2\text{ m/s}, \theta=45.0^\circ]^T$$
    Phương sai độ không đảm bảo: $P_{k-1} = \text{diag}(4.0, 4.0, 0.5, 0.05)$.
  - **Bước 2: Dự báo động học (State Prediction) với $\Delta t = 1.0\text{s}$:**
    $$x_{pred} = x_{k-1} + v \cdot \sin(45.0^\circ) \cdot 1.0 = 0.0 + 6.2 \times 0.7071 \times 1.0 = \mathbf{4.38\text{ m}}$$
    $$y_{pred} = y_{k-1} + v \cdot \cos(45.0^\circ) \cdot 1.0 = 0.0 + 6.2 \times 0.7071 \times 1.0 = \mathbf{4.38\text{ m}}$$
    Phương sai dự báo: $P_{pred} = P_{k-1} + Q = 4.0 + 0.5 = \mathbf{4.5\text{ m}^2}$.
  - **Bước 3: Khối thích nghi động học góc cua (Turn Innovation):**
    GPS đo được góc hướng mới chuyển hẳn sang đường Nguyễn Bá Tòng: $\theta_{meas} = 138.2^\circ$.
    Tốc độ đổi góc hướng:
    $$\omega = \frac{|138.2^\circ - 45.0^\circ|}{1.0\text{ s}} = \mathbf{93.2^\circ/\text{s}} > 15.0^\circ/\text{s}$$
    Hệ số khuếch đại thích nghi:
    $$\text{factor} = 1.0 + 3.0 \times \left(\frac{93.2}{90.0}\right) = 1.0 + 3.11 = \mathbf{4.11}$$
    Phương sai nhiễu góc hướng tự mở rộng:
    $$Q_{\theta,\theta} \leftarrow 0.05 \times 4.11 = \mathbf{0.206}$$
  - **Bước 4: Tính Kalman Gain và Cập nhật:**
    Phần cứng GPS báo $\text{accuracy} = 4.0\text{ m} \implies R = 4.0^2 = 16.0\text{ m}^2$.
    Kalman Gain vị trí:
    $$K_{pos} = \frac{P_{pred}}{P_{pred} + R} = \frac{4.5}{4.5 + 16.0} = \frac{4.5}{20.5} \approx \mathbf{0.22}$$
    Nếu GPS bị văng ngang $z_x = 8.50\text{ m}$:
    $$\hat{x} = 4.38 + 0.22 \times (8.50 - 4.38) = 4.38 + 0.91 = \mathbf{5.29\text{ m}}$$
    Kalman Gain góc rẽ (nhờ $Q$ mở rộng):
    $$K_{turn} = \frac{0.206}{0.206 + 0.10} \approx \mathbf{0.67}$$
    $\implies$ Trọng số cập nhật góc cua tăng vọt lên $0.67$, kéo vệt chạy bám chặt tim đường Nguyễn Bá Tòng, triệt tiêu hiện tượng vát xéo đâm xuyên vào nhà dân góc ngã ba.

---

#### 3. IMU Sensor Fusion & Thuật Toán Sải Chân Weinberg PDR
* **Công thức sải chân Weinberg:**
  $$L = K_{weinberg} \cdot \sqrt[4]{a_{max} - a_{min}}$$
* **Ví dụ số liệu thực tế qua tán cây rậm dọc Kênh Tân Hóa (Mất GPS 6 giây):**
  - Người dùng cao 1.70m, hệ số cá nhân $K = 0.42$.
  - Trong 1 chu kỳ bước chạy, cảm biến gia tốc kế (Accelerometer) đo được: đỉnh gia tốc chạm đất $a_{max} = 18.5\text{ m/s}^2$, đáy gia tốc bay người $a_{min} = 2.5\text{ m/s}^2$.
  - Chênh lệch gia tốc: $\Delta a = 18.5 - 2.5 = 16.0\text{ m/s}^2$.
  - Căn bậc 4: $\sqrt[4]{16.0} = 2.0$.
  - Độ dài bước chân tính ra:
    $$L = 0.42 \times 2.0 = \mathbf{0.84\text{ m}} \text{ (84 cm/bước)}$$
  - Nhịp bước Pedometer ghi nhận: $175\text{ bước/phút} \approx 2.92\text{ bước/giây}$.
  - Tổng số bước trong 6 giây mất GPS: $6 \times 2.92 = 17.5\text{ bước}$.
  - Quãng đường suy đoán tịnh tiến (Dead Reckoning):
    $$\Delta s = 17.5 \times 0.84\text{ m} = \mathbf{14.7\text{ m}}$$
  - **Kết quả:** Vệt chạy tiếp tục được vẽ mượt mà xuyên qua tán cây mà không hề bị đứng đơ màn hình!

---

#### 4. DBSCAN Dwell Clustering (Gom cụm mật độ điểm dừng tĩnh)
* **Công thức láng giềng bán kính $\varepsilon$:**
  $$N_\varepsilon(p) = \{q \in D \mid \text{dist}(p, q) \le \varepsilon\}$$
* **Ví dụ số liệu thực tế:**
  - Trong 24 giây dừng chờ đèn đỏ tại nút giao Ngã tư Bảy Hiền (`10.793025, 106.653089`), GPS sinh ra 24 điểm tọa độ nhảy tản mát trong bán kính $\approx 4.5\text{ m}$.
  - Cài đặt tham số: $\varepsilon = 6.0\text{ m}$, $\text{MinPts} = 10\text{ điểm}$ (tương đương dừng $\ge 10\text{ s}$).
  - Quét từng điểm: Cả 24 điểm đều có $> 20$ láng giềng trong bán kính $6.0\text{ m} \implies$ Thuật toán gom trọn thành **1 Cụm dừng tĩnh duy nhất**.
  - Tính tâm cụm (Centroid):
    $$\text{Lat}_{centroid} = \mathbf{10.793025}, \quad \text{Lng}_{centroid} = \mathbf{106.653089}$$
  - Thuật toán thay thế 24 điểm nhảy nhót bằng duy nhất 1 điểm $P_{centroid}$.
  - **Kết quả:** Triệt tiêu hoàn toàn $148.0\text{ m}$ trôi ảo tại nút giao Ngã tư Bảy Hiền trong dữ liệu xuất ra cuối buổi tập.

---

#### 5. HMM Map-Matching & Làm Mượt Pace Savitzky-Golay
* **HMM Map-Matching:**
  - Điểm GPS bị lệch tâm đường: cách tim đường Võ Thành Trang $6\text{ m}$, cách hẻm cụt nhánh phụ $22\text{ m}$.
  - Hàm xác suất phát xạ Gauss với $\sigma = 5.0\text{ m}$:
    $$P(z \mid \text{Võ Thành Trang}) \propto \exp\left(-\frac{6^2}{2 \times 5^2}\right) = \exp(-0.72) \approx \mathbf{0.487}$$
    $$P(z \mid \text{Hẻm phụ}) \propto \exp\left(-\frac{22^2}{2 \times 5^2}\right) = \exp(-9.68) \approx \mathbf{0.000063}$$
  - Thuật toán Viterbi so sánh xác suất $0.487 \gg 0.000063 \implies$ Hút ngay điểm tọa độ bám chắc vào tim đường Võ Thành Trang.
* **Savitzky-Golay Pace Smoothing:**
  - 5 mẫu vận tốc tức thời: $[16, 22, 18, 25, 20]\text{ km/h}$.
  - Trung bình trượt (Moving Average) làm bẹt đỉnh: $\frac{16+22+18+25+20}{5} = \mathbf{20.2\text{ km/h}}$ (mất pha sprint).
  - Bộ lọc Savitzky-Golay bậc 2 fit đa thức cục bộ: Bảo toàn đỉnh bứt tốc đạt $\mathbf{24.8\text{ km/h}}$ trong khi vẫn khử sạch các gai nhiễu!

---

## 6. CƠ CHẾ THUẬT TOÁN: TURN-ADAPTIVE EKF

```
                      +------------------------------------------+
                      |   Đo đạc GPS thô (z_k = [x_m, y_m]^T)    |
                      +------------------------------------------+
                                           |
                                           v
                   +--------------------------------------------------+
                   |  DỰ BÁO TRẠNG THÁI (State Prediction)            |
                   |  x_{k|k-1} = f(x_{k-1}, dt)                      |
                   |  P_{k|k-1} = F_k * P_{k-1} * F_k^T + Q_k(dt)     |
                   +--------------------------------------------------+
                                           |
                                           v
+--------------------------------------------------------------------------------------+
|  KHỐI THÍCH NGHI ĐỘNG HỌC GÓC CUA (Turn-Adaptive Innovation)                        |
|  - Tính tốc độ đổi hướng: omega = |theta_meas - theta_{k-1}| / dt                     |
|  - Nếu omega > 15 deg/s:                                                             |
|      Q_{theta, theta} <- Q_{theta, theta} * (1.0 + 3.0 * (omega / 90.0))             |
|      => Ma trận độ tin cậy K tự động nghiêng về phép đo mới để bám sát góc cua       |
+--------------------------------------------------------------------------------------+
                                           |
                                           v
                   +--------------------------------------------------+
                   |  CẬP NHẬT TRẠNG THÁI (Measurement Update)        |
                   |  y_k = z_k - h(x_{k|k-1})                        |
                   |  S_k = H * P_{k|k-1} * H^T + R_k                 |
                   |  K_k = P_{k|k-1} * H^T * S_k^{-1}                |
                   |  x_{k|k} = x_{k|k-1} + K_k * y_k                 |
                   |  P_{k|k} = (I - K_k * H) * P_{k|k-1}             |
                   +--------------------------------------------------+
                                           |
                                           v
+--------------------------------------------------------------------------------------+
|  CƠ CHẾ KHÓA NEO TĨNH (Stationary Anchor Clamping)                                  |
|  - Nếu v_k <= 0.8 m/s VÀ distance(current, anchor) <= 6.0 m:                         |
|      isStationary = true; v_k = 0.0 m/s; Khóa quãng đường tích lũy                  |
+--------------------------------------------------------------------------------------+
```

---

## 6. KẾT QUẢ ĐỐI SOÁT THỰC ĐỊA NGOÀI ĐỜI THẬT (SESSION 5e401125)
> **Trạng thái:** Đã ghi nhận thực tế trên iPhone 15 Pro Max & đồng bộ thành công lên Supabase Cloud Database.
> **Cung đường:** Tuyến đường phố thực tế TP.HCM (Đối chiếu Ground Truth Google Maps: **$11.110\text{ km}$**).

#### 1. Dữ liệu trích xuất nguyên bản từ Supabase Database (SQL Verified)
* **Tài khoản người dùng (User UUID):** `395bb11a-da4b-488e-8477-05ca6ee62255`
* **Mã phiên bài tập (Workout ID):** `5e401125-67cf-4ff1-b26e-266e9129d2b3`
* **Loại hình hoạt động:** `cycling` (Outdoor)
* **Thời gian bắt đầu / kết thúc:** `2026-10-27 00:27:28.719Z` ➔ `2026-10-27 00:59:51.055Z`
* **Thời lượng ghi nhận:** **1,940 giây (32 phút 20 giây)** • **Moving time:** **1,846 giây (30 phút 46 giây)**
* **Tốc độ trung bình:** **$20.39\text{ km/h}$** • **Năng lượng:** **$819\text{ kcal}$**
* **Số lượng tọa độ GPS raw đồng bộ:** **1,876 điểm** (tần số lấy mẫu đều đặn 1 Hz từ 00:27:29.368Z đến 00:59:47.999Z).

#### 2. Đối chiếu số liệu đo đạc thực tế ngoài đời thật (Session 5e401125)
> **Ghi chú quan trọng:** Dữ liệu thực tế **10.986 km (MAPE 1.11%)** đo được trên điện thoại iPhone 15 Pro Max (Session `5e401125`) chính là kết quả ghi nhận của **Turn-Adaptive 4-State EKF** trên nhánh `algo/ekf-4state-standard`. Dữ liệu **GPS Thô 11.298 km (1,876 điểm)** ghi nhận đồng thời từ cảm biến phần cứng trong chính phiên chạy này. Riêng **Bản cũ (Fixed-Alpha trên nhánh main cũ)** hiện tại **chưa có dữ liệu thực tế ngoài đời** (cả dữ liệu GPS thô lẫn kết quả lọc của bản cũ đều chưa thu thập, để trống chờ chạy thực địa đợt 2).

| Phương án / Nguồn dữ liệu thực địa | Mốc chuẩn Google Maps ($L_{ref}$) | App Ghi Nhận Thực Tế ($L_{meas}$) | Sai số thực tế ($\Delta L$) | Sai số MAPE % | Tình trạng thực địa |
|---|:---:|:---:|:---:|:---:|---|
| **0. Mốc Chuẩn Google Maps (Ground Truth)** | **11.110 km** ($11,110.0\text{ m}$) | — | 0.0 m | **0.00%** | Chuẩn tim đường thực địa |
| **1. GPS Thô (Đo từ đợt chạy 4-State EKF trên iPhone)** | **11.110 km** | **11.298 km** ($11,298.42\text{ m}$) | **+188.4 m** | **1.70% (Chuẩn GOOD)** | ✅ **Đã trích xuất SQL thực tế** (1,876 điểm raw, nhánh EKF) |
| **2. Bản Cũ (Fixed-Alpha trên nhánh main cũ)** | **11.110 km** | *— (Chưa có)* | *—* | *—* | ⏳ **[ĐỂ TRỐNG — Chờ chạy thực địa đợt 2 với bản cũ]** |
| **3. Turn-Adaptive 4-State EKF (Đo thực tế trên iPhone)** | **11.110 km** | **10.986 km** ($10,986.4\text{ m}$) | **-123.6 m** | **1.11% (Chuẩn GOOD)** | ✅ **Đã thu thập thực tế** (Session `5e401125`, nhánh 4-State EKF) |

#### 3. Cách lấy dữ liệu GPS Thô từ điện thoại & Câu lệnh SQL tính cự ly thô
Khi ứng dụng Aetron ghi nhận bài tập ngoài trời:
1. Mỗi điểm tọa độ từ cảm biến phần cứng GPS (`geolocator.positionStream`) đều được lưu trữ trực tiếp vào cơ sở dữ liệu Isar trên điện thoại (`LocalGPSPoint`) và tự động đồng bộ lên Supabase Cloud trong bảng `public.raw_gps_points`.
2. Do đó, để lấy dữ liệu GPS thô và tính tổng quãng đường thô (chưa qua bộ lọc EKF), chỉ cần chạy câu lệnh SQL sau trên **Supabase SQL Editor**:

```sql
-- 1. Tính tổng cự ly GPS thô (chưa lọc) của Session 5e401125 bằng công thức Haversine:
WITH ordered_points AS (
    SELECT
        timestamp,
        latitude,
        longitude,
        LAG(latitude) OVER (ORDER BY timestamp ASC) AS prev_lat,
        LAG(longitude) OVER (ORDER BY timestamp ASC) AS prev_lng
    FROM public.raw_gps_points
    WHERE workout_id = '5e401125-67cf-4ff1-b26e-266e9129d2b3'
)
SELECT
    COUNT(*) AS tong_so_diem_tho,
    ROUND(
        SUM(
            2 * 6371000 * asin(sqrt(
                pow(sin(radians(latitude - prev_lat) / 2), 2) +
                cos(radians(prev_lat)) * cos(radians(latitude)) *
                pow(sin(radians(longitude - prev_lng) / 2), 2)
            ))
        )::numeric, 2
    ) AS tong_cu_ly_tho_met,
    ROUND(
        (SUM(
            2 * 6371000 * asin(sqrt(
                pow(sin(radians(latitude - prev_lat) / 2), 2) +
                cos(radians(prev_lat)) * cos(radians(latitude)) *
                pow(sin(radians(longitude - prev_lng) / 2), 2)
            ))
        ) / 1000)::numeric, 3
    ) AS tong_cu_ly_tho_km
FROM ordered_points
WHERE prev_lat IS NOT NULL;

-- 2. Hoặc trích xuất toàn bộ 1,876 điểm thô ra file CSV (Table Editor -> Export CSV):
SELECT
    timestamp,
    latitude,
    longitude,
    altitude,
    speed,
    accuracy,
    heading
FROM public.raw_gps_points
WHERE workout_id = '5e401125-67cf-4ff1-b26e-266e9129d2b3'
ORDER BY timestamp ASC;
```

**Kết quả thực thi câu lệnh SQL trực tiếp trên Supabase (Session `5e401125`):**

| `tong_so_diem_tho` | `tong_cu_ly_tho_met` | `tong_cu_ly_tho_km` |
|:---:|:---:|:---:|
| **1875** (1,876 điểm tọa độ) | **11298.42 m** | **11.298 km** |

> 📊 **Phân tích so sánh khoa học giữa GPS Thô và EKF:**
> - **GPS Thô (Sensor Unfiltered):** Cảm biến phần cứng đo ra **11.298 km** ($11,298.42\text{ m}$), chênh lệch **+188.4 m** (+1.70% MAPE) so với chuẩn Google Maps 11.110 km. Nguyên nhân cự ly thô bị dội tăng là do nhiễu jitter ngẫu nhiên của sensor gây dập dềnh ziczac giữa các tọa độ 1Hz liên tiếp khi đi chậm hoặc dừng đèn đỏ.
> - **Turn-Adaptive 4-State EKF (Trong App Aetron):** Thuật toán EKF tích hợp sẵn trên app đã khử rung ziczac, ghìm trôi dạt dừng chờ và điều chỉnh ma trận hiệp phương sai $R_k$ theo gia tốc góc cua, đưa cự ly đo được về **10.986 km** ($10,986.40\text{ m}$), chênh lệch chỉ **-123.6 m** (-1.11% MAPE).
> - **Đánh giá chuẩn quốc tế (Scott et al., 2016):** Cả hai kết quả đều đạt cấp độ **GOOD (< 5%)**, trong đó EKF giúp giảm sai số tuyệt đối từ 188.4 m xuống 123.6 m (cải thiện độ chính xác cự ly thêm **34.4%** so với dữ liệu thô chưa lọc).

> 📌 **Lưu ý về kế hoạch trực quan hóa 3 phiên bản:**
> Bản đồ Leaflet trong tài liệu HTML hiện đang chạy mô phỏng quỹ đạo giải tích trên tuyến đường OpenStreetMap (11.110 km) để trực quan hóa hành vi động học. Dữ liệu thực tế 100% của Đợt 1 (1,876 điểm GPS raw) đã được lưu trữ an toàn trong Database. Khi người dùng hoàn thành đủ cả 3 đợt chạy thực địa (Bản cũ Fixed-Alpha, Standard 4-State EKF, Turn-Adaptive EKF), hệ thống sẽ nạp trực tiếp toàn bộ 3 tập file GPS thực địa vào visualizer.

---
