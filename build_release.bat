@echo off
echo ============================================
echo  Building Release APK with Supabase config
echo ============================================

set SUPABASE_URL=https://xsqptdzselqyefpmdozz.supabase.co
set SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhzcXB0ZHpzZWxxeWVmcG1kb3p6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAyNjU4MjEsImV4cCI6MjA4NTg0MTgyMX0.MfdUQpEDB4m5d7xv4wmjKf52sRmapewG-r1ecW6Hndk

flutter build apk --release ^
  --dart-define=SUPABASE_URL=%SUPABASE_URL% ^
  --dart-define=SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY%

if %ERRORLEVEL% == 0 (
    echo.
    echo [OK] Build thanh cong!
    echo APK: build\app\outputs\flutter-apk\app-release.apk
    echo.
    explorer build\app\outputs\flutter-apk
) else (
    echo.
    echo [FAIL] Build that bai. Xem log phia tren.
)

pause
