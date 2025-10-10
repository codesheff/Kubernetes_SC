@echo off
echo Starting kubectl setup for Windows...
echo.

REM Check if PowerShell is available
powershell -Command "Get-Host" >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: PowerShell is not available or not in PATH
    echo Please ensure PowerShell is installed and accessible
    pause
    exit /b 1
)

REM Run the PowerShell setup script
powershell -ExecutionPolicy Bypass -File "%~dp0setup-local-kubectl.ps1"

echo.
echo Would you like to run the validation test? (y/N)
set /p runtest=
if /i "%runtest%"=="y" (
    echo.
    echo Running validation test...
    powershell -ExecutionPolicy Bypass -File "%~dp0test-kubectl-setup.ps1"
)

echo.
echo Setup completed. Press any key to exit...
pause >nul