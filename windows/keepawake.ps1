<#
.SYNOPSIS
Keeps this PC awake while ComfyUI is in use, and lets Windows' sleep timer take over otherwise.

.DESCRIPTION
Checks every CheckIntervalSeconds and holds the PC awake while any of these is true:
  1. a ComfyUI job is running or queued;
  2. someone used the ComfyUI page in the last IdleMinutes;
  3. the PC started or resumed less than IdleMinutes ago, so a Wake-on-LAN wake doesn't
     fall straight back asleep before anyone starts working.
If ComfyUI can't be reached, only condition 3 can hold.

Holding the PC awake is a SetThreadExecutionState(ES_CONTINUOUS | ES_SYSTEM_REQUIRED) request,
which `powercfg /requests` lists under SYSTEM. install.ps1 registers a scheduled task that runs
this script at boot, at logon and on resume from sleep.
#>
param(
    [string]$ComfyUrl = "http://localhost:8188",
    [int]$IdleMinutes = 30,
    [int]$CheckIntervalSeconds = 60,
    [string]$LogPath = (Join-Path $env:ProgramData "comfyui-keepawake\keepawake.log")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Returns the parsed /keepawake/status response, or $null if ComfyUI can't be reached.
function Get-ComfyStatus {
    param([string]$Url)
    try {
        Invoke-RestMethod -Uri "$($Url.TrimEnd('/'))/keepawake/status" -TimeoutSec 5 -UseBasicParsing
    } catch {
        $null
    }
}

# Returns why the PC should stay awake, or $null if it may sleep. Does no I/O, so the tests can call it.
# The ping age is measured on ComfyUI's clock (server_time - last_ping), so it doesn't matter if
# the container's clock differs from Windows'.
function Get-KeepAwakeReason {
    param(
        $Status,
        [datetime]$Now,
        [datetime]$AwakeSince,
        [timespan]$IdlePeriod
    )
    if ($null -ne $Status) {
        if ($Status.busy) {
            return "a ComfyUI job is running or queued"
        }
        if ($null -ne $Status.last_ping -and
            [timespan]::FromSeconds($Status.server_time - $Status.last_ping) -lt $IdlePeriod) {
            return "ComfyUI was used in the last $($IdlePeriod.TotalMinutes) minutes"
        }
    }
    if ($Now - $AwakeSince -lt $IdlePeriod) {
        return "the PC started or resumed less than $($IdlePeriod.TotalMinutes) minutes ago"
    }
    $null
}

function Write-Log {
    param([string]$Message)
    $dir = Split-Path $LogPath
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    # Keep the log small: start a new one past 1 MB, keeping the previous one.
    if ((Test-Path $LogPath) -and (Get-Item $LogPath).Length -gt 1MB) {
        Move-Item $LogPath "$LogPath.old" -Force
    }
    Add-Content -Path $LogPath -Value "$(Get-Date -Format s) $Message"
}

function Start-KeepAwake {
    Add-Type -Namespace KeepAwake -Name Native -MemberDefinition @'
[DllImport("kernel32.dll")]
public static extern uint SetThreadExecutionState(uint esFlags);
'@
    $ES_CONTINUOUS = [uint32]2147483648 # 0x80000000
    $ES_SYSTEM_REQUIRED = [uint32]1
    $holdAwake = [uint32]($ES_CONTINUOUS -bor $ES_SYSTEM_REQUIRED)

    $idlePeriod = [timespan]::FromMinutes($IdleMinutes)
    $awakeSince = Get-Date
    $lastCheck = $awakeSince
    $holding = $null
    $reachable = $null
    Write-Log "started: ComfyUrl=$ComfyUrl IdleMinutes=$IdleMinutes CheckIntervalSeconds=$CheckIntervalSeconds"

    while ($true) {
        $now = Get-Date
        # The task restarts this script on resume, but if that trigger is missed, a gap much longer
        # than the check interval also means the PC slept and has just resumed.
        if (($now - $lastCheck).TotalSeconds -gt $CheckIntervalSeconds + 60) {
            $awakeSince = $now
            Write-Log "resumed from sleep"
        }
        $lastCheck = $now

        $status = Get-ComfyStatus -Url $ComfyUrl
        if (($null -ne $status) -ne $reachable) {
            $reachable = $null -ne $status
            Write-Log $(if ($reachable) { "ComfyUI is reachable" } else { "ComfyUI is not reachable at $ComfyUrl" })
        }

        $reason = Get-KeepAwakeReason -Status $status -Now $now -AwakeSince $awakeSince -IdlePeriod $idlePeriod
        # ES_CONTINUOUS on its own clears the request and hands control back to the sleep timer.
        $flags = if ($reason) { $holdAwake } else { $ES_CONTINUOUS }
        if ([KeepAwake.Native]::SetThreadExecutionState($flags) -eq 0) {
            Write-Log "SetThreadExecutionState failed"
        }
        if ([bool]$reason -ne $holding) {
            $holding = [bool]$reason
            Write-Log $(if ($holding) { "holding the PC awake: $reason" } else { "released: Windows may sleep" })
        }

        Start-Sleep -Seconds $CheckIntervalSeconds
    }
}

# Dot-sourcing (as the tests do) loads the functions without starting the loop.
if ($MyInvocation.InvocationName -ne ".") {
    Start-KeepAwake
}
