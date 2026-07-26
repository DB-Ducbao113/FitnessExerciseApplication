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
  "database/patches/user_goals.sql",
  "database/patches/profile_avatar.sql",
  "database/patches/workout_lap_splits.sql",
  "database/patches/raw_tracking_tables.sql",
  "database/patches/user_profiles_compatibility.sql",
  "database/patches/workout_processing_jobs.sql",
  "database/patches/workout_processing_logs.sql",
  "database/patches/workout_processing_metadata.sql",
  "database/patches/route_matching.sql",
  "database/patches/workout_moving_time.sql",
  "database/patches/workout_segment_audits.sql"
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
