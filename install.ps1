$ErrorActionPreference = "Stop"

function Write-LogInfo($msg) {
    Write-Host "[INFO] $msg" -ForegroundColor Cyan
}

function Write-LogSuccess($msg) {
    Write-Host "[SUCCESS] $msg" -ForegroundColor Green
}

function Write-LogError($msg) {
    Write-Host "[ERROR] $msg" -ForegroundColor Red
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-LogError "git is required but not found in PATH."
    exit 1
}

$toolsDir = if ($env:TOOLS_DIR) { $env:TOOLS_DIR } else { Join-Path $HOME "Tools" }
$scriptDir = $PSScriptRoot

if (-not (Test-Path $toolsDir)) {
    New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null
}

function Clone-Or-Pull($name, $url) {
    $dest = Join-Path $toolsDir $name
    if (Test-Path (Join-Path $dest ".git")) {
        Write-LogInfo "Updating repository $name..."
        git -C $dest pull
    } else {
        Write-LogInfo "Cloning $name from $url..."
        git clone $url $dest
    }
}

Write-LogInfo "Phase 1: Synchronizing repositories into $toolsDir..."
$repos = @(
    @("anti-slop", "https://github.com/miqdadbadjuber/anti-slop.git"),
    @("ponytail", "https://github.com/DietrichGebert/ponytail.git"),
    @("graphify", "https://github.com/Graphify-Labs/graphify.git"),
    @("rtk", "https://github.com/rtk-ai/rtk.git"),
    @("codegraph", "https://github.com/colbymchenry/codegraph.git"),
    @("context7", "https://github.com/upstash/context7.git"),
    @("Understand-Anything", "https://github.com/Egonex-AI/Understand-Anything.git"),
    @("caveman", "https://github.com/JuliusBrussee/caveman.git")
)

foreach ($item in $repos) {
    Clone-Or-Pull $item[0] $item[1]
}

Write-LogSuccess "All repositories synchronized into $toolsDir."

Write-LogInfo "Phase 2: Executing configuration script..."
$configFile = Join-Path $scriptDir "config.ps1"
if (Test-Path $configFile) {
    & $configFile
} else {
    Write-LogError "config.ps1 not found in $scriptDir."
    exit 1
}

Write-LogSuccess "Installation and configuration completed successfully."
