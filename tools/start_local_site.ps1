# One-click starter for the local standards site with the Dify assistant.
# Startup order: Docker Desktop -> local Dify -> embeddings -> MkDocs.

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$python = Join-Path $root ".venv\Scripts\python.exe"
$runtime = Join-Path $root ".runtime"

if (-not (Test-Path -LiteralPath $python)) {
    throw "Missing local Python environment: $python"
}

New-Item -ItemType Directory -Path $runtime -Force | Out-Null

function Test-Port([int]$Port) {
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $task = $client.ConnectAsync("127.0.0.1", $Port)
        $ok = $task.Wait(1000) -and $client.Connected
        $client.Close()
        return $ok
    }
    catch {
        return $false
    }
}

function Test-Http([string]$Url) {
    try {
        $null = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5
        return $true
    }
    catch {
        # Any HTTP answer (404, 502, ...) still proves something is listening.
        if ($_.Exception.Response) {
            return $true
        }
        return $false
    }
}

function Wait-Until {
    param(
        [scriptblock]$Probe,
        [int]$TimeoutSeconds,
        [string]$Message
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if (& $Probe) {
            return $true
        }
        Write-Host $Message
        Start-Sleep -Seconds 5
    }
    return (& $Probe)
}

function Get-DockerExe {
    $command = Get-Command docker -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }
    $fallback = "C:\Program Files\Docker\Docker\resources\bin\docker.exe"
    if (Test-Path -LiteralPath $fallback) {
        return $fallback
    }
    return $null
}

$difyUrl = "http://localhost/"
$dockerExe = Get-DockerExe

if ($dockerExe) {
    $engineRunning = $false
    try {
        $null = & $dockerExe info --format "{{.ServerVersion}}" 2>$null
        $engineRunning = ($LASTEXITCODE -eq 0)
    }
    catch {
        $engineRunning = $false
    }

    if (-not $engineRunning) {
        $desktop = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
        if (Test-Path -LiteralPath $desktop) {
            Write-Host "Starting Docker Desktop ..."
            Start-Process -FilePath $desktop -ArgumentList "-Autostart" -WindowStyle Hidden
        }
    }

    if (-not (Test-Http $difyUrl)) {
        Write-Host "Waiting for the local Dify stack (first start takes a minute or two) ..."
        if (-not (Wait-Until -Probe { Test-Http $difyUrl } -TimeoutSeconds 300 -Message "  Dify is not ready yet, still waiting ...")) {
            Write-Host "Warning: local Dify did not become ready, the chat bubble may fail to answer."
        }
    }
}
else {
    Write-Host "Warning: docker command not found, skipping the local Dify check."
}

if (Test-Path -LiteralPath "D:\ollama\start_services.ps1") {
    & "D:\ollama\start_services.ps1"
}

$siteUrl = "http://127.0.0.1:8000/"

if (-not (Test-Http $siteUrl)) {
    Start-Process -FilePath $python `
        -ArgumentList @("-m", "mkdocs", "serve", "--dev-addr", "127.0.0.1:8000") `
        -WorkingDirectory $root `
        -WindowStyle Hidden `
        -RedirectStandardOutput (Join-Path $runtime "local-site.out.log") `
        -RedirectStandardError (Join-Path $runtime "local-site.err.log")

    Write-Host "Building the local site (first build takes two to three minutes) ..."
    if (-not (Wait-Until -Probe { Test-Http $siteUrl } -TimeoutSeconds 600 -Message "  still building, please wait ...")) {
        throw "The local site did not start, see $runtime\local-site.err.log"
    }
}
else {
    Write-Host "The local site is already running."
}

Write-Host "Ready, opening the browser ..."
Start-Process $siteUrl
Start-Sleep -Seconds 2
