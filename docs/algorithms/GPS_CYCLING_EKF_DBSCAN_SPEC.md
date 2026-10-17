# Đặc tả: Benchmark và tích hợp EKF/DBSCAN cho đạp xe

## Các giả định cần xác nhận

1. Phạm vi đầu tiên chỉ là workout `cycling`; walking/running giữ nguyên.
2. Bảy workout đạp xe hiện có là development dataset, không phải ground-truth và không được dùng để tuyên bố sai số vị trí thực tế.
3. Giai đoạn đầu chạy offline replay, chưa đổi kết quả workout đang hiển thị cho người dùng.
4. EKF dùng GPS position, reported accuracy, speed và heading hiện có; chưa gọi đây là GNSS/INS vì log chưa có accelerometer/gyroscope đồng bộ.
5. T-DBSCAN hiện tại dùng để phát hiện/collapse cụm đứng yên. Điểm bay xa khi đang di chuyển vẫn phải qua validation/outlier gate.
6. Chỉ bật pipeline mới trong app sau khi benchmark, test và review hoàn tất; mặc định an toàn vẫn là pipeline hiện tại.

## Mục tiêu

Xây dựng một benchmark có thể lặp lại để chạy cùng một raw GPS trace qua các biến thể:

1. Pipeline hiện tại (validation + fixed-alpha smoothing).
2. EKF.
3. T-DBSCAN dwell simplification.
4. Validation → EKF → T-DBSCAN.

Không benchmark T-DBSCAN → EKF. T-DBSCAN dwell cần quan sát một cửa sổ
thời gian hoàn chỉnh và collapse nhiều mẫu đứng yên thành một centroid, trong
khi EKF là bộ lọc causal chạy theo nhịp mẫu. Đưa output đã collapse vào EKF sẽ
làm mất speed/heading, thay đổi `dt` và không đại diện cho kiến trúc realtime.
Outlier đơn lẻ trước EKF thuộc trách nhiệm của validation/innovation gate,
không phải dwell clustering.

Benchmark phải tách rõ:

- **Synthetic có ground-truth:** được báo cáo RMSE, P50 và P95 theo mét.
- **Field log không có ground-truth:** chỉ báo cáo đặc tính dữ liệu và sự khác biệt giữa pipeline; không gọi đó là accuracy thực.

## Development dataset hiện tại

- Tổng cộng: 7 workout đạp xe, 10.779 dòng journal và 10.730 timestamp duy nhất sau khi khử trùng lặp.
- Workout mới `8674084e-a189-42da-b769-4bab1d9aaa45`: 1.680 dòng, 1.674 timestamp duy nhất, span 1.781 giây, reported-accuracy P95 14,25 m, max gap 9 giây.
- Workout mới `8a554aec-f0d8-4780-b82f-5cdf34848eaf`: 2.346 dòng, 2.322 timestamp duy nhất, span 2.664 giây, reported-accuracy P95 21,52 m sau khử trùng lặp, max 302,40 m, 61 gap trên 5 giây.
- Raw files nằm ngoài Git tại `/Users/baobungbu/Downloads/AetronRecovery-20261015/latest-journals/`.

Hai file mới là dữ liệu development tốt vì một phiên tương đối ổn định và một phiên có signal degradation/outlier rõ rệt.

## Công nghệ và cấu trúc

- Dart/Flutter hiện tại của repository; không thêm package nếu thư viện chuẩn và dependency hiện có đáp ứng được.
- Core filtering: `lib/features/workout/domain/services/`.
- Benchmark/replay: `lib/features/workout/domain/services/benchmark/`.
- CLI local-only: `tool/gps_benchmark.dart`.
- Unit tests: `test/`.
- Báo cáo sinh ra: thư mục người dùng chỉ định; không commit raw tọa độ.

## Giao diện lệnh dự kiến

```bash
dart run tool/gps_benchmark.dart \
  --activity cycling \
  --input /absolute/path/to/raw-gps-<workout-id>.jsonl \
  --output /absolute/path/to/report.json
```

Kiểm tra thay đổi:

```bash
flutter analyze
flutter test
```

