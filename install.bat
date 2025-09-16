@echo off
REM Cross-Platform Flash Installation System - Windows Batch Version
REM Supports: Windows (WSL recommended, chocolatey/winget fallback)

setlocal enabledelayedexpansion

REM Colors (limited in batch)
set "LOG_FILE=flash_install.log"
set "FLASH_DIR=%~dp0"
set "SKIP_WSL=%1"

REM Logging functions
:log
echo [%date% %time%] %~1 >> "%LOG_FILE%"
echo [%date% %time%] %~1
goto :eof

:log_warn
echo [%date% %time%] WARNING: %~1 >> "%LOG_FILE%"
echo [%date% %time%] WARNING: %~1
goto :eof

:log_error
echo [%date% %time%] ERROR: %~1 >> "%LOG_FILE%"
echo [%date% %time%] ERROR: %~1
goto :eof

:log_info
echo [%date% %time%] INFO: %~1 >> "%LOG_FILE%"
echo [%date% %time%] INFO: %~1
goto :eof

REM Error handling
:fail
call :log_error "Installation failed: %~1"
exit /b 1

REM Check if running in WSL
:check_wsl
if defined WSL_DISTRO_NAME (
    call :log "Running in WSL: %WSL_DISTRO_NAME%"
    call :log "Switching to Linux installer..."
    call :switch_to_wsl
    exit /b 0
)
goto :eof

REM Install WSL if not present
:install_wsl
call :log "Checking for WSL installation..."
wsl --status >nul 2>&1
if %errorLevel% equ 0 (
    call :log "WSL is already installed"
    exit /b 0
)

call :log "WSL not found. Installing WSL..."

REM Enable WSL feature
call :log "Enabling WSL feature..."
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart

REM Enable Virtual Machine Platform
call :log "Enabling Virtual Machine Platform..."
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

REM Install WSL
call :log "Installing WSL..."
wsl --install --no-distribution

call :log "WSL installation initiated. Please restart your computer and run this script again."
call :log "After restart, WSL will be ready to use."

set /p "restart=Would you like to restart now? (y/N): "
if /i "%restart%"=="y" (
    shutdown /r /t 0
)

exit /b 1

REM Switch to WSL and run Linux installer
:switch_to_wsl
call :log "Switching to WSL environment..."

REM Convert Windows path to WSL path
set "WSL_PATH=%FLASH_DIR%"
set "WSL_PATH=%WSL_PATH:C:=/mnt/c%"
set "WSL_PATH=%WSL_PATH:\=/%"
set "WSL_PATH=%WSL_PATH:/mnt/c/=/mnt/c/%"

call :log "Running Linux installer in WSL at: %WSL_PATH%"

REM Run the Linux installer in WSL
wsl -e bash -c "cd '%WSL_PATH%' && chmod +x install.sh && ./install.sh"

if %errorLevel% equ 0 (
    call :log "Installation completed successfully in WSL!"
    exit /b 0
) else (
    call :log_error "Installation failed in WSL"
    exit /b 1
)

REM Check if running as administrator
:check_admin
net session >nul 2>&1
if %errorLevel% == 0 (
    call :log_warn "Running as administrator. This is not recommended for most operations."
    set /p "continue=Continue anyway? (y/N): "
    if /i not "!continue!"=="y" exit /b 1
) else (
    call :log_info "Not running as administrator (good)"
)
goto :eof

REM Install package manager
:install_package_manager
call :log "Installing package manager..."

REM Try chocolatey first
where choco >nul 2>&1
if %errorLevel% neq 0 (
    call :log "Installing Chocolatey..."
    powershell -Command "Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))"
    if %errorLevel% neq 0 (
        call :log_warn "Chocolatey installation failed, trying winget..."
        where winget >nul 2>&1
        if %errorLevel% neq 0 (
            call :fail "Neither Chocolatey nor winget available. Please install one manually."
        )
        set "PACKAGE_MANAGER=winget"
    ) else (
        set "PACKAGE_MANAGER=choco"
    )
) else (
    call :log "Chocolatey already installed"
    set "PACKAGE_MANAGER=choco"
)
goto :eof

