# Keeps one SmartSchool server alive on the school's PC.
#
# The servers used to be started by hand. That works on a desk you are
# sitting at, and fails on a school PC: a power cut, a Windows update or
# somebody pressing the power button leaves the whole system down until a
# person drives over and starts it again. This script is what the scheduled
# task runs instead -- it starts the server and, if the server ever exits,
# starts it again.
#
# It is deliberately a loop rather than a plain "run once" command, because
# a scheduled task's own restart-on-failure only reacts to the task ending,
# and this way the ordering problem solves itself too: at boot PostgreSQL
# may not be accepting connections yet, uvicorn dies, and the next attempt a
# few seconds later succeeds.
#
#   powershell -ExecutionPolicy Bypass -File scripts\run_server.ps1 `
#              -Name backend -WorkingDirectory C:\...\backend -Port 8000
#
# Installed by scripts\install_service.ps1; not usually run by hand.

param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$WorkingDirectory,
    [Parameter(Mandatory = $true)][int]$Port,
    [string]$Python,
    [string]$LogDirectory = "$PSScriptRoot\..\logs",

    # A server that dies immediately is usually waiting on something that is
    # not ready yet (PostgreSQL, the network). Retrying every 5 seconds for
    # hours just fills the disk with the same error, so repeated fast
    # failures back off -- while a server that ran fine for an hour and then
    # crashed is restarted promptly.
    [int]$MinDelaySeconds = 5,
    [int]$MaxDelaySeconds = 120,
    [int]$HealthyAfterSeconds = 60
)

$ErrorActionPreference = 'Stop'

if (-not $Python) { $Python = Join-Path $WorkingDirectory 'venv\Scripts\python.exe' }

if (-not (Test-Path $Python)) {
    throw "Python topilmadi: $Python"
}
if (-not (Test-Path $WorkingDirectory)) {
    throw "Papka topilmadi: $WorkingDirectory"
}

if (-not (Test-Path $LogDirectory)) {
    New-Item -ItemType Directory -Force -Path $LogDirectory | Out-Null
}
$LogDirectory = (Resolve-Path $LogDirectory).Path

$outLog = Join-Path $LogDirectory "$Name.out.log"
$errLog = Join-Path $LogDirectory "$Name.err.log"
$runLog = Join-Path $LogDirectory "$Name.supervisor.log"

function Write-Line([string]$message) {
    $line = "{0}  {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $message
    Add-Content -Path $runLog -Value $line -Encoding utf8
}

# Uvicorn logs every request, so a term of traffic would grow these without
# limit on a machine nobody is watching. Roll them over at 20 MB, keeping
# one previous file.
function Limit-Log([string]$path, [int]$maxBytes = 20MB) {
    if (-not (Test-Path $path)) { return }
    if ((Get-Item $path).Length -lt $maxBytes) { return }
    $old = "$path.1"
    if (Test-Path $old) { Remove-Item $old -Force -ErrorAction SilentlyContinue }
    Move-Item $path $old -Force -ErrorAction SilentlyContinue
}

Write-Line "=== nazoratchi ishga tushdi: $Name (port $Port) ==="
Write-Line "python: $Python"
Write-Line "papka : $WorkingDirectory"

$delay = $MinDelaySeconds

while ($true) {
    Limit-Log $outLog
    Limit-Log $errLog

    $startedAt = Get-Date
    Write-Line "ishga tushiryapman..."

    try {
        $process = Start-Process -FilePath $Python `
            -ArgumentList '-m', 'uvicorn', 'app.main:app', '--host', '0.0.0.0', '--port', "$Port" `
            -WorkingDirectory $WorkingDirectory `
            -RedirectStandardOutput $outLog `
            -RedirectStandardError $errLog `
            -WindowStyle Hidden `
            -PassThru

        $process.WaitForExit()
        $exitCode = $process.ExitCode
    } catch {
        Write-Line "ishga tushirib bo'lmadi: $($_.Exception.Message)"
        $exitCode = -1
    }

    $lived = ((Get-Date) - $startedAt).TotalSeconds
    Write-Line ("to'xtadi (kod={0}), {1:N0} soniya ishladi" -f $exitCode, $lived)

    if ($lived -ge $HealthyAfterSeconds) {
        # It was up and serving; whatever killed it was probably a one-off.
        $delay = $MinDelaySeconds
    } else {
        $delay = [Math]::Min($delay * 2, $MaxDelaySeconds)
    }

    Write-Line "$delay soniyadan keyin qayta uriniladi"
    Start-Sleep -Seconds $delay
}
