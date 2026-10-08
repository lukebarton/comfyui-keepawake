# Tests the keep-awake decision in windows/keepawake.ps1. Plain assertions, so it needs no modules.
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# keepawake.ps1's default log path uses ProgramData, which only Windows sets.
if (-not $env:ProgramData) { $env:ProgramData = [IO.Path]::GetTempPath() }
. (Join-Path $PSScriptRoot "../windows/keepawake.ps1")

$failures = 0
function Assert-Reason {
    param([string]$Name, $Expected, $Status, [int]$MinutesSinceWake = 60)
    $now = [datetime]"2026-01-01T12:00:00"
    $actual = Get-KeepAwakeReason -Status $Status -Now $now `
        -AwakeSince $now.AddMinutes(-$MinutesSinceWake) -IdlePeriod ([timespan]::FromMinutes(30))
    $ok = if ($null -eq $Expected) { $null -eq $actual } else { "$actual" -like $Expected }
    if ($ok) {
        Write-Host "ok   $Name"
    } else {
        Write-Host "FAIL $Name`n     expected: $Expected`n     actual:   $actual"
        $script:failures++
    }
}

function New-Status {
    param([bool]$Busy = $false, $PingMinutesAgo = $null)
    $serverTime = 1700000000.0
    [pscustomobject]@{
        last_ping    = if ($null -ne $PingMinutesAgo) { $serverTime - 60 * $PingMinutesAgo } else { $null }
        jobs_running = [int]$Busy
        jobs_queued  = 0
        busy         = $Busy
        server_time  = $serverTime
    }
}

Assert-Reason "busy keeps awake" "*job*" (New-Status -Busy $true)
Assert-Reason "busy keeps awake even with an old ping" "*job*" (New-Status -Busy $true -PingMinutesAgo 120)
Assert-Reason "recent ping keeps awake" "*used*" (New-Status -PingMinutesAgo 29)
Assert-Reason "old ping lets it sleep" $null (New-Status -PingMinutesAgo 31)
Assert-Reason "no ping lets it sleep" $null (New-Status)
Assert-Reason "recent wake keeps awake" "*resumed*" (New-Status) -MinutesSinceWake 5
Assert-Reason "recent wake keeps awake when ComfyUI is unreachable" "*resumed*" $null -MinutesSinceWake 5
Assert-Reason "unreachable ComfyUI lets it sleep" $null $null

if ($failures) { throw "$failures test(s) failed" }
