import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kAppLanguagePrefKey = 'settings.language.code';

enum AppLanguage { vi, en }

class AppLanguageNotifier extends StateNotifier<AppLanguage> {
  AppLanguageNotifier() : super(AppLanguage.vi) {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(kAppLanguagePrefKey) ?? 'vi';
    state = code == 'en' ? AppLanguage.en : AppLanguage.vi;
  }

  Future<void> setLanguage(AppLanguage lang) async {
    state = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      kAppLanguagePrefKey,
      lang == AppLanguage.en ? 'en' : 'vi',
    );
  }
}

final appLanguageProvider =
    StateNotifierProvider<AppLanguageNotifier, AppLanguage>((ref) {
  return AppLanguageNotifier();
});

class AppTranslations {
  static const Map<String, Map<AppLanguage, String>> _keys = {
    // Navigation Shell
    'nav_home': {AppLanguage.vi: 'Trang chủ', AppLanguage.en: 'Home'},
    'nav_activity': {AppLanguage.vi: 'Hoạt động', AppLanguage.en: 'Activity'},
    'nav_history': {AppLanguage.vi: 'Lịch sử', AppLanguage.en: 'History'},
    'nav_analytics': {AppLanguage.vi: 'Thống kê', AppLanguage.en: 'Analytics'},
    'nav_profile': {AppLanguage.vi: 'Hồ sơ', AppLanguage.en: 'Profile'},

    // Greetings & Subtitles
    'daily_telemetry': {
      AppLanguage.vi: 'DỮ LIỆU TẬP HÀNG NGÀY',
      AppLanguage.en: 'DAILY TELEMETRY',
    },
    'good_morning': {AppLanguage.vi: 'Chào buổi sáng', AppLanguage.en: 'Good Morning'},
    'good_afternoon': {
      AppLanguage.vi: 'Chào buổi chiều',
      AppLanguage.en: 'Good Afternoon',
    },
    'good_evening': {AppLanguage.vi: 'Chào buổi tối', AppLanguage.en: 'Good Evening'},

    // Empty States & Standby Labels
    'ready': {AppLanguage.vi: 'SẴN SÀNG', AppLanguage.en: 'READY'},
    'first_session': {
      AppLanguage.vi: 'BUỔI TẬP ĐẦU TIÊN',
      AppLanguage.en: 'FIRST SESSION',
    },
    'dashboard_ready_title': {
      AppLanguage.vi: 'BẢNG DỮ LIỆU ĐÃ SẴN SÀNG',
      AppLanguage.en: 'YOUR DASHBOARD IS READY',
    },
    'dashboard_ready_sub': {
      AppLanguage.vi:
          'Hãy ghi lại một buổi tập để kích hoạt bản đồ lộ trình, phân tích hàng tuần và chuỗi tập luyện.',
      AppLanguage.en:
          'Record a workout to activate route telemetry, weekly insights, and your streak signal.',
    },
    'sessions': {AppLanguage.vi: 'BUỔI TẬP', AppLanguage.en: 'SESSIONS'},
    'minutes': {AppLanguage.vi: 'PHÚT', AppLanguage.en: 'MINUTES'},
    'select_your_mode': {
      AppLanguage.vi: 'Chọn chế độ tập của bạn',
      AppLanguage.en: 'Select your mode',
    },
    'ready_to_move': {
      AppLanguage.vi: 'SẴN SÀNG VẬN ĐỘNG',
      AppLanguage.en: 'READY TO MOVE',
    },
    'allow_gps': {AppLanguage.vi: 'BẬT GPS', AppLanguage.en: 'ALLOW GPS'},
    'running': {AppLanguage.vi: 'Chạy bộ', AppLanguage.en: 'Running'},
    'route_timeline_standby': {
      AppLanguage.vi: 'CHỜ DỮ LIỆU LỘ TRÌNH',
      AppLanguage.en: 'ROUTE TIMELINE STANDBY',
    },
    'no_activity_recorded': {
      AppLanguage.vi: 'CHƯA CÓ HOẠT ĐỘNG NÀO',
      AppLanguage.en: 'NO ACTIVITY RECORDED',
    },
    'no_activity_sub': {
      AppLanguage.vi:
          'Lộ trình hoàn thành và mốc thời gian tập luyện của bạn sẽ xuất hiện tại đây.',
      AppLanguage.en:
          'Your completed routes and workout timeline will appear here.',
    },
    'record_activity': {
      AppLanguage.vi: 'Ghi lại hoạt động',
      AppLanguage.en: 'Record Activity',
    },
    'analysis_standby': {
      AppLanguage.vi: 'CHỜ PHÂN TÍCH',
      AppLanguage.en: 'ANALYSIS STANDBY',
    },
    'no_telemetry_yet': {
      AppLanguage.vi: 'CHƯA CÓ DỮ LIỆU THỐNG KÊ',
      AppLanguage.en: 'NO TELEMETRY YET',
    },
    'no_telemetry_sub': {
      AppLanguage.vi:
          'Hoàn thành buổi tập đầu tiên để mở khóa phân tích tốc độ, khoảng cách, xu hướng và kỷ lục.',
      AppLanguage.en:
          'Complete your first workout to unlock pace, distance, trends, and records.',
    },
    'all': {AppLanguage.vi: 'TẤT CẢ', AppLanguage.en: 'ALL'},
    'overview': {AppLanguage.vi: 'TỔNG QUAN', AppLanguage.en: 'OVERVIEW'},
    'distance_trend': {
      AppLanguage.vi: 'XU HƯỚNG KHOẢNG CÁCH',
      AppLanguage.en: 'DISTANCE TREND',
    },
    'achievement_records': {
      AppLanguage.vi: 'KỶ LỤC ĐẠT ĐƯỢC',
      AppLanguage.en: 'ACHIEVEMENT RECORDS',
    },
    'activity_mix': {
      AppLanguage.vi: 'TỶ LỆ HOẠT ĐỘNG',
      AppLanguage.en: 'ACTIVITY MIX',
    },
    'avg_distance': {
      AppLanguage.vi: 'KHOẢNG CÁCH TB',
      AppLanguage.en: 'AVG DISTANCE',
    },
    'best_pace': {
      AppLanguage.vi: 'Tốc độ tốt nhất',
      AppLanguage.en: 'Best Pace',
    },
    'days': {AppLanguage.vi: 'NGÀY', AppLanguage.en: 'DAYS'},

    // Profile & Biometrics
    'biometric_data': {
      AppLanguage.vi: 'DỮ LIỆU SINH TRẮC',
      AppLanguage.en: 'BIOMETRIC DATA',
    },
    'weight': {AppLanguage.vi: 'Cân nặng', AppLanguage.en: 'Weight'},
    'height': {AppLanguage.vi: 'Chiều cao', AppLanguage.en: 'Height'},
    'age': {AppLanguage.vi: 'Tuổi', AppLanguage.en: 'Age'},
    'gender': {AppLanguage.vi: 'Giới tính', AppLanguage.en: 'Gender'},
    'years_old': {AppLanguage.vi: 'tuổi', AppLanguage.en: 'years'},
    'male': {AppLanguage.vi: 'Nam', AppLanguage.en: 'Male'},
    'female': {AppLanguage.vi: 'Nữ', AppLanguage.en: 'Female'},
    'system_actions': {
      AppLanguage.vi: 'THAO TÁC HỆ THỐNG',
      AppLanguage.en: 'SYSTEM ACTIONS',
    },
    'security': {AppLanguage.vi: 'Bảo mật', AppLanguage.en: 'Security'},
    'achievements': {AppLanguage.vi: 'Thành tựu', AppLanguage.en: 'Achievements'},
    'choose_from_gallery': {
      AppLanguage.vi: 'Chọn từ thư viện ảnh',
      AppLanguage.en: 'Choose from gallery',
    },
    'take_a_photo': {AppLanguage.vi: 'Chụp ảnh mới', AppLanguage.en: 'Take a photo'},
    'remove_current_photo': {
      AppLanguage.vi: 'Xóa ảnh hiện tại',
      AppLanguage.en: 'Remove current photo',
    },
    'member_since': {
      AppLanguage.vi: 'Thành viên từ',
      AppLanguage.en: 'Member since',
    },

    // Settings & Permissions
    'allowed': {AppLanguage.vi: 'Đã cho phép', AppLanguage.en: 'Allowed'},
    'limited': {AppLanguage.vi: 'Giới hạn', AppLanguage.en: 'Limited'},
    'restricted': {AppLanguage.vi: 'Bị hạn chế', AppLanguage.en: 'Restricted'},
    'blocked': {AppLanguage.vi: 'Bị chặn', AppLanguage.en: 'Blocked'},
    'denied': {AppLanguage.vi: 'Từ chối', AppLanguage.en: 'Denied'},
    'full_access': {AppLanguage.vi: 'Quyền đầy đủ', AppLanguage.en: 'Full Access'},
    'checking_access': {
      AppLanguage.vi: 'Đang kiểm tra quyền...',
      AppLanguage.en: 'Checking access...',
    },
    'camera_ready': {
      AppLanguage.vi: 'Sẵn sàng để chụp ảnh đại diện',
      AppLanguage.en: 'Ready for taking profile photos',
    },
    'camera_denied': {
      AppLanguage.vi: 'Nhấn để cấp quyền máy ảnh hoặc mở Cài đặt',
      AppLanguage.en: 'Tap to request camera access or open Settings',
    },
    'photos_ready': {
      AppLanguage.vi: 'Quyền đầy đủ sẵn sàng để chọn ảnh đại diện',
      AppLanguage.en: 'Full access is ready for choosing profile photos',
    },
    'photos_denied': {
      AppLanguage.vi: 'Nhấn để cấp quyền thư viện ảnh hoặc mở Cài đặt',
      AppLanguage.en: 'Tap to request photo access or open Settings',
    },
    'photos_limited': {
      AppLanguage.vi: 'Quyền giới hạn. Đổi sang Quyền đầy đủ trong Cài đặt',
      AppLanguage.en: 'Limited access. Switch to Full Access in Settings',
    },
    'location_ready': {
      AppLanguage.vi: 'Sẵn sàng theo dõi tập luyện ngoài trời',
      AppLanguage.en: 'Ready for outdoor workout tracking',
    },
    'location_denied': {
      AppLanguage.vi: 'Nhấn để cấp quyền GPS hoặc mở Cài đặt',
      AppLanguage.en: 'Tap to request GPS access or open Settings',
    },
    'clearing_cache': {
      AppLanguage.vi: 'Đang xóa tệp tạm...',
      AppLanguage.en: 'Clearing temporary files...',
    },
    'clear_cache_confirm': {
      AppLanguage.vi:
          'Bạn có chắc chắn muốn xóa bộ nhớ đệm và tệp tạm? Dữ liệu bài tập của bạn sẽ không bị xóa.',
      AppLanguage.en:
          'Are you sure you want to clear temporary files and image cache? Your workouts will not be deleted.',
    },
    'cancel': {AppLanguage.vi: 'Hủy', AppLanguage.en: 'Cancel'},
    'clear': {AppLanguage.vi: 'Xóa', AppLanguage.en: 'Clear'},
    'logout_confirm': {
      AppLanguage.vi: 'Bạn có chắc chắn muốn đăng xuất?',
      AppLanguage.en: 'Are you sure you want to logout?',
    },

    // Auth & Onboarding
    'welcome_title': {
      AppLanguage.vi: 'CHÀO MỪNG ĐẾN VỚI AETRON',
      AppLanguage.en: 'WELCOME TO AETRON',
    },
    'welcome_subtitle': {
      AppLanguage.vi: 'Theo dõi tập luyện thông minh & Phân tích hiệu suất',
      AppLanguage.en: 'Smart workout tracking & Performance telemetry',
    },
    'get_started': {AppLanguage.vi: 'Bắt đầu ngay', AppLanguage.en: 'Get Started'},
    'login': {AppLanguage.vi: 'Đăng nhập', AppLanguage.en: 'Sign In'},
    'register': {AppLanguage.vi: 'Đăng ký', AppLanguage.en: 'Sign Up'},
    'email': {AppLanguage.vi: 'Email', AppLanguage.en: 'Email'},
    'username': {AppLanguage.vi: 'Tên người dùng', AppLanguage.en: 'Username'},
    'password': {AppLanguage.vi: 'Mật khẩu', AppLanguage.en: 'Password'},
    'confirm_password': {
      AppLanguage.vi: 'Xác nhận mật khẩu',
      AppLanguage.en: 'Confirm Password',
    },
    'forgot_password': {
      AppLanguage.vi: 'Quên mật khẩu?',
      AppLanguage.en: 'Forgot Password?',
    },
    'dont_have_account': {
      AppLanguage.vi: 'Chưa có tài khoản?',
      AppLanguage.en: "Don't have an account?",
    },
    'already_have_account': {
      AppLanguage.vi: 'Đã có tài khoản?',
      AppLanguage.en: 'Already have an account?',
    },
    'sign_in_google': {
      AppLanguage.vi: 'Đăng nhập bằng Google',
      AppLanguage.en: 'Sign in with Google',
    },
    'enter_email': {
      AppLanguage.vi: 'Nhập email của bạn',
      AppLanguage.en: 'Enter your email',
    },
    'enter_password': {
      AppLanguage.vi: 'Nhập mật khẩu',
      AppLanguage.en: 'Enter password',
    },
    'reset_password': {
      AppLanguage.vi: 'Khôi phục mật khẩu',
      AppLanguage.en: 'Reset Password',
    },

    // Home Dashboard
    'home_title': {AppLanguage.vi: 'Trang chủ', AppLanguage.en: 'Home'},
    'daily_target': {
      AppLanguage.vi: 'Mục tiêu hàng ngày',
      AppLanguage.en: 'Daily Target',
    },
    'quick_start': {AppLanguage.vi: 'Tập luyện ngay', AppLanguage.en: 'Quick Start'},
    'ai_insights': {AppLanguage.vi: 'Gợi ý từ AI', AppLanguage.en: 'AI Insights'},
    'recent_activities': {
      AppLanguage.vi: 'Hoạt động gần đây',
      AppLanguage.en: 'Recent Activities',
    },
    'see_all': {AppLanguage.vi: 'Xem tất cả', AppLanguage.en: 'See All'},
    'distance': {AppLanguage.vi: 'Khoảng cách', AppLanguage.en: 'Distance'},
    'duration': {AppLanguage.vi: 'Thời gian', AppLanguage.en: 'Duration'},
    'calories': {AppLanguage.vi: 'Calo', AppLanguage.en: 'Calories'},
    'pace': {AppLanguage.vi: 'Tốc độ', AppLanguage.en: 'Pace'},
    'avg_pace': {AppLanguage.vi: 'Tốc độ trung bình', AppLanguage.en: 'Avg Pace'},
    'weekly_summary': {
      AppLanguage.vi: 'Tóm tắt tuần',
      AppLanguage.en: 'Weekly Summary',
    },
    'streak': {
      AppLanguage.vi: 'Chuỗi tập luyện',
      AppLanguage.en: 'Workout Streak',
    },

    // Workout Flow
    'start_workout': {
      AppLanguage.vi: 'Bắt đầu tập',
      AppLanguage.en: 'Start Workout',
    },
    'outdoor_run': {
      AppLanguage.vi: 'Chạy bộ ngoài trời',
      AppLanguage.en: 'Outdoor Run',
    },
    'indoor_run': {
      AppLanguage.vi: 'Chạy máy (Treadmill)',
      AppLanguage.en: 'Indoor Run',
    },
    'cycling': {AppLanguage.vi: 'Đạp xe', AppLanguage.en: 'Cycling'},
    'walking': {AppLanguage.vi: 'Đi bộ', AppLanguage.en: 'Walking'},
    'Cycling': {AppLanguage.vi: 'Đạp xe', AppLanguage.en: 'Cycling'},
    'Walking': {AppLanguage.vi: 'Đi bộ', AppLanguage.en: 'Walking'},
    'Running': {AppLanguage.vi: 'Chạy bộ', AppLanguage.en: 'Running'},
    'gps_searching': {
      AppLanguage.vi: 'Đang tìm tín hiệu GPS...',
      AppLanguage.en: 'Searching for GPS signal...',
    },
    'gps_ready': {
      AppLanguage.vi: 'GPS đã sẵn sàng',
      AppLanguage.en: 'GPS Signal Ready',
    },
    'pause': {AppLanguage.vi: 'Tạm dừng', AppLanguage.en: 'Pause'},
    'resume': {AppLanguage.vi: 'Tiếp tục', AppLanguage.en: 'Resume'},
    'finish': {AppLanguage.vi: 'Hoàn thành', AppLanguage.en: 'Finish'},
    'discard': {AppLanguage.vi: 'Hủy bỏ', AppLanguage.en: 'Discard'},
    'heart_rate': {AppLanguage.vi: 'Nhịp tim', AppLanguage.en: 'Heart Rate'},
    'cadence': {AppLanguage.vi: 'Nhịp bước', AppLanguage.en: 'Cadence'},
    'workout_summary': {
      AppLanguage.vi: 'Tóm tắt buổi tập',
      AppLanguage.en: 'Workout Summary',
    },
    'workout_details': {
      AppLanguage.vi: 'Chi tiết buổi tập',
      AppLanguage.en: 'Workout Details',
    },
    'save_workout': {
      AppLanguage.vi: 'Lưu buổi tập',
      AppLanguage.en: 'Save Workout',
    },

    // History & Calendar
    'calendar': {AppLanguage.vi: 'Lịch tập luyện', AppLanguage.en: 'Workout Calendar'},
    'no_activities': {
      AppLanguage.vi: 'Chưa có hoạt động nào trong ngày này',
      AppLanguage.en: 'No activities recorded for this day',
    },
    'filter': {AppLanguage.vi: 'Lọc', AppLanguage.en: 'Filter'},
    'all_activities': {
      AppLanguage.vi: 'Tất cả hoạt động',
      AppLanguage.en: 'All Activities',
    },

    // Analytics & Stats
    'analytics': {
      AppLanguage.vi: 'Thống kê & Phân tích',
      AppLanguage.en: 'Analytics & Stats',
    },
    'week': {AppLanguage.vi: 'Tuần', AppLanguage.en: 'Week'},
    'month': {AppLanguage.vi: 'Tháng', AppLanguage.en: 'Month'},
    'year': {AppLanguage.vi: 'Năm', AppLanguage.en: 'Year'},
    'vo2_max': {AppLanguage.vi: 'Chỉ số VO2 Max', AppLanguage.en: 'VO2 Max Indicator'},
    'pace_distribution': {
      AppLanguage.vi: 'Phân bố tốc độ',
      AppLanguage.en: 'Pace Distribution',
    },
    'heart_rate_zones': {
      AppLanguage.vi: 'Vùng nhịp tim',
      AppLanguage.en: 'Heart Rate Zones',
    },
    'total_distance': {
      AppLanguage.vi: 'Tổng khoảng cách',
      AppLanguage.en: 'Total Distance',
    },
    'total_workouts': {
      AppLanguage.vi: 'Tổng số buổi tập',
      AppLanguage.en: 'Total Workouts',
    },

    // Profile & Setup
    'profile': {AppLanguage.vi: 'Hồ sơ cá nhân', AppLanguage.en: 'Profile'},
    'personal_records': {
      AppLanguage.vi: 'Kỷ lục cá nhân',
      AppLanguage.en: 'Personal Records',
    },
    'goals': {AppLanguage.vi: 'Mục tiêu', AppLanguage.en: 'Goals'},
    'create_goal': {
      AppLanguage.vi: 'Tạo mục tiêu mới',
      AppLanguage.en: 'Create New Goal',
    },
    'edit_profile': {
      AppLanguage.vi: 'Chỉnh sửa hồ sơ',
      AppLanguage.en: 'Edit Profile',
    },
    'badges': {
      AppLanguage.vi: 'Huy hiệu & Thành tích',
      AppLanguage.en: 'Badges & Achievements',
    },
    'athlete_level': {
      AppLanguage.vi: 'Cấp độ vận động viên',
      AppLanguage.en: 'Athlete Level',
    },
    'save_changes': {
      AppLanguage.vi: 'Lưu thay đổi',
      AppLanguage.en: 'Save Changes',
    },

    // Activity
    'activity': {AppLanguage.vi: 'Hoạt động', AppLanguage.en: 'Activity'},
    'share_workout': {
      AppLanguage.vi: 'Chia sẻ buổi tập',
      AppLanguage.en: 'Share Workout',
    },
    'delete_workout': {
      AppLanguage.vi: 'Xóa buổi tập',
      AppLanguage.en: 'Delete Workout',
    },
    'confirm_delete_workout': {
      AppLanguage.vi: 'Bạn có chắc chắn muốn xóa buổi tập này không?',
      AppLanguage.en: 'Are you sure you want to delete this workout?',
    },
    'outdoor_session': {
      AppLanguage.vi: 'BUỔI TẬP NGOÀI TRỜI',
      AppLanguage.en: 'OUTDOOR SESSION',
    },
    'outdoor_mode': {
      AppLanguage.vi: 'Chế độ ngoài trời',
      AppLanguage.en: 'Outdoor mode',
    },
    'flexible_start': {
      AppLanguage.vi: 'Bắt đầu linh hoạt',
      AppLanguage.en: 'Flexible start',
    },
    'gps_off': {AppLanguage.vi: 'TẮT GPS', AppLanguage.en: 'GPS OFF'},
    'gps_on': {AppLanguage.vi: 'BẬT GPS', AppLanguage.en: 'GPS ON'},
    'gps_status': {AppLanguage.vi: 'TRẠNG THÁI GPS', AppLanguage.en: 'GPS STATUS'},
    'route_locked': {AppLanguage.vi: 'ĐÃ KHÓA LỘ TRÌNH', AppLanguage.en: 'ROUTE LOCKED'},
    'route_pending': {AppLanguage.vi: 'ĐANG TÌM LỘ TRÌNH', AppLanguage.en: 'ROUTE PENDING'},
    'gps_settings': {AppLanguage.vi: 'CÀI ĐẶT GPS', AppLanguage.en: 'GPS SETTINGS'},
    'locating': {AppLanguage.vi: 'ĐANG ĐỊNH VỊ', AppLanguage.en: 'LOCATING'},
    'live_map': {AppLanguage.vi: 'BẢN ĐỒ TRỰC TIẾP', AppLanguage.en: 'LIVE MAP'},
    'checking': {AppLanguage.vi: 'ĐANG KIỂM TRA', AppLanguage.en: 'CHECKING'},
    'location_blocked': {
      AppLanguage.vi: 'BỊ CHẶN VỊ TRÍ',
      AppLanguage.en: 'LOCATION BLOCKED',
    },
    'location_services_off': {
      AppLanguage.vi: 'Dịch vụ vị trí đang tắt',
      AppLanguage.en: 'Location services are off',
    },
    'outdoor_tracking_ready': {
      AppLanguage.vi: 'Theo dõi ngoài trời sẵn sàng',
      AppLanguage.en: 'Outdoor tracking is ready',
    },
    'location_access_blocked': {
      AppLanguage.vi: 'Quyền vị trí đã bị chặn',
      AppLanguage.en: 'Location access is blocked',
    },
    'location_permission_needed': {
      AppLanguage.vi: 'Cần cấp quyền vị trí',
      AppLanguage.en: 'Location permission is needed',
    },
    'workout_saved': {
      AppLanguage.vi: 'ĐÃ LƯU BÀI TẬP',
      AppLanguage.en: 'WORKOUT SAVED',
    },
    'route_not_available': {
      AppLanguage.vi: 'KHÔNG CÓ LỘ TRÌNH',
      AppLanguage.en: 'ROUTE NOT AVAILABLE',
    },
    'moving_pace': {
      AppLanguage.vi: 'Tốc độ di chuyển',
      AppLanguage.en: 'Moving Pace',
    },
    'high_precision_signal': {
      AppLanguage.vi: 'TÍN HIỆU ĐỘ CHÍNH XÁC CAO',
      AppLanguage.en: 'HIGH PRECISION SIGNAL',
    },
    'moving_time': {
      AppLanguage.vi: 'Thời gian di chuyển',
      AppLanguage.en: 'Moving Time',
    },
    'rest_time': {
      AppLanguage.vi: 'Thời gian nghỉ',
      AppLanguage.en: 'Rest Time',
    },
    'back_to_history': {
      AppLanguage.vi: 'Về lịch sử tập',
      AppLanguage.en: 'Back To History',
    },
    'view_details': {
      AppLanguage.vi: 'Xem chi tiết',
      AppLanguage.en: 'View Details',
    },
    'indoor_movement': {
      AppLanguage.vi: 'CHUYỂN ĐỘNG TRONG NHÀ',
      AppLanguage.en: 'INDOOR MOVEMENT',
    },
    'route_recap': {
      AppLanguage.vi: 'TÓM TẮT LỘ TRÌNH',
      AppLanguage.en: 'ROUTE RECAP',
    },
    'session_time': {
      AppLanguage.vi: 'THỜI GIAN TẬP',
      AppLanguage.en: 'SESSION TIME',
    },
    'saving': {
      AppLanguage.vi: 'ĐANG LƯU...',
      AppLanguage.en: 'SAVING...',
    },
    'auto_pause': {
      AppLanguage.vi: 'TỰ ĐỘNG TẠM DỪNG',
      AppLanguage.en: 'AUTO PAUSE',
    },
    'dist': {
      AppLanguage.vi: 'K.CÁCH',
      AppLanguage.en: 'DIST',
    },
    'core_stats': {
      AppLanguage.vi: 'Chỉ số chính',
      AppLanguage.en: 'Core Stats',
    },
    'performance': {
      AppLanguage.vi: 'Hiệu suất',
      AppLanguage.en: 'Performance',
    },
    'latest_split': {
      AppLanguage.vi: 'Tách vòng mới nhất',
      AppLanguage.en: 'Latest Split',
    },
    'lap_splits': {
      AppLanguage.vi: 'Các mốc tách vòng',
      AppLanguage.en: 'Lap Splits',
    },
    'details': {
      AppLanguage.vi: 'Chi tiết',
      AppLanguage.en: 'Details',
    },
    'calorie_goal': {
      AppLanguage.vi: 'MỤC TIÊU CALO',
      AppLanguage.en: 'CALORIE GOAL',
    },
    'workout_goal': {
      AppLanguage.vi: 'MỤC TIÊU BÀI TẬP',
      AppLanguage.en: 'WORKOUT GOAL',
    },
    'distance_goal': {
      AppLanguage.vi: 'MỤC TIÊU KHOẢNG CÁCH',
      AppLanguage.en: 'DISTANCE GOAL',
    },
    'completion': {
      AppLanguage.vi: 'Hoàn thành',
      AppLanguage.en: 'Completion',
    },

    // Header & Settings
    'settings': {AppLanguage.vi: 'Cài đặt', AppLanguage.en: 'Settings'},
    'account': {AppLanguage.vi: 'TÀI KHOẢN', AppLanguage.en: 'ACCOUNT'},
    'workout_reminders': {
      AppLanguage.vi: 'NHẮC NHỞ TẬP LUYỆN',
      AppLanguage.en: 'WORKOUT REMINDERS',
    },
    'daily_reminder': {
      AppLanguage.vi: 'Nhắc nhở tập chạy hàng ngày',
      AppLanguage.en: 'Daily run reminder',
    },
    'personalized_reminders': {
      AppLanguage.vi: 'Nhắc nhở thông minh',
      AppLanguage.en: 'Personalized reminders',
    },
    'personalized_subtitle': {
      AppLanguage.vi:
          'Hệ thống học thói quen tập của bạn để đưa ra gợi ý phù hợp.',
      AppLanguage.en:
          'We learn your routine and only send a nudge when it is useful.',
    },
    'app_preferences': {
      AppLanguage.vi: 'CẤU HÌNH ỨNG DỤNG',
      AppLanguage.en: 'APP PREFERENCES',
    },
    'app_language': {
      AppLanguage.vi: 'Ngôn ngữ ứng dụng',
      AppLanguage.en: 'App Language',
    },
    'units': {AppLanguage.vi: 'Đơn vị đo', AppLanguage.en: 'Units'},
    'privacy_access': {
      AppLanguage.vi: 'QUYỀN RIÊNG TƯ & TRUY CẬP',
      AppLanguage.en: 'PRIVACY ACCESS',
    },
    'camera_access': {
      AppLanguage.vi: 'Quyền truy cập Camera',
      AppLanguage.en: 'Camera Access',
    },
    'photo_access': {
      AppLanguage.vi: 'Quyền truy cập Thư viện ảnh',
      AppLanguage.en: 'Photo Library Access',
    },
    'location_access': {
      AppLanguage.vi: 'Quyền truy cập Vị trí (GPS)',
      AppLanguage.en: 'Location Access',
    },
    'data': {AppLanguage.vi: 'DỮ LIỆU & BẢO MẬT', AppLanguage.en: 'DATA'},
    'clear_cache': {
      AppLanguage.vi: 'Xóa bộ nhớ tạm (Cache)',
      AppLanguage.en: 'Clear Cache',
    },
    'delete_account': {
      AppLanguage.vi: 'Xóa tài khoản vĩnh viễn',
      AppLanguage.en: 'Delete Account',
    },
    'delete_account_subtitle': {
      AppLanguage.vi:
          'Xóa vĩnh viễn tài khoản, mục tiêu và dữ liệu tập luyện.',
      AppLanguage.en: 'Permanently remove your account and synced data',
    },
    'about_legal': {
      AppLanguage.vi: 'VỀ ỨNG DỤNG & PHÁP LÝ',
      AppLanguage.en: 'ABOUT & LEGAL',
    },
    'version': {AppLanguage.vi: 'Phiên bản', AppLanguage.en: 'Version'},
    'terms_of_service': {
      AppLanguage.vi: 'Điều khoản sử dụng',
      AppLanguage.en: 'Terms of Service',
    },
    'privacy_policy': {
      AppLanguage.vi: 'Chính sách bảo mật',
      AppLanguage.en: 'Privacy Policy',
    },
    'data_compliance': {
      AppLanguage.vi: 'Dữ liệu & Tuân thủ',
      AppLanguage.en: 'Data & Compliance',
    },
    'intellectual_property': {
      AppLanguage.vi: 'Sở hữu trí tuệ',
      AppLanguage.en: 'Intellectual Property',
    },
    'logout': {AppLanguage.vi: 'Đăng xuất', AppLanguage.en: 'Logout'},
    'logout_confirm_title': {
      AppLanguage.vi: 'Xác nhận Đăng xuất',
      AppLanguage.en: 'Log out',
    },
    'logout_confirm_msg': {
      AppLanguage.vi:
          'Bạn có thể đăng nhập lại bất kỳ lúc nào để truy cập dữ liệu của mình.',
      AppLanguage.en:
          'You can sign back in at any time to return to your data.',
    },
    'select_language': {
      AppLanguage.vi: 'Chọn ngôn ngữ ứng dụng',
      AppLanguage.en: 'Select App Language',
    },
    'vietnamese': {AppLanguage.vi: 'Tiếng Việt', AppLanguage.en: 'Vietnamese'},
    'english': {AppLanguage.vi: 'Tiếng Anh', AppLanguage.en: 'English'},
    'back': {AppLanguage.vi: 'Quay lại', AppLanguage.en: 'Back'},
  };

  static String get(String key, AppLanguage lang) {
    return _keys[key]?[lang] ?? _keys[key]?[AppLanguage.en] ?? key;
  }
}
