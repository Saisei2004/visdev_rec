[CmdletBinding()]
param(
    [string]$SharedRoot,
    [string]$InstallRoot = (Join-Path $env:USERPROFILE 'visitas-tasks'),
    [switch]$SkipScheduledTasks
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Resolve-SharedRoot {
    param([string]$Requested)

    if ($Requested) {
        return (Resolve-Path -LiteralPath $Requested).Path
    }

    $candidates = @(
        $env:VISITAS_TASK_HUB_SHARED_ROOT,
        (Join-Path $env:USERPROFILE 'Box\Codex Transfers\Visitas Task Hub Shared'),
        (Join-Path $env:USERPROFILE 'Box Sync\Codex Transfers\Visitas Task Hub Shared'),
        (Join-Path $env:USERPROFILE 'Documents\Box\Codex Transfers\Visitas Task Hub Shared')
    ) | Where-Object { $_ }

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath (Join-Path $candidate 'data\events')) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    throw 'Box同期ルートが見つかりません。-SharedRoot で Visitas Task Hub Shared を指定してください。'
}

function Set-ManagedInstructionBlock {
    param(
        [string]$Path,
        [string]$Content
    )

    $begin = '<!-- BEGIN VISITAS TASK HUB WINDOWS -->'
    $end = '<!-- END VISITAS TASK HUB WINDOWS -->'
    $block = "$begin`r`n$Content`r`n$end"
    $directory = Split-Path -Parent $Path
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    $current = if (Test-Path -LiteralPath $Path) { Get-Content -Raw -LiteralPath $Path } else { '' }
    $pattern = '(?s)' + [regex]::Escape($begin) + '.*?' + [regex]::Escape($end)
    if ([regex]::IsMatch($current, $pattern)) {
        $next = [regex]::Replace($current, $pattern, $block)
    } else {
        $separator = if ($current.Length -gt 0 -and -not $current.EndsWith("`n")) { "`r`n`r`n" } else { "`r`n" }
        $next = $current + $separator + $block + "`r`n"
    }
    Set-Content -LiteralPath $Path -Value $next -Encoding utf8NoBOM
}

if (-not (Get-Command py -ErrorAction SilentlyContinue)) {
    throw 'Python Launcher (py.exe) が必要です。Python 3をインストールしてから再実行してください。'
}

$resolvedSharedRoot = Resolve-SharedRoot -Requested $SharedRoot
$sourceRoot = Join-Path $PSScriptRoot 'app'
if (-not (Test-Path -LiteralPath (Join-Path $sourceRoot 'taskctl.py'))) {
    throw "インストール元が不完全です: $sourceRoot"
}

New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null
Copy-Item -Path (Join-Path $sourceRoot '*') -Destination $InstallRoot -Recurse -Force
New-Item -ItemType Directory -Force -Path (Join-Path $env:LOCALAPPDATA 'VisitasTaskHub') | Out-Null

[Environment]::SetEnvironmentVariable('VISITAS_TASK_HUB_SHARED_ROOT', $resolvedSharedRoot, 'User')
$env:VISITAS_TASK_HUB_SHARED_ROOT = $resolvedSharedRoot

& py -3 (Join-Path $InstallRoot 'taskctl.py') --actor installer init --shared-root $resolvedSharedRoot --device-name $env:COMPUTERNAME
if ($LASTEXITCODE -ne 0) { throw 'Task Hubの初期化に失敗しました。' }

$skillNames = @('visitas-task-review', 'visitas-daily-report')
foreach ($skillName in $skillNames) {
    $sourceSkill = Join-Path $InstallRoot "skills\$skillName"
    foreach ($destinationBase in @(
        (Join-Path $env:USERPROFILE '.agents\skills'),
        (Join-Path $env:USERPROFILE '.claude\skills')
    )) {
        New-Item -ItemType Directory -Force -Path $destinationBase | Out-Null
        Copy-Item -LiteralPath $sourceSkill -Destination $destinationBase -Recurse -Force
    }
}

$instructions = @"
## Visitas Task Hub v2

Visitas作業の開始時に次を実行する。Codexはactor `codex`、Claudeはactor `claude`を使う。

```powershell
py -3 `$env:USERPROFILE\visitas-tasks\taskctl.py --actor <actor> sync
py -3 `$env:USERPROFILE\visitas-tasks\taskctl.py --actor <actor> brief
```

終了時は `handoff` を記録してから同じactorで `sync` する。`tasks.json` とBoxの `data/events` は直接変更せず、必ず `taskctl.py` を使う。
"@
Set-ManagedInstructionBlock -Path (Join-Path $env:USERPROFILE '.codex\AGENTS.md') -Content $instructions
Set-ManagedInstructionBlock -Path (Join-Path $env:USERPROFILE '.claude\CLAUDE.md') -Content $instructions

if (-not $SkipScheduledTasks) {
    $syncScript = Join-Path $InstallRoot 'Sync-Visitas-Task-Hub.cmd'
    $action = New-ScheduledTaskAction -Execute $env:ComSpec -Argument "/d /c `"$syncScript`""
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 2)
    $principal = New-ScheduledTaskPrincipal -UserId ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited

    $logonTrigger = New-ScheduledTaskTrigger -AtLogOn -User ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
    Register-ScheduledTask -TaskName 'Visitas Task Hub - Sync at logon' -Action $action -Trigger $logonTrigger -Settings $settings -Principal $principal -Force | Out-Null

    $minuteTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 1) -RepetitionDuration (New-TimeSpan -Days 3650)
    Register-ScheduledTask -TaskName 'Visitas Task Hub - Sync every minute' -Action $action -Trigger $minuteTrigger -Settings $settings -Principal $principal -Force | Out-Null
}

& py -3 (Join-Path $InstallRoot 'taskctl.py') --actor installer sync | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'インストール後の同期確認に失敗しました。' }

Write-Host "Visitas Task Hubをインストールしました: $InstallRoot"
Write-Host "Box正典: $resolvedSharedRoot\data\events"
Write-Host "UI: $InstallRoot\Start-Visitas-Task-Hub.cmd"
