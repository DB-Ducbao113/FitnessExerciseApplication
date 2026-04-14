param(
  [string]$DbUrl = "postgresql://postgres:postgres@127.0.0.1:54322/postgres",
  [switch]$IncludeSeed
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$files = @(
  "database/schema.sql",
  "database/users.sql",
  "database/user_metrics.sql",
  "database/workouts.sql",
  "database/gps_tracks.sql",
  "database/raw_tracking.sql",
  "database/processing.sql",
  "database/views.sql",
  "migrations/20260311_user_goals.sql",
  "migrations/20260311_add_avatar_url.sql",
  "migrations/20260324_add_workout_lap_splits.sql",
  "migrations/20260413_user_profiles_compatibility.sql",
  "migrations/20260413_workout_processing_metadata.sql",
  "migrations/20260413_raw_tracking_tables.sql",
  "migrations/20260413_workout_processing_jobs.sql",
  "migrations/20260413_workout_processing_logs.sql"
)

if ($IncludeSeed) {
  $files += "seed/dev_seed.sql"
}

Write-Host "Applying SQL files to $DbUrl" -ForegroundColor Cyan

foreach ($relativePath in $files) {
  $fullPath = Join-Path $root $relativePath
  if (-not (Test-Path -LiteralPath $fullPath)) {
    throw "Missing SQL file: $fullPath"
  }

  Write-Host "-> $relativePath" -ForegroundColor Yellow
  & psql $DbUrl -v ON_ERROR_STOP=1 -f $fullPath
  if ($LASTEXITCODE -ne 0) {
    throw "psql failed for $relativePath"
  }
}

Write-Host "SQL apply complete." -ForegroundColor Green
