# Creates Royal Ph7 test accounts via Supabase Auth Admin API.
# Prerequisites:
#   1. Run supabase/migrations/002_fix_auth_trigger.sql in Supabase SQL Editor first
#   2. Set SUPABASE_SERVICE_ROLE_KEY environment variable (Dashboard → Settings → API → service_role)

param(
    [string]$ServiceRoleKey = $env:SUPABASE_SERVICE_ROLE_KEY
)

$ProjectUrl = "https://yhsnshragqqllctirgky.supabase.co"

if (-not $ServiceRoleKey) {
    Write-Host "ERROR: Set SUPABASE_SERVICE_ROLE_KEY first." -ForegroundColor Red
    Write-Host '  $env:SUPABASE_SERVICE_ROLE_KEY = "your-service-role-key"'
    exit 1
}

$headers = @{
    "apikey"        = $ServiceRoleKey
    "Authorization" = "Bearer $ServiceRoleKey"
    "Content-Type"  = "application/json"
}

$testUsers = @(
    @{
        email    = "admin@royalph7.com"
        password = "admin1234"
        metadata = @{ role = "admin"; full_name = "Admin User" }
    },
    @{
        email    = "driver@royalph7.com"
        password = "driver1234"
        metadata = @{ role = "driver"; full_name = "Driver One" }
    },
    @{
        email    = "customer@royalph7.com"
        password = "customer1234"
        metadata = @{ role = "customer"; full_name = "Test Customer" }
    }
)

Write-Host "Creating test accounts..." -ForegroundColor Cyan

foreach ($user in $testUsers) {
    $body = @{
        email          = $user.email
        password       = $user.password
        email_confirm  = $true
        user_metadata  = $user.metadata
    } | ConvertTo-Json -Depth 3

    try {
        $response = Invoke-WebRequest `
            -Uri "$ProjectUrl/auth/v1/admin/users" `
            -Method POST `
            -Headers $headers `
            -Body $body `
            -UseBasicParsing

        Write-Host "  OK  $($user.email) (role: $($user.metadata.role))" -ForegroundColor Green
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        $errorBody = $reader.ReadToEnd()

        if ($statusCode -eq 422 -or $errorBody -match "already") {
            Write-Host "  SKIP $($user.email) - already exists" -ForegroundColor Yellow
        }
        else {
            Write-Host "  FAIL $($user.email)" -ForegroundColor Red
            Write-Host "        $errorBody" -ForegroundColor Red
            Write-Host ""
            Write-Host "Did you run 002_fix_auth_trigger.sql in Supabase SQL Editor first?" -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "Verifying profiles..." -ForegroundColor Cyan

try {
    $profiles = Invoke-RestMethod `
        -Uri "$ProjectUrl/rest/v1/profiles?select=full_name,role" `
        -Method GET `
        -Headers $headers

    if ($profiles.Count -eq 0) {
        Write-Host "  No profiles found yet." -ForegroundColor Yellow
    }
    else {
        foreach ($p in $profiles) {
            Write-Host "  Profile: $($p.full_name) ($($p.role))" -ForegroundColor Green
        }
    }
}
catch {
    Write-Host "  Could not fetch profiles: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Test login credentials:" -ForegroundColor Cyan
Write-Host "  admin@royalph7.com    / admin1234    -> Admin Panel"
Write-Host "  driver@royalph7.com   / driver1234   -> Driver Home"
Write-Host "  customer@royalph7.com / customer1234 -> Customer Home"
