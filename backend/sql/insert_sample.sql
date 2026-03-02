-- =================================================================
-- SCRIPT CẬP NHẬT DỮ LIỆU (ID ĐÃ ĐƯỢC ĐIỀN SẴN)
-- =================================================================

-- Bước 1: Tạo User Profile trong bảng 'users' (public) để tránh lỗi Foreign Key
-- (Sử dụng ID của bạn: 6e2f84d1-e16c-4ab4-bd89-1688aea5a37d)

INSERT INTO users (id, name, gender, age, weight_kg, height_cm)
VALUES (
  '6e2f84d1-e16c-4ab4-bd89-1688aea5a37d', -- ID CỦA BẠN
  'Duc Bao',
  'Male',
  22,
  65.0,
  175.0
) ON CONFLICT (id) DO UPDATE 
SET name = 'Duc Bao'; -- Update để đảm bảo row tồn tại


-- Bước 2: Thêm dữ liệu Workouts mẫu
-- (Đã bao gồm Running, Cycling, Weights, Yoga)

-- Sample 1: Running (Hôm qua - 5.2km trong 30p)
INSERT INTO workouts (user_id, activity_type, started_at, ended_at, duration_min, calories, distance_km, avg_speed_kmh)
VALUES 
('6e2f84d1-e16c-4ab4-bd89-1688aea5a37d', 'running', NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day' + INTERVAL '30 minutes', 30, 320, 5.2, 10.4);

-- Sample 2: Cycling (Sáng nay - 20.5km trong 60p)
INSERT INTO workouts (user_id, activity_type, started_at, ended_at, duration_min, calories, distance_km, avg_speed_kmh)
VALUES 
('6e2f84d1-e16c-4ab4-bd89-1688aea5a37d', 'cycling', NOW() - INTERVAL '4 hours', NOW() - INTERVAL '3 hours', 60, 450, 20.5, 20.5);

-- Sample 3: Weights (2 ngày trước - 45p tập tạ)
INSERT INTO workouts (user_id, activity_type, started_at, ended_at, duration_min, calories)
VALUES 
('6e2f84d1-e16c-4ab4-bd89-1688aea5a37d', 'weights', NOW() - INTERVAL '2 days', NOW() - INTERVAL '2 days' + INTERVAL '45 minutes', 45, 200);

-- Sample 4: Yoga (Vừa tập xong - 20p)
INSERT INTO workouts (user_id, activity_type, started_at, ended_at, duration_min, calories)
VALUES 
('6e2f84d1-e16c-4ab4-bd89-1688aea5a37d', 'yoga', NOW() - INTERVAL '20 minutes', NOW(), 20, 80);


-- Bước 3: Kiểm tra kết quả
SELECT activity_type, duration_min, calories, distance_km, started_at 
FROM workouts 
WHERE user_id = '6e2f84d1-e16c-4ab4-bd89-1688aea5a37d'
ORDER BY started_at DESC;
