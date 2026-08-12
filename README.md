<div align="center">

  <img src="assets/logo.png" alt="Aetron Logo" width="140" />

  # ⚡ Aetron - Next-Gen Fitness & Exercise Application
  
  **Nền tảng theo dõi và phân tích luyện tập thông minh thế hệ mới tích hợp 3D Visuals & AI Analytics**

  [![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
  [![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
  [![Supabase](https://img.shields.io/badge/Supabase-Cloud%20Backend-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com)
  [![Riverpod](https://img.shields.io/badge/Riverpod-State%20Management-0E7490?style=for-the-badge)](https://riverpod.dev)
  [![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)]()

</div>

---

## 🌟 Giới thiệu Sản phẩm (Product Overview)

**Aetron** là ứng dụng di động theo dõi thể thao & sức khỏe cá nhân hàng đầu được xây dựng trên nền tảng **Flutter & Supabase Engine**. Aetron mang đến trải nghiệm luyện tập hoàn hảo: từ việc **đo đạc chính xác lộ trình GPS ngoài trời**, **tự động chuyển đổi chế độ indoor/outdoor**, **tính toán calo thông minh theo chuẩn MET**, đến **hệ thống giao diện 3D phong cách Aetron UI độc đáo** giúp truyền cảm hứng luyện tập mỗi ngày.

---

## 🔥 Tính năng Nổi bật (Key Product Features)

### 1. 🏃 Theo dõi Lộ trình Realtime & GPS Thông minh (Precision Tracking Engine)
- **Định vị & Lọc nhiễu GPS tự động:** Tự động loại bỏ các điểm nhiễu (`<0.25m`), lọc mượt vận tốc (`Smoothed Speed`) và tự động nhận diện tạm dừng (`Auto-Pause`).
- **Phân loại môi trường (Indoor vs Outdoor Classifier):** Tự động phát hiện khi người dùng tập luyện trong nhà (chạy trên máy Treadmill) để chuyển sang đo đạc qua cảm biến Pedometer/Gia tốc kế, giúp tiết kiệm pin hiệu quả.
- **Bản đồ lộ trình tương tác:** Hiển thị trực quan tuyến đường chạy/đạp xe với marker 3D sinh động.

### 2. 🎨 Giao diện Aetron 3D Visual & Trải nghiệm Người dùng Premium
- **Hệ thống thiết kế Aetron Design System:** Phong cách Dark/Glassmorphism hiện đại, tỉ mỉ với hiệu ứng bóng đổ mượt mà, typography tối ưu và micro-animations.
- **Biểu tượng & Mascot 3D sống động:** Đồ họa 3D phong cách nhân vật Shiba & bộ nhận diện môn thể thao (*Chạy bộ, Đạp xe, Đi bộ*).

### 3. 📊 Phân tích & Thống kê Tối ưu (Smart Analytics & Calorie MET)
- **Công thức tính Calo chuẩn y khoa:** Tính toán năng lượng tiêu hao dựa trên chỉ số sinh học cá nhân (Chiều cao, Cân nặng, MET index theo tốc độ).
- **Biểu đồ xu hướng & Lịch sử tập luyện:** Trực quan hóa tiến trình qua biểu đồ tương tác (`fl_chart`), lịch thống kê ngày/tuần/tháng (`table_calendar`).
- **Phản hồi tính kiên trì (Consistency Feedback):** Hệ thống đánh giá mức độ đều đặn của bài tập để đưa ra lời khuyên cá nhân hóa.

### 4. 🎯 Mục tiêu & Lịch trình Nhắc nhở (Goals & Smart Notifications)
- **Đặt mục tiêu cá nhân:** Cho phép thiết lập và theo dõi tiến độ mục tiêu (*Quãng đường, Calo tiêu thụ, Thời lượng tập*).
- **Hệ thống thông báo nhắc nhở thông minh:** Đặt lịch thông báo đẩy (Push Notifications) giúp duy trì thói quen tập luyện hàng ngày.

### 5. 🔒 Bảo mật & Hoạt động Ngoại tuyến (Offline-First Architecture)
- **Kiến trúc Offline-First:** Dữ liệu buổi tập được lưu trữ an toàn tại bộ nhớ cục bộ (Isar DB & SQLite) ngay cả khi không có kết nối mạng.
- **Đồng bộ đám mây Supabase:** Tự động đồng bộ lộ trình & chỉ số lên Cloud một cách an toàn và bảo mật khi có kết nối Internet.
- **Bảo mật tài khoản nâng cao:** Hỗ trợ đăng nhập Google OAuth, Email/Password với luồng xác thực nâng cấp mật khẩu an toàn.

---

## 📸 Hình ảnh Giao diện (App Screenshots & Visual Assets)

| Chạy bộ 3D (Running) | Đạp xe 3D (Cycling) | Đi bộ 3D (Walking) | Mascot Shiba 3D |
| :---: | :---: | :---: | :---: |
| <img src="assets/running_3d.png" width="160" /> | <img src="assets/cycling_3d.png" width="160" /> | <img src="assets/walking_3d.png" width="160" /> | <img src="assets/shiba_3d.png" width="160" /> |

---

## 🛠️ Công nghệ Sử dụng (Tech Stack)

| Phân loại | Công nghệ / Thư viện |
| :--- | :--- |
| **Framework Mobile** | [Flutter 3.x](https://flutter.dev) (Dart 3.x) |
| **State Management** | [Riverpod 2.x](https://riverpod.dev) with `riverpod_generator` |
| **Backend & Cloud** | [Supabase](https://supabase.com) (Auth, PostgreSQL Database, Storage, Edge Functions) |
| **Local Storage** | [Isar Database](https://isar.dev) & `sqflite` (NoSQL & SQLite offline engine) |
| **GPS & Sensors** | `geolocator`, `flutter_map`, `pedometer`, `sensors_plus` |
| **UI & Charts** | `fl_chart`, `table_calendar`, custom Aetron Design System |
| **Data Generation** | `freezed`, `json_serializable` |

---

## ⚡ Hướng dẫn Cài đặt & Trải nghiệm (Getting Started)

### Yêu cầu môi trường:
* **Flutter SDK:** `>= 3.19.0`
* **Dart SDK:** `>= 3.3.0`
* **Android Studio / Xcode** cho lập trình di động.

### Các bước thực hiện:

1. **Clone repository:**
   ```bash
   git clone https://github.com/DB-Ducbao113/FitnessExerciseApplication.git
   cd FitnessExerciseApplication
   ```

2. **Cài đặt các gói phụ thuộc (Dependencies):**
   ```bash
   flutter pub get
   ```

3. **Cấu hình môi trường (Mẫu .env):**
   Tạo file `.env` tại thư mục gốc của dự án và khai báo thông tin kết nối Supabase:
   ```env
   SUPABASE_URL=https://your-supabase-project.supabase.co
   SUPABASE_ANON_KEY=your-anon-key
   ```

4. **Khởi chạy ứng dụng:**
   ```bash
   # Chạy trên thiết bị Android / iOS
   flutter run
   ```

---

## 🛣️ Định hướng Phát triển (Product Roadmap)

- [x] Tích hợp GPS Tracking & Bộ lọc nhiễu tự động.
- [x] Giao diện Aetron 3D Visual & Hệ thống thiết kế chuẩn hóa.
- [x] Đồng bộ dữ liệu Offline-First với Supabase Cloud.
- [x] Hệ thống Nhắc nhở & Thiết lập mục tiêu luyện tập.
- [ ] **AI Personal Coach (Sắp ra mắt):** Phân tích và đưa ra khuyến nghị bài tập bằng AI dựa trên lịch sử nhịp tim và hiệu suất chạy.
- [ ] **Social Leaderboard & Challenges:** Thách đấu và chia sẻ thành tích luyện tập cùng bạn bè.

---

## 📄 Giấy phép (License)

Dự án được phát hành dưới giấy phép **MIT License**.

---

<div align="center">
  <sub>Phát triển bởi <b>Nguyễn Đức Bảo (DB-Ducbao113)</b> 🚀</sub>
</div>
