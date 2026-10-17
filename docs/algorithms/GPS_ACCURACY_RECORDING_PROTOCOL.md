# Quy trình thu dữ liệu benchmark độ chính xác GPS cho Aetron

## 1. Mục tiêu

Tài liệu này quy định cách record dữ liệu GPS để:

- đo baseline của Aetron trước khi thay đổi EKF và DBSCAN;
- so sánh Raw GPS, pipeline hiện tại, EKF và EKF + DBSCAN trên cùng dữ liệu;
- đo sai số quãng đường, độ ổn định khi đứng yên, GPS gap và outlier;
- bảo đảm các buổi đo có thể lặp lại và so sánh công bằng.

Đây là protocol pilot sử dụng Google Maps làm khoảng cách tham chiếu. Khoảng cách Google Maps không phải ground-truth trắc địa. Kết quả pilot dùng để phát hiện lỗi logging, chọn tham số và chuẩn bị thí nghiệm chính thức; không được trình bày như độ chính xác tuyệt đối cấp nghiên cứu. Khi cần kết luận chính thức, thay Google Maps bằng RTK GNSS, bánh xe đo đường đã hiệu chuẩn hoặc tuyến đã được chứng nhận.

## 2. Phạm vi pilot

Nếu chỉ đánh giá đi/chạy, thu tối thiểu 9 session hợp lệ:

| Mã bài | Bài đo | Số session | Thời lượng hoặc khoảng cách |
|---|---|---:|---:|
| STATIC | Đứng yên ngoài trời | 3 | 10 phút/session |
| LOOP400 | Chạy tuyến Google Maps 400 m × 5 vòng | 3 | 2.000 m/session |
| URBAN | Đi/chạy tuyến đô thị hoặc có cây | 3 | 10–15 phút/session |

Nếu Aetron hỗ trợ cả đạp xe, bổ sung 6 session riêng:

| Mã bài | Bài đo | Số session | Thời lượng hoặc khoảng cách |
|---|---|---:|---:|
| BIKE-OPEN | Đạp xe tuyến thoáng, ít giao cắt | 3 | 3–5 km/session |
| BIKE-URBAN | Đạp xe tuyến đô thị/có cây và điểm dừng | 3 | 3–5 km/session |

- Chỉ đánh giá đi/chạy: `STATIC + LOOP400 + URBAN` = 9 session.
- Chỉ đánh giá đạp xe: `STATIC + BIKE-OPEN + BIKE-URBAN` = 9 session.
- Đánh giá đủ đi/chạy và đạp xe: 15 session vì 3 session STATIC được dùng chung.

Không gộp session đi bộ, chạy bộ và đạp xe khi tính MAPE, P50, P95 hoặc RMSE. Báo cáo mỗi activity type thành một nhóm riêng.

Chỉ thu tập chính thức sau khi các session pilot liên quan đạt tiêu chí chất lượng ở mục 10.

## 3. Thiết lập cố định

Giữ nguyên các điều kiện sau trong mọi session:

- Dùng cùng một điện thoại và cùng phiên bản Aetron.
- Bật quyền vị trí chính xác (`Precise location`).
- Tắt chế độ tiết kiệm pin và không bật chế độ máy bay.
- Đảm bảo pin ít nhất 40% trước khi bắt đầu.
- Đặt điện thoại cùng một vị trí trên cơ thể, ưu tiên túi đeo cố định ở eo hoặc cánh tay.
- Không cầm điện thoại trên tay ở session này rồi bỏ túi ở session khác.
- Với đạp xe, cố định điện thoại trên giá đỡ tay lái hoặc trong cùng một túi áo xe đạp. Không để điện thoại rung tự do trong giỏ xe.
- Không thay đổi tham số GPS, EKF, validation hoặc DBSCAN trong cùng một đợt benchmark.
- Không xóa workout, đăng xuất, gỡ app hoặc xóa dữ liệu app trước khi xác nhận raw GPS đã có trên Supabase.
- Không record trong điều kiện giao thông hoặc thời tiết gây nguy hiểm.

Trước mỗi session, ghi lại:

```text
Ngày và giờ:
Điện thoại:
Phiên bản OS:
Phiên bản/commit Aetron:
Loại bài đo: STATIC / LOOP400 / URBAN / BIKE-OPEN / BIKE-URBAN
Thời tiết: nắng / nhiều mây / mưa
Vị trí mang điện thoại:
Ghi chú môi trường:
```

## 4. Quy tắc đặt tên session

Ghi mã session vào sổ theo dõi ngay sau khi record:

