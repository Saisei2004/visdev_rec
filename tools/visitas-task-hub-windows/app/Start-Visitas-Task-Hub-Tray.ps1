[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

$script:hubUrl = 'http://127.0.0.1:7700/'
$script:healthUrl = 'http://127.0.0.1:7700/api/health'
$script:serverProcess = $null
$script:notifyIcon = $null
$script:context = $null
$script:timer = $null
$logRoot = Join-Path $env:LOCALAPPDATA 'VisitasTaskHub'
$trayLog = Join-Path $logRoot 'tray.log'
$serverLog = Join-Path $logRoot 'server.log'
$serverErrorLog = Join-Path $logRoot 'server-error.log'
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null

$createdNew = $false
$mutex = New-Object System.Threading.Mutex($true, 'Local\VisitasTaskHub.Tray.Singleton', [ref]$createdNew)
if (-not $createdNew) {
    $mutex.Dispose()
    exit 0
}

function Write-TrayLog {
    param([string]$Message)
    Add-Content -LiteralPath $trayLog -Value "$(Get-Date -Format o) $Message" -Encoding utf8
}

function Test-TaskHubHealth {
    try {
        $response = Invoke-WebRequest -Uri $script:healthUrl -UseBasicParsing -TimeoutSec 1
        return $response.StatusCode -eq 200
    } catch {
        return $false
    }
}

function Start-TaskHubServer {
    if (Test-TaskHubHealth) { return $true }

    $pythonLauncher = (Get-Command py.exe -ErrorAction Stop).Source
    $pythonExecutable = (& $pythonLauncher -3 -c 'import sys; print(sys.executable)').Trim()
    if (-not (Test-Path -LiteralPath $pythonExecutable)) { throw "Python executable was not found: $pythonExecutable" }
    $serverScript = Join-Path $PSScriptRoot 'server.py'
    if (-not (Test-Path -LiteralPath $serverScript)) { throw "Task Hub server was not found: $serverScript" }

    $arguments = "`"$serverScript`" --port 7700"
    $script:serverProcess = Start-Process -FilePath $pythonExecutable -ArgumentList $arguments -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -RedirectStandardOutput $serverLog -RedirectStandardError $serverErrorLog -PassThru

    foreach ($attempt in 1..20) {
        Start-Sleep -Milliseconds 250
        if (Test-TaskHubHealth) {
            Write-TrayLog "server started pid=$($script:serverProcess.Id)"
            return $true
        }
        if ($script:serverProcess.HasExited) { break }
    }
    Write-TrayLog 'server health check failed'
    return $false
}

function Show-TrayMessage {
    param(
        [string]$Title,
        [string]$Message,
        [System.Windows.Forms.ToolTipIcon]$Icon = [System.Windows.Forms.ToolTipIcon]::Info
    )
    $script:notifyIcon.BalloonTipTitle = $Title
    $script:notifyIcon.BalloonTipText = $Message
    $script:notifyIcon.BalloonTipIcon = $Icon
    $script:notifyIcon.ShowBalloonTip(4000)
}

function Open-TaskHub {
    if (-not (Start-TaskHubServer)) {
        Show-TrayMessage -Title 'Visitas Task Hub' -Message 'Task Hub could not start. Check tray.log.' -Icon Error
        return
    }
    Start-Process -FilePath $script:hubUrl
}

function Invoke-TaskHubSync {
    $launcher = Join-Path $PSScriptRoot 'Sync-Visitas-Task-Hub-Hidden.vbs'
    $wscript = Join-Path $env:SystemRoot 'System32\wscript.exe'
    $process = Start-Process -FilePath $wscript -ArgumentList "//B //Nologo `"$launcher`"" -WindowStyle Hidden -Wait -PassThru
    if ($process.ExitCode -eq 0) {
        Show-TrayMessage -Title 'Visitas Task Hub' -Message 'Synchronization completed.'
    } else {
        Show-TrayMessage -Title 'Visitas Task Hub' -Message "Synchronization failed (exit $($process.ExitCode))." -Icon Error
    }
}

$script:notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$script:notifyIcon.Icon = [System.Drawing.SystemIcons]::Information
$script:notifyIcon.Text = 'Visitas Task Hub'
$script:notifyIcon.Visible = $true

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$openItem = New-Object System.Windows.Forms.ToolStripMenuItem -ArgumentList @('Open tasks')
$syncItem = New-Object System.Windows.Forms.ToolStripMenuItem -ArgumentList @('Sync now')
$exitItem = New-Object System.Windows.Forms.ToolStripMenuItem -ArgumentList @('Exit')
$null = $menu.Items.Add($openItem)
$null = $menu.Items.Add($syncItem)
$null = $menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
$null = $menu.Items.Add($exitItem)
$script:notifyIcon.ContextMenuStrip = $menu

$openItem.add_Click({ Open-TaskHub })
$syncItem.add_Click({ Invoke-TaskHubSync })
$script:notifyIcon.add_DoubleClick({ Open-TaskHub })

$script:context = New-Object System.Windows.Forms.ApplicationContext
$exitItem.add_Click({
    $script:timer.Stop()
    $script:notifyIcon.Visible = $false
    if ($script:serverProcess -and -not $script:serverProcess.HasExited) {
        Stop-Process -Id $script:serverProcess.Id -Force -ErrorAction SilentlyContinue
    }
    $script:context.ExitThread()
})

$script:timer = New-Object System.Windows.Forms.Timer
$script:timer.Interval = 60000
$script:timer.add_Tick({
    if (-not (Test-TaskHubHealth)) { $null = Start-TaskHubServer }
})

try {
    if (-not (Start-TaskHubServer)) {
        Show-TrayMessage -Title 'Visitas Task Hub' -Message 'Task Hub server could not start.' -Icon Error
    }
    $script:timer.Start()
    [System.Windows.Forms.Application]::Run($script:context)
} catch {
    Write-TrayLog $_.Exception.ToString()
    throw
} finally {
    $script:timer.Dispose()
    $script:notifyIcon.Visible = $false
    $script:notifyIcon.Dispose()
    $menu.Dispose()
    $mutex.ReleaseMutex()
    $mutex.Dispose()
}
