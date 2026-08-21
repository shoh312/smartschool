# Watches the school installation and tells you when it breaks.
#
# Without this, the first person to notice a dead server is a teacher whose
# register is empty -- by which time the morning's attendance is already
# lost. This runs every few minutes from a scheduled task and messages you
# on Telegram the moment something stops answering.
#
# It reports on a change of state, not on every run: a server that has been
# down for three hours should not produce ninety messages. One message when
# it breaks, one when it comes back, and one reminder a day while it stays
# broken.
#
#   powershell -ExecutionPolicy Bypass -File scripts\healthcheck.ps1
#
# Telegram is optional. With no scripts\alerts.json the checks still run and
# still write to logs\healthcheck.log -- you just have to go and read it.

param(
    [string]$ConfigPath = "$PSScriptRoot\alerts.json",
    [string]$LogDirectory = "$PSScriptRoot\..\logs",
    [string]$StatePath = "$PSScriptRoot\..\logs\health-state.json",

    # Cameras are only expected to see anybody while the school is running.
    # Outside these hours an empty camera is normal, not a fault.
    [int]$SchoolStartHour = 7,
    [int]$SchoolEndHour = 18,
    [int]$BlindMinutes = 90,

    [int]$ReminderHours = 24
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $LogDirectory)) {
    New-Item -ItemType Directory -Force -Path $LogDirectory | Out-Null
}
$logFile = Join-Path (Resolve-Path $LogDirectory).Path 'healthcheck.log'

function Write-Line([string]$message) {
    $line = "{0}  {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $message
    Add-Content -Path $logFile -Value $line -Encoding utf8
}

# ---------------------------------------------------------------- checks --

function Test-Server([string]$label, [int]$port) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:$port/" -TimeoutSec 10 -UseBasicParsing
        if ($response.StatusCode -lt 500) { return $null }
        return "$label (port $port) xatolik qaytardi: HTTP $($response.StatusCode)"
    } catch {
        return "$label (port $port) javob bermayapti"
    }
}

# "Are the cameras still seeing anyone?" A camera whose stream has quietly
# died keeps its process alive and its port open, so only the data tells you
# it went blind.
function Test-CameraActivity([string]$repoRoot) {
    $now = Get-Date
    if ($now.DayOfWeek -eq 'Sunday') { return $null }
    if ($now.Hour -lt $SchoolStartHour -or $now.Hour -ge $SchoolEndHour) { return $null }

    $python = Join-Path $repoRoot 'backend\venv\Scripts\python.exe'
    if (-not (Test-Path $python)) { return $null }

    # Written to a file rather than passed with -c: PowerShell mangles the
    # quotes inside an inline Python snippet when it hands the argument to a
    # native executable, which silently turned the SQL string into a syntax
    # error the first time this ran.
    $queryFile = Join-Path $env:TEMP 'smartschool_last_seen.py'
    $queryLines = @(
        'import os, sys',
        'sys.path.insert(0, os.getcwd())',
        'from app.database import SessionLocal',
        'from sqlalchemy import text',
        'db = SessionLocal()',
        'try:',
        '    row = db.execute(text("select max(last_seen) from attendance")).scalar()',
        '    print(row.isoformat() if row else "NONE")',
        'finally:',
        '    db.close()'
    )
    Set-Content -Path $queryFile -Value $queryLines -Encoding utf8

    $backend = Join-Path $repoRoot 'backend'
    $previous = Get-Location
    try {
        Set-Location $backend
        $env:PYTHONIOENCODING = 'utf-8'
        $output = & $python $queryFile
    } catch {
        return $null   # Can't reach the database: the server check covers that.
    } finally {
        Set-Location $previous
        Remove-Item $queryFile -Force -ErrorAction SilentlyContinue
    }

    $stamp = ($output | Select-Object -Last 1)
    if (-not $stamp -or $stamp -eq 'NONE') { return $null }

    try { $lastSeen = [datetime]::Parse($stamp) } catch { return $null }

    $idle = ($now - $lastSeen).TotalMinutes
    if ($idle -gt $BlindMinutes) {
        return ("Kamera {0:N0} daqiqadan beri hech kimni ko'rmadi (oxirgi: {1:HH:mm})" -f $idle, $lastSeen)
    }
    return $null
}

