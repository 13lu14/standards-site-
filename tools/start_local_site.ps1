$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$python = Join-Path $root ".venv\Scripts\python.exe"

if (-not (Test-Path -LiteralPath $python)) {
    throw "Missing local Python environment: $python"
}

if (Test-Path -LiteralPath "D:\ollama\start_services.ps1") {
    & "D:\ollama\start_services.ps1"
}

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

if (-not (Test-Port 8000)) {
    $runtime = Join-Path $root ".runtime"
    New-Item -ItemType Directory -Path $runtime -Force | Out-Null

    Start-Process -FilePath $python `
        -ArgumentList @("-m", "mkdocs", "serve", "--dev-addr", "127.0.0.1:8000") `
        -WorkingDirectory $root `
        -WindowStyle Hidden `
        -RedirectStandardOutput (Join-Path $runtime "local-site.out.log") `
        -RedirectStandardError (Join-Path $runtime "local-site.err.log")

    for ($i = 0; $i -lt 40; $i++) {
        Start-Sleep -Milliseconds 500
        if (Test-Port 8000) {
            break
        }
    }
}

if (-not (Test-Port 8000)) {
    throw "The local standards site did not start on port 8000."
}

Start-Process "http://127.0.0.1:8000/"
