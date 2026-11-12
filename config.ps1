$ErrorActionPreference = "Stop"

function Write-LogInfo($msg) {
    Write-Host "[INFO] $msg" -ForegroundColor Cyan
}

function Write-LogSuccess($msg) {
    Write-Host "[SUCCESS] $msg" -ForegroundColor Green
}

function Write-LogWarn($msg) {
    Write-Host "[WARN] $msg" -ForegroundColor Yellow
}

function Write-LogError($msg) {
    Write-Host "[ERROR] $msg" -ForegroundColor Red
}

$toolsDir = if ($env:TOOLS_DIR) { $env:TOOLS_DIR } else { Join-Path $HOME "Tools" }
$geminiDir = if ($env:GEMINI_DIR) { $env:GEMINI_DIR } else { Join-Path $HOME ".gemini" }
$antigravitySkillsDir = Join-Path $geminiDir "antigravity-cli\skills"
$configSkillsDir = Join-Path $geminiDir "config\skills"
$configDir = Join-Path $geminiDir "config"
$localBinDir = Join-Path $HOME ".local\bin"
$scriptDir = $PSScriptRoot

$dirsToCreate = @($toolsDir, $antigravitySkillsDir, $configSkillsDir, $configDir, $localBinDir)
foreach ($d in $dirsToCreate) {
    if (-not (Test-Path $d)) {
        New-Item -ItemType Directory -Path $d -Force | Out-Null
    }
}

function Safe-Link-Or-Copy($sourcePath, $targetPath) {
    if (Test-Path $targetPath) {
        Remove-Item -Path $targetPath -Recurse -Force
    }
    try {
        New-Item -ItemType SymbolicLink -Path $targetPath -Target $sourcePath -ErrorAction Stop | Out-Null
        Write-LogInfo "Linked $(Split-Path $targetPath -Leaf)"
    } catch {
        Copy-Item -Path $sourcePath -Destination $targetPath -Recurse -Force
        Write-LogInfo "Copied $(Split-Path $targetPath -Leaf) (Windows symlink fallback)"
    }
}

Write-LogInfo "Task 1: Setting up PATH environment variable..."
$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ([string]::IsNullOrEmpty($userPath)) {
    [Environment]::SetEnvironmentVariable("PATH", $localBinDir, "User")
    $env:PATH = "$localBinDir;$env:PATH"
    Write-LogSuccess "Added $localBinDir to User PATH."
} elseif ($userPath -notlike "*$localBinDir*") {
    [Environment]::SetEnvironmentVariable("PATH", "$localBinDir;$userPath", "User")
    $env:PATH = "$localBinDir;$env:PATH"
    Write-LogSuccess "Added $localBinDir to User PATH."
}

Write-LogInfo "Task 2: Linking Anti-Slop skills..."
$antiSlopSkills = Join-Path $toolsDir "anti-slop\skills"
if (Test-Path $antiSlopSkills) {
    Get-ChildItem -Path $antiSlopSkills -Directory | ForEach-Object {
        Safe-Link-Or-Copy $_.FullName (Join-Path $configSkillsDir $_.Name)
        Safe-Link-Or-Copy $_.FullName (Join-Path $antigravitySkillsDir $_.Name)
    }
    Write-LogSuccess "Anti-slop skills configured."
} else {
    Write-LogWarn "anti-slop repository not found at $antiSlopSkills"
}

Write-LogInfo "Task 3: Linking Ponytail skills..."
$ponytailSkills = Join-Path $toolsDir "ponytail\skills"
if (Test-Path $ponytailSkills) {
    Get-ChildItem -Path $ponytailSkills -Directory | ForEach-Object {
        Safe-Link-Or-Copy $_.FullName (Join-Path $configSkillsDir $_.Name)
        Safe-Link-Or-Copy $_.FullName (Join-Path $antigravitySkillsDir $_.Name)
    }
    Write-LogSuccess "Ponytail skills configured."
} else {
    Write-LogWarn "ponytail repository not found at $ponytailSkills"
}

