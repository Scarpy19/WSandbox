# Compatibility wrapper: canonical script is Install-VC-Redist.ps1.
# Keeps this path working for existing configs/scripts.
param(
    [string]$ExistingInstallerFilesPath,
    [switch]$ForceCachedFilesOnly,
    [switch]$NoCheckLatestVersion
)

$target = Join-Path $PSScriptRoot 'Install-VC-Redist.ps1'
if (-not (Test-Path $target)) {
    Write-Error "Canonical script not found: $target"
    exit 1
}

& $target @PSBoundParameters
exit $LASTEXITCODE
