# S1 Client — Pre-commit hook installer
#
# Copies the pre-commit hook script into .git/hooks/ so that
# `dart format`, `flutter analyze`, `flutter test`, and M3 audit
# run automatically before every `git commit`.
#
# Usage:
#   .\scripts\install_precommit.ps1
#
# To uninstall, delete .git/hooks/pre-commit.

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$hookSource = Join-Path (Join-Path $repoRoot "scripts") "pre-commit-hook.sh"
$gitDir = Join-Path $repoRoot ".git"
$hooksDir = Join-Path $gitDir "hooks"
$hookDest = Join-Path $hooksDir "pre-commit"

if (-not (Test-Path $hookSource)) {
    Write-Error "Hook source not found: $hookSource"
    exit 1
}

if (-not (Test-Path $gitDir)) {
    Write-Error "No .git directory found. Are you in the repo root?"
    exit 1
}

# Ensure hooks directory exists
if (-not (Test-Path $hooksDir)) {
    New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null
}

Copy-Item -Path $hookSource -Destination $hookDest -Force
Write-Host "Pre-commit hook installed at: $hookDest"
Write-Host ""
Write-Host "Now every 'git commit' will automatically run:"
Write-Host "  1. dart format (code style check)"
Write-Host "  2. flutter analyze (static analysis)"
Write-Host "  3. flutter test (unit tests)"
Write-Host "  4. dart run scripts/audit_m3.dart (M3 compliance)"
Write-Host ""
Write-Host "If any check fails, the commit is rejected."
Write-Host "To bypass temporarily, use:  git commit --no-verify"
