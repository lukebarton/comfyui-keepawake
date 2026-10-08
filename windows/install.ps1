<#
.SYNOPSIS
Installs keepawake.ps1 and registers the scheduled task that runs it. Run in an admin PowerShell window.

.DESCRIPTION
Copies keepawake.ps1 to %ProgramData%\comfyui-keepawake, then registers the "ComfyUI keep awake"
task to run it as SYSTEM at boot, at logon and on resume from sleep, and starts it.
Run it again to change the settings; it replaces the existing task.

Run from a clone, it copies the keepawake.ps1 next to it. Run from a URL (see the README), it
downloads keepawake.ps1 from the same git tag, given by -Ref.
#>
param(
    [string]$ComfyUrl = "http://localhost:8188",
    [int]$IdleMinutes = 30,
    [int]$CheckIntervalSeconds = 60,
    # Git tag or branch to download keepawake.ps1 from, when not run from a clone.
    [string]$Ref = "main"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$TaskName = "ComfyUI keep awake"
$InstallDir = Join-Path $env:ProgramData "comfyui-keepawake"
$ScriptPath = Join-Path $InstallDir "keepawake.ps1"

$identity = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $identity.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    # throw rather than exit: when run from a URL, exit would close the PowerShell window.
    throw "Run this in an admin PowerShell window (right-click PowerShell > Run as administrator)."
}

New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
$localCopy = if ($PSScriptRoot) { Join-Path $PSScriptRoot "keepawake.ps1" }
if ($localCopy -and (Test-Path $localCopy)) {
    Copy-Item $localCopy $ScriptPath -Force
    Write-Host "Copied $localCopy to $ScriptPath"
} else {
    $url = "https://raw.githubusercontent.com/lukebarton/comfyui-keepawake/$Ref/windows/keepawake.ps1"
    Invoke-WebRequest -Uri $url -OutFile $ScriptPath -UseBasicParsing
    Write-Host "Downloaded $url to $ScriptPath"
}

$arguments = @(
    "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden",
    "-File", "`"$ScriptPath`"",
    "-ComfyUrl", "`"$ComfyUrl`"",
    "-IdleMinutes", $IdleMinutes,
    "-CheckIntervalSeconds", $CheckIntervalSeconds
) -join " "
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $arguments

# Windows logs event 1 from Power-Troubleshooter each time it resumes from sleep.
$resumeTrigger = Get-CimClass -ClassName MSFT_TaskEventTrigger -Namespace Root/Microsoft/Windows/TaskScheduler |
    New-CimInstance -ClientOnly
$resumeTrigger.Enabled = $true
$resumeTrigger.Subscription = @'
<QueryList><Query Id="0" Path="System"><Select Path="System">*[System[Provider[@Name='Microsoft-Windows-Power-Troubleshooter'] and EventID=1]]</Select></Query></QueryList>
'@
$triggers = @(
    (New-ScheduledTaskTrigger -AtStartup),
    (New-ScheduledTaskTrigger -AtLogOn),
    $resumeTrigger
)

# SYSTEM, so it runs at boot before anyone logs on.
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit ([timespan]::Zero) -StartWhenAvailable
# Each trigger restarts the script, so it counts the idle period from the latest boot, logon or
# resume. The cmdlet has no option for "stop the existing instance"; 3 is its value in the task schema.
$settings.CimInstanceProperties.Item("MultipleInstances").Value = 3

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $triggers -Principal $principal `
    -Settings $settings -Description "Keeps the PC awake while ComfyUI is in use. https://github.com/lukebarton/comfyui-keepawake" `
    -Force | Out-Null
Start-ScheduledTask -TaskName $TaskName

Write-Host "Registered and started the '$TaskName' scheduled task."
Write-Host "Log: $(Join-Path $InstallDir 'keepawake.log')"
Write-Host "Check it's holding the PC awake with: powercfg /requests"
