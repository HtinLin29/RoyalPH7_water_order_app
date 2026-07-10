# Deploy Flutter web build to GitHub Pages (gh-pages branch).
# Usage: .\scripts\deploy_gh_pages.ps1

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path $PSScriptRoot -Parent
$BaseHref = "/RoyalPH7_water_order_app/"

Set-Location $RepoRoot

if (-not (Test-Path ".env")) {
    Write-Host "ERROR: .env is missing. Copy .env.example and add your Supabase URL + anon key." -ForegroundColor Red
    exit 1
}

if ((Select-String -Path ".env" -Pattern "your_supabase_project_url" -Quiet)) {
    Write-Host "ERROR: .env still has placeholder values. Add your real Supabase credentials." -ForegroundColor Red
    exit 1
}

Write-Host "Building Flutter web..." -ForegroundColor Cyan
flutter build web --base-href $BaseHref
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$deploy = Join-Path $env:TEMP "royal_ph7_web_final"
$worktree = Join-Path $env:TEMP "royal_ph7_ghpages_wt"

Remove-Item $deploy -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item (Join-Path $RepoRoot "build\web") $deploy -Recurse

if (Test-Path $worktree) {
    git worktree remove $worktree --force
    Remove-Item $worktree -Recurse -Force -ErrorAction SilentlyContinue
}
git worktree add -B gh-pages $worktree origin/gh-pages

Set-Location $worktree
Get-ChildItem -Force | Where-Object { $_.Name -ne ".git" } | Remove-Item -Recurse -Force
Copy-Item "$deploy\*" . -Recurse -Force
New-Item .nojekyll -ItemType File -Force | Out-Null

git add -A
git commit -m "Deploy Flutter web to GitHub Pages"
git push origin gh-pages

Set-Location $RepoRoot
git worktree remove $worktree --force

Write-Host "Deployed: https://htinlin29.github.io$BaseHref" -ForegroundColor Green