function Test-Backup([string]$repoRoot) {
    $backups = Join-Path $repoRoot 'backups'
    if (-not (Test-Path $backups)) {
        return "Zaxira papkasi yo'q -- hech qachon zaxira olinmagan"
    }
    $newest = Get-ChildItem $backups -Directory -ErrorAction SilentlyContinue |
              Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $newest) {
        return "Zaxira papkasi bo'sh -- hech qachon zaxira olinmagan"
    }
    $age = ((Get-Date) - $newest.LastWriteTime).TotalHours
    if ($age -gt 48) {
        return ("Oxirgi zaxira {0:N0} soat oldin olingan" -f $age)
    }
    return $null
}

function Test-DiskSpace([string]$repoRoot) {
    try {
        $drive = (Get-Item $repoRoot).PSDrive
        $freeGb = [Math]::Round($drive.Free / 1GB, 1)
        if ($freeGb -lt 5) {
            return "Diskda joy kam qoldi: $freeGb GB"
        }
    } catch { }
    return $null
}

# ---------------------------------------------------------------- alerts --

function Read-Config() {
    if (-not (Test-Path $ConfigPath)) { return $null }
    try {
        return Get-Content $ConfigPath -Raw -Encoding utf8 | ConvertFrom-Json
    } catch {
        Write-Line "alerts.json o'qib bo'lmadi"
        return $null
    }
}

function Send-Telegram([string]$text) {
    $config = Read-Config
    if (-not $config) { return $false }
    if (-not $config.telegram_bot_token -or -not $config.telegram_chat_id) { return $false }

    $uri = "https://api.telegram.org/bot$($config.telegram_bot_token)/sendMessage"
    try {
        Invoke-RestMethod -Uri $uri -Method Post -TimeoutSec 20 -Body @{
            chat_id = $config.telegram_chat_id
            text    = $text
        } | Out-Null
        return $true
    } catch {
        Write-Line "Telegram yuborilmadi: $($_.Exception.Message)"
        return $false
    }
}

# ------------------------------------------------------------------ main --

$repoRoot = (Resolve-Path "$PSScriptRoot\..").Path

$schoolName = 'SmartSchool'
$config = Read-Config
if ($config -and $config.school_name) { $schoolName = $config.school_name }

$problems = @()
foreach ($problem in @(
    (Test-Server 'Maktab serveri' 8000),
    (Test-Server 'Ochiq server' 8200),
    (Test-CameraActivity $repoRoot),
    (Test-Backup $repoRoot),
    (Test-DiskSpace $repoRoot)
)) {
    if ($problem) { $problems += $problem }
}

$state = @{ failing = $false; since = $null; last_notified = $null }
if (Test-Path $StatePath) {
    try {
        $saved = Get-Content $StatePath -Raw -Encoding utf8 | ConvertFrom-Json
        $state.failing = [bool]$saved.failing
        $state.since = $saved.since
        $state.last_notified = $saved.last_notified
    } catch { }
}

$now = Get-Date

if ($problems.Count -gt 0) {
    Write-Line ("MUAMMO: " + ($problems -join ' | '))

    $shouldNotify = $false
    if (-not $state.failing) {
        $shouldNotify = $true
        $state.since = $now.ToString('o')
    } elseif ($state.last_notified) {
        $sinceNotify = ($now - [datetime]::Parse($state.last_notified)).TotalHours
        if ($sinceNotify -ge $ReminderHours) { $shouldNotify = $true }
    } else {
        $shouldNotify = $true
    }

    if ($shouldNotify) {
        $body = "[$schoolName] Muammo aniqlandi" + [Environment]::NewLine + [Environment]::NewLine
        foreach ($p in $problems) { $body += "- $p" + [Environment]::NewLine }
        $body += [Environment]::NewLine + "Vaqt: " + $now.ToString('yyyy-MM-dd HH:mm')
        if (Send-Telegram $body) {
            $state.last_notified = $now.ToString('o')
            Write-Line "Telegram xabari yuborildi"
        }
    }

    $state.failing = $true
} else {
    Write-Line "OK"
    if ($state.failing) {
        $downFor = ''
        if ($state.since) {
            $minutes = ($now - [datetime]::Parse($state.since)).TotalMinutes
            $downFor = " ({0:N0} daqiqa davom etdi)" -f $minutes
        }
        Send-Telegram "[$schoolName] Tizim qayta ishlayapti$downFor" | Out-Null
    }
    $state.failing = $false
    $state.since = $null
    $state.last_notified = $null
}

$state | ConvertTo-Json | Set-Content -Path $StatePath -Encoding utf8
