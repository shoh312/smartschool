# Makes a school PC run SmartSchool without anybody logging in.
#
#   Administrator PowerShell:
#     powershell -ExecutionPolicy Bypass -File scripts\install_service.ps1
#     powershell -ExecutionPolicy Bypass -File scripts\install_service.ps1 -Uninstall
#
# Registers four scheduled tasks:
#
#   SmartSchool Backend        at boot, kept alive by run_server.ps1
#   SmartSchool PublicServer   at boot, kept alive by run_server.ps1
#   SmartSchool Healthcheck    every 10 minutes
#   SmartSchool Backup         nightly
#
# The two servers run under SYSTEM with an AtStartup trigger, which is the
# combination that survives the thing that actually happens in a school: the
# power goes out, the PC comes back on its own, and nobody is standing there
# to log in. A task tied to a user account would sit and wait for a login
# that may not come until morning.
#
# Ordering with PostgreSQL is not configured here on purpose. At boot the
# database is often not accepting connections yet, and rather than guess at
# a delay, run_server.ps1 simply retries -- the server comes up whenever
# PostgreSQL is ready, however long that takes.

param(
    [switch]$Uninstall,
    [string]$BackupTime = '02:00',
    [int]$HealthEveryMinutes = 10
)

$ErrorActionPreference = 'Stop'

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Administrator huquqi kerak. PowerShell ni 'Run as administrator' bilan oching."
}

$repoRoot = (Resolve-Path "$PSScriptRoot\..").Path
$scripts = Join-Path $repoRoot 'scripts'
$backend = Join-Path $repoRoot 'backend'
$publicServer = Join-Path $repoRoot 'public_server'

$tasks = @{
    Backend      = 'SmartSchool Backend'
    PublicServer = 'SmartSchool PublicServer'
    Healthcheck  = 'SmartSchool Healthcheck'
    Backup       = 'SmartSchool Backup'
}

function Remove-TaskIfPresent([string]$name) {
    $existing = Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
    if ($existing) {
        Unregister-ScheduledTask -TaskName $name -Confirm:$false
        Write-Output "  o'chirildi: $name"
    }
}

if ($Uninstall) {
    Write-Output "Vazifalar o'chirilyapti..."
    foreach ($name in $tasks.Values) { Remove-TaskIfPresent $name }
    Write-Output ""
    Write-Output "Tugadi. Serverlar endi o'zi ishga tushmaydi."
    return
}

foreach ($path in @($backend, $publicServer)) {
    if (-not (Test-Path (Join-Path $path 'venv\Scripts\python.exe'))) {
        throw "venv topilmadi: $path\venv -- avval muhitni o'rnating"
    }
}

function New-PowerShellAction([string]$scriptPath, [string]$extraArguments = '') {
    $arguments = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$scriptPath`""
    if ($extraArguments) { $arguments += " $extraArguments" }
    return New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arguments -WorkingDirectory $repoRoot
}

# SYSTEM, highest privileges: no password to store and no login to wait for.
$systemPrincipal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest

function New-ServerSettings() {
    # ExecutionTimeLimit 0 = never kill it; these are meant to run forever.
    # RestartCount covers the case where the supervisor script itself dies.
    New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -RestartCount 999 `
        -RestartInterval (New-TimeSpan -Minutes 1) `
        -ExecutionTimeLimit (New-TimeSpan -Seconds 0) `
        -MultipleInstances IgnoreNew
}

function New-JobSettings() {
    New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -ExecutionTimeLimit (New-TimeSpan -Hours 2) `
        -MultipleInstances IgnoreNew
}

Write-Output "SmartSchool avtomatik ishga tushirish o'rnatilyapti"
Write-Output "  papka: $repoRoot"
Write-Output ""

# --------------------------------------------------------------- servers --

$runServer = Join-Path $scripts 'run_server.ps1'

$serverJobs = @(
    @{ Task = $tasks.Backend;      Name = 'backend';       Dir = $backend;       Port = 8000 },
    @{ Task = $tasks.PublicServer; Name = 'public_server'; Dir = $publicServer;  Port = 8200 }
)

foreach ($job in $serverJobs) {
    Remove-TaskIfPresent $job.Task

    $arguments = "-Name $($job.Name) -WorkingDirectory `"$($job.Dir)`" -Port $($job.Port)"
    Register-ScheduledTask `
        -TaskName $job.Task `
        -Action (New-PowerShellAction $runServer $arguments) `
        -Trigger (New-ScheduledTaskTrigger -AtStartup) `
        -Principal $systemPrincipal `
        -Settings (New-ServerSettings) `
        -Description "SmartSchool $($job.Name) -- kompyuter yonganda o'zi ishga tushadi va o'lsa qayta ko'tariladi" | Out-Null

    Write-Output "  qo'shildi: $($job.Task)  (port $($job.Port))"
}

# ----------------------------------------------------------------- jobs --

Remove-TaskIfPresent $tasks.Healthcheck
$healthTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Minutes $HealthEveryMinutes)
Register-ScheduledTask `
    -TaskName $tasks.Healthcheck `
    -Action (New-PowerShellAction (Join-Path $scripts 'healthcheck.ps1')) `
    -Trigger $healthTrigger `
    -Principal $systemPrincipal `
    -Settings (New-JobSettings) `
    -Description "Serverlar, kamera, zaxira va disk holatini tekshiradi; muammo bo'lsa Telegram orqali xabar beradi" | Out-Null
Write-Output "  qo'shildi: $($tasks.Healthcheck)  (har $HealthEveryMinutes daqiqada)"

Remove-TaskIfPresent $tasks.Backup
Register-ScheduledTask `
    -TaskName $tasks.Backup `
    -Action (New-PowerShellAction (Join-Path $scripts 'backup.ps1')) `
    -Trigger (New-ScheduledTaskTrigger -Daily -At $BackupTime) `
    -Principal $systemPrincipal `
    -Settings (New-JobSettings) `
    -Description "Har kecha ikkala bazani va suratlarni zaxiralaydi" | Out-Null
Write-Output "  qo'shildi: $($tasks.Backup)  (har kuni $BackupTime)"

# ---------------------------------------------------------------- finish --

Write-Output ""
Write-Output "Tayyor. Serverlarni hozir ishga tushirish uchun:"
Write-Output "  Start-ScheduledTask -TaskName '$($tasks.Backend)'"
Write-Output "  Start-ScheduledTask -TaskName '$($tasks.PublicServer)'"
Write-Output ""
Write-Output "Holatni ko'rish:"
Write-Output "  Get-ScheduledTask -TaskName 'SmartSchool*' | Select-Object TaskName, State"
Write-Output ""
Write-Output "Jurnallar: $repoRoot\logs"

if (-not (Test-Path (Join-Path $scripts 'alerts.json'))) {
    Write-Output ""
    Write-Output "DIQQAT: scripts\alerts.json yo'q -- Telegram xabari yuborilmaydi."
    Write-Output "        scripts\alerts.example.json dan nusxa oling va to'ldiring."
}
