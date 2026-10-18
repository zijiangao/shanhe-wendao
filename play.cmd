@echo off
setlocal
set "GAME=%~dp0build\windows\ShanheWendao.exe"
if not exist "%GAME%" (
    echo Full-game build not found:
    echo   %GAME%
    echo Export the Windows Desktop preset first.
    pause
    exit /b 1
)
rem Launch the local build through PowerShell's CreateProcess path instead of
rem Explorer's ShellExecute path. This avoids the SmartScreen prompt for an
rem unsigned local build; it does not make the EXE trusted for distribution.
start "" /b powershell.exe -NoProfile -WindowStyle Hidden -Command "& '%GAME%'"
exit /b 0
