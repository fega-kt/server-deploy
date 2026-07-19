# Keeps Cloudflare Access TCP tunnels alive for local dev access to internal
# services (redis, rabbitmq) that are only bound to 127.0.0.1 on the server.
#
# Each tunnel runs as an independent hidden background process (a small .cmd
# loop) that survives this script exiting, and auto-restarts cloudflared if
# the connection drops. Safe to re-run: previous tunnels are stopped first.

$ErrorActionPreference = "Stop"

$cloudflaredPath = (Get-Command cloudflared -ErrorAction Stop).Source

$tunnels = @(
    @{ Name = "redis";    Hostname = "redis.zhizhu.online";         LocalPort = 6379 },
    @{ Name = "rabbitmq"; Hostname = "rabbitmq-amqp.zhizhu.online"; LocalPort = 5672 }
)

$baseDir = Split-Path $PSScriptRoot -Parent
$runDir = Join-Path $baseDir "run"
$logDir = Join-Path $baseDir "logs"
New-Item -ItemType Directory -Force -Path $runDir | Out-Null
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

& (Join-Path $PSScriptRoot "stop-tunnels.ps1") | Out-Null

foreach ($t in $tunnels) {
    $logFile = Join-Path $logDir "$($t.Name).log"
    $cmdFile = Join-Path $runDir "tunnel-$($t.Name).cmd"

    @"
:loop
"$cloudflaredPath" access tcp --hostname $($t.Hostname) --url localhost:$($t.LocalPort) >> "$logFile" 2>&1
timeout /t 5 /nobreak >nul
goto loop
"@ | Set-Content -Path $cmdFile -Encoding ASCII

    Start-Process -WindowStyle Hidden -FilePath $cmdFile
    Write-Host "Started tunnel '$($t.Name)': localhost:$($t.LocalPort) -> $($t.Hostname)"
}

Write-Host "Logs: $logDir"
