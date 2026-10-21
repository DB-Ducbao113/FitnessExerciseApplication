# Báo cáo Chặng A — Benchmark GPS cho đạp xe

Ngày chạy: 2026-10-15

## Kết luận ngắn

Chưa nên bật EKF hoặc DBSCAN vào pipeline live.

- Trên mô phỏng đạp xe có ground-truth, pipeline hiện tại đạt RMSE **3,42 m**, P50 **2,62 m**, P95 **5,88 m**. EKF hiện có làm P95 tăng lên **18,48 m** và RMSE tăng lên **8,07 m**.
- DBSCAN không cải thiện sai số vị trí khi xe đang chạy; vai trò phù hợp của nó là collapse cụm đứng yên. Trong 7 workout thật, DBSCAN chỉ phát hiện 2 cụm ở 1 workout.
- 7 workout thật không có ground-truth. Vì vậy, khác biệt quãng đường giữa pipeline chỉ là diagnostic, không chứng minh pipeline nào chính xác hơn.
- Pipeline app đang chạy không bị thay đổi trong Chặng A.

## Bốn pipeline được so sánh

| Pipeline | Mục đích |
|---|---|
| Hiện tại | Validation + fixed-alpha smoothing đang dùng trong app |
| EKF | Cùng validation, thay smoothing bằng EKF |
| DBSCAN | Cùng validation, dùng T-DBSCAN để collapse dwell |
| EKF → DBSCAN | EKF trước, T-DBSCAN post-process sau |

Không chạy `DBSCAN → EKF`: T-DBSCAN cần cả cửa sổ thời gian và collapse nhiều điểm thành một centroid. Làm vậy trước EKF sẽ phá nhịp lấy mẫu, làm đổi `dt`, mất speed/heading của các mẫu đã collapse và không đại diện cho pipeline realtime. Outlier đơn lẻ trước EKF phải do validation hoặc innovation gate xử lý, không phải dwell clustering.

## 1. Dữ liệu iPhone thật — không có ground-truth

Tổng cộng 7 workout, 10.779 dòng journal, 10.730 timestamp duy nhất, 49 timestamp trùng, 149 gap trên 2 giây và 89 gap trên 5 giây. Gap lớn nhất là 17,007 giây.

`Reported P95` dưới đây là độ bất định do iPhone tự báo, **không phải** sai số đo so với vị trí thật.

| Workout | Điểm | Sampling availability | Reported P95 | Max gap | Điểm qua validation | Hiện tại | EKF | DBSCAN | EKF→DBSCAN | Dwell |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `session_1` | 1.186 | 100,00% | 31,16 m | 9,00 s | 60,88% | 5,082 km | 5,168 km | 5,158 km | 5,168 km | 0 |
| `session_6` | 1.674 | 93,94% | 14,25 m | 9,00 s | 71,45% | 8,624 km | 8,681 km | 8,720 km | 8,681 km | 0 |
| `session_7` | 2.322 | 87,13% | 21,52 m | 12,70 s | 75,84% | 11,943 km | 12,068 km | 12,209 km | 12,068 km | 0 |
| `session_5` | 1.957 | 98,10% | 14,25 m | 6,00 s | 84,16% | 10,899 km | 11,135 km | 11,036 km | 11,126 km | 2 |
| `session_3` | 101 | 95,28% | 14,25 m | 6,62 s | 53,47% | 0,234 km | 0,233 km | 0,242 km | 0,233 km | 0 |
| `session_4` | 2.330 | 99,62% | 10,05 m | 4,37 s | 83,39% | 14,690 km | 14,961 km | 14,849 km | 14,961 km | 0 |
| `session_2` | 1.160 | 88,62% | 14,25 m | 17,01 s | 70,00% | 5,597 km | 5,680 km | 5,671 km | 5,680 km | 0 |
| **Tổng** | **10.730** | — | — | **17,01 s** | **75,82%** | **57,069 km** | **57,926 km** | **57,884 km** | **57,916 km** | **2** |

So với chiều dài hiển thị của pipeline hiện tại, tổng chiều dài thay đổi:

- EKF: **+1,50%**.
- DBSCAN: **+1,43%**.
- EKF → DBSCAN: **+1,48%**.

Các phần trăm này không phải mức tăng accuracy. Không có đường chuẩn nên chưa biết phần tăng đó sửa thiếu khoảng cách hay tạo thêm sai số.

