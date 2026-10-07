# Danh Mục Màn Hình Thiết Kế (Screen Catalog) — Aetron

> **Tài liệu tham chiếu chuẩn UI/UX cho toàn bộ ứng dụng Aetron.**  
> Dùng để đối chiếu số thứ tự màn hình, đường dẫn mã nguồn, cấu trúc widget và ghi chú các yêu cầu chỉnh sửa giao diện.  
> Cập nhật lần cuối: 06/10/2026

---

## Bảng Tóm Tắt Tra Cứu Nhanh (Quick Index)

| ID | Tên Màn Hình (Screen) | Tên File / Đường Dẫn Mã Nguồn | Nhóm Chức Năng | Trạng Thái Chú Thích |
|:---:|---|---|---|:---:|
| **01** | **WelcomeScreen** | [`welcome_screen.dart`](file:///Users/baobungbu/Aetron/lib/features/onboarding/presentation/screens/welcome_screen.dart) | Khởi động & Giới thiệu | ⚪ Chờ góp ý |
| **02** | **LoginScreen** | [`login_screen.dart`](file:///Users/baobungbu/Aetron/lib/features/auth/presentation/screens/login_screen.dart) | Xác thực & Đăng nhập | ⚪ Chờ góp ý |
| **03** | **RegisterScreen** | [`register_screen.dart`](file:///Users/baobungbu/Aetron/lib/features/auth/presentation/screens/register_screen.dart) | Xác thực & Đăng ký | ⚪ Chờ góp ý |
| **04** | **ForgotPasswordScreen** | [`forgot_password_screen.dart`](file:///Users/baobungbu/Aetron/lib/features/auth/presentation/screens/forgot_password_screen.dart) | Khôi phục mật khẩu | ⚪ Chờ góp ý |
| **05** | **ForcePasswordUpgradeScreen** | [`force_password_upgrade_screen.dart`](file:///Users/baobungbu/Aetron/lib/features/auth/presentation/screens/force_password_upgrade_screen.dart) | Bảo mật tài khoản | ⚪ Chờ góp ý |
| **06** | **AthleteSetupFlow** | [`athlete_setup_flow.dart`](file:///Users/baobungbu/Aetron/lib/features/profile/presentation/screens/athlete_setup_flow.dart) | Onboarding vận động viên | ⚪ Chờ góp ý |
| **07** | **MainShell** | [`main_shell.dart`](file:///Users/baobungbu/Aetron/lib/features/shell/presentation/screens/main_shell.dart) | Khung Dock điều hướng 5 Tab | ⚪ Chờ góp ý |
| **08** | **HomeScreen** | [`home_screen.dart`](file:///Users/baobungbu/Aetron/lib/features/home/presentation/screens/home_screen.dart) | Tab 1: Trang chủ Dashboard | 🟢 **Đã tối ưu bố cục tiêu đề & tinh gọn** |
| **09** | **ActivityScreen** | [`activity_screen.dart`](file:///Users/baobungbu/Aetron/lib/features/activity/presentation/screens/activity_screen.dart) | Tab 2: Sảnh chọn hoạt động | 🟢 **Đã nâng cấp KineticActivityTopBar** |
| **10** | **CalendarScreen** | [`calendar_screen.dart`](file:///Users/baobungbu/Aetron/lib/features/history/presentation/screens/calendar_screen.dart) | Tab 3: Lịch sử & Nhật ký tập | 🟢 **Đã tối ưu bố cục tiêu đề Kinetic** |
| **11** | **AnalyticsScreen** | [`analytics_screen.dart`](file:///Users/baobungbu/Aetron/lib/features/analytics/presentation/screens/analytics_screen.dart) | Tab 4: Thống kê & Kỷ lục | 🟢 **Đã tối ưu bố cục tiêu đề Kinetic** |
| **12** | **ProfileScreen** | [`profile_screen.dart`](file:///Users/baobungbu/Aetron/lib/features/profile/presentation/screens/profile_screen.dart) | Tab 5: Hồ sơ Athlete & BMI | ⚪ Chờ góp ý |
| **13** | **RunningProgramsScreen** | [`running_programs_screen.dart`](file:///Users/baobungbu/Aetron/lib/features/workout/presentation/screens/running_programs_screen.dart) | Thư viện giáo án chạy bộ | ⚪ Chờ góp ý |
| **14** | **RecordScreen** | [`record_screen.dart`](file:///Users/baobungbu/Aetron/lib/features/workout/presentation/screens/record/record_screen.dart) | Live Tracking 3D & HUD | ⚪ Chờ góp ý |
| **15** | **WorkoutSummaryScreen** | [`workout_summary_screen.dart`](file:///Users/baobungbu/Aetron/lib/features/workout/presentation/screens/summary/workout_summary_screen.dart) | Tổng kết & Lưu bài tập | ⚪ Chờ góp ý |
| **16** | **WorkoutDetailsScreen** | [`workout_details_screen.dart`](file:///Users/baobungbu/Aetron/lib/features/workout/presentation/screens/details/workout_details_screen.dart) | Xem chi tiết bài tập cũ | ⚪ Chờ góp ý |
| ~~**17**~~ | ~~**WorkoutAiInsightDetailScreen**~~ | [`workout_ai_insight_detail_screen.dart`](file:///Users/baobungbu/Aetron/lib/features/workout/presentation/screens/details/workout_ai_insight_detail_screen.dart) | Báo cáo phân tích AI Coach | 🚫 **Đã lược bỏ theo yêu cầu** |
| **18** | **AchievementsScreen** | [`achievements_screen.dart`](file:///Users/baobungbu/Aetron/lib/features/profile/presentation/screens/achievements_screen.dart) | Thành tựu & Huy hiệu | ⚪ Chờ góp ý |
| **19** | **GoalScreen** | [`goal_screen.dart`](file:///Users/baobungbu/Aetron/lib/features/profile/presentation/screens/goal_screen.dart) | Thiết lập mục tiêu tuần | 🟢 **Đang bổ sung điểm chạm (Profile & Home)** |
| **20** | **SettingsScreen** | [`settings_screen.dart`](file:///Users/baobungbu/Aetron/lib/features/settings/presentation/screens/settings_screen.dart) | Cài đặt hệ thống | 🟢 **Đã tối ưu bố cục tiêu đề Kinetic** |
| **21** | **NotificationSettingsScreen** | [`notification_settings_screen.dart`](file:///Users/baobungbu/Aetron/lib/features/settings/presentation/screens/notification_settings_screen.dart) | Cài đặt thông báo & Nhắc | 🟢 **Đã tinh gọn 3 nhóm thông minh** |
| **22** | **PrivacyPolicyScreen** | [`privacy_policy_screen.dart`](file:///Users/baobungbu/Aetron/lib/features/legal/presentation/screens/privacy_policy_screen.dart) | Chính sách quyền riêng tư | ⚪ Chờ góp ý |
| **23** | **TermsOfServiceScreen** | [`terms_of_service_screen.dart`](file:///Users/baobungbu/Aetron/lib/features/legal/presentation/screens/terms_of_service_screen.dart) | Điều khoản dịch vụ | ⚪ Chờ góp ý |
| **24** | **AetronGlobeOrbitScreen** | [`aetron_globe_orbit_screen.dart`](file:///Users/baobungbu/Aetron/lib/shared/aetron/aetron_globe_orbit_screen.dart) | Visualizer Địa cầu 3D Orbit | 🟢 **Đang đồng bộ Kinetic & kích hoạt chạy** |

---

## Chi Tiết Từng Màn Hình & Thành Phần Thiết Kế

### 🟢 Nhóm 1: Khởi Động & Xác Thực (Onboarding & Authentication)

#### 01. `WelcomeScreen`
- **Đường dẫn file:** [`lib/features/onboarding/presentation/screens/welcome_screen.dart`](file:///Users/baobungbu/Aetron/lib/features/onboarding/presentation/screens/welcome_screen.dart)
- **Vai trò:** Màn hình chào mừng người dùng lần đầu mở app.
- **Thành phần chính:** Kinetic Background Glow, Logo Aetron, Typography "Unleash Your Kinetic Potential", nút bấm chuyển sang luồng thiết lập vận động viên hoặc đăng nhập.
- **Ghi chú sửa đổi của Bảo:** *(Chưa có)*

#### 02. `LoginScreen`
- **Đường dẫn file:** [`lib/features/auth/presentation/screens/login_screen.dart`](file:///Users/baobungbu/Aetron/lib/features/auth/presentation/screens/login_screen.dart)
- **Vai trò:** Đăng nhập tài khoản.
- **Thành phần chính:** Header chào mừng, Form nhập Email & Password có validation, nút Đăng nhập chính, nút Đăng nhập bằng Google (Native Google Sign-In), liên kết Quên mật khẩu & Tạo tài khoản mới.
- **Ghi chú sửa đổi của Bảo:** *(Chưa có)*

#### 03. `RegisterScreen`
- **Đường dẫn file:** [`lib/features/auth/presentation/screens/register_screen.dart`](file:///Users/baobungbu/Aetron/lib/features/auth/presentation/screens/register_screen.dart)
- **Vai trò:** Đăng ký tài khoản người dùng mới.
- **Thành phần chính:** Header đăng ký, Form nhập Tên hiển thị, Email, Mật khẩu & Xác nhận mật khẩu, thanh đo độ mạnh mật khẩu (Strong password meter), Checkbox đồng ý Điều khoản dịch vụ & Chính sách bảo mật.
- **Ghi chú sửa đổi của Bảo:** *(Chưa có)*

#### 04. `ForgotPasswordScreen` & `ResetPasswordScreen`
- **Đường dẫn file:** [`lib/features/auth/presentation/screens/forgot_password_screen.dart`](file:///Users/baobungbu/Aetron/lib/features/auth/presentation/screens/forgot_password_screen.dart)
- **Vai trò:** Khôi phục tài khoản khi quên mật khẩu.
- **Thành phần chính:** Nhập email để gửi liên kết/OTP đặt lại mật khẩu; màn hình nhập mật khẩu mới với tiêu chuẩn an toàn.
- **Ghi chú sửa đổi của Bảo:** *(Chưa có)*

#### 05. `ForcePasswordUpgradeScreen`
- **Đường dẫn file:** [`lib/features/auth/presentation/screens/force_password_upgrade_screen.dart`](file:///Users/baobungbu/Aetron/lib/features/auth/presentation/screens/force_password_upgrade_screen.dart)
- **Vai trò:** Màn hình bảo mật bắt buộc nâng cấp mật khẩu đạt chuẩn mạnh v1 cho tài khoản cũ.
- **Thành phần chính:** Badge cảnh báo bảo mật, Form nhập mật khẩu mới, nút xác nhận nâng cấp.
- **Ghi chú sửa đổi của Bảo:** *(Chưa có)*

#### 06. `AthleteSetupFlow` / `ProfileSetupScreen`
- **Đường dẫn file:** [`lib/features/profile/presentation/screens/athlete_setup_flow.dart`](file:///Users/baobungbu/Aetron/lib/features/profile/presentation/screens/athlete_setup_flow.dart) & [`profile_setup_screen.dart`](file:///Users/baobungbu/Aetron/lib/features/profile/presentation/screens/profile_setup_screen.dart)
- **Vai trò:** Quy trình Onboarding từng bước thiết lập thể trạng vận động viên ban đầu.
- **Thành phần chính:** Chọn giới tính, con lăn/slider nhập Chiều cao (cm), Cân nặng (kg), chọn Mục tiêu tuần ưu tiên. Tự động tính chỉ số BMI ban đầu.
- **Ghi chú sửa đổi của Bảo:** *(Chưa có)*

---

### 🔵 Nhóm 2: Khung Điều Hướng Chính (Main Shell - 5 Tabs)

#### 07. `MainShell`
- **Đường dẫn file:** [`lib/features/shell/presentation/screens/main_shell.dart`](file:///Users/baobungbu/Aetron/lib/features/shell/presentation/screens/main_shell.dart)
- **Vai trò:** Khung chứa toàn bộ ứng dụng và thanh Dock điều hướng cố định dưới đáy màn hình.
- **Thành phần chính:** IndexedStack 5 màn hình, thanh Dock kính mờ (`_AetronDock`) với hiệu ứng glow teal `#A8DCE7` cho tab đang kích hoạt, xử lý double-back để thoát app.
- **Ghi chú sửa đổi của Bảo:** *(Chưa có)*

#### 08. `HomeScreen` (Tab 1: Trang chủ Dashboard)
- **Đường dẫn file:** [`lib/features/home/presentation/screens/home_screen.dart`](file:///Users/baobungbu/Aetron/lib/features/home/presentation/screens/home_screen.dart)
- **Vai trò:** Trung tâm điều hành thông tin hàng ngày của vận động viên.
- **Cấu trúc thứ bậc đã tối ưu:**
  1. `KineticHomeTopBar`: Avatar người dùng, lời chào cá nhân & tên vận động viên, chuỗi Streak và phím Thông báo (đã loại bỏ chữ thương hiệu AETRON).
  2. `KineticActivityQuickSwitch`: Phím tắt chọn nhanh bộ môn (Đạp xe / Chạy bộ / Đi bộ) được đẩy lên vị trí hàng 2 giúp thao tác nhanh và thuận tay nhất (thay cho thanh trạng thái môi trường đã bỏ).
  3. `KineticHeroCard`: Thẻ hình ảnh động lực với ảnh chụp thể thao thực tế sắc nét, không bị văn bản overlay che khuất (đã loại bỏ badge GPS và nhãn tên bộ môn đè lên ảnh); tích hợp chỉ số tuần, mục tiêu và nút Bắt đầu.
  4. `KineticYourWeekBento`: Bento grid 2 cột phân tích km và số buổi tập, tích hợp phím mở `GoalScreen`.
  5. `KineticRecentActivityCard`: Thẻ tóm tắt buổi tập gần nhất hoặc CTA bắt đầu bài tập đầu tiên.
  6. `KineticExploreRoutes`: Gợi ý cung đường tập luyện khám phá.
- **Ghi chú sửa đổi của Bảo:** 🟢 **Đã hoàn thành tinh gọn giao diện theo yêu cầu:**
  1. Xóa chữ `AETRON` trên TopBar.
  2. Bỏ thanh trạng thái môi trường `KineticSensorStatusBar` ("Ngoài trời GPS (Sẵn sàng)", "Thời tiết lý tưởng").
  3. Hoán đổi phần chọn bộ môn nhanh (`KineticActivityQuickSwitch`) lên vị trí ngay trên Hero Card.
  4. Xóa câu châm ngôn dài ở đáy màn hình ("Không có cự ly nào quá dài khi từng bước chân đều hướng về phía trước...").
  5. Xóa toàn bộ text overlay trên ảnh Hero Card (`GPS SẴN SÀNG`, `ĐẠP XE NGOÀI TRỜI`, `CHẠY BỘ NGOÀI TRỜI`, `ĐI BỘ THỂ THAO`) để giữ hình ảnh vận động viên nổi bật và sạch sẽ.
  6. **Chi tiết chuỗi ngày Streak (`KineticStreakDetailsSheet`)**: Đồng bộ hoàn hảo sáng/tối (Light/Dark mode) theo chuẩn Kinetic Design System; tinh gọn triệt để nội dung (loại bỏ lộ trình 5 cột mốc trùng với trang Huy hiệu và khối bento dư thừa); tổ chức giao diện gọn gàng nhất với Hero ngọn lửa + số ngày, dải 7 ngày tuần này, 2 ô chỉ số cốt lõi (Kỷ lục tốt nhất & Mốc tiếp theo) và 1 nút CTA duy nhất. Giảm hơn 1,140 dòng code thừa trong `home_screen.dart`.

#### 09. `ActivityScreen` (Tab 2: Sảnh chọn & Bắt đầu hoạt động)
- **Đường dẫn file:** [`lib/features/activity/presentation/screens/activity_screen.dart`](file:///Users/baobungbu/Aetron/lib/features/activity/presentation/screens/activity_screen.dart)
- **Vai trò:** Phòng chờ khởi động buổi tập thể thao.
- **Cấu trúc đã tối ưu:**
  1. Tiêu đề trang: "Chọn bộ môn" (Select Activity) - đã loại bỏ dòng "Khởi động luyện tập", làm tiêu đề chính rõ ràng, sắc nét.
  2. Danh sách thẻ bộ môn Kinetic (`KineticActivityCard`):
     - Chạy bộ (`running_real.jpg`)
     - Đạp xe (`cycling_real.jpg`)
     - Đi bộ (`walking_real.jpg`)
     - Giao diện thẻ siêu sạch: hiển thị hình ảnh thực tế chất lượng cao, tên bộ môn nổi bật (đã loại bỏ hoàn toàn các tag xám rườm rà), chỉ hiển thị thống kê khi có dữ liệu thật (đã loại bỏ `0.0 km / buổi` và `TB hoạt động`).
  3. Thanh Cockpit tinh gọn ở đáy màn hình (`KineticActivityCockpit`):
     - Khối vệ tinh GPS: Icon vệ tinh, trạng thái "GPS sẵn sàng", chỉ số sai số mét `< X.Xm`, nút xem trước bản đồ và nút làm mới GPS (loại bỏ hoàn toàn "cảm biến trong nhà").
     - Nút Bắt đầu trực tiếp: "BẮT ĐẦU CHẠY BỘ", "BẮT ĐẦU ĐẠP XE", "BẮT ĐẦU ĐI BỘ" (đã loại bỏ chữ "hiking").
     - Đã loại bỏ phần chọn mục tiêu và 4 chip cự ly không cần thiết, giúp người dùng vào tập ngay chỉ với 1 cú chạm.
- **Ghi chú sửa đổi của Bảo:** 🟢 **Đã hoàn thành tinh gọn giao diện theo yêu cầu:**
  1. Xóa dòng chữ xám kế bên các chế độ (`Ngoài trời / Máy chạy`, `Ngoài trời / Trong nhà`, `Trong nhà (máy tập)`).
  2. Bỏ hiển thị `0.0 km / buổi` và xóa bỏ hoàn toàn dòng fallback `TB hoạt động`.
  3. Đổi tên bộ môn đi bộ thành "Đi bộ" (bỏ hiking); nút bắt đầu là "BẮT ĐẦU ĐI BỘ" (xóa hiking).
  4. Xóa trạng thái "Cảm biến trong nhà" (toàn bộ chuyển sang GPS vệ tinh ngoài trời đồng bộ).
  5. Xóa phần "Mục tiêu buổi tập" và các chip cự ly/thời gian không cần thiết để người dùng không phải chọn rườm rà trước khi xuất phát.

#### 10. `CalendarScreen` (Tab 3: Lịch sử & Nhật ký luyện tập)
- **Đường dẫn file:** [`lib/features/history/presentation/screens/calendar_screen.dart`](file:///Users/baobungbu/Aetron/lib/features/history/presentation/screens/calendar_screen.dart)
- **Vai trò:** Quản lý và tra cứu nhật ký tập luyện theo ngày tháng.
- **Thành phần chính:**
  - Thanh tiêu đề `KineticHistoryTopBar`: Tiêu đề chính to rõ "Lịch sử tập luyện" (Workout History), loại bỏ hoàn toàn dòng eyebrow `AETRON ARCHIVE`.
  - Lịch tương tác tháng/tuần (`table_calendar`) có chấm đánh dấu ngày tập.
  - Bộ lọc cự ly và môn thể thao (`KineticHistorySportFilter`).
  - Danh sách thẻ bài tập `KineticWorkoutHistoryCard` hiển thị cự ly, thời gian, pace, calo, mini GPS map.
- **Ghi chú sửa đổi của Bảo:** 🟢 Đã tinh gọn header: xóa bỏ `AETRON ARCHIVE`, làm nổi bật tiêu đề "Lịch sử tập luyện".

#### 11. `AnalyticsScreen` / `StatsScreen` (Tab 4: Thống kê & Phân tích chuyên sâu)
- **Đường dẫn file:** [`lib/features/analytics/presentation/screens/analytics_screen.dart`](file:///Users/baobungbu/Aetron/lib/features/analytics/presentation/screens/analytics_screen.dart)
- **Vai trò:** Báo cáo dữ liệu thể lực, biểu đồ khối lượng vận động và thành tích cá nhân.
- **Thành phần chính:**
  - Thanh tiêu đề `KineticAnalyticsHeader`: Tiêu đề chính to rõ "Phân tích" (Analytics), loại bỏ hoàn toàn dòng eyebrow "NHỊP ĐIỆU VẬN ĐỘNG", 3 tab lọc thời gian (Tuần này / Tháng này / Năm nay) được dàn đều toàn chiều rộng màn hình.
  - Bento grid phân tích khối lượng tập (Tuần / Tháng / Năm).
  - Biểu đồ phân bố tốc độ/pace và thời gian hoạt động.
  - `PersonalRecordsTrophyWall`: Tủ cúp kỷ lục cá nhân (1km, 5km, 10km, buổi tập dài nhất...).
  - `KineticRecoveryGuidanceCard`: Thẻ tư vấn thời gian nghỉ ngơi phục hồi cơ bắp.
- **Ghi chú sửa đổi của Bảo:** 🟢 Đã tối ưu tiêu đề "Phân tích", xóa "NHỊP ĐIỆU VẬN ĐỘNG" và giãn đều bộ chọn thời gian Tuần / Tháng / Năm.

#### 12. `ProfileScreen` (Tab 5: Hồ sơ cá nhân người dùng)
- **Đường dẫn file:** [`lib/features/profile/presentation/screens/profile_screen.dart`](file:///Users/baobungbu/Aetron/lib/features/profile/presentation/screens/profile_screen.dart)
- **Vai trò:** Quản trị hồ sơ thể chất, tài khoản và thành tích tổng hợp.
- **Thành phần chính:**
  - `KineticProfileTopBar`: Tiêu đề trực diện "Hồ sơ cá nhân" / "Profile", đã bỏ chữ AETRON ở phía trên.
  - `KineticAthleteCard`: Bố cục ngang chuẩn công thái học: Avatar nằm bên trái (thay vì nằm giữa), bên phải là tên hiển thị (kèm icon chỉnh sửa), ngày tham gia và huy hiệu chuỗi ngày streak.
  - Thẻ Sinh trắc học & BMI (Chiều cao, Cân nặng, Phân loại thể trạng).
  - Phím điều hướng góc trên bên phải: `SettingsScreen` (Cài đặt hệ thống).
  - Thao tác hệ thống tinh gọn: `GoalScreen` (Mục tiêu rèn luyện), `AchievementsScreen` (Thành tựu), Đổi mật khẩu bảo mật và Đăng xuất (đã loại bỏ mục Vệ tinh quỹ đạo 3D).
- **Ghi chú sửa đổi của Bảo:** 🟢 **Đã hoàn thành tinh gọn giao diện theo yêu cầu:**
  1. Bỏ chữ "Aetron" ở tiêu đề top bar hồ sơ cá nhân.
  2. Bỏ hoàn toàn phần "Vệ tinh quỹ đạo 3D" trong danh sách thao tác hệ thống.
  3. Tái cấu trúc thẻ người dùng: Ảnh đại diện (avatar) căn lề trái sang trọng, cân đối, không còn nằm giữa trang.

---

### 🟠 Nhóm 3: Luyện Tập & Kết Quả (Workout Tracking & Summary)

#### 13. `RunningProgramsScreen`
- **Đường dẫn file:** [`lib/features/workout/presentation/screens/running_programs_screen.dart`](file:///Users/baobungbu/Aetron/lib/features/workout/presentation/screens/running_programs_screen.dart)
- **Vai trò:** Thư viện các bài tập chạy bộ có huấn luyện theo giáo án.
- **Thành phần chính:**
  - Danh mục giáo án: Bắt đầu chạy bộ (C25K), Chạy ngắt quãng (Interval), Chạy duy trì tốc độ (Tempo), Phục hồi (Recovery).
  - Thẻ chi tiết giáo án kèm timeline trực quan các hiệp (Khởi động -> Chạy nhanh -> Nghỉ -> Thả lỏng).
  - Nút xuất phát bài tập trực tiếp theo giáo án đã chọn.
- **Ghi chú sửa đổi của Bảo:** *(Chưa có)*

#### 14. `RecordScreen`
- **Đường dẫn file:** [`lib/features/workout/presentation/screens/record/record_screen.dart`](file:///Users/baobungbu/Aetron/lib/features/workout/presentation/screens/record/record_screen.dart)
- **Vai trò:** Màn hình ghi bài tập trực tiếp (Live Tracking) với bản đồ 3D và các chỉ số thời gian thực.
- **Thành phần chính:**
  - `Workout3DCountdownOverlay`: Đếm ngược 3 giây vào bài tập.
  - `TrackingMapWidget`: Bản đồ vệ tinh/phẳng, camera 3D tilt, avatar định vị billboard.
  - `KineticLiveTopBar`: Thiết kế 2 cánh đối xứng chuẩn mực ở 2 góc màn hình: góc trái hiển thị trạng thái hoạt động / nhãn Tạm dừng cảnh báo nổi bật kèm GPS, góc phải hiển thị phím chuyển đổi chế độ Số liệu lớn / Bản đồ.
  - `KineticMiniMetricsCard`: Thẻ chỉ số live telemetry nổi trên bản đồ (km, thời gian, pace, calo).
  - `GuidedProgramHud` & `WorkoutTargetProgressHud`: HUD thông minh theo dõi giáo án/mục tiêu.
  - `LiveLapHudToast`: Banner tự động thông báo khi hoàn thành mỗi 1 km (Lap Split).
  - `KineticLiveControlDock`: Dock tactile 1 hàng gồm nút Khóa chống chạm nhầm, nút Tạm dừng/Tiếp tục Hero button, và nút Dừng lại thể thao thế hệ mới nổi bật với viền cảnh báo neon và nhãn chữ trực quan.
  - `KineticWorkoutStopSheet`: Màn hình/sheet xác nhận kết thúc bài tập Cyber-Kinetic cao cấp, hiển thị biểu tượng cờ đích phát sáng, hộp Bento tóm tắt nhanh thành tích (Quãng đường, Thời gian, Pace/Tốc độ) và 2 nút hành động lớn công thái học (Tiếp tục tập luyện / Kết thúc & Lưu bài tập).
  - `_CompactRecordingHud`: Chế độ hiển thị số liệu lớn toàn màn hình (Big Metrics Mode).
- **Ghi chú sửa đổi của Bảo:** 🟢 **Đã hoàn thành nâng cấp & thiết kế lại theo yêu cầu:**
  1. Căn chỉnh phần chữ Tạm dừng (hoặc trạng thái hoạt động) và phần Số liệu lớn đối xứng chuẩn xác ở góc trái và góc phải trên cùng của màn hình, chiều cao đồng bộ 42dp và phong cách bo cong glassmorphic cao cấp.
  2. Thiết kế lại nút bấm Dừng lại trên thanh dock dưới: không còn là ô vuông xám chìm nghỉm, mà là nút bấm thể thao nổi bật với viền neon đỏ cam, icon Stop sắc nét, nhãn chữ "DỪNG" (hoặc "KẾT THÚC" khi đang tạm dừng).
  3. Thiết kế lại toàn bộ màn hình xác nhận dừng lại thành modal Cyber-Kinetic thể thao chuyên nghiệp với tóm tắt nhanh các chỉ số đạt được (Bento Quãng đường, Thời gian, Tốc độ) và 2 nút bấm lớn dễ thao tác bằng ngón cái.

#### 15. `WorkoutSummaryScreen`
- **Đường dẫn file:** [`lib/features/workout/presentation/screens/summary/workout_summary_screen.dart`](file:///Users/baobungbu/Aetron/lib/features/workout/presentation/screens/summary/workout_summary_screen.dart)
- **Vai trò:** Tổng kết thành tích bài tập ngay sau khi nhấn Kết thúc.
- **Thành phần chính:**
  - Header tổng kết (`KineticSummaryHeader`) hiển thị tên bộ môn và nút quay về trang chủ.
  - Thẻ cự ly Kinetic Hero (`KineticSummaryHeroDistance`) hiển thị cự ly lớn và nhãn kiểm định GPS.
  - Lưới 4 ô chỉ số telemetry (`KineticSummaryTelemetryGrid`).
  - Bản đồ route hoàn chỉnh của buổi tập (`KineticSummaryRouteRecap`).
  - Bảng chi tiết từng km (`KineticSummarySplitsCard`).
  - Thanh hành động đáy (`KineticSummaryActionDock`) với nút chia sẻ duy nhất, nút Hoàn thành và nút Xem chi tiết.
- **Ghi chú sửa đổi của Bảo:** 🟢 **Đã tối ưu hóa giao diện theo yêu cầu:**
  1. Header: Loại bỏ hoàn toàn huy hiệu `GPS Ngoài trời` (và chế độ cảm biến), chỉ giữ huy hiệu bộ môn và trạng thái Đã lưu.
  2. Thẻ cự ly Hero: Bỏ toàn bộ câu khẩu hiệu/cảm thán (ví dụ: `Bước đi vững chãi và đều đặn!`), giữ thẻ cự ly sạch sẽ, hiện đại và tập trung vào chỉ số thực tế.
  3. Đồng bộ nút chia sẻ: Loại bỏ nút chia sẻ thừa ở góc trên bên phải header; chỉ sử dụng 1 nút chia sẻ duy nhất (`CHIA SẺ BUỔI TẬP`) nằm ở thanh hành động phía dưới màn hình cạnh nút Hoàn thành.


#### 16. `WorkoutDetailsScreen`
- **Đường dẫn file:** [`lib/features/workout/presentation/screens/details/workout_details_screen.dart`](file:///Users/baobungbu/Aetron/lib/features/workout/presentation/screens/details/workout_details_screen.dart)
- **Vai trò:** Màn hình xem lại thông tin chi tiết một buổi tập cũ từ trang Lịch sử.
- **Thành phần chính:**
  - Header thể thao tối giản hiển thị tên bộ môn (ĐI BỘ / CHẠY BỘ / ĐẠP XE), loại bỏ ngày/thứ bên dưới.
  - Bản đồ GPS lộ trình (`KineticDetailsRouteCard`) đưa lên ngay dưới Header.
  - Thẻ thông số chi tiết duy nhất (`KineticDetailsTelemetryListCard`) nằm dưới màn hình Route: Gộp toàn bộ Quãng đường, Thời gian, Pace TB, Calo, Số bước, Pace di chuyển, Thời gian di chuyển, Thời gian nghỉ, Tốc độ TB, Thời gian bắt đầu, kết thúc, ngày lưu.
  - Bảng phân tích splits từng km (`KineticDetailsSplitsCard`).
  - Hộp thoại xác nhận xóa bài tập (`KineticDetailsDeleteDialog`).
- **Ghi chú sửa đổi của Bảo:** 🟢 **Đã tối ưu hóa giao diện theo yêu cầu:**
  1. Header: Chỉ để tên bộ môn (Đi bộ / Chạy bộ / Đạp xe), không cần dòng ngày/thứ ở dưới.
  2. Bố cục: Bản đồ route đưa lên ngay dưới Header; toàn bộ thông số (quãng đường, thời gian, pace TB, calo, số bước và thông tin bổ sung) được gộp chung thành một list thông tin duy nhất (`KineticDetailsTelemetryListCard`) nằm bên dưới Route.
  3. Bỏ hoàn toàn mục "Môi trường" (Trong nhà / Ngoài trời) khỏi thông số vì đây là cơ chế tự động của ứng dụng.


#### 17. ~~`WorkoutAiInsightDetailScreen`~~ (Đã lược bỏ)
- **Đường dẫn file:** [`lib/features/workout/presentation/screens/details/workout_ai_insight_detail_screen.dart`](file:///Users/baobungbu/Aetron/lib/features/workout/presentation/screens/details/workout_ai_insight_detail_screen.dart)
- **Vai trò:** Báo cáo phân tích phong độ thể lực do Huấn luyện viên AI tạo lập.
- **Thành phần chính:**
  - Đánh giá tổng quan phong độ (Hiệu quả hiếu khí, độ ổn định pace).
  - Phân tích điểm sáng (Điểm mạnh của buổi tập) và điểm cần khắc phục.
  - Khuyến nghị dinh dưỡng & thời gian hồi phục thể lực cụ thể.
- **Ghi chú sửa đổi của Bảo:** 🚫 **Đã bỏ màn hình AI Coach khỏi luồng thiết kế chính.** Không còn hiển thị card trong WorkoutDetailsScreen.

---

### 🟣 Nhóm 4: Mục Tiêu, Thành Tựu & Cài Đặt (Goals & Settings)

#### 18. `AchievementsScreen`
- **Đường dẫn file:** [`lib/features/profile/presentation/screens/achievements_screen.dart`](file:///Users/baobungbu/Aetron/lib/features/profile/presentation/screens/achievements_screen.dart)
- **Vai trò:** Tủ huy hiệu và thành tích thể thao của vận động viên.
- **Thành phần chính:**
  - Thẻ tiêu điểm huy hiệu kế tiếp cần chinh phục (`KineticNextMilestoneSpotlight`).
  - Tab lọc theo phân loại: Tất cả, Cự ly, Chuỗi ngày (Streak), Tốc độ, Kiên trì.
  - Lưới huy hiệu 3D mở khóa kèm tiến độ thực tế (ví dụ: 18.5/20 km).
- **Ghi chú sửa đổi của Bảo:** *(Chưa có)*

#### 19. `GoalScreen`
- **Đường dẫn file:** [`lib/features/profile/presentation/screens/goal_screen.dart`](file:///Users/baobungbu/Aetron/lib/features/profile/presentation/screens/goal_screen.dart)
- **Vai trò:** Thiết lập và quản lý mục tiêu rèn luyện thể lực (Cự ly • Buổi tập • Calo) theo chu kỳ Tuần/Tháng với phong cách Kinetic sống động.
- **Thành phần chính:**
  - **Hero Kinetic Reactor Dial**: Custom painter với vòng quét năng lượng đa lớp, thước chia vạch thể thao (ticking notches), kim chỉ phát sáng (glowing knob) và hiệu ứng pulsing halo nhịp thở.
  - **Thước đo cường độ thích ứng (Intensity Meter)**: 4 cấp độ thể lực (Khởi động 🟢, Vừa sức 🔵, Thử thách 🟣, Vô cực 🔥) kèm mô tả phản hồi nhịp tim sinh học.
  - **Ý nghĩa & Hiệu quả thực tế (Real-World Benchmark)**: Quy chiếu số liệu khô khan thành kỳ tích cụ thể (vòng Hồ Hoàn Kiếm, Hồ Tây, Full Marathon, khối lượng mỡ giải phóng, bữa ăn nạp bù).
  - **Gói mục tiêu đề xuất (Strategic Presets)**: 4 mức vận động (Khởi Đầu, Tiến Bộ, Bứt Phá, Vô Cực) cập nhật nhanh chỉ với 1 chạm.
  - **Bộ chuyển chu kỳ (Cadence Selector)**: Chuyển đổi mượt mà giữa Sprint Tuần Này (7 ngày) và Chiến Dịch Tháng (30 ngày).
  - **Sticky Action Dock**: Thanh dock cố định chân màn hình tóm tắt loại mục tiêu, số lượng và nút kích hoạt/cập nhật với phản hồi xúc giác Haptic.
- **Ghi chú sửa đổi của Bảo:** 🟢 **Redesign toàn diện GoalScreen (Kinetic Reactor Experience):**
  1. Loại bỏ thanh arc tĩnh và slider đơn điệu, thay bằng Reactor Dial tương tác cao cấp.
  2. Bổ sung popup nhập số trực tiếp (`_showDirectValueEditor`) khi chạm vào số mục tiêu trung tâm.
  3. Tích hợp nút xóa mục tiêu an toàn có hộp thoại xác nhận trên top bar.
  4. Đảm bảo hỗ trợ đầy đủ song ngữ (Tiếng Việt & Tiếng Anh) và quy đổi đơn vị (km/mi).

#### 20. `SettingsScreen`
- **Đường dẫn file:** [`lib/features/settings/presentation/screens/settings_screen.dart`](file:///Users/baobungbu/Aetron/lib/features/settings/presentation/screens/settings_screen.dart)
- **Vai trò:** Trung tâm cài đặt hệ thống ứng dụng.
- **Thành phần chính:**
  - Chọn ngôn ngữ hiển thị: Tiếng Việt / English.
  - Chọn đơn vị đo: Hệ Mét (km, m) / Hệ Anh-Mỹ (miles, ft).
  - Chọn giao diện: Tối (Dark) / Sáng (Light) / Theo hệ điều hành.
  - Cài đặt âm thanh báo km (Audio Cues) & Tự động tạm dừng (Auto Pause).
  - Đồng bộ đám mây Supabase & Xóa cache cục bộ.
  - Điều hướng sang Thông báo, Pháp lý, và nút Đăng xuất tài khoản.
- **Ghi chú sửa đổi của Bảo:** *(Chưa có)*

#### 21. `NotificationSettingsScreen`
- **Đường dẫn file:** [`lib/features/settings/presentation/screens/notification_settings_screen.dart`](file:///Users/baobungbu/Aetron/lib/features/settings/presentation/screens/notification_settings_screen.dart)
- **Vai trò:** Tùy biến lịch nhắc nhở luyện tập thông minh, tinh gọn tối đa để tránh quá tải tùy chọn.
- **Thành phần chính đã gộp:**
  1. **Master Switch**: Thẻ bật/tắt toàn bộ thông báo đẩy (`Push Notifications`).
  2. **Nhóm 1: Luyện tập & Chuỗi ngày**: Gộp toàn bộ nhắc nhở giờ tập hàng ngày, bảo vệ ngọn lửa Streak và cảnh báo không hoạt động 48h; tích hợp bộ chọn giờ nhắc mỗi ngày tinh tế.
  3. **Nhóm 2: Mục tiêu & Thành tích**: Gộp thông báo tiến độ mục tiêu tuần, cập nhật hoàn thành mốc và chúc mừng huy hiệu mới.
  4. **Nhóm 3: Khung giờ yên tĩnh**: Chế độ không làm phiền với thanh chọn giờ nghỉ ngơi đôi (`Start` ➔ `End`) trực quan.
- **Ghi chú sửa đổi của Bảo:** 🟢 **Đã hoàn thành tinh gọn theo yêu cầu:**
  1. Loại bỏ hoàn toàn khối xem trước thông báo giả định (`_NotificationPreviewCard`) gây loãng màn hình.
  2. Gộp 8 switch riêng lẻ rời rạc thành 3 nhóm thông minh gắn liền với nhu cầu thực tế của người dùng, giúp giao diện gọn gàng trong 1 trang duy nhất không phải cuộn.
  3. Đồng bộ hoàn hảo chế độ sáng/tối Kinetic và tương thích 100% với scheduler ngầm.

---

### ⚪ Nhóm 5: Pháp Lý & Tiện Ích Không Gian 3D

#### 22. `PrivacyPolicyScreen`
- **Đường dẫn file:** [`lib/features/legal/presentation/screens/privacy_policy_screen.dart`](file:///Users/baobungbu/Aetron/lib/features/legal/presentation/screens/privacy_policy_screen.dart)
- **Vai trò:** Văn bản chính sách quyền riêng tư.
- **Thành phần chính:** Nội dung pháp lý về thu thập và bảo vệ dữ liệu tọa độ GPS, dữ liệu bước chân, tài khoản cá nhân, chuẩn GDPR/PDPA.
- **Ghi chú sửa đổi của Bảo:** *(Chưa có)*

#### 23. `TermsOfServiceScreen`
- **Đường dẫn file:** [`lib/features/legal/presentation/screens/terms_of_service_screen.dart`](file:///Users/baobungbu/Aetron/lib/features/legal/presentation/screens/terms_of_service_screen.dart)
- **Vai trò:** Văn bản điều khoản dịch vụ.
- **Thành phần chính:** Quy định điều kiện sử dụng app, cảnh báo y tế thể thao, miễn trừ trách nhiệm khi luyện tập ngoài trời.
- **Ghi chú sửa đổi của Bảo:** *(Chưa có)*

#### 24. `AetronGlobeOrbitScreen`
- **Đường dẫn file:** [`lib/shared/aetron/aetron_globe_orbit_screen.dart`](file:///Users/baobungbu/Aetron/lib/shared/aetron/aetron_globe_orbit_screen.dart)
- **Vai trò:** Màn hình visualizer địa cầu 3D Cyber Dark.
- **Thành phần chính:** Mô hình địa cầu quay 3D với các vòng quỹ đạo hạt phát sáng, dùng cho màn hình loading kết nối vệ tinh hoặc visualizer đặc biệt.
- **Ghi chú sửa đổi của Bảo:** 🟢 **Đồng bộ thiết kế Kinetic & kích hoạt chạy:**
  1. Chuyển đổi toàn diện token màu và phông chữ sang Kinetic Design System (`KineticColors`, `KineticTypography`, Plus Jakarta Sans).
  2. Thêm hỗ trợ vuốt xoay 3D tương tác tay (interactive rotation) và nút thoát/đóng tiện lợi.
  3. Kích hoạt chạy thực tế: Kết nối làm splash/telemetry transition sau màn hình Welcome và thêm action tile "Vệ tinh quỹ đạo 3D" trong ProfileScreen.

---

### 🧩 Phụ Lục: 6 Modal Bottom Sheets Thiết Kế Độc Lập

| Mã | Tên Modal Sheet | Đường Dẫn File | Mục Đích Thiết Kế |
|:---:|---|---|---|
| **S1** | `WorkoutTargetSelectorSheet` | [`workout_target_selector_sheet.dart`](file:///Users/baobungbu/Aetron/lib/features/workout/presentation/widgets/workout_target_selector_sheet.dart) | Sheet chọn mục tiêu cự ly/thời gian/calo trước khi chạy |
| **S2** | `WorkoutShareCard` | [`workout_share_card.dart`](file:///Users/baobungbu/Aetron/lib/features/workout/presentation/widgets/workout_share_card.dart) | Khung render ảnh Kinetic chia sẻ lên Instagram/Facebook Story |
| **S3** | `AetronPermissionSheet` | [`aetron_permission_sheet.dart`](file:///Users/baobungbu/Aetron/lib/shared/aetron/aetron_permission_sheet.dart) | Sheet xin cấp quyền GPS và cảm biến chuyển động Motion |
| **S4** | `AetronLogoutDialog` | [`aetron_logout_dialog.dart`](file:///Users/baobungbu/Aetron/lib/shared/aetron/aetron_logout_dialog.dart) | Sheet xác nhận đăng xuất tài khoản |
| **S5** | `AchievementDetailSheet` | [`achievement_detail_sheet.dart`](file:///Users/baobungbu/Aetron/lib/features/profile/presentation/widgets/achievement_detail_sheet.dart) | Sheet popup ngắm chi tiết huy hiệu và ngày mở khóa |
| **S6** | `EditDisplayNameSheet` | [`edit_display_name_sheet.dart`](file:///Users/baobungbu/Aetron/lib/features/profile/presentation/widgets/edit_display_name_sheet.dart) | Sheet đổi biệt danh hiển thị của vận động viên |