Write-LogInfo "Task 4: Linking Caveman skills..."
$cavemanSkills = Join-Path $toolsDir "caveman\skills"
if (Test-Path $cavemanSkills) {
    Get-ChildItem -Path $cavemanSkills -Directory | ForEach-Object {
        Safe-Link-Or-Copy $_.FullName (Join-Path $configSkillsDir $_.Name)
        Safe-Link-Or-Copy $_.FullName (Join-Path $antigravitySkillsDir $_.Name)
    }
    Write-LogSuccess "Caveman skills configured."
} else {
    Write-LogWarn "caveman repository not found at $cavemanSkills"
}

Write-LogInfo "Task 5: Setting up rtk binary for Windows..."
$rtkExe = Join-Path $localBinDir "rtk.exe"
if (-not (Get-Command rtk -ErrorAction SilentlyContinue) -and -not (Test-Path $rtkExe)) {
    $rtkVersion = "v1.2.0"
    $rtkUrl = "https://github.com/rtk-ai/rtk/releases/download/$rtkVersion/rtk-x86_64-pc-windows-msvc.zip"
    $tmpZip = Join-Path $env:TEMP "rtk.zip"
    $tmpExtract = Join-Path $env:TEMP "rtk_extracted"

    Write-LogInfo "Downloading rtk for Windows from $rtkUrl..."
    try {
        Invoke-WebRequest -Uri $rtkUrl -OutFile $tmpZip -UseBasicParsing
        Expand-Archive -Path $tmpZip -DestinationPath $tmpExtract -Force
        $foundExe = Get-ChildItem -Path $tmpExtract -Filter "rtk.exe" -Recurse | Select-Object -First 1
        if ($foundExe) {
            Copy-Item -Path $foundExe.FullName -Destination $rtkExe -Force
            Write-LogSuccess "rtk binary installed to $rtkExe"
        }
        Remove-Item -Path $tmpZip -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $tmpExtract -Recurse -Force -ErrorAction SilentlyContinue
    } catch {
        Write-LogWarn "Failed to download rtk automatically: $_"
    }
} else {
    Write-LogSuccess "rtk binary is available."
}

Write-LogInfo "Task 6: Setting up codegraph for Windows..."
if (-not (Get-Command codegraph -ErrorAction SilentlyContinue)) {
    $codegraphInstaller = Join-Path $toolsDir "codegraph\install.ps1"
    if (Test-Path $codegraphInstaller) {
        Write-LogInfo "Running codegraph Windows installer..."
        try {
            & $codegraphInstaller
            Write-LogSuccess "Codegraph installed successfully."
        } catch {
            Write-LogWarn "Could not run codegraph installer: $_"
        }
    }
}

Write-LogInfo "Task 7: Configuring mcp_config.json..."
$mcpFile = Join-Path $configDir "mcp_config.json"
$dashTwo = [char]45 + [char]45
$mcpFlag = $dashTwo + "mcp"
$contrastLauncher = (Join-Path $toolsDir "anti-slop\.claude-plugin\contrast-mcp-launcher.mjs").Replace("\", "/")

if (-not (Test-Path $mcpFile)) {
    $mcpContent = @"
{
  "mcpServers": {
    "graphify": {
      "command": "graphify-mcp",
      "args": [
        "`${workspace.path}/graphify-out/graph.json"
      ]
    },
    "codegraph": {
      "command": "codegraph",
      "args": [
        "serve",
        "$mcpFlag"
      ]
    },
    "context7": {
      "command": "npx",
      "args": [
        "-y",
        "@upstash/context7-mcp"
      ]
    },
    "antislop-contrast": {
      "command": "node",
      "args": [
        "$contrastLauncher"
      ]
    }
  }
}
"@
    Set-Content -Path $mcpFile -Value $mcpContent -Encoding UTF8
    Write-LogSuccess "Created $mcpFile"
} else {
    Write-LogInfo "$mcpFile already exists."
}

Write-LogInfo "Task 8: Syncing global agent guidelines (GEMINI.md)..."
$geminiTarget = Join-Path $geminiDir "GEMINI.md"
$geminiSource = Join-Path $scriptDir "GEMINI.md"
if (-not (Test-Path $geminiTarget) -and (Test-Path $geminiSource)) {
    Copy-Item -Path $geminiSource -Destination $geminiTarget -Force
    Write-LogSuccess "Copied GEMINI.md to $geminiTarget"
}

Write-LogSuccess "Windows configuration completed successfully."
Write-LogInfo "Tips: Tutup dan buka kembali terminal PowerShell Anda agar session baru membaca PATH terbaru."
