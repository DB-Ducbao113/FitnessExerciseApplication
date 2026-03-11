@echo off
echo ============================================
echo  Building Release APK with Supabase config
echo ============================================

set SUPABASE_URL=YOUR_SUPABASE_URL
set SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY

flutter build apk --release ^
  --dart-define=SUPABASE_URL=%SUPABASE_URL% ^
  --dart-define=SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY%

if %ERRORLEVEL% == 0 (
    echo.
    echo [OK] Build success!
    echo APK: build\app\outputs\flutter-apk\app-release.apk
    echo.
    explorer build\app\outputs\flutter-apk
) else (
    echo.
    echo [FAIL] Build failed. Check log above.
)

pause
