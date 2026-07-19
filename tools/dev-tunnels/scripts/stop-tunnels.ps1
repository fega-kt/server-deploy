# Stops all background tunnels started by dev-tunnels.ps1.

$baseDir = Split-Path $PSScriptRoot -Parent
$runDir = Join-Path $baseDir "run"

Get-CimInstance Win32_Process -Filter "Name = 'cmd.exe'" |
    Where-Object { $_.CommandLine -like "*$runDir*" } |
    ForEach-Object {
        Write-Host "Stopping cmd PID $($_.ProcessId)"
        Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
    }

Get-CimInstance Win32_Process -Filter "Name = 'cloudflared.exe'" |
    Where-Object { $_.CommandLine -like "*access tcp*" } |
    ForEach-Object {
        Write-Host "Stopping cloudflared PID $($_.ProcessId)"
        Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
    }

Write-Host "Dev tunnels stopped."