```text
YYYYMMDD_<TEST>_<LẦN>
```

Ví dụ:

```text
20261012_STATIC_01
20261012_LOOP400_01
20261012_URBAN_01
20261012_BIKE-OPEN_01
20261012_BIKE-URBAN_01
```

Ghi kèm UUID của workout trên Supabase để đối chiếu:

| Mã session | Workout UUID | Bài đo | Tham chiếu | Ghi chú |
|---|---|---|---:|---|
| 20261012_LOOP400_01 | `<uuid>` | LOOP400 | 2.000 m | Trời quang |

## 5. Kiểm tra logging trước khi thu pilot

Chỉ cần làm một lần trước toàn bộ pilot.

1. Ra khu vực ngoài trời thoáng, tránh đứng sát tường hoặc dưới mái che.
2. Bật Aetron và chờ 60 giây để điện thoại bắt GPS ổn định.
3. Đặt điện thoại cố định, bắt đầu record và để yên đúng 10 phút.
4. Không pause workout và không chuyển app sang background.
5. Kết thúc workout, giữ kết nối mạng thêm ít nhất 15 giây để buffer upload.
6. Kiểm tra `raw_gps_points` trên Supabase.

Một session 10 phút ở tần số gần 1 Hz nên có khoảng 600 điểm. Chấp nhận để tiếp tục pilot khi:

- có ít nhất 540 điểm;
- timestamp tăng đúng thứ tự;
- không có khoảng mất mẫu dài bất thường do app bị đóng;
- workout có thời lượng xấp xỉ 10 phút.

Nếu có dưới 540 điểm, dừng việc thu pilot và kiểm tra logging trước.

## 6. Bài STATIC — đứng yên ngoài trời

### Mục tiêu

Đo độ phân tán, drift, outlier và quãng đường ảo khi thiết bị không di chuyển.

### Chuẩn bị

1. Chọn một điểm ngoài trời thoáng và có thể quay lại chính xác.
2. Đánh dấu vị trí đặt điện thoại bằng băng dính, viên gạch hoặc một mốc cố định.
3. Đặt điện thoại nằm yên; không cầm trên tay.
4. Chờ GPS ổn định 60 giây trước khi record.

### Thực hiện một session

1. Nhấn bắt đầu record.
2. Không chạm hoặc di chuyển điện thoại trong 10 phút.
3. Không pause, không khóa app bằng cách force close.
4. Sau đúng 10 phút, kết thúc workout.
5. Giữ mạng hoạt động ít nhất 15 giây.
6. Ghi mã session và UUID workout.

### Số lần

- Thực hiện 3 session.
- Nên thực hiện vào ít nhất 2 thời điểm khác nhau.
- Nghỉ ít nhất 2 phút giữa các session.

### Kết quả sẽ tính

- số điểm và availability;
- bán kính P50/P95 quanh tâm cụm điểm;
- độ lệch chuẩn East/North;
- tổng quãng đường ảo;
- số outlier và GPS gap;
- mức phù hợp giữa sai số thực nghiệm và trường `accuracy` của hệ điều hành.

Nếu tọa độ thật của mốc chưa được khảo sát, bài này đo precision và drift, không đo absolute accuracy.

## 7. Bài LOOP400 — tuyến Google Maps 400 m × 5 vòng

### Mục tiêu

Đo sai số tổng quãng đường trên một tuyến lặp lại, đồng thời quan sát sai số tại khúc cua và sai số đóng vòng.

### 7.1. Tạo tuyến tham chiếu

1. Mở Google Maps trên máy tính để thao tác dễ hơn.
2. Chọn một khu vực an toàn, ít giao cắt và có thể chạy lặp lại.
3. Dùng chức năng **Measure distance** để tạo một vòng dài gần 400 m.
4. Đặt các điểm đo bám theo đúng đường sẽ chạy, đặc biệt tại các khúc cua.
5. Điều chỉnh đến khi tổng chiều dài hiển thị là 400 m hoặc ghi lại chính xác giá trị Maps hiển thị, ví dụ 397 m hoặc 403 m.
6. Chọn một vật thể cố định làm vạch xuất phát/kết thúc.
7. Chụp màn hình tuyến, lưu đường link nếu có, và không chỉnh lại tuyến giữa các session.

Không làm tròn một tuyến 397 m thành 400 m. Khoảng cách tham chiếu phải dùng đúng giá trị Google Maps:

```text
reference_per_lap_m = khoảng cách Google Maps hiển thị
reference_total_m = reference_per_lap_m × 5
```

Ví dụ:

```text
reference_per_lap_m = 397 m
reference_total_m = 397 × 5 = 1.985 m
```

