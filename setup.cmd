@echo off
setlocal
where pwsh.exe >nul 2>nul
if errorlevel 1 (
  echo PowerShell 7.2+ is required. Install it from https://aka.ms/powershell-release
  pause
  exit /b 1
)
pwsh.exe -NoProfile -File "%~dp0installer\Setup.ps1" -Interactive
set "PSS_RESULT=%ERRORLEVEL%"
if not "%PSS_RESULT%"=="0" echo Setup stopped. Review the message; no browser was closed or restarted.
pause
exit /b %PSS_RESULT%
