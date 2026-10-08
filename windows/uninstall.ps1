<#
.SYNOPSIS
Removes the "ComfyUI keep awake" scheduled task and %ProgramData%\comfyui-keepawake. Run in an admin PowerShell window.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$TaskName = "ComfyUI keep awake"
$InstallDir = Join-Path $env:ProgramData "comfyui-keepawake"

$identity = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $identity.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Run this in an admin PowerShell window (right-click PowerShell > Run as administrator)."
}

if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    # Stopping the script ends its keep-awake request.
    Stop-ScheduledTask -TaskName $TaskName
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "Removed the '$TaskName' scheduled task."
} else {
    Write-Host "No '$TaskName' scheduled task to remove."
}

if (Test-Path $InstallDir) {
    Remove-Item $InstallDir -Recurse -Force
    Write-Host "Removed $InstallDir."
}