### 7.2. Chuẩn bị trước khi chạy

1. Đến đúng vạch xuất phát đã chọn.
2. Gắn điện thoại vào vị trí cố định đã quy định.
3. Mở Aetron và chờ GPS ổn định 60 giây.
4. Kiểm tra pin, quyền vị trí chính xác và kết nối mạng.
5. Chuẩn bị cách đếm vòng độc lập: đồng hồ bấm vòng, vòng tay cao su hoặc ghi chú giấy.

### 7.3. Thực hiện một session

1. Đứng đúng vạch xuất phát và nhấn bắt đầu record.
2. Đứng yên 30 giây để đo drift ban đầu.
3. Bắt đầu chạy và bám cùng một mép đường đã đo trên Google Maps.
4. Chạy đúng 5 vòng, không cắt góc và không đổi chiều giữa session.
5. Không pause Aetron khi dừng ngắn hoặc phải giảm tốc.
6. Sau vòng thứ 5, dừng đúng tại vạch xuất phát.
7. Đứng yên thêm 30 giây để đo drift cuối và sai số đóng vòng.
8. Kết thúc workout.
9. Giữ mạng hoạt động ít nhất 15 giây.
10. Ghi mã session, UUID, số vòng thực tế và mọi sự cố.

Nếu không thể chạy liên tục, được phép đi bộ. Khi đó phải ghi rõ activity là `walking` và dùng cùng cách di chuyển cho cả 3 session. Không trộn một session đi bộ với hai session chạy khi tính cùng một nhóm kết quả.

### 7.4. Số lần

- Thực hiện 3 session hợp lệ.
- Ưu tiên thực hiện vào ít nhất 2 ngày hoặc 2 thời điểm khác nhau.
- Nghỉ đủ để tốc độ giữa các session không thay đổi vì mệt.

### 7.5. Kết quả sẽ tính

Với khoảng cách app ghi nhận là `aetron_distance_m`:

```text
signed_error_percent =
  (aetron_distance_m - reference_total_m) / reference_total_m × 100

absolute_percentage_error = abs(signed_error_percent)
```

Ngoài ra tính:

- sai số từng session theo mét và phần trăm;
- MAPE của 3 session;
- sai số đóng vòng giữa điểm đầu và điểm cuối;
- số điểm, availability, GPS gap và outlier;
- độ lặp lại giữa 3 session.

## 8. Bài URBAN — tuyến đô thị hoặc có cây

### Mục tiêu

Kiểm tra app trong điều kiện multipath và che khuất thực tế.

### Chuẩn bị

1. Chọn một tuyến cố định dài khoảng 1–2 km hoặc mất 10–15 phút.
2. Tuyến nên có một số nhà cao tầng, hàng cây hoặc đoạn che khuất nhưng vẫn an toàn.
3. Dùng đúng cùng điểm bắt đầu, điểm kết thúc và hướng di chuyển trong mọi session.
4. Đo tuyến bằng Google Maps và lưu ảnh/link như với LOOP400.
5. Ghi rõ tuyến là `urban`, `tree-covered` hoặc kết hợp cả hai.

### Thực hiện một session

1. Chờ GPS ổn định 60 giây tại điểm bắt đầu.
2. Nhấn record và đứng yên 30 giây.
3. Đi hoặc chạy hết tuyến với tốc độ tự nhiên, không pause app.
4. Không cố ý đổi sang vỉa hè đối diện hoặc rẽ khỏi tuyến đã định.
5. Đứng yên 30 giây tại điểm cuối rồi kết thúc workout.
6. Giữ mạng hoạt động ít nhất 15 giây.
7. Ghi lại các sự kiện như dừng đèn đỏ, mất mạng, đổi vỉa hè hoặc lệch tuyến.

### Số lần

- Thực hiện 3 session.
- Dùng cùng activity type và cách mang điện thoại.
- Nên trải qua ít nhất 2 thời điểm khác nhau.

### Kết quả sẽ tính

- sai số quãng đường so với Google Maps;
- GPS gap và availability;
- số outlier;
- drift trong lúc dừng;
- khác biệt giữa Raw GPS và các pipeline lọc;
- mức suy giảm so với tuyến thoáng LOOP400.

## 9. Bài đạp xe

### Vì sao cần protocol riêng

Không dùng kết quả đi/chạy để suy ra độ chính xác khi đạp xe. Đạp xe có tốc độ cao hơn, quãng đường giữa hai mẫu GPS dài hơn, cách mang điện thoại khác và dễ phát sinh sai số cắt góc. Các lần dừng đèn đỏ cũng là tình huống quan trọng để đánh giá stationary drift và DBSCAN.

