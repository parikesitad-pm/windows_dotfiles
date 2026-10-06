@echo off
setlocal
set "OWL_SCRIPT=%USERPROFILE%\.gemini\owl\owl.ps1"
if not exist "%OWL_SCRIPT%" (
    if exist "%~dp0..\owl\owl.ps1" set "OWL_SCRIPT=%~dp0..\owl\owl.ps1"
)
where pwsh >nul 2>nul
if %ERRORLEVEL% equ 0 (
    pwsh -NoLogo -ExecutionPolicy Bypass -File "%OWL_SCRIPT%" %*
) else (
    powershell -NoLogo -ExecutionPolicy Bypass -File "%OWL_SCRIPT%" %*
)
