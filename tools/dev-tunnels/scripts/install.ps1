# One-time setup: registers the ZhizhuDevTunnels scheduled task (auto-start
# at logon) and starts the tunnels immediately. Safe to re-run.

$ErrorActionPreference = "Stop"

if (-not (Get-Command cloudflared -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: cloudflared chua duoc cai. Tai tai https://developers.cloudflare.com/cloudflared/" -ForegroundColor Red
    exit 1
}

$scriptPath = Join-Path $PSScriptRoot "dev-tunnels.ps1"

$action   = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""
$trigger  = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit ([TimeSpan]::Zero)

Register-ScheduledTask -TaskName "ZhizhuDevTunnels" -Action $action -Trigger $trigger -Settings $settings `
    -Description "Cloudflare Access TCP tunnels for redis/rabbitmq local dev" -Force | Out-Null

Write-Host "Da dang ky task 'ZhizhuDevTunnels' (tu chay luc login)." -ForegroundColor Green

& $scriptPath

Write-Host ""
Write-Host "Xong. Tu gio chi can bat may/login la co san tunnel, khong can chay lai script nay nua." -ForegroundColor Green