REM Install system packages
:install_system_packages
call :log "Installing system packages..."

if "%PACKAGE_MANAGER%"=="choco" (
    choco install -y cmake git python wget curl
    choco install -y opencv
) else if "%PACKAGE_MANAGER%"=="winget" (
    winget install --id Kitware.CMake
    winget install --id Git.Git
    winget install --id Python.Python.3.9
    winget install --id GNU.Wget
    winget install --id cURL.cURL
    winget install --id OpenCV.OpenCV
)

REM Verify Python installation
python --version >nul 2>&1
if %errorLevel% neq 0 (
    call :fail "Python installation failed or not in PATH"
)
goto :eof

REM Setup Python environment
:setup_python_environment
call :log "Setting up Python environment..."

if not exist "venv" (
    call :log "Creating Python virtual environment..."
    python -m venv venv
    if %errorLevel% neq 0 (
        call :fail "Failed to create virtual environment"
    )
)

call :log "Activating virtual environment..."
call venv\Scripts\activate.bat
if %errorLevel% neq 0 (
    call :fail "Failed to activate virtual environment"
)

call :log "Upgrading pip..."
python -m pip install --upgrade pip

if exist "base_requirements.txt" (
    call :log "Installing Python requirements..."
    pip install -r base_requirements.txt
) else (
    call :log_warn "base_requirements.txt not found, skipping Python package installation"
)
goto :eof

REM Install OpenCV
:install_opencv
call :log "Checking OpenCV installation..."

python -c "import cv2; print(f'OpenCV version: {cv2.__version__}')" >nul 2>&1
if %errorLevel% == 0 (
    call :log "OpenCV already installed"
    goto :eof
)

call :log "Installing OpenCV via pip..."
pip install opencv-python opencv-contrib-python

python -c "import cv2; print(f'OpenCV version: {cv2.__version__}')" >nul 2>&1
if %errorLevel% == 0 (
    call :log "OpenCV installed successfully"
) else (
    call :fail "OpenCV installation failed"
)
goto :eof

REM Main installation function
:main
call :log "Starting cross-platform flash installation..."

REM Check if running in WSL
call :check_wsl
if %errorLevel% equ 0 exit /b 0

REM Check if WSL should be used
if "%SKIP_WSL%" neq "skip" (
    call :log "WSL is recommended for the best experience with elodin-db and other tools."
    set /p "use_wsl=Would you like to install and use WSL? (Y/n): "
    if /i not "%use_wsl%"=="n" (
        call :install_wsl
        if %errorLevel% equ 0 (
            call :switch_to_wsl
            if %errorLevel% equ 0 exit /b 0
            call :log_error "Failed to run Linux installer in WSL"
            exit /b 1
        ) else (
            call :log "WSL installation requires restart. Please restart and run this script again."
            exit /b 0
        )
    )
)

REM Fallback to native Windows installation
call :log "Proceeding with native Windows installation (limited functionality)..."

call :check_admin
if %errorLevel% neq 0 exit /b 1

call :install_package_manager
if %errorLevel% neq 0 exit /b 1

call :install_system_packages
if %errorLevel% neq 0 exit /b 1

call :setup_python_environment
if %errorLevel% neq 0 exit /b 1

call :install_opencv
if %errorLevel% neq 0 exit /b 1

call :log "Installation completed successfully!"
call :log "Note: Some features like elodin-db are not available on native Windows."
call :log "For full functionality, consider using WSL."
call :log "You can now use the Python environment by activating it:"
call :log "  venv\\Scripts\\activate"
goto :eof

REM Run main function
call :main
if %errorLevel% neq 0 exit /b 1

pause