Không chạy `flutter run` hoặc `flutter build` trực tiếp. Khi cần chạy app, dùng `./run.sh` theo hướng dẫn repository.

## Quy tắc code

- Logic benchmark và filter là pure Dart khi có thể.
- Một input trace luôn cho cùng output; không dùng random không seed.
- Timestamp phải được sort ổn định và xử lý duplicate rõ ràng.
- Giá trị NaN, infinity, accuracy âm và timestamp lùi phải được validate.
- Tên metric phải ghi rõ `reportedAccuracy` hay `groundTruthError`, không dùng từ `accuracy` mơ hồ.

Ví dụ API mong muốn:

```dart
final report = runner.run(
  trace,
  variants: const {
    GpsPipelineVariant.current,
    GpsPipelineVariant.ekf,
    GpsPipelineVariant.dbscan,
    GpsPipelineVariant.ekfThenDbscan,
  },
);
```

## Metric

### Synthetic có ground-truth

- Horizontal RMSE, P50, P95 theo mét.
- Mean East/North bias nếu trace cung cấp hệ tọa độ cục bộ.
- Availability.
- Sai số quãng đường so với ground-truth.

### Field log không có ground-truth

- Input/output point count và availability.
- Reported-accuracy mean/P50/P95 (chỉ mô tả chất lượng fix do iPhone báo).
- Tổng quãng đường theo từng pipeline và phần trăm thay đổi so với baseline.
- Số duplicate timestamp, gap >2 giây, gap >5 giây và max gap.
- Số điểm bị validation loại, theo từng reason.
- Số dwell cluster, dwell points collapsed và phantom drift removed.
- Max implied speed, max segment jump và path roughness/turn retention.
- Thời gian xử lý mỗi điểm.

## Chiến lược test

- Unit test parser bằng fixture nhỏ đã làm mờ tọa độ.
- TDD cho từng variant: test đỏ trước, code tối thiểu, rồi refactor.
- Synthetic regression test chứng minh metric RMSE/P50/P95 được tính đúng.
- Edge cases: duplicate timestamp, gap dài, accuracy 302 m, speed/heading không hợp lệ, rẽ gấp, đứng đèn đỏ.
- Regression test pipeline hiện tại để bảo đảm mặc định không đổi.
- Cuối mỗi lát cắt: chạy test liên quan; cuối toàn bộ: `flutter analyze` rồi `flutter test`.

## Ranh giới

### Luôn làm

- Giữ raw GPS ngoài Git và không upload dữ liệu vị trí.
- So sánh mọi variant trên cùng input.
- Tách metric ground-truth khỏi reported accuracy.
- Mặc định pipeline live hiện tại cho tới khi có review bật feature flag.

### Hỏi trước

- Bật EKF/DBSCAN cho người dùng thật.
- Thay đổi schema/database hoặc payload backend.
- Thêm dependency mới.
- Ghi đè kết quả workout đã lưu.

### Không làm

- Không tuyên bố RMSE/P95 thực địa nếu không có ground-truth.
- Không tune trên final test set.
- Không dùng đường “mượt hơn” làm bằng chứng vị trí chính xác hơn.
- Không commit raw latitude/longitude hoặc tài khoản/token.

## Tiêu chí hoàn thành

1. Replay được cả bảy workout mà không crash và xuất report cho bốn variant.
2. Synthetic report có RMSE/P50/P95 đúng, deterministic và có test.
3. Field report không gắn reported accuracy thành ground-truth error.
4. EKF xử lý gap, rẽ, heading không hợp lệ và measurement noise cao bằng test.
5. T-DBSCAN chỉ collapse dwell hợp lệ, không xóa các đoạn đạp xe bình thường.
6. Có bảng so sánh riêng từng workout và tổng hợp development dataset.
7. `flutter analyze` và toàn bộ `flutter test` xanh.
8. Pipeline live vẫn tắt mặc định cho đến checkpoint review cuối.

## Câu hỏi mở

- Hai workout mới có cùng cách gắn/mang iPhone với năm workout trước không?
- Có thể thu một final test set hoàn toàn mới sau khi khóa tham số không?
- Khi bật production, ưu tiên metric quãng đường hay hình dạng route nếu hai mục tiêu xung đột?
