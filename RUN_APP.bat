@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"
title EduQuest - Chay ung dung

where dotnet >nul 2>nul
if errorlevel 1 (
  echo [THIEU .NET] Cai .NET 8 SDK truoc: https://dotnet.microsoft.com/download/dotnet/8.0
  pause
  exit /b 1
)
where flutter >nul 2>nul
if errorlevel 1 (
  echo [THIEU FLUTTER] Cai Flutter SDK va them flutter\bin vao PATH.
  pause
  exit /b 1
)

rem Mac dinh: chay tren Android Emulator, bam nut Upload trong app se mo hop thoai chon file ngay tren may tinh.
rem Muon chay kieu khac, goi: RUN_APP.bat windows | phone | chrome
set MODE=2
if /i "%~1"=="windows" set MODE=1
if /i "%~1"=="phone" set MODE=3
if /i "%~1"=="chrome" set MODE=4

echo =====================================================
echo  EduQuest - Android Emulator
echo  Bam nut Upload trong app de chon file tu MAY TINH
echo =====================================================

set EXTRA_ARGS=
if "%MODE%"=="3" call :find_ip
if "%MODE%"=="3" if "%PC_IP%"=="" exit /b 1
if "%MODE%"=="3" set EXTRA_ARGS=--dart-define=API_BASE_URL=http://%PC_IP%:5080

echo.
echo [1/3] Kiem tra / khoi dong API...
call :api_up
if errorlevel 1 (
  start "EduQuest API" cmd /k ""%~dp0backend\RUN_API.bat""
) else (
  echo API da chay san tai cong 5080, se tai su dung.
)

echo [2/3] Dang cho API san sang - toi da 60 giay...
set API_READY=0
for /l %%i in (1,1,60) do (
  call :api_up
  if not errorlevel 1 (
    set API_READY=1
    goto :api_ready
  )
  timeout /t 1 /nobreak >nul
)
:api_ready
if "%API_READY%"=="0" (
  echo [LOI] API chua san sang. Xem cua so EduQuest API roi thu lai.
  pause
  exit /b 1
)

echo [3/3] Chuan bi va chay Flutter...
cd /d "%~dp0flutter_app"
if "%MODE%"=="1" if not exist windows call flutter create --platforms=windows,web .
if "%MODE%"=="4" if not exist web call flutter create --platforms=windows,web .
call flutter pub get
if errorlevel 1 (
  echo [LOI] flutter pub get that bai. Kiem tra mang va Flutter SDK.
  pause
  exit /b 1
)

if "%MODE%"=="1" call flutter run -d windows
if "%MODE%"=="2" call flutter devices
if "%MODE%"=="2" call flutter run
if "%MODE%"=="3" call flutter devices
if "%MODE%"=="3" call flutter run %EXTRA_ARGS%
if "%MODE%"=="4" call flutter run -d chrome

if errorlevel 1 (
  echo.
  echo [LOI] Khong chay duoc. Voi lua chon 1 can Visual Studio voi workload Desktop development with C++.
  echo Neu chua cai, hay chay lai va chon 4 - Chrome.
  pause
)
endlocal
exit /b 0

:api_up
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $r = Invoke-WebRequest -Uri 'http://127.0.0.1:5080/' -TimeoutSec 1; $j = $r.Content | ConvertFrom-Json; if ($j.name -eq 'EduQuest API') { exit 0 } else { exit 1 } } catch { exit 1 }" >nul 2>nul
exit /b %errorlevel%

:find_ip
set PC_IP=
for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command "Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -match '^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)' -and $_.InterfaceAlias -notmatch 'Virtual|vEthernet|WSL|Loopback|Hyper-V' } | Select-Object -First 1 -ExpandProperty IPAddress"`) do set PC_IP=%%I
if "%PC_IP%"=="" (
  echo Khong tim duoc IP LAN. Hay noi PC va dien thoai cung Wi-Fi.
  pause
) else (
  echo IP may tinh duoc chon: %PC_IP% - cho phep firewall neu Windows hoi.
)
exit /b 0
