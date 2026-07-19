# Removes the ZhizhuDevTunnels scheduled task and stops any running tunnels.
# Does not uninstall cloudflared itself, only this dev-tunnels setup.

$ErrorActionPreference = "Stop"

& (Join-Path $PSScriptRoot "stop-tunnels.ps1")

$task = Get-ScheduledTask -TaskName "ZhizhuDevTunnels" -ErrorAction SilentlyContinue
if ($task) {
    Unregister-ScheduledTask -TaskName "ZhizhuDevTunnels" -Confirm:$false
    Write-Host "Da go task 'ZhizhuDevTunnels'." -ForegroundColor Green
} else {
    Write-Host "Task 'ZhizhuDevTunnels' khong ton tai, bo qua." -ForegroundColor Yellow
}

$baseDir = Split-Path $PSScriptRoot -Parent
$runDir = Join-Path $baseDir "run"
$logDir = Join-Path $baseDir "logs"
Remove-Item $runDir -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $logDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "Da go dev tunnels hoan toan." -ForegroundColor Green
