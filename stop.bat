@echo off
rem ============================================================
rem  SmartSchool -- hamma serverni to'xtatish
rem
rem  Nazoratchilar avval to'xtatiladi: aks holda ular serverni
rem  darrov qaytadan ko'tarib qo'yadi -- ularning vazifasi shu.
rem ============================================================

chcp 65001 >nul

set "PS=powershell -NoProfile -ExecutionPolicy Bypass"

echo.
echo   nazoratchilar to'xtatilmoqda...
%PS% -Command "Get-CimInstance Win32_Process -Filter \"Name='powershell.exe'\" | Where-Object { $_.CommandLine -match 'run_server' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }"

echo   serverlar to'xtatilmoqda...
%PS% -Command "Get-NetTCPConnection -LocalPort 8000,8200 -State Listen -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }"

rem  ping, not timeout: timeout.exe exits with an error the moment stdin is
rem  redirected, leaving no pause at all before the check below.
ping -n 4 127.0.0.1 >nul

echo.
%PS% -Command "$busy = Get-NetTCPConnection -LocalPort 8000,8200 -State Listen -ErrorAction SilentlyContinue; if ($busy) { Write-Host '  DIQQAT: portlar hali band' } else { Write-Host '  hammasi to''xtadi' }"
echo.
pause
