
<div align="center">

# Aetron

### A modern fitness tracking app built with Flutter

Track workouts, monitor progress, set goals, and keep your fitness journey organized in one clean mobile experience.

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-Backend-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)
![Riverpod](https://img.shields.io/badge/Riverpod-State%20Management-0E7490?style=for-the-badge)

</div>

## Overview

Aetron is a Flutter fitness application designed to help users build consistent workout habits. The app combines workout tracking, personal goals, history, and analytics into a single product-focused experience.

It supports both indoor and outdoor activities, uses local persistence for a smoother offline experience, and syncs important user data through Supabase.

## What The App Does

- Lets users register and sign in with Supabase Authentication
- Supports personal profile setup and avatar management
- Tracks workout sessions with live metrics
- Records outdoor activity with GPS-based location tracking
- Tracks step-based movement for supported workout flows
- Stores workout history for later review
- Visualizes progress through analytics and summary screens
- Helps users stay consistent with goal tracking

## Experience Highlights

- Clean fitness-first mobile interface
- Feature-first Flutter architecture for easier scaling
- Offline-capable local storage for smoother day-to-day usage
- Remote sync with Supabase for account and workout data
- Modular state management powered by Riverpod

## Tech Stack

- `Flutter` for cross-platform application development
- `Riverpod` and `riverpod_generator` for state management
- `Supabase` for auth, backend data, storage, and server integration
- `Isar` for workout persistence
- `sqflite` for local profile-related persistence
- `Freezed` and `json_serializable` for immutable models and code generation
- `Geolocator`, `flutter_map`, and `pedometer` for tracking features
- `fl_chart` and `table_calendar` for analytics and history UI

## Project Structure

```text
lib/
  app/        App bootstrap and app-level wiring
  core/       Shared services, providers, constants, storage, and utilities
  features/   Feature modules organized by domain/data/presentation
  shared/     Reusable helpers and formatters
```

More architecture notes are available in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Backend Structure

```text
backend/
  database/   SQL reference files
  migrations/ Database migrations
  seed/       Seed data
  supabase/   Supabase functions and related configuration
```

Current Supabase Edge Functions:

- `workouts-start`
- `workouts-end`
- `gps-track`
- `deterministic-finalize-worker`
- `route-correction-worker`

## Core Workflow (Tổng quan luồng sản phẩm)

Aetron được thiết kế xoay quanh việc ghi nhận và xử lý workout như một đường ống dữ liệu rõ ràng.

### 1) Tạo session workout (client)
- App tạo một workout “shell” ở backend.
- Trạng thái xử lý ban đầu cho biết workout đang ở giai đoạn client recording.

### 2) Ghi nhận dữ liệu realtime (client)
- GPS: thu thập điểm GPS theo thời gian thực.
- Step tracking: ghi nhận chuyển động/nhịp bước phù hợp với luồng workout.
- Dữ liệu realtime được lưu thành raw samples để dùng cho việc tính toán canonical sau này.

### 3) Kết thúc workout (client)
- App kết thúc session và gửi snapshot tạm thời của các chỉ số.
- Đồng thời backend được enqueue để tính toán deterministic canonical metrics.

### 4) Xử lý deterministic & đối soát chất lượng (backend)
- Backend đọc raw tracking, recompute metrics dựa trên các segment hợp lệ.
- Hệ thống ghi nhận bằng chứng kiểm định (audit/quality) ở cấp segment.
- Kết quả sẽ cập nhật trạng thái xử lý để UI có thể hiển thị “provisional” vs “finalized”.

### 5) Hiển thị lịch sử (client)
- UI ưu tiên đọc canonical từ các bảng workout sessions.
- `processing_status` giúp phân biệt workout đang xử lý/chưa finalize.

Mô tả API-contract hiện có: [docs/api/api_contract.md](docs/api/api_contract.md)

## Architecture at a Glance

### Feature-first + core/shared
- `lib/features/`: mỗi feature sở hữu domain/data/presentation.
- `lib/core/`: hạ tầng dùng chung (provider, constants, platform services, storage helpers, utils… không thuộc riêng một feature).
- `lib/shared/`: phần UI/formatting tái sử dụng giữa các feature.

Tham khảo chi tiết: [docs/architecture/ARCHITECTURE.md](docs/architecture/ARCHITECTURE.md)

### MVVM cho luồng Workout Recording
Luồng recording hiện tại là ví dụ rõ nhất của cách tách View / ViewModel / controllers / domain services.

- `View`: render UI, gửi intent (start/pause/resume/stop) đến ViewModel.
- `ViewModel`: quản lý `WorkoutSessionState`, nhận callback từ sensor/classifier, điều phối các helper.
- Controllers: quản lý lifecycle GPS/step và environment classifier.
- Domain service: quyết định luật lọc/đánh giá cập nhật GPS/step theo engine.
- Coordinator: điều phối buffer raw data, upload và enqueue processing job.

Tham khảo: [docs/architecture/MVVM_WORKOUT_RECORDING.md](docs/architecture/MVVM_WORKOUT_RECORDING.md)

## Repository Goal

This repository is not just a Flutter codebase. It is the foundation of a fitness product focused on helping users:

- move consistently
- understand workout progress
- stay motivated through goals and history
- keep their data available across sessions

## Status

The project is actively evolving, with continued work around workout flow, tracking reliability, local persistence, and overall product polish.
