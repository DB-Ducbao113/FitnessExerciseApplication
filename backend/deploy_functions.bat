@echo off
echo ==========================================
echo Deploying Supabase Edge Functions
echo ==========================================

echo.
echo Deploying workouts-start...
call supabase functions deploy workouts-start --no-verify-jwt

echo.
echo Deploying workouts-end...
call supabase functions deploy workouts-end --no-verify-jwt

echo.
echo ==========================================
echo Deployment Completed!
echo ==========================================
echo.
echo NOTE: If deployment failed, please ensure you are logged in via 'supabase login'
echo and linked to your project via 'supabase link'.
echo.
pause