Không khuyến nghị dùng vòng 400 m × 5 cho xe đạp, trừ khi đó là đường khép kín dành riêng cho xe. Vòng ngắn khiến khúc cua chiếm tỷ lệ quá lớn và có thể không an toàn. Dùng tuyến 3–5 km sẽ phù hợp hơn.

### 9.1. Tạo khoảng cách tham chiếu

Chọn một trong các phương án, theo thứ tự ưu tiên:

1. RTK GNSS gắn cùng xe.
2. Cảm biến tốc độ bánh xe hoặc đồng hồ xe đạp đã hiệu chỉnh chu vi bánh.
3. Tuyến có khoảng cách được chứng nhận hoặc đo bằng bánh xe đo đường.
4. Google Maps cho pilot sơ bộ.

Nếu dùng cảm biến bánh xe:

1. Bơm lốp tới áp suất thường sử dụng.
2. Đánh dấu một điểm trên lốp và mặt đất.
3. Cho xe lăn thẳng đúng một vòng bánh khi người lái ngồi trên xe.
4. Đo khoảng cách giữa hai dấu bằng milimét.
5. Nhập chu vi này vào đồng hồ/cảm biến xe đạp.
6. Không đổi lốp hoặc áp suất giữa các session nếu có thể.

Cảm biến bánh xe là tham chiếu quãng đường độc lập tốt cho pilot, nhưng không tạo ground-truth tọa độ theo timestamp.

### 9.2. BIKE-OPEN — tuyến xe đạp thoáng

#### Chuẩn bị tuyến

1. Chọn tuyến dài 3–5 km, ưu tiên đường thẳng hoặc khứ hồi.
2. Tuyến phải an toàn, ít giao cắt, ít nhà cao tầng và ít cây che phủ.
3. Đánh dấu điểm đầu, điểm quay đầu và điểm kết thúc bằng các vật thể cố định.
4. Đo và lưu khoảng cách tham chiếu; không chỉnh lại tuyến giữa các session.
5. Chụp màn hình hoặc lưu link tuyến nếu dùng Google Maps.

#### Thực hiện một session

1. Chọn activity `cycling` trong Aetron.
2. Gắn chắc điện thoại; không thao tác điện thoại khi xe đang di chuyển.
3. Chờ GPS ổn định 60 giây tại vạch xuất phát.
4. Nhấn record và đứng yên 30 giây.
5. Đạp hết tuyến ở tốc độ tự nhiên, ổn định; không cần chạy nước rút.
6. Giữ đúng hướng và mép đường đã chọn. Nếu là tuyến khứ hồi, quay đầu tại đúng mốc.
7. Không pause Aetron khi giảm tốc hoặc dừng ngắn.
8. Dừng đúng vạch kết thúc, đứng yên 30 giây rồi kết thúc workout.
9. Giữ mạng hoạt động ít nhất 15 giây.
10. Ghi mã session, UUID, khoảng cách tham chiếu, khoảng cách cảm biến bánh xe nếu có và mọi sự cố.

Thực hiện 3 session, ưu tiên vào ít nhất 2 thời điểm khác nhau. Dùng cùng xe, lốp, vị trí điện thoại và hướng tuyến.

### 9.3. BIKE-URBAN — tuyến xe đạp đô thị/có cây

#### Chuẩn bị tuyến

1. Chọn tuyến cố định dài 3–5 km có một số tòa nhà, hàng cây, khúc cua và điểm phải dừng.
2. Ưu tiên làn xe đạp hoặc đường ít nguy hiểm; an toàn quan trọng hơn việc giữ tốc độ.
3. Dùng cùng điểm đầu, điểm cuối, hướng di chuyển và phía đường trong mọi session.
4. Đo và lưu khoảng cách tham chiếu như BIKE-OPEN.
5. Ghi trước các điểm dừng dự kiến, ví dụ đèn đỏ hoặc giao lộ.

#### Thực hiện một session

1. Chọn activity `cycling`, gắn điện thoại cố định và chờ GPS 60 giây.
2. Nhấn record, đứng yên 30 giây rồi bắt đầu đạp.
3. Đi đúng tuyến với tốc độ tự nhiên và tuân thủ giao thông.
4. Không pause Aetron tại đèn đỏ. Các đoạn dừng này là dữ liệu cần thiết để đánh giá drift và DBSCAN.
5. Không cố tạo tình huống nguy hiểm để giữ tốc độ hoặc tránh dừng.
6. Tại điểm cuối, đứng yên 30 giây rồi kết thúc workout.
7. Ghi lại thời điểm hoặc vị trí các lần dừng, đổi tuyến, mất mạng và sự cố.

