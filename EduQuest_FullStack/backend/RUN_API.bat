@echo off
setlocal
cd /d "%~dp0"
echo ================================================
echo EduQuest REST API - http://localhost:5080
echo Swagger: http://localhost:5080/swagger
echo ================================================
where dotnet >nul 2>nul
if errorlevel 1 (
  echo [LOI] Khong tim thay .NET SDK. Cai .NET 8 SDK roi chay lai.
  echo https://dotnet.microsoft.com/download/dotnet/8.0
  pause
  exit /b 1
)
dotnet --list-sdks | findstr /R /C:"^8\." >nul
if errorlevel 1 (
  echo [LOI] Chua tim thay .NET SDK 8.0. Cai .NET 8 SDK roi chay lai.
  echo https://dotnet.microsoft.com/download/dotnet/8.0
  pause
  exit /b 1
)
set ASPNETCORE_URLS=http://0.0.0.0:5080
set ASPNETCORE_ENVIRONMENT=Development
dotnet run --no-launch-profile
if errorlevel 1 (
  echo.
  echo [LOI] Backend khong khoi dong duoc. Hay kiem tra thong bao phia tren.
  pause
)
endlocal
