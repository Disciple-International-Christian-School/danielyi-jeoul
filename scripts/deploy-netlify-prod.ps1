param(
  [switch]$SkipPull
)

$ErrorActionPreference = "Stop"
$SiteId = "df6ae713-42c1-4e56-bb5a-e134553fcb24"

function Step($message) {
  Write-Host ""
  Write-Host "==> $message" -ForegroundColor Cyan
}

Step "Locate repository"
$repoRoot = (git rev-parse --show-toplevel 2>$null)
if (-not $repoRoot) {
  throw "Run this script from inside the danielyi-jeoul Git repository."
}
Set-Location $repoRoot

Step "Protect against deploying local uncommitted changes"
$dirty = git status --porcelain
if ($dirty) {
  Write-Host $dirty
  throw "Working tree is not clean. Commit/stash local changes before production deployment."
}

if (-not $SkipPull) {
  Step "Update main from GitHub"
  git fetch origin
  git checkout main
  git pull --ff-only origin main
}

$branch = (git branch --show-current).Trim()
if ($branch -ne "main") {
  throw "Production deployment is allowed only from main. Current branch: $branch"
}

$localHead = (git rev-parse HEAD).Trim()
$remoteHead = (git rev-parse origin/main).Trim()
if ($localHead -ne $remoteHead) {
  throw "Local main is not identical to origin/main. Local=$localHead Remote=$remoteHead"
}

Write-Host "Deploying main commit: $localHead" -ForegroundColor Green

Step "Ensure Netlify CLI is available"
npx --yes netlify-cli@latest --version

Step "Link this local repository to the existing Netlify project"
npx --yes netlify-cli@latest link --id $SiteId

Step "Build using Netlify production configuration and environment variables"
npx --yes netlify-cli@latest build --context production

if (-not (Test-Path (Join-Path $repoRoot "dist/index.html"))) {
  throw "Build completed but dist/index.html was not found."
}

Step "Deploy dist to production"
npx --yes netlify-cli@latest deploy --prod --dir=dist --site $SiteId --message "Git main $localHead"

Step "Deployment finished"
Write-Host "Site: https://dics-daniels-scale.netlify.app" -ForegroundColor Green
Write-Host "Commit: $localHead" -ForegroundColor Green
