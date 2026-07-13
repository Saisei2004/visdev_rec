[CmdletBinding()]
param(
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'OneFPSRecorder'),
    [switch]$SkipTaskHub,
    [switch]$NoStart
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Test-DotNet8Sdk {
    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) { return $false }
    return [bool](dotnet --list-sdks | Where-Object { $_ -match '^8\.' })
}

function Test-DdaFfmpeg {
    if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) { return $false }
    $filters = ffmpeg -hide_banner -filters 2>&1 | Out-String
    return $filters -match '\bddagrab\b'
}

function Set-NotificationIconPromoted {
    param([string]$Tooltip)
    $root = 'HKCU:\Control Panel\NotifyIconSettings'
    if (-not (Test-Path -LiteralPath $root)) { return }
    foreach ($attempt in 1..10) {
        $key = Get-ChildItem -LiteralPath $root | Where-Object {
            $properties = Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction SilentlyContinue
            $properties -and
                ($properties.PSObject.Properties.Name -contains 'InitialTooltip') -and
                $properties.InitialTooltip -eq $Tooltip
        } | Select-Object -First 1
        if ($key) {
            New-ItemProperty -LiteralPath $key.PSPath -Name IsPromoted -Value 1 -PropertyType DWord -Force | Out-Null
            return
        }
        Start-Sleep -Milliseconds 500
    }
}

if (-not (Test-DotNet8Sdk)) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw '.NET 8 SDKが必要です。wingetも見つからないため自動インストールできません。'
    }
    winget install --id Microsoft.DotNet.SDK.8 --exact --source winget --accept-source-agreements --accept-package-agreements --silent --disable-interactivity
    if ($LASTEXITCODE -ne 0 -or -not (Test-DotNet8Sdk)) { throw '.NET 8 SDKのインストールに失敗しました。' }
}

if (-not (Test-DdaFfmpeg)) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw 'ddagrab対応ffmpegが必要です。wingetも見つからないため自動インストールできません。'
    }
    winget install --id Gyan.FFmpeg --exact --source winget --accept-source-agreements --accept-package-agreements --silent --disable-interactivity
    if ($LASTEXITCODE -ne 0) { throw 'ffmpegのインストールに失敗しました。' }
}

$project = Join-Path $PSScriptRoot 'OneFPSRecorder.Windows\OneFPSRecorder.Windows.csproj'
$publish = Join-Path $env:TEMP "OneFPSRecorder-publish-$([guid]::NewGuid().ToString('N'))"
$appRoot = Join-Path $InstallRoot 'app'

$running = Get-Process -Name 'OneFPSRecorder.Windows' -ErrorAction SilentlyContinue
if ($running) {
    throw 'OneFPSRecorderが実行中です。録画を停止してアプリを終了してから、インストーラを再実行してください。'
}

try {
    dotnet publish $project -c Release -r win-x64 --self-contained false -p:PublishSingleFile=false -o $publish
    if ($LASTEXITCODE -ne 0) { throw 'OneFPSRecorderのpublishに失敗しました。' }
    New-Item -ItemType Directory -Force -Path $appRoot | Out-Null
    Copy-Item -Path (Join-Path $publish '*') -Destination $appRoot -Recurse -Force
} finally {
    if (Test-Path -LiteralPath $publish) {
        $resolved = [System.IO.Path]::GetFullPath($publish)
        $prefix = [System.IO.Path]::GetFullPath((Join-Path $env:TEMP 'OneFPSRecorder-publish-'))
        if ($resolved.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $resolved -Recurse -Force
        }
    }
}

$executable = Join-Path $appRoot 'OneFPSRecorder.Windows.exe'
if (-not (Test-Path -LiteralPath $executable)) { throw "インストール結果が見つかりません: $executable" }

$action = New-ScheduledTaskAction -Execute $executable
$trigger = New-ScheduledTaskTrigger -AtLogOn -User ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit ([TimeSpan]::Zero)
$principal = New-ScheduledTaskPrincipal -UserId ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName 'OneFPSRecorder Windows - Start at logon' -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null

$startMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
New-Item -ItemType Directory -Force -Path $startMenu | Out-Null
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut((Join-Path $startMenu 'OneFPSRecorder Windows.lnk'))
$shortcut.TargetPath = $executable
$shortcut.WorkingDirectory = $appRoot
$shortcut.Description = '1 FPS screen recorder for Windows'
$shortcut.Save()

if (-not $SkipTaskHub) {
    $taskHubInstaller = Join-Path (Split-Path $PSScriptRoot -Parent) 'tools\visitas-task-hub-windows\Install-Visitas-Task-Hub.ps1'
    if (-not (Test-Path -LiteralPath $taskHubInstaller)) { throw "Task Hubインストーラが見つかりません: $taskHubInstaller" }
    & $taskHubInstaller
}

if (-not $NoStart) {
    Start-Process -FilePath $executable
    Set-NotificationIconPromoted -Tooltip 'OneFPSRecorder'
}

Write-Host "OneFPSRecorder Windowsをインストールしました: $appRoot"
Write-Host '外部投稿は既定でdry-runです。動画・Drive・SlackはUIが個別に許可を確認します。'