Thực hiện 3 session, ưu tiên vào ít nhất 2 thời điểm khác nhau.

### 9.4. Chỉ số riêng cho đạp xe

Báo cáo BIKE-OPEN và BIKE-URBAN riêng, gồm:

- sai số quãng đường theo mét và phần trăm;
- MAPE giữa các session;
- availability, GPS gap và outlier;
- sai số đóng tuyến nếu điểm đầu và cuối trùng nhau;
- drift và quãng đường ảo tại các lần dừng;
- độ trễ hoặc cắt góc khi rẽ;
- sai số tốc độ so với cảm biến bánh xe, nếu có tham chiếu tốc độ;
- kết quả Raw, validation, EKF và EKF + DBSCAN trên cùng log.

Không so tốc độ GPS với cảm giác hoặc tốc độ hiển thị không được hiệu chỉnh. Không cộng session xe đạp vào trung bình của session chạy bộ.

## 10. Tiêu chí một session hợp lệ

Một session chỉ được đưa vào benchmark khi đáp ứng tất cả điều kiện:

- đúng tuyến, đúng số vòng và đúng activity type đã ghi;
- raw GPS tồn tại trên Supabase;
- thời gian record khớp với ghi chú thực địa;
- số điểm đạt ít nhất 90% số điểm kỳ vọng ở tần số 1 Hz;
- không force close app hoặc khởi động lại điện thoại giữa session;
- không thay đổi vị trí mang điện thoại;
- không thiếu thông tin tham chiếu và UUID workout.

Số điểm kỳ vọng:

```text
expected_points ≈ duration_seconds + 1
availability_percent = actual_points / expected_points × 100
```

Không xóa session lỗi. Đánh dấu `INVALID` và ghi lý do để phân biệt lỗi thuật toán với lỗi protocol.

## 11. Kiểm tra dữ liệu sau mỗi session

Chạy truy vấn sau trong Supabase SQL Editor và thay UUID:

```sql
select
  workout_id,
  count(*) as gps_points,
  min(timestamp) as started_at,
  max(timestamp) as ended_at,
  round(
    extract(epoch from max(timestamp) - min(timestamp))::numeric,
    1
  ) as duration_seconds,
  round(avg(accuracy)::numeric, 2) as avg_reported_accuracy,
  round(
    percentile_cont(0.95) within group (order by accuracy)::numeric,
    2
  ) as p95_reported_accuracy
from public.raw_gps_points
where workout_id = '<WORKOUT_UUID>'
group by workout_id;
```

Ghi kết quả vào bảng theo dõi:

| Session | UUID | Điểm | Thời gian (s) | Availability | Hợp lệ? | Lý do nếu lỗi |
|---|---|---:|---:|---:|---|---|
| 20261012_LOOP400_01 | `<uuid>` | 720 | 735 | 97,8% | Có | — |

## 12. Trình tự thực hiện đề xuất

1. Làm bài kiểm tra logging 10 phút.
2. Nếu logging đạt, thu 3 session STATIC.
3. Kiểm tra dữ liệu trước khi tiếp tục.
4. Thu 3 session LOOP400.
5. Kiểm tra dữ liệu và xác nhận đủ 5 vòng mỗi session.
6. Thu 3 session URBAN.
7. Nếu đánh giá đạp xe, thu 3 session BIKE-OPEN.
8. Kiểm tra dữ liệu rồi thu 3 session BIKE-URBAN.
9. Khóa tập pilot, không sửa hoặc xóa raw log.
10. Chạy offline replay cho Raw, validation, EKF và EKF + DBSCAN.
11. Báo cáo từng activity type riêng rồi mới chốt quy mô tập test chính thức.

## 13. Những điều không được kết luận từ pilot Google Maps

- Không gọi khoảng cách Google Maps là tọa độ ground-truth cấp centimet hoặc mét.
- Không dùng trường `accuracy` của điện thoại làm sai số thực tế.
- Không kết luận EKF chính xác hơn chỉ vì đường hiển thị mượt hơn.
- Không tính P50/P95 sai số vị trí tuyệt đối nếu không có ground-truth theo timestamp.
- Không dùng một session đơn lẻ để tuyên bố độ chính xác của Aetron.

Pilot này đủ để đánh giá logging, sai số quãng đường sơ bộ, drift, outlier, availability và chuẩn bị cho thí nghiệm có ground-truth chính xác hơn.
