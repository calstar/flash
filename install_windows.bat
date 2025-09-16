@echo off
REM Windows-specific installer that recommends WSL
REM This script checks for WSL and provides installation guidance

echo ========================================
echo Cross-Platform Flash Installer - Windows
echo ========================================
echo.

REM Check if running in WSL
if defined WSL_DISTRO_NAME (
    echo ✅ Running in WSL: %WSL_DISTRO_NAME%
    echo This is the recommended environment for the flash installer.
    echo.
    echo Please run the Linux installer instead:
    echo   ./install.sh
    echo.
    pause
    exit /b 0
)

echo ⚠️  WARNING: Running on native Windows
echo.
echo The flash installer is designed to work best in WSL (Windows Subsystem for Linux).
echo Some features like elodin-db are not available on native Windows.
echo.

REM Check if WSL is installed
wsl --status >nul 2>&1
if %errorLevel% equ 0 (
    echo ✅ WSL is installed on this system
    echo.
    echo To use the full installer, please:
    echo 1. Open WSL terminal
    echo 2. Navigate to this directory
    echo 3. Run: ./install.sh
    echo.
    echo Would you like to open WSL now? (y/n)
    set /p choice=
    if /i "%choice%"=="y" (
        wsl
    )
) else (
    echo ❌ WSL is not installed
    echo.
    echo To install WSL:
    echo 1. Open PowerShell as Administrator
    echo 2. Run: wsl --install
    echo 3. Restart your computer
    echo 4. Run this installer again
    echo.
    echo Alternatively, you can use the native Windows installer:
    echo   install.bat
    echo.
    echo Note: The native Windows installer has limited functionality.
)

echo.
echo ========================================
echo Manual Installation Options
echo ========================================
echo.
echo If you prefer to install manually:
echo.
echo 1. Python: Download from https://python.org
echo 2. OpenCV: pip install opencv-python opencv-contrib-python
echo 3. Elodin Editor: Download from https://github.com/elodin-sys/elodin/releases
echo 4. Other packages: pip install -r base_requirements.txt
echo.
echo For the best experience, we strongly recommend using WSL.
echo.

pause
