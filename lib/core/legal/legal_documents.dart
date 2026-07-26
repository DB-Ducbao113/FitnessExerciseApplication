import 'package:fitness_exercise_application/core/l10n/app_translations.dart';

class LegalDocumentSection {
  final String title;
  final String content;

  const LegalDocumentSection({
    required this.title,
    required this.content,
  });
}

class LegalDocuments {
  // ──────────────────────────────────────────────────────────────────────────
  // TERMS OF SERVICE — 16 sections (VI / EN)
  // ──────────────────────────────────────────────────────────────────────────
  static List<LegalDocumentSection> getTermsOfService(AppLanguage lang) {
    if (lang == AppLanguage.vi) {
      return const [
        // 1
        LegalDocumentSection(
          title: '1. Chấp thuận Điều khoản & Cảnh báo Sức khỏe',
          content:
              'Bằng việc tải xuống, cài đặt hoặc sử dụng ứng dụng Aetron ("Ứng dụng"), bạn đồng ý bị ràng buộc bởi các Điều khoản Sử dụng này ("Điều khoản"). Nếu bạn không đồng ý với bất kỳ phần nào của Điều khoản, vui lòng không sử dụng Ứng dụng.\n\n'
              'Aetron là ứng dụng theo dõi thể thao và phân tích chỉ số tập luyện cá nhân. Tất cả các chỉ số hiển thị trong ứng dụng — bao gồm vận tốc, pace (tốc độ), lượng calo tiêu thụ, nhịp tim ước tính, quãng đường, số bước chân — được tính toán dựa trên cảm biến thiết bị và thuật toán phần mềm, mang tính chất tham khảo kỹ thuật.\n\n'
              'CẢNH BÁO: Ứng dụng không đưa ra lời khuyên y tế, chẩn đoán bệnh lý hoặc thay thế tư vấn từ bác sĩ chuyên khoa. Bạn cần tham khảo ý kiến bác sĩ trước khi bắt đầu hoặc thay đổi bất kỳ chương trình tập luyện cường độ cao nào. Nếu bạn có tiền sử bệnh tim mạch, huyết áp, hoặc bất kỳ vấn đề sức khỏe nào, hãy dừng tập ngay lập tức khi cảm thấy khó chịu và liên hệ cơ sở y tế gần nhất.',
        ),
        // 2
        LegalDocumentSection(
          title: '2. Điều kiện Sử dụng & Đủ Tuổi',
          content:
              'Để sử dụng Aetron, bạn phải đáp ứng các điều kiện sau:\n\n'
              '• Tối thiểu 13 tuổi (hoặc tuổi tối thiểu theo quy định pháp luật tại quốc gia của bạn).\n'
              '• Nếu bạn dưới 18 tuổi, việc sử dụng ứng dụng phải có sự đồng ý và giám sát từ cha mẹ hoặc người giám hộ hợp pháp.\n'
              '• Bạn xác nhận rằng mọi thông tin cung cấp cho Aetron là chính xác, đầy đủ và cập nhật.\n'
              '• Bạn đồng ý không tạo nhiều tài khoản cho mục đích gian lận hoặc vi phạm Điều khoản.\n\n'
              'Aetron có quyền từ chối cung cấp dịch vụ cho bất kỳ người dùng nào vi phạm các điều kiện trên mà không cần thông báo trước.',
        ),
        // 3
        LegalDocumentSection(
          title: '3. Tài khoản Người dùng & Bảo mật',
          content:
              'Khi đăng ký tài khoản Aetron, bạn có trách nhiệm:\n\n'
              '• Bảo mật tuyệt đối mật khẩu và thông tin đăng nhập của mình.\n'
              '• Thông báo ngay lập tức cho chúng tôi nếu phát hiện bất kỳ truy cập trái phép nào vào tài khoản.\n'
              '• Chịu trách nhiệm hoàn toàn về mọi hoạt động được thực hiện dưới tài khoản của bạn, bao gồm các bài tập đã ghi, dữ liệu đã tải lên và thay đổi cài đặt.\n'
              '• Cung cấp thông tin sinh trắc học chính xác (chiều cao, cân nặng, tuổi, giới tính) để đảm bảo tính toán chỉ số tập luyện chuẩn xác.\n\n'
              'Aetron sử dụng xác thực qua Google OAuth 2.0 và Supabase Auth. Chúng tôi không lưu trữ mật khẩu dạng văn bản thuần (plaintext) trên hệ thống.',
        ),
        // 4
        LegalDocumentSection(
          title: '4. Mô tả Dịch vụ & Tính năng',
          content:
              'Aetron cung cấp các dịch vụ và tính năng chính bao gồm:\n\n'
              '• Ghi nhận và theo dõi buổi tập luyện: Chạy bộ ngoài trời, chạy máy (treadmill), đi bộ và đạp xe với GPS tracking thời gian thực.\n'
              '• Phân tích chỉ số: Khoảng cách, thời gian, tốc độ trung bình, pace, lượng calo tiêu thụ, nhịp bước (cadence), nhịp tim ước tính và chỉ số VO2 Max.\n'
              '• Bản đồ lộ trình: Hiển thị bản đồ đường đi với các mốc tốc độ được mã hóa màu sắc.\n'
              '• Thống kê & Phân tích: Biểu đồ xu hướng theo tuần/tháng/năm, phân bố tốc độ, kỷ lục cá nhân.\n'
              '• Hồ sơ cá nhân: Quản lý thông tin sinh trắc học, lịch sử tập luyện, huy hiệu thành tích.\n'
              '• Lịch tập luyện: Xem và quản lý các buổi tập theo ngày/tháng.\n\n'
              'Chúng tôi có quyền thêm, sửa đổi hoặc ngừng cung cấp bất kỳ tính năng nào mà không cần thông báo trước, miễn là đảm bảo các chức năng cốt lõi của ứng dụng.',
        ),
        // 5
        LegalDocumentSection(
          title: '5. Đăng ký & Thanh toán (Nếu áp dụng)',
          content:
              'Aetron hiện cung cấp miễn phí toàn bộ các tính năng cốt lõi. Trong tương lai, chúng tôi có thể giới thiệu các gói đăng ký Premium với tính năng nâng cao.\n\n'
              'Nếu gói Premium được triển khai:\n'
              '• Thanh toán sẽ được xử lý qua Apple App Store hoặc Google Play Store tùy theo nền tảng thiết bị.\n'
              '• Đăng ký sẽ tự động gia hạn trừ khi bạn hủy trước ít nhất 24 giờ trước ngày gia hạn.\n'
              '• Bạn có thể quản lý hoặc hủy đăng ký thông qua cài đặt tài khoản trên App Store/Play Store.\n'
              '• Phí đăng ký không được hoàn lại cho phần thời gian đã sử dụng trong chu kỳ thanh toán hiện tại.\n'
              '• Giá có thể thay đổi với thông báo trước ít nhất 30 ngày qua email hoặc thông báo trong ứng dụng.',
        ),
        // 6
        LegalDocumentSection(
          title: '6. Định vị GPS & Độ Chính xác Dữ liệu',
          content:
              'Aetron sử dụng hệ thống định vị toàn cầu GPS và các cảm biến chuyển động tích hợp trên thiết bị di động (gia tốc kế, con quay hồi chuyển, từ kế) để ghi nhận bản đồ lộ trình và tính toán khoảng cách.\n\n'
              'Bạn xác nhận và đồng ý rằng:\n'
              '• Độ chính xác của dữ liệu GPS phụ thuộc vào chất lượng phần cứng thiết bị, điều kiện thời tiết, môi trường xung quanh (tòa nhà cao tầng, rừng cây, đường hầm) và độ ổn định tín hiệu vệ tinh.\n'
              '• Khoảng cách, tốc độ và bản đồ lộ trình có thể có sai số từ 1% đến 10% tùy điều kiện thực tế.\n'
              '• Buổi tập trong nhà (treadmill) sử dụng cảm biến chuyển động để ước tính khoảng cách và có độ chính xác thấp hơn so với GPS ngoài trời.\n'
              '• Aetron không chịu trách nhiệm về sự khác biệt giữa dữ liệu ghi nhận và khoảng cách thực tế.\n\n'
              'Để có kết quả tốt nhất, hãy đảm bảo thiết bị có tầm nhìn trời thoáng và đợi tín hiệu GPS ổn định (hiển thị "GPS đã sẵn sàng") trước khi bắt đầu buổi tập.',
        ),
        // 7
        LegalDocumentSection(
          title: '7. Nội dung Người dùng & Cấp phép',
          content:
              'Khi sử dụng Aetron, bạn có thể tạo và tải lên các nội dung bao gồm: dữ liệu buổi tập, ảnh đại diện, thông tin hồ sơ cá nhân và bản đồ lộ trình (gọi chung là "Nội dung Người dùng").\n\n'
              'Bạn giữ toàn bộ quyền sở hữu đối với Nội dung Người dùng của mình. Tuy nhiên, bằng việc sử dụng Ứng dụng, bạn cấp cho Aetron giấy phép không độc quyền, miễn phí bản quyền, có thể chuyển nhượng, để:\n'
              '• Lưu trữ, xử lý và hiển thị Nội dung Người dùng nhằm cung cấp các tính năng của Ứng dụng.\n'
              '• Sử dụng dữ liệu tổng hợp ẩn danh (đã loại bỏ thông tin nhận dạng cá nhân) để cải thiện thuật toán và chất lượng dịch vụ.\n\n'
              'Bạn cam kết Nội dung Người dùng không vi phạm bản quyền, nhãn hiệu, bí mật kinh doanh hoặc quyền sở hữu trí tuệ của bên thứ ba.',
        ),
        // 8
        LegalDocumentSection(
          title: '8. Quy tắc Sử dụng Hợp lệ',
          content:
              'Người dùng cam kết tuân thủ các quy tắc sử dụng sau đây:\n\n'
              '• KHÔNG sử dụng Aetron cho các hoạt động vi phạm pháp luật địa phương hoặc quốc tế.\n'
              '• KHÔNG gian lận thành tích tập luyện bằng cách sử dụng GPS giả lập, thiết bị can thiệp hoặc phần mềm bên thứ ba để tạo dữ liệu bài tập không thực.\n'
              '• KHÔNG cố tình phá hoại, dịch ngược (reverse engineer), giải mã hoặc can thiệp vào mã nguồn, API hoặc hạ tầng máy chủ của Ứng dụng.\n'
              '• KHÔNG gây quá tải (DDoS) hoặc cố tình làm gián đoạn hoạt động bình thường của hệ thống máy chủ.\n'
              '• KHÔNG sử dụng bot, trình thu thập dữ liệu tự động (crawler) hoặc công cụ scraping để trích xuất dữ liệu từ Ứng dụng.\n'
              '• KHÔNG mạo danh người dùng khác hoặc tạo tài khoản giả mạo.\n\n'
              'Vi phạm các quy tắc trên có thể dẫn đến tạm ngưng hoặc chấm dứt tài khoản vĩnh viễn mà không cần hoàn tiền.',
        ),
        // 9
        LegalDocumentSection(
          title: '9. Quyền Sở hữu Trí tuệ',
          content:
              'Tất cả giao diện người dùng (UI/UX), logo Aetron, thiết kế đồ họa, biểu tượng, hệ thống màu sắc, phông chữ tùy chỉnh, mã nguồn phần mềm, thuật toán tính toán, cơ sở dữ liệu và kiến trúc hệ thống đều thuộc quyền sở hữu trí tuệ độc quyền của Aetron và/hoặc bên cấp phép liên quan.\n\n'
              'Bạn KHÔNG được:\n'
              '• Sao chép, tái sản xuất, phân phối hoặc tạo tác phẩm phái sinh từ bất kỳ phần nào của Ứng dụng.\n'
              '• Sử dụng thương hiệu, logo hoặc tên "Aetron" cho mục đích thương mại khi chưa có sự đồng ý bằng văn bản.\n'
              '• Trích xuất hoặc tái sử dụng cơ sở dữ liệu bản đồ hoặc thuật toán phân tích của Ứng dụng.\n\n'
              'Mọi nhãn hiệu, tên thương mại và logo của bên thứ ba hiển thị trong Ứng dụng (Google Maps, Supabase, v.v.) thuộc quyền sở hữu của chủ sở hữu tương ứng.',
        ),
        // 10
        LegalDocumentSection(
          title: '10. Dịch vụ Bên thứ ba & Tích hợp',
          content:
              'Aetron tích hợp với các dịch vụ bên thứ ba để cung cấp trải nghiệm đầy đủ:\n\n'
              '• Google Maps Platform: Hiển thị bản đồ lộ trình và xác định vị trí GPS.\n'
              '• Supabase: Lưu trữ dữ liệu đám mây, xác thực người dùng và đồng bộ hóa.\n'
              '• Google OAuth 2.0: Đăng nhập nhanh bằng tài khoản Google.\n'
              '• Firebase (nếu áp dụng): Thông báo đẩy và phân tích sử dụng.\n\n'
              'Mỗi dịch vụ bên thứ ba có điều khoản sử dụng và chính sách bảo mật riêng. Aetron không chịu trách nhiệm về nội dung, tính sẵn sàng hoặc bảo mật của các dịch vụ bên thứ ba. Bạn nên tham khảo trực tiếp điều khoản của từng nhà cung cấp.',
        ),
        // 11
        LegalDocumentSection(
          title: '11. Tạm ngưng & Chấm dứt Tài khoản',
          content:
              'Aetron có quyền tạm ngưng hoặc chấm dứt tài khoản của bạn trong các trường hợp sau:\n\n'
              '• Vi phạm bất kỳ điều khoản nào trong Điều khoản Sử dụng này.\n'
              '• Phát hiện hành vi gian lận, lạm dụng hoặc hoạt động đáng ngờ.\n'
              '• Yêu cầu từ cơ quan thực thi pháp luật hoặc theo quy định pháp lý.\n'
              '• Không hoạt động liên tục trong thời gian dài (trên 24 tháng).\n\n'
              'Bạn có quyền tự xóa tài khoản bất kỳ lúc nào thông qua mục "Xóa tài khoản vĩnh viễn" trong phần Cài đặt. Khi tài khoản bị xóa:\n'
              '• Toàn bộ dữ liệu cá nhân, lịch sử bài tập và bản đồ lộ trình sẽ bị xóa vĩnh viễn khỏi hệ thống trong vòng 30 ngày.\n'
              '• Dữ liệu tổng hợp ẩn danh đã được sử dụng cho phân tích có thể được giữ lại.\n'
              '• Hành động xóa tài khoản không thể hoàn tác.',
        ),
        // 12
        LegalDocumentSection(
          title: '12. Giới hạn Trách nhiệm',
          content:
              'TRONG PHẠM VI TỐI ĐA ĐƯỢC PHÁP LUẬT CHO PHÉP:\n\n'
              'Aetron được cung cấp theo nguyên tắc "NGUYÊN TRẠNG" (AS IS) và "THEO KHẢ NĂNG SẴN CÓ" (AS AVAILABLE). Chúng tôi không đưa ra bất kỳ bảo đảm nào, dù rõ ràng hay ngụ ý, về:\n\n'
              '• Tính chính xác, đầy đủ hoặc kịp thời của dữ liệu tập luyện.\n'
              '• Khả năng hoạt động liên tục, không gián đoạn hoặc không có lỗi của Ứng dụng.\n'
              '• Tính tương thích với mọi thiết bị hoặc hệ điều hành.\n\n'
              'Nhà phát triển Aetron KHÔNG chịu trách nhiệm đối với:\n'
              '• Bất kỳ chấn thương thể chất, sự cố sức khỏe hoặc tử vong phát sinh trong quá trình tập luyện.\n'
              '• Mất mát dữ liệu do lỗi hệ thống, thiết bị hoặc kết nối mạng.\n'
              '• Thiệt hại gián tiếp, ngẫu nhiên, đặc biệt hoặc mang tính hậu quả phát sinh từ việc sử dụng hoặc không thể sử dụng Ứng dụng.\n'
              '• Bất kỳ quyết định nào bạn đưa ra dựa trên dữ liệu hoặc phân tích từ Ứng dụng.',
        ),
        // 13
        LegalDocumentSection(
          title: '13. Bồi thường & Miễn trừ',
          content:
              'Bạn đồng ý bồi thường, bảo vệ và giữ cho Aetron, các giám đốc, nhân viên, đối tác và nhà cung cấp dịch vụ không bị thiệt hại trước bất kỳ khiếu nại, yêu cầu bồi thường, tổn thất, chi phí (bao gồm phí luật sư hợp lý) phát sinh từ:\n\n'
              '• Việc bạn vi phạm Điều khoản Sử dụng này.\n'
              '• Nội dung Người dùng mà bạn tải lên hoặc chia sẻ qua Ứng dụng.\n'
              '• Việc bạn vi phạm quyền của bên thứ ba, bao gồm quyền sở hữu trí tuệ và quyền riêng tư.\n'
              '• Bất kỳ hoạt động bất hợp pháp nào bạn thực hiện thông qua tài khoản Aetron.\n\n'
              'Nghĩa vụ bồi thường này vẫn tiếp tục có hiệu lực ngay cả sau khi bạn ngừng sử dụng Ứng dụng hoặc xóa tài khoản.',
        ),
        // 14
        LegalDocumentSection(
          title: '14. Giải quyết Tranh chấp & Trọng tài',
          content:
              'Bất kỳ tranh chấp nào phát sinh từ hoặc liên quan đến Điều khoản Sử dụng này sẽ được giải quyết theo trình tự sau:\n\n'
              '1. Thương lượng thiện chí: Các bên sẽ cố gắng giải quyết tranh chấp thông qua đàm phán trực tiếp trong vòng 30 ngày kể từ ngày thông báo tranh chấp.\n\n'
              '2. Hòa giải: Nếu thương lượng không thành công, tranh chấp sẽ được đưa ra hòa giải tại một trung tâm hòa giải được cả hai bên chấp thuận.\n\n'
              '3. Trọng tài ràng buộc: Nếu hòa giải không đạt kết quả, tranh chấp sẽ được giải quyết bằng trọng tài ràng buộc theo quy tắc của Trung tâm Trọng tài Quốc tế Việt Nam (VIAC) hoặc cơ quan trọng tài có thẩm quyền tại khu vực tài phán áp dụng.\n\n'
              'BẠN ĐỒNG Ý RẰNG BẤT KỲ TRANH CHẤP NÀO SẼ ĐƯỢC GIẢI QUYẾT TRÊN CƠ SỞ CÁ NHÂN, KHÔNG PHẢI NHƯ NGUYÊN ĐƠN HOẶC THÀNH VIÊN CỦA BẤT KỲ VỤ KIỆN TẬP THỂ NÀO.',
        ),
        // 15
        LegalDocumentSection(
          title: '15. Luật Áp dụng & Quyền Tài phán',
          content:
              'Điều khoản Sử dụng này được điều chỉnh và giải thích theo pháp luật nước Cộng hòa Xã hội Chủ nghĩa Việt Nam, không áp dụng các quy tắc xung đột pháp luật.\n\n'
              'Tòa án nhân dân có thẩm quyền tại Thành phố Hồ Chí Minh, Việt Nam sẽ có quyền tài phán độc quyền đối với bất kỳ vụ kiện nào phát sinh từ hoặc liên quan đến Điều khoản này, trừ trường hợp các bên đã đồng ý giải quyết bằng trọng tài theo Điều 14.\n\n'
              'Nếu bạn truy cập Ứng dụng từ bên ngoài Việt Nam, bạn có trách nhiệm tuân thủ pháp luật địa phương của quốc gia bạn. Việc sử dụng Ứng dụng từ các khu vực pháp lý mà nội dung hoặc dịch vụ bị cấm là hoàn toàn tự chịu rủi ro.',
        ),
        // 16
        LegalDocumentSection(
          title: '16. Cập nhật & Điều chỉnh Điều khoản',
          content:
              'Aetron có quyền sửa đổi, cập nhật hoặc thay thế Điều khoản Sử dụng này bất kỳ lúc nào. Khi có thay đổi quan trọng, chúng tôi sẽ:\n\n'
              '• Hiển thị thông báo trong ứng dụng về việc Điều khoản đã được cập nhật.\n'
              '• Cập nhật ngày "Có hiệu lực từ" ở đầu tài liệu.\n'
              '• Đối với thay đổi trọng yếu, gửi email thông báo đến địa chỉ email đã đăng ký.\n\n'
              'Việc bạn tiếp tục sử dụng Ứng dụng sau khi Điều khoản được cập nhật đồng nghĩa với việc bạn chấp nhận và đồng ý bị ràng buộc bởi phiên bản mới nhất của Điều khoản.\n\n'
              'Nếu bạn không đồng ý với bất kỳ thay đổi nào, bạn có quyền ngừng sử dụng Ứng dụng và xóa tài khoản theo quy trình tại Điều 11.\n\n'
              'Ngày có hiệu lực: 26/07/2026\n'
              'Phiên bản: 1.0.0\n'
              '© 2026 Aetron. Tất cả các quyền được bảo lưu.',
        ),
      ];
    } else {
      return const [
        // 1
        LegalDocumentSection(
          title: '1. Acceptance of Terms & Health Disclaimer',
          content:
              'By downloading, installing, or using the Aetron application ("App"), you agree to be bound by these Terms of Service ("Terms"). If you do not agree to any part of these Terms, please do not use the App.\n\n'
              'Aetron is a personal fitness tracking and performance telemetry application. All metrics displayed within the App — including speed, pace, calorie expenditure, estimated heart rate, distance, and step count — are calculated using device sensors and software algorithms for technical informational purposes only.\n\n'
              'WARNING: The App does not provide medical advice, diagnose health conditions, or replace consultation with a licensed healthcare professional. You should consult a physician before starting or modifying any high-intensity exercise program. If you have a history of cardiovascular disease, hypertension, or any health condition, stop exercising immediately if you feel unwell and contact your nearest medical facility.',
        ),
        // 2
        LegalDocumentSection(
          title: '2. Eligibility & Age Requirements',
          content:
              'To use Aetron, you must meet the following requirements:\n\n'
              '• Be at least 13 years of age (or the minimum age required by applicable law in your jurisdiction).\n'
              '• If you are under 18 years of age, your use of the App must be with the consent and supervision of a parent or legal guardian.\n'
              '• You represent that all information provided to Aetron is accurate, complete, and current.\n'
              '• You agree not to create multiple accounts for fraudulent purposes or to circumvent these Terms.\n\n'
              'Aetron reserves the right to refuse service to any user who violates these eligibility requirements without prior notice.',
        ),
        // 3
        LegalDocumentSection(
          title: '3. User Account & Security',
          content:
              'When registering an Aetron account, you are responsible for:\n\n'
              '• Maintaining strict confidentiality of your password and login credentials.\n'
              '• Notifying us immediately if you detect any unauthorized access to your account.\n'
              '• All activities conducted under your account, including recorded workouts, uploaded data, and configuration changes.\n'
              '• Providing accurate biometric information (height, weight, age, gender) to ensure optimal telemetry calculations.\n\n'
              'Aetron utilizes Google OAuth 2.0 and Supabase Auth for authentication. We do not store passwords in plaintext on our systems.',
        ),
        // 4
        LegalDocumentSection(
          title: '4. Service Description & Features',
          content:
              'Aetron provides the following core services and features:\n\n'
              '• Workout recording and tracking: Outdoor running, treadmill (indoor run), walking, and cycling with real-time GPS tracking.\n'
              '• Performance analytics: Distance, duration, average speed, pace, calorie expenditure, cadence, estimated heart rate, and VO2 Max metrics.\n'
              '• Route mapping: Displaying route maps with color-coded pace segments.\n'
              '• Statistics & Analysis: Weekly/monthly/yearly trend charts, pace distribution, personal records.\n'
              '• Personal profile: Biometric data management, workout history, achievement badges.\n'
              '• Workout calendar: View and manage workouts by day/month.\n\n'
              'We reserve the right to add, modify, or discontinue any feature without prior notice, provided that core application functionality is maintained.',
        ),
        // 5
        LegalDocumentSection(
          title: '5. Subscriptions & Billing (If Applicable)',
          content:
              'Aetron currently provides all core features free of charge. In the future, we may introduce Premium subscription tiers with enhanced capabilities.\n\n'
              'If Premium subscriptions are implemented:\n'
              '• Payments will be processed through the Apple App Store or Google Play Store, depending on your device platform.\n'
              '• Subscriptions will auto-renew unless cancelled at least 24 hours before the renewal date.\n'
              '• You can manage or cancel subscriptions through your App Store/Play Store account settings.\n'
              '• Subscription fees are non-refundable for any unused portion of the current billing cycle.\n'
              '• Prices may change with at least 30 days advance notice via email or in-app notification.',
        ),
        // 6
        LegalDocumentSection(
          title: '6. GPS Location & Telemetry Accuracy',
          content:
              'Aetron relies on the Global Positioning System (GPS) and integrated device motion sensors (accelerometer, gyroscope, magnetometer) to map routes and calculate distances.\n\n'
              'You acknowledge and agree that:\n'
              '• GPS data accuracy depends on device hardware quality, weather conditions, surrounding environment (tall buildings, dense foliage, tunnels), and satellite signal stability.\n'
              '• Distance, speed, and route maps may have a margin of error from 1% to 10% depending on real-world conditions.\n'
              '• Indoor workouts (treadmill) rely on motion sensors for distance estimation and have lower accuracy than outdoor GPS tracking.\n'
              '• Aetron is not responsible for discrepancies between recorded data and actual distances.\n\n'
              'For optimal results, ensure your device has a clear line of sight to the sky and wait for GPS signal stabilization (displaying "GPS Signal Ready") before starting your workout.',
        ),
        // 7
        LegalDocumentSection(
          title: '7. User Content & Licensing',
          content:
              'Through your use of Aetron, you may create and upload content including workout data, profile photos, personal profile information, and route maps (collectively, "User Content").\n\n'
              'You retain full ownership of your User Content. However, by using the App, you grant Aetron a non-exclusive, royalty-free, transferable license to:\n'
              '• Store, process, and display your User Content to provide App functionality.\n'
              '• Use aggregated, anonymized data (with all personally identifiable information removed) to improve algorithms and service quality.\n\n'
              'You warrant that your User Content does not infringe upon any copyright, trademark, trade secret, or intellectual property right of any third party.',
        ),
        // 8
        LegalDocumentSection(
          title: '8. Acceptable Use & Conduct',
          content:
              'You agree to comply with the following rules of conduct:\n\n'
              '• DO NOT use Aetron for any activity that violates local or international law.\n'
              '• DO NOT falsify workout achievements using GPS spoofing, interference devices, or third-party software to generate fabricated workout data.\n'
              '• DO NOT attempt to reverse engineer, decompile, decrypt, or tamper with the App\'s source code, APIs, or server infrastructure.\n'
              '• DO NOT launch denial-of-service (DDoS) attacks or intentionally disrupt normal system operations.\n'
              '• DO NOT use bots, automated crawlers, or scraping tools to extract data from the App.\n'
              '• DO NOT impersonate other users or create fraudulent accounts.\n\n'
              'Violations may result in immediate suspension or permanent termination of your account without refund.',
        ),
        // 9
        LegalDocumentSection(
          title: '9. Intellectual Property Rights',
          content:
              'All user interfaces (UI/UX), the Aetron logo, graphic designs, icons, color systems, custom fonts, software source code, computational algorithms, databases, and system architecture are the exclusive intellectual property of Aetron and/or its licensors.\n\n'
              'You may NOT:\n'
              '• Copy, reproduce, distribute, or create derivative works from any portion of the App.\n'
              '• Use the "Aetron" brand, logo, or name for commercial purposes without prior written consent.\n'
              '• Extract or reuse the App\'s mapping database or analytics algorithms.\n\n'
              'All third-party trademarks, trade names, and logos displayed within the App (Google Maps, Supabase, etc.) are the property of their respective owners.',
        ),
        // 10
        LegalDocumentSection(
          title: '10. Third-Party Services & Integrations',
          content:
              'Aetron integrates with third-party services to deliver a comprehensive experience:\n\n'
              '• Google Maps Platform: Route map display and GPS location services.\n'
              '• Supabase: Cloud data storage, user authentication, and synchronization.\n'
              '• Google OAuth 2.0: Quick sign-in via Google accounts.\n'
              '• Firebase (if applicable): Push notifications and usage analytics.\n\n'
              'Each third-party service maintains its own terms of use and privacy policy. Aetron is not responsible for the content, availability, or security practices of third-party services. You are encouraged to review each provider\'s terms independently.',
        ),
        // 11
        LegalDocumentSection(
          title: '11. Account Suspension & Termination',
          content:
              'Aetron reserves the right to suspend or terminate your account in the following circumstances:\n\n'
              '• Violation of any provision in these Terms of Service.\n'
              '• Detection of fraudulent behavior, abuse, or suspicious activity.\n'
              '• Request from law enforcement agencies or as required by applicable law.\n'
              '• Extended inactivity exceeding 24 consecutive months.\n\n'
              'You may delete your account at any time via the "Delete Account" option in Settings. Upon account deletion:\n'
              '• All personal data, workout history, and route maps will be permanently removed from our systems within 30 days.\n'
              '• Aggregated anonymous data previously used for analytics may be retained.\n'
              '• Account deletion is irreversible.',
        ),
        // 12
        LegalDocumentSection(
          title: '12. Limitation of Liability',
          content:
              'TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW:\n\n'
              'Aetron is provided on an "AS IS" and "AS AVAILABLE" basis. We make no warranties, express or implied, regarding:\n\n'
              '• The accuracy, completeness, or timeliness of workout data.\n'
              '• Continuous, uninterrupted, or error-free operation of the App.\n'
              '• Compatibility with all devices or operating systems.\n\n'
              'Aetron developers SHALL NOT be liable for:\n'
              '• Any physical injury, health incident, or death arising during exercise.\n'
              '• Data loss resulting from system failures, device malfunctions, or network connectivity issues.\n'
              '• Indirect, incidental, special, or consequential damages arising from the use or inability to use the App.\n'
              '• Any decisions you make based on data or analysis provided by the App.',
        ),
        // 13
        LegalDocumentSection(
          title: '13. Indemnification',
          content:
              'You agree to indemnify, defend, and hold harmless Aetron, its directors, employees, partners, and service providers from and against any claims, demands, losses, costs (including reasonable attorney fees) arising from:\n\n'
              '• Your violation of these Terms of Service.\n'
              '• User Content you upload or share through the App.\n'
              '• Your violation of any third-party rights, including intellectual property and privacy rights.\n'
              '• Any unlawful activity conducted through your Aetron account.\n\n'
              'This indemnification obligation shall survive the termination of your use of the App or deletion of your account.',
        ),
        // 14
        LegalDocumentSection(
          title: '14. Dispute Resolution & Arbitration',
          content:
              'Any disputes arising from or relating to these Terms of Service shall be resolved in the following order:\n\n'
              '1. Good Faith Negotiation: The parties shall attempt to resolve the dispute through direct negotiation within 30 days of the dispute notice.\n\n'
              '2. Mediation: If negotiation fails, the dispute shall be submitted to mediation at a center mutually agreed upon by both parties.\n\n'
              '3. Binding Arbitration: If mediation is unsuccessful, the dispute shall be resolved through binding arbitration under the rules of the Vietnam International Arbitration Centre (VIAC) or the relevant arbitration body in the applicable jurisdiction.\n\n'
              'YOU AGREE THAT ANY DISPUTE SHALL BE RESOLVED ON AN INDIVIDUAL BASIS, NOT AS A PLAINTIFF OR CLASS MEMBER IN ANY PURPORTED CLASS ACTION.',
        ),
        // 15
        LegalDocumentSection(
          title: '15. Governing Law & Jurisdiction',
          content:
              'These Terms of Service shall be governed by and construed in accordance with the laws of the Socialist Republic of Vietnam, without regard to conflict of law principles.\n\n'
              'The competent People\'s Courts in Ho Chi Minh City, Vietnam shall have exclusive jurisdiction over any litigation arising from or related to these Terms, unless the parties have agreed to arbitration under Section 14.\n\n'
              'If you access the App from outside Vietnam, you are responsible for compliance with local laws in your jurisdiction. Use of the App from jurisdictions where the content or services are prohibited is entirely at your own risk.',
        ),
        // 16
        LegalDocumentSection(
          title: '16. Revisions & Updates',
          content:
              'Aetron reserves the right to modify, update, or replace these Terms of Service at any time. When significant changes are made, we will:\n\n'
              '• Display an in-app notification regarding the updated Terms.\n'
              '• Update the "Effective Date" at the top of this document.\n'
              '• For material changes, send email notification to your registered email address.\n\n'
              'Your continued use of the App after Terms are updated constitutes your acceptance of and agreement to be bound by the latest version of these Terms.\n\n'
              'If you do not agree with any changes, you may discontinue use of the App and delete your account as per Section 11.\n\n'
              'Effective Date: July 26, 2026\n'
              'Version: 1.0.0\n'
              '© 2026 Aetron. All rights reserved.',
        ),
      ];
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // PRIVACY POLICY — 14 sections (VI / EN)
  // ──────────────────────────────────────────────────────────────────────────
  static List<LegalDocumentSection> getPrivacyPolicy(AppLanguage lang) {
    if (lang == AppLanguage.vi) {
      return const [
        // 1
        LegalDocumentSection(
          title: '1. Dữ liệu Thu thập',
          content:
              'Aetron thu thập các loại thông tin sau để cung cấp và cải thiện dịch vụ theo dõi tập luyện:\n\n'
              'Thông tin Hồ sơ Cá nhân:\n'
              '• Email đăng ký và tên hiển thị.\n'
              '• Ảnh đại diện (nếu bạn chọn tải lên).\n'
              '• Dữ liệu sinh trắc học: chiều cao, cân nặng, tuổi, giới tính — được sử dụng để tính toán calo, BMI và các chỉ số sức khỏe.\n\n'
              'Dữ liệu Tập luyện:\n'
              '• Tọa độ GPS theo thời gian thực trong các buổi tập ngoài trời (chạy bộ, đi bộ, đạp xe).\n'
              '• Khoảng cách, thời gian, tốc độ, pace, lượng calo tiêu thụ.\n'
              '• Nhịp bước (cadence) và dữ liệu cảm biến chuyển động.\n'
              '• Bản đồ lộ trình và các mốc GPS.',
        ),
        // 2
        LegalDocumentSection(
          title: '2. Dữ liệu Tự động Thu thập',
          content:
              'Ngoài thông tin bạn chủ động cung cấp, Aetron tự động thu thập một số dữ liệu kỹ thuật:\n\n'
              '• Thông tin thiết bị: Mẫu thiết bị, phiên bản hệ điều hành (iOS/Android), độ phân giải màn hình, ngôn ngữ hệ thống.\n'
              '• Dữ liệu sử dụng ứng dụng: Tần suất mở ứng dụng, thời gian sử dụng, các tính năng được truy cập, sự cố ứng dụng (crash logs).\n'
              '• Trạng thái kết nối: Loại mạng (Wi-Fi, 4G/5G), trạng thái GPS (bật/tắt), trạng thái quyền hệ thống.\n'
              '• Nhật ký phiên đăng nhập: Thời gian đăng nhập, phương thức xác thực (Google, email), địa chỉ IP (được ẩn danh hóa).\n\n'
              'Dữ liệu tự động thu thập được sử dụng để chẩn đoán lỗi, tối ưu hóa hiệu suất ứng dụng và cải thiện trải nghiệm người dùng.',
        ),
        // 3
        LegalDocumentSection(
          title: '3. Mục đích Sử dụng Thông tin',
          content:
              'Dữ liệu của bạn được sử dụng cho các mục đích cụ thể sau:\n\n'
              '• Cung cấp dịch vụ: Tính toán khoảng cách, tốc độ, lượng calo, tạo bản đồ lộ trình và biểu đồ thống kê.\n'
              '• Đồng bộ hóa đám mây: Lưu trữ an toàn dữ liệu tập luyện trên Supabase Cloud để bạn có thể truy cập từ nhiều thiết bị.\n'
              '• Cá nhân hóa trải nghiệm: Điều chỉnh giao diện, ngôn ngữ hiển thị và gợi ý tập luyện dựa trên thói quen sử dụng.\n'
              '• Phân tích & cải tiến: Sử dụng dữ liệu tổng hợp ẩn danh để cải thiện thuật toán tính toán, phát hiện lỗi và phát triển tính năng mới.\n'
              '• Giao tiếp: Gửi thông báo quan trọng về cập nhật ứng dụng, thay đổi điều khoản hoặc cảnh báo bảo mật (nếu có).\n\n'
              'Chúng tôi KHÔNG sử dụng dữ liệu của bạn cho mục đích quảng cáo đích danh hoặc bán cho bên thứ ba.',
        ),
        // 4
        LegalDocumentSection(
          title: '4. Cơ sở Pháp lý để Xử lý Dữ liệu',
          content:
              'Aetron xử lý dữ liệu cá nhân của bạn dựa trên các cơ sở pháp lý sau (phù hợp với GDPR và các quy định tương đương):\n\n'
              '• Thực hiện hợp đồng (Điều 6(1)(b) GDPR): Xử lý dữ liệu cần thiết để cung cấp dịch vụ bạn đã đăng ký — ghi nhận bài tập, tính toán chỉ số, đồng bộ dữ liệu.\n'
              '• Sự đồng ý (Điều 6(1)(a) GDPR): Thu thập dữ liệu GPS, ảnh đại diện và thông báo đẩy chỉ khi bạn cấp quyền rõ ràng.\n'
              '• Lợi ích hợp pháp (Điều 6(1)(f) GDPR): Phân tích dữ liệu tổng hợp ẩn danh để cải thiện ứng dụng, phát hiện gian lận và đảm bảo bảo mật hệ thống.\n'
              '• Nghĩa vụ pháp lý (Điều 6(1)(c) GDPR): Tuân thủ các yêu cầu pháp luật về lưu trữ dữ liệu và bảo vệ quyền riêng tư.\n\n'
              'Bạn có quyền rút lại sự đồng ý bất kỳ lúc nào bằng cách tắt các quyền tương ứng trong Cài đặt thiết bị hoặc liên hệ với chúng tôi.',
        ),
        // 5
        LegalDocumentSection(
          title: '5. Chia sẻ & Tiết lộ Dữ liệu',
          content:
              'Aetron có thể chia sẻ dữ liệu của bạn trong các trường hợp giới hạn sau:\n\n'
              'Nhà cung cấp dịch vụ tin cậy:\n'
              '• Supabase: Lưu trữ cơ sở dữ liệu và xác thực người dùng.\n'
              '• Google Cloud Platform: Dịch vụ bản đồ và API định vị.\n'
              '• Các nhà cung cấp dịch vụ này bị ràng buộc bởi hợp đồng xử lý dữ liệu (DPA) nghiêm ngặt.\n\n'
              'Yêu cầu pháp lý:\n'
              '• Khi được yêu cầu bởi lệnh tòa án, trát đòi hầu tòa hoặc quy trình pháp lý hợp lệ.\n'
              '• Khi cần thiết để bảo vệ quyền lợi, tài sản hoặc an toàn của Aetron, người dùng hoặc công chúng.\n\n'
              'Dữ liệu tổng hợp ẩn danh:\n'
              '• Chúng tôi có thể chia sẻ dữ liệu thống kê tổng hợp (đã loại bỏ hoàn toàn thông tin nhận dạng cá nhân) cho mục đích nghiên cứu hoặc phát triển sản phẩm.\n\n'
              'Chúng tôi KHÔNG BAO GIỜ bán dữ liệu cá nhân cho nhà quảng cáo hoặc đại lý dữ liệu.',
        ),
        // 6
        LegalDocumentSection(
          title: '6. Quyền Truy cập Thiết bị',
          content:
              'Aetron yêu cầu các quyền truy cập thiết bị sau để hoạt động đầy đủ:\n\n'
              '• Quyền Vị trí (GPS): Chỉ kích hoạt trong thời gian bạn thực hiện bài tập ngoài trời. Ứng dụng yêu cầu quyền "Luôn cho phép" hoặc "Khi sử dụng" tùy theo hệ điều hành để ghi nhận lộ trình chính xác ngay cả khi màn hình tắt.\n\n'
              '• Quyền Máy ảnh: Chỉ sử dụng khi bạn chủ động chụp ảnh mới để làm ảnh đại diện hồ sơ.\n\n'
              '• Quyền Thư viện ảnh: Chỉ sử dụng khi bạn chọn ảnh từ thư viện để làm ảnh đại diện.\n\n'
              '• Quyền Cảm biến chuyển động: Truy cập gia tốc kế và con quay hồi chuyển để đếm bước chân và phát hiện loại hoạt động.\n\n'
              '• Quyền Thông báo (tùy chọn): Gửi nhắc nhở tập luyện và thông báo tiến trình.\n\n'
              'Bạn có toàn quyền bật hoặc tắt bất kỳ quyền nào trong phần Cài đặt > Quyền riêng tư của thiết bị. Việc tắt một số quyền có thể ảnh hưởng đến chức năng của ứng dụng.',
        ),
        // 7
        LegalDocumentSection(
          title: '7. Cookie & Công nghệ Theo dõi',
          content:
              'Aetron là ứng dụng di động gốc (native mobile app) và không sử dụng cookie trình duyệt web truyền thống. Tuy nhiên, chúng tôi sử dụng các công nghệ tương đương:\n\n'
              '• SharedPreferences / UserDefaults: Lưu trữ cục bộ trên thiết bị các tùy chọn người dùng (ngôn ngữ, đơn vị đo, chế độ hiển thị) và token xác thực phiên đăng nhập.\n\n'
              '• Bộ nhớ đệm (Cache): Lưu trữ tạm thời bản đồ, ảnh đại diện và dữ liệu thống kê để tăng tốc tải ứng dụng và giảm tiêu thụ dữ liệu di động.\n\n'
              '• SDK phân tích (nếu tích hợp): Có thể thu thập dữ liệu sử dụng ẩn danh để phân tích xu hướng và cải thiện trải nghiệm.\n\n'
              'Bạn có thể xóa bộ nhớ đệm bất kỳ lúc nào thông qua mục "Xóa bộ nhớ tạm (Cache)" trong phần Cài đặt ứng dụng.',
        ),
        // 8
        LegalDocumentSection(
          title: '8. Cam kết Không Bán Dữ liệu',
          content:
              'Aetron cam kết TUYỆT ĐỐI KHÔNG:\n\n'
              '• Bán dữ liệu cá nhân của bạn cho bất kỳ bên thứ ba nào, bao gồm nhà quảng cáo, đại lý dữ liệu (data broker), công ty phân tích thị trường hoặc tổ chức chính phủ (trừ khi được yêu cầu bởi pháp luật).\n\n'
              '• Cho thuê, trao đổi hoặc cung cấp quyền truy cập vào dữ liệu vị trí GPS, lịch sử tập luyện hoặc thông tin sinh trắc học của bạn cho mục đích thương mại.\n\n'
              '• Sử dụng dữ liệu cá nhân để tạo hồ sơ quảng cáo đích danh (targeted advertising profile) hoặc bán quảng cáo cá nhân hóa.\n\n'
              '• Chia sẻ thông tin liên hệ (email, tên) với các bên tiếp thị bên ngoài.\n\n'
              'Cam kết này là trọng tâm trong triết lý bảo mật của Aetron: "Dữ liệu của bạn thuộc về bạn — chúng tôi chỉ là người giữ hộ."',
        ),
        // 9
        LegalDocumentSection(
          title: '9. Lưu trữ & Truyền tải Dữ liệu Quốc tế',
          content:
              'Dữ liệu cá nhân và dữ liệu tập luyện của bạn được lưu trữ trên cơ sở hạ tầng đám mây Supabase, với máy chủ đặt tại các khu vực sau:\n\n'
              '• Đông Nam Á (Singapore) — máy chủ chính.\n'
              '• Hoa Kỳ — máy chủ sao lưu và dự phòng.\n\n'
              'Việc truyền tải dữ liệu quốc tế tuân thủ:\n'
              '• Điều khoản hợp đồng tiêu chuẩn (SCCs) của Ủy ban Châu Âu cho chuyển dữ liệu ngoài EEA.\n'
              '• Các biện pháp kỹ thuật và tổ chức phù hợp để đảm bảo mức bảo vệ tương đương.\n\n'
              'Bạn đồng ý rằng dữ liệu của bạn có thể được xử lý tại các quốc gia ngoài quốc gia cư trú của bạn, nơi luật bảo vệ dữ liệu có thể khác biệt.',
        ),
        // 10
        LegalDocumentSection(
          title: '10. Thời gian Lưu giữ Dữ liệu',
          content:
              'Aetron lưu giữ dữ liệu của bạn theo các chính sách sau:\n\n'
              '• Dữ liệu hồ sơ cá nhân: Được lưu giữ trong suốt thời gian tài khoản hoạt động và tối đa 30 ngày sau khi tài khoản bị xóa.\n\n'
              '• Lịch sử bài tập & bản đồ lộ trình: Được lưu giữ trong suốt thời gian tài khoản hoạt động. Xóa vĩnh viễn trong vòng 30 ngày sau khi bạn yêu cầu xóa tài khoản.\n\n'
              '• Dữ liệu tổng hợp ẩn danh: Có thể được lưu giữ vô thời hạn vì không chứa thông tin nhận dạng cá nhân.\n\n'
              '• Nhật ký hệ thống (logs): Được lưu giữ tối đa 90 ngày để phục vụ chẩn đoán lỗi và bảo mật.\n\n'
              '• Bộ nhớ đệm thiết bị: Bạn có thể xóa bất kỳ lúc nào thông qua Cài đặt > Xóa bộ nhớ tạm.',
        ),
        // 11
        LegalDocumentSection(
          title: '11. Quyền Kiểm soát & Xóa Dữ liệu',
          content:
              'Bạn có toàn quyền kiểm soát dữ liệu cá nhân của mình với các quyền sau:\n\n'
              '• Quyền truy cập: Xem tất cả dữ liệu cá nhân mà Aetron lưu trữ về bạn thông qua phần Hồ sơ và Lịch sử.\n\n'
              '• Quyền chỉnh sửa: Cập nhật thông tin hồ sơ sinh trắc học (chiều cao, cân nặng, tuổi, giới tính) bất kỳ lúc nào.\n\n'
              '• Quyền xóa: Xóa từng bài tập riêng lẻ hoặc yêu cầu xóa toàn bộ tài khoản và dữ liệu liên quan.\n\n'
              '• Quyền xuất dữ liệu: Yêu cầu xuất dữ liệu tập luyện của bạn ở định dạng máy có thể đọc được (JSON/CSV) — tính năng sẽ được bổ sung trong phiên bản tương lai.\n\n'
              '• Quyền hạn chế xử lý: Tắt các quyền thiết bị (GPS, máy ảnh) để hạn chế thu thập dữ liệu mới.\n\n'
              '• Quyền phản đối: Liên hệ với chúng tôi để phản đối việc xử lý dữ liệu cho các mục đích cụ thể.\n\n'
              'Để thực hiện bất kỳ quyền nào, vui lòng liên hệ: aetron.support@gmail.com',
        ),
        // 12
        LegalDocumentSection(
          title: '12. Bảo mật Đám mây & Mã hóa',
          content:
              'Aetron cam kết bảo vệ dữ liệu của bạn bằng các biện pháp bảo mật đa tầng:\n\n'
              'Mã hóa truyền tải:\n'
              '• Tất cả thông tin truyền tải giữa ứng dụng và máy chủ Supabase Cloud được mã hóa bằng giao thức TLS 1.3 (Transport Layer Security) tiêu chuẩn ngành.\n\n'
              'Mã hóa lưu trữ:\n'
              '• Dữ liệu được mã hóa khi lưu trữ (encryption at rest) trên cơ sở dữ liệu Supabase sử dụng AES-256.\n\n'
              'Xác thực & Phân quyền:\n'
              '• Xác thực qua Google OAuth 2.0 với token JWT (JSON Web Token).\n'
              '• Row Level Security (RLS) trên Supabase đảm bảo mỗi người dùng chỉ có thể truy cập dữ liệu của chính mình.\n\n'
              'Giám sát bảo mật:\n'
              '• Hệ thống giám sát tự động phát hiện truy cập bất thường và cảnh báo nhà phát triển.\n'
              '• Cập nhật bản vá bảo mật thường xuyên cho tất cả thư viện phụ thuộc.',
        ),
        // 13
        LegalDocumentSection(
          title: '13. Bảo vệ Quyền riêng tư Trẻ em',
          content:
              'Aetron không cố ý thu thập dữ liệu cá nhân từ trẻ em dưới 13 tuổi (hoặc tuổi tối thiểu theo quy định pháp luật tại quốc gia của bạn, ví dụ: 16 tuổi theo GDPR tại một số quốc gia EU).\n\n'
              'Nếu chúng tôi phát hiện rằng dữ liệu đã được thu thập từ trẻ em dưới độ tuổi quy định mà không có sự đồng ý của cha mẹ hoặc người giám hộ, chúng tôi sẽ:\n\n'
              '• Xóa ngay lập tức tất cả dữ liệu liên quan đến tài khoản đó.\n'
              '• Vô hiệu hóa tài khoản.\n'
              '• Thông báo cho cha mẹ hoặc người giám hộ (nếu có thông tin liên hệ).\n\n'
              'Nếu bạn là cha mẹ hoặc người giám hộ và tin rằng con bạn đã cung cấp dữ liệu cá nhân cho Aetron, vui lòng liên hệ ngay: aetron.support@gmail.com',
        ),
        // 14
        LegalDocumentSection(
          title: '14. Cập nhật Chính sách & Liên hệ',
          content:
              'Chúng tôi có thể cập nhật Chính sách Bảo mật này theo thời gian để phản ánh:\n'
              '• Thay đổi trong thực tiễn thu thập và xử lý dữ liệu.\n'
              '• Cập nhật quy định pháp luật về bảo vệ dữ liệu.\n'
              '• Bổ sung tính năng mới ảnh hưởng đến quyền riêng tư.\n\n'
              'Khi có thay đổi quan trọng, chúng tôi sẽ thông báo qua ứng dụng và/hoặc email.\n\n'
              'Liên hệ về Quyền riêng tư:\n'
              '• Email: aetron.support@gmail.com\n'
              '• Chủ thể dữ liệu: Đặng Đức Bảo\n'
              '• Địa chỉ: Thành phố Hồ Chí Minh, Việt Nam\n\n'
              'Ngày có hiệu lực: 26/07/2026\n'
              'Phiên bản: 1.0.0\n'
              '© 2026 Aetron. Tất cả các quyền được bảo lưu.',
        ),
      ];
    } else {
      return const [
        // 1
        LegalDocumentSection(
          title: '1. Information We Collect',
          content:
              'Aetron collects the following types of information to provide and improve workout tracking services:\n\n'
              'Personal Profile Information:\n'
              '• Registration email and display name.\n'
              '• Profile photo (if you choose to upload one).\n'
              '• Biometric data: height, weight, age, gender — used to calculate calories, BMI, and health metrics.\n\n'
              'Workout Data:\n'
              '• Real-time GPS coordinates during outdoor workouts (running, walking, cycling).\n'
              '• Distance, duration, speed, pace, calorie expenditure.\n'
              '• Cadence and motion sensor data.\n'
              '• Route maps and GPS waypoints.',
        ),
        // 2
        LegalDocumentSection(
          title: '2. Automatically Collected Data',
          content:
              'In addition to information you actively provide, Aetron automatically collects certain technical data:\n\n'
              '• Device information: Device model, operating system version (iOS/Android), screen resolution, system language.\n'
              '• App usage data: Frequency of app opens, usage duration, features accessed, crash logs.\n'
              '• Connectivity status: Network type (Wi-Fi, 4G/5G), GPS status (on/off), system permission states.\n'
              '• Session logs: Login timestamps, authentication method (Google, email), IP addresses (anonymized).\n\n'
              'Automatically collected data is used for error diagnostics, app performance optimization, and user experience improvement.',
        ),
        // 3
        LegalDocumentSection(
          title: '3. How We Use Information',
          content:
              'Your data is used for the following specific purposes:\n\n'
              '• Service delivery: Computing distance, speed, calorie expenditure, generating route maps and statistical charts.\n'
              '• Cloud synchronization: Securely storing workout data on Supabase Cloud so you can access your history across multiple devices.\n'
              '• Personalization: Adapting the interface, display language, and workout suggestions based on your usage patterns.\n'
              '• Analytics & improvement: Using aggregated anonymous data to improve calculation algorithms, detect bugs, and develop new features.\n'
              '• Communication: Sending important notifications about app updates, terms changes, or security alerts (when applicable).\n\n'
              'We do NOT use your data for targeted advertising or sell it to third parties.',
        ),
        // 4
        LegalDocumentSection(
          title: '4. Legal Basis for Data Processing',
          content:
              'Aetron processes your personal data based on the following legal grounds (in compliance with GDPR and equivalent regulations):\n\n'
              '• Performance of contract (Article 6(1)(b) GDPR): Processing data necessary to deliver the services you signed up for — recording workouts, computing metrics, synchronizing data.\n'
              '• Consent (Article 6(1)(a) GDPR): Collecting GPS data, profile photos, and push notifications only when you grant explicit permission.\n'
              '• Legitimate interests (Article 6(1)(f) GDPR): Analyzing aggregated anonymous data to improve the app, detect fraud, and ensure system security.\n'
              '• Legal obligations (Article 6(1)(c) GDPR): Complying with legal requirements for data retention and privacy protection.\n\n'
              'You may withdraw your consent at any time by disabling relevant permissions in your device Settings or by contacting us.',
        ),
        // 5
        LegalDocumentSection(
          title: '5. Data Sharing & Disclosure',
          content:
              'Aetron may share your data in the following limited circumstances:\n\n'
              'Trusted Service Providers:\n'
              '• Supabase: Database storage and user authentication.\n'
              '• Google Cloud Platform: Map services and location APIs.\n'
              '• These providers are bound by strict Data Processing Agreements (DPAs).\n\n'
              'Legal Requirements:\n'
              '• When required by court orders, subpoenas, or valid legal process.\n'
              '• When necessary to protect the rights, property, or safety of Aetron, users, or the public.\n\n'
              'Aggregated Anonymous Data:\n'
              '• We may share aggregate statistical data (with all personally identifiable information completely removed) for research or product development purposes.\n\n'
              'We NEVER sell personal data to advertisers or data brokers.',
        ),
        // 6
        LegalDocumentSection(
          title: '6. Device Permissions & Privacy',
          content:
              'Aetron requests the following device permissions for full functionality:\n\n'
              '• Location (GPS): Active only during outdoor workout sessions. The app requests "Always Allow" or "While Using" permission depending on your OS, to record accurate routes even when the screen is off.\n\n'
              '• Camera: Used only when you actively capture a new photo for your profile picture.\n\n'
              '• Photo Library: Used only when selecting an existing photo from your library for your avatar.\n\n'
              '• Motion Sensors: Accessing accelerometer and gyroscope for step counting and activity type detection.\n\n'
              '• Notifications (optional): Sending workout reminders and progress alerts.\n\n'
              'You retain full control to enable or disable any permission via Settings > Privacy on your device. Disabling certain permissions may affect app functionality.',
        ),
        // 7
        LegalDocumentSection(
          title: '7. Cookies & Tracking Technologies',
          content:
              'Aetron is a native mobile application and does not use traditional browser cookies. However, we use equivalent technologies:\n\n'
              '• SharedPreferences / UserDefaults: Local device storage for user preferences (language, measurement units, display mode) and session authentication tokens.\n\n'
              '• Cache: Temporary storage of maps, profile photos, and statistical data to accelerate app loading and reduce mobile data consumption.\n\n'
              '• Analytics SDKs (if integrated): May collect anonymous usage data for trend analysis and experience improvement.\n\n'
              'You may clear cached data at any time via the "Clear Cache" option in App Settings.',
        ),
        // 8
        LegalDocumentSection(
          title: '8. No Third-Party Data Sales',
          content:
              'Aetron ABSOLUTELY DOES NOT:\n\n'
              '• Sell your personal data to any third party, including advertisers, data brokers, market analytics firms, or government organizations (unless required by law).\n\n'
              '• Rent, trade, or provide access to your GPS location data, workout history, or biometric information for commercial purposes.\n\n'
              '• Use personal data to create targeted advertising profiles or sell personalized advertisements.\n\n'
              '• Share your contact information (email, name) with external marketing parties.\n\n'
              'This commitment is central to Aetron\'s privacy philosophy: "Your data belongs to you — we are merely its custodian."',
        ),
        // 9
        LegalDocumentSection(
          title: '9. International Data Storage & Transfer',
          content:
              'Your personal data and workout data are stored on Supabase cloud infrastructure, with servers located in the following regions:\n\n'
              '• Southeast Asia (Singapore) — primary server.\n'
              '• United States — backup and redundancy server.\n\n'
              'International data transfers comply with:\n'
              '• European Commission Standard Contractual Clauses (SCCs) for transfers outside the EEA.\n'
              '• Appropriate technical and organizational measures to ensure equivalent levels of protection.\n\n'
              'You acknowledge that your data may be processed in countries outside your country of residence, where data protection laws may differ.',
        ),
        // 10
        LegalDocumentSection(
          title: '10. Data Retention Periods',
          content:
              'Aetron retains your data according to the following policies:\n\n'
              '• Personal profile data: Retained for the duration of active account status and up to 30 days after account deletion.\n\n'
              '• Workout history & route maps: Retained for the duration of active account status. Permanently deleted within 30 days of your account deletion request.\n\n'
              '• Aggregated anonymous data: May be retained indefinitely as it contains no personally identifiable information.\n\n'
              '• System logs: Retained for a maximum of 90 days for error diagnostics and security purposes.\n\n'
              '• Device cache: You may clear this at any time via Settings > Clear Cache.',
        ),
        // 11
        LegalDocumentSection(
          title: '11. Your Data Ownership Rights',
          content:
              'You retain full control over your personal data with the following rights:\n\n'
              '• Right of access: View all personal data that Aetron stores about you via your Profile and History sections.\n\n'
              '• Right to rectification: Update biometric profile information (height, weight, age, gender) at any time.\n\n'
              '• Right to erasure: Delete individual workouts or request complete account and data deletion.\n\n'
              '• Right to data portability: Request export of your workout data in a machine-readable format (JSON/CSV) — feature to be added in a future release.\n\n'
              '• Right to restrict processing: Disable device permissions (GPS, camera) to limit new data collection.\n\n'
              '• Right to object: Contact us to object to data processing for specific purposes.\n\n'
              'To exercise any of these rights, please contact: aetron.support@gmail.com',
        ),
        // 12
        LegalDocumentSection(
          title: '12. Cloud Security & Encryption',
          content:
              'Aetron is committed to protecting your data with multi-layered security measures:\n\n'
              'Transit Encryption:\n'
              '• All data transmitted between the app and Supabase Cloud servers is encrypted using industry-standard TLS 1.3 (Transport Layer Security) protocol.\n\n'
              'Storage Encryption:\n'
              '• Data is encrypted at rest on Supabase databases using AES-256 encryption.\n\n'
              'Authentication & Authorization:\n'
              '• Authentication via Google OAuth 2.0 with JWT (JSON Web Token) tokens.\n'
              '• Row Level Security (RLS) on Supabase ensures each user can only access their own data.\n\n'
              'Security Monitoring:\n'
              '• Automated monitoring systems detect anomalous access patterns and alert developers.\n'
              '• Regular security patches for all dependent libraries.',
        ),
        // 13
        LegalDocumentSection(
          title: '13. Children\'s Privacy Protection',
          content:
              'Aetron does not knowingly collect personal data from children under 13 years of age (or the minimum age required by applicable law in your jurisdiction, e.g., 16 years under GDPR in certain EU countries).\n\n'
              'If we discover that data has been collected from a child below the applicable age without parental or guardian consent, we will:\n\n'
              '• Immediately delete all data associated with that account.\n'
              '• Deactivate the account.\n'
              '• Notify the parent or guardian (if contact information is available).\n\n'
              'If you are a parent or guardian and believe your child has provided personal data to Aetron, please contact us immediately: aetron.support@gmail.com',
        ),
        // 14
        LegalDocumentSection(
          title: '14. Policy Updates & Contact',
          content:
              'We may update this Privacy Policy from time to time to reflect:\n'
              '• Changes in data collection and processing practices.\n'
              '• Updates to data protection regulations.\n'
              '• New features that affect privacy.\n\n'
              'When significant changes occur, we will notify you via the app and/or email.\n\n'
              'Privacy Contact:\n'
              '• Email: aetron.support@gmail.com\n'
              '• Data Subject: Dang Duc Bao\n'
              '• Address: Ho Chi Minh City, Vietnam\n\n'
              'Effective Date: July 26, 2026\n'
              'Version: 1.0.0\n'
              '© 2026 Aetron. All rights reserved.',
        ),
      ];
    }
  }
}