## 2. Mô phỏng có ground-truth

Mô phỏng deterministic 30 phút đạp xe gồm nhiễu GPS, một gap 10 giây và một outlier 55 m. Đây là test thuật toán, không mô hình hóa chính xác một iPhone hay điều kiện vệ tinh thực tế.

| Pipeline | Operational availability | RMSE | P50 | P95 | Sai số quãng đường |
|---|---:|---:|---:|---:|---:|
| Raw measurement | 99,44% | 4,91 m | 4,86 m | 5,99 m | +75,46% |
| Hiện tại | 59,41% | **3,42 m** | **2,62 m** | **5,88 m** | +8,40% |
| EKF | 59,41% | 8,07 m | 3,41 m | 18,48 m | +8,57% |
| DBSCAN | 59,41% | 4,66 m | 4,73 m | 5,98 m | +28,73% |
| EKF → DBSCAN | 59,41% | 8,07 m | 3,41 m | 18,48 m | +8,57% |

`Operational availability` là tỷ lệ mẫu kỳ vọng còn được validation chấp nhận. Giá trị 59,41% cho thấy bộ validation loại nhiều mẫu trong kịch bản mô phỏng; nó không có nghĩa điện thoại mất GPS 40,59% thời gian. Cần bổ sung test giữ góc cua và xem lại synthetic route trước khi dùng con số này làm KPI production.

Kịch bản đứng yên 10 phút:

| Pipeline | RMSE | P50 | P95 | Dwell cluster | Điểm collapse |
|---|---:|---:|---:|---:|---:|
| Raw measurement | 2,53 m | 2,59 m | 3,19 m | — | — |
| Hiện tại | 1,38 m | 1,16 m | **2,27 m** | 0 | 0 |
| EKF | 1,46 m | 1,08 m | 2,52 m | 0 | 0 |
| DBSCAN | 1,18 m | **0,07 m** | 3,07 m | 20 | 234 |
| EKF → DBSCAN | **0,91 m** | 0,37 m | 2,29 m | 20 | 234 |

DBSCAN có ích đúng mục tiêu dwell, nhưng không nên hiểu là bộ sửa multipath hoặc bias kéo dài khi xe đang chạy.

## 3. Quyết định tại checkpoint A2

1. Giữ pipeline hiện tại cho app live.
2. Chưa sang Chặng B với cấu hình EKF hiện tại vì P95 mô phỏng xấu hơn khoảng 3,14 lần: 18,48 m so với 5,88 m.
3. Giữ DBSCAN ở vai trò post-process tùy chọn cho đoạn đứng yên; chưa bật mặc định vì chỉ 1/7 workout thật có dwell được phát hiện.
4. Bước nghiên cứu tiếp theo là tune EKF trên development scenarios, bổ sung test rẽ gấp/đèn đỏ/multipath, khóa tham số, rồi thu một final test set mới có ground-truth hoặc tuyến tham chiếu độc lập.
5. Chỉ dùng final test set mới để tuyên bố app giảm được bao nhiêu mét hoặc bao nhiêu phần trăm.

### Lưu ý về benchmark cũ trong pre-thesis

`test/gps_accuracy_benchmark_test.dart` hiện chỉ có một trial mẫu `T01`: reference 0,526 km và Aetron 0,520 km. Ngay trong source, reference này được suy ngược từ mục tiêu sai số khoảng 1,2% và có chú thích yêu cầu thay bằng phép đo Google Maps. Vì vậy kết quả `MAPE 1,14% / GOOD` của test đó là ví dụ cách tính, **không phải bằng chứng thực nghiệm về độ chính xác của app**. Báo cáo Chặng A không dùng con số đó để chọn pipeline.

## 4. Cách tái tạo

Field replay:

```bash
dart run tool/gps_benchmark.dart \
  --activity cycling \
  --input /absolute/path/to/raw-gps-<workout-id>.jsonl \
  --output /absolute/path/to/report.json
```

Synthetic ground-truth:

```bash
dart run tool/gps_synthetic_benchmark.dart \
  --output /absolute/path/to/synthetic-report.json
```

Các JSON report hiện tại nằm ngoài Git tại:

`/Users/baobungbu/Downloads/AetronRecovery-20261015/benchmark-reports/`

Chúng không chứa latitude/longitude. Raw GPS cá nhân vẫn nằm ngoài repository.
