# Royal Ph7 — One-command Supabase setup
# Fixes auth trigger + creates all 3 test accounts
#
# Usage:
#   $env:SUPABASE_SERVICE_ROLE_KEY = "your-service-role-key"
#   .\scripts\setup_all.ps1 -DbPassword "your-database-password"
#
# Get database password from:
#   Supabase Dashboard → Project Settings → Database → Database password
#   (Click "Reset database password" if you don't know it)

param(
    [Parameter(Mandatory = $true)]
    [string]$DbPassword,

    [string]$ServiceRoleKey = $env:SUPABASE_SERVICE_ROLE_KEY
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$ProjectRef = "yhsnshragqqllctirgky"

Write-Host ""
Write-Host "=== Royal Ph7 Supabase Setup ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Apply SQL fix via direct Postgres connection
Write-Host "[1/2] Applying database fix..." -ForegroundColor Yellow

$encodedPassword = [uri]::EscapeDataString($DbPassword)
$DbUrl = "postgresql://postgres:${encodedPassword}@db.${ProjectRef}.supabase.co:5432/postgres"

Push-Location $ProjectRoot
try {
    npx supabase db query `
        --file "supabase/migrations/002_fix_auth_trigger.sql" `
        --db-url $DbUrl

    if ($LASTEXITCODE -ne 0) {
        throw "SQL fix failed. Check your database password."
    }

    Write-Host "  Database fix applied successfully." -ForegroundColor Green
}
finally {
    Pop-Location
}

# Step 2: Create test users
Write-Host ""
Write-Host "[2/2] Creating test accounts..." -ForegroundColor Yellow

if (-not $ServiceRoleKey) {
    Write-Host "  WARNING: SUPABASE_SERVICE_ROLE_KEY not set. Skipping user creation." -ForegroundColor Yellow
    Write-Host '  Run: $env:SUPABASE_SERVICE_ROLE_KEY = "your-key"; .\scripts\create_test_users.ps1'
    exit 0
}

& "$PSScriptRoot\create_test_users.ps1" -ServiceRoleKey $ServiceRoleKey

Write-Host ""
Write-Host "=== Setup Complete ===" -ForegroundColor Green
Write-Host "Hot restart your Flutter app (press R) and login with:"
Write-Host "  customer@royalph7.com / customer1234"
Write-Host "  driver@royalph7.com   / driver1234"
Write-Host "  admin@royalph7.com    / admin1234"
