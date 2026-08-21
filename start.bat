@echo off
rem ============================================================
rem  SmartSchool -- hammasini bitta bosishda ishga tushirish
rem
rem  Ikkala serverni ham tarmoqqa ochiq holda (0.0.0.0) ko'taradi,
rem  ya'ni bir Wi-Fi dagi telefon ularni ko'ra oladi. Serverlar
rem  scripts\run_server.ps1 nazoratchisi ostida ishlaydi -- biror
rem  server yiqilsa, o'zi qayta ko'tariladi.
rem
rem  Oxirida kompyuterning tarmoqdagi manzilini chiqaradi.
rem ============================================================

chcp 65001 >nul
setlocal

set "REPO=%~dp0"
set "PS=powershell -NoProfile -ExecutionPolicy Bypass"

echo.
echo ============================================
echo   SmartSchool ishga tushmoqda
echo ============================================
echo.

rem --- PostgreSQL ishlayaptimi? Serverlar unga bog'liq ---------
sc query postgresql-x64-16 >nul 2>&1
if errorlevel 1 (
    %PS% -Command "$s = Get-Service -Name 'postgresql*' -ErrorAction SilentlyContinue | Select-Object -First 1; if ($s) { if ($s.Status -ne 'Running') { Write-Host '  PostgreSQL to''xtagan, ishga tushirilmoqda...'; Start-Service $s.Name } else { Write-Host '  PostgreSQL: ishlayapti' } } else { Write-Host '  PostgreSQL xizmati topilmadi -- qo''lda tekshiring' }"
) else (
    %PS% -Command "$s = Get-Service postgresql-x64-16; if ($s.Status -ne 'Running') { Write-Host '  PostgreSQL to''xtagan, ishga tushirilmoqda...'; Start-Service postgresql-x64-16 } else { Write-Host '  PostgreSQL: ishlayapti' }"
)

rem --- eskilarini to'xtatish, aks holda port band bo'ladi -------
echo   eski jarayonlar tozalanmoqda...
%PS% -Command "Get-CimInstance Win32_Process -Filter \"Name='powershell.exe'\" | Where-Object { $_.CommandLine -match 'run_server' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }"
%PS% -Command "Get-NetTCPConnection -LocalPort 8000,8200 -State Listen -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }"
rem  ping, not timeout: Windows' timeout.exe refuses to run at all when
rem  stdin is redirected, and then the wait is silently skipped -- which
rem  below would mean checking the ports before the backend has finished
rem  loading its models, and reporting a healthy server as dead.
ping -n 4 127.0.0.1 >nul

rem --- ochiq server (8200) --------------------------------------
rem  `start ""` would put a console window on screen for each server and
rem  leave it there all day. Start-Process -WindowStyle Hidden runs them
rem  detached and out of sight; they keep running after this window closes,
rem  and their output goes to logs\ where it can be read when needed.
echo   ochiq server (8200) ko'tarilmoqda...
%PS% -Command "Start-Process powershell -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','%REPO%scripts\run_server.ps1','-Name','public_server','-WorkingDirectory','%REPO%public_server','-Port','8200' -WindowStyle Hidden"
ping -n 9 127.0.0.1 >nul

rem --- maktab serveri (8000) ------------------------------------
rem  Modellarni yuklashi tufayli sekinroq ko'tariladi.
echo   maktab serveri (8000) ko'tarilmoqda...
%PS% -Command "Start-Process powershell -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','%REPO%scripts\run_server.ps1','-Name','backend','-WorkingDirectory','%REPO%backend','-Port','8000' -WindowStyle Hidden"

echo.
echo   kutilmoqda (modellar yuklanmoqda)...
ping -n 46 127.0.0.1 >nul

rem --- natija ---------------------------------------------------
echo.
echo ============================================
%PS% -Command "$ok=$true; foreach ($p in 8000,8200) { try { $r = Invoke-WebRequest -Uri \"http://localhost:$p/\" -TimeoutSec 10 -UseBasicParsing; Write-Host ('  port {0}: ISHLAYAPTI' -f $p) } catch { Write-Host ('  port {0}: KO''TARILMADI' -f $p); $ok=$false } }; if (-not $ok) { Write-Host ''; Write-Host '  Jurnalni qarang: logs\backend.err.log' }"
echo ============================================
echo.
echo   Telefon uchun manzil:
%PS% -Command "Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' -and $_.IPAddress -notlike '172.*' } | ForEach-Object { '     http://{0}:8000   ({1})' -f $_.IPAddress, $_.InterfaceAlias }"
echo.
echo   Ilova serverni tarmoqdan o'zi topadi -- manzil kiritish shart emas.
echo.

rem --- kuzatuv oynasi -------------------------------------------
rem  The one window that should be on screen. The servers run hidden
rem  because nobody reads a scrolling uvicorn log; this is the opposite --
rem  it exists to be watched, so it gets its own console and stays open
rem  after the watcher exits (cmd /k) instead of vanishing with whatever
rem  it last printed.
echo   kuzatuv oynasi ochilmoqda...
start "SmartSchool kuzatuv" cmd /k "chcp 65001 >nul && set PYTHONIOENCODING=utf-8 && "%REPO%backend\venv\Scripts\python.exe" "%REPO%scripts\watch.py""

echo.
echo   To'xtatish uchun: stop.bat
echo.
pause
