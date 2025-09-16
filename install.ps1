# Cross-Platform Flash Installation System - PowerShell Version
# Supports: Windows (WSL recommended, chocolatey/winget fallback)

param(
    [switch]$Force,
    [switch]$Verbose,
    [switch]$SkipWSL
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Configuration
$LogFile = "flash_install.log"
$FlashDir = $PSScriptRoot

# Logging functions
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Level`: $Message"
    
    # Write to console with colors
    switch ($Level) {
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "INFO" { Write-Host $logMessage -ForegroundColor Blue }
        default { Write-Host $logMessage -ForegroundColor Green }
    }
    
    # Write to log file
    Add-Content -Path $LogFile -Value $logMessage
}

function Write-LogError {
    param([string]$Message)
    Write-Log $Message "ERROR"
}

function Write-LogWarning {
    param([string]$Message)
    Write-Log $Message "WARNING"
}

function Write-LogInfo {
    param([string]$Message)
    Write-Log $Message "INFO"
}

# Error handling
function Invoke-Fail {
    param([string]$Message)
    Write-LogError "Installation failed: $Message"
    exit 1
}

# Check if running in WSL
function Test-WSL {
    return $env:WSL_DISTRO_NAME -ne $null
}

# Install WSL if not present
function Install-WSL {
    Write-Log "Checking for WSL installation..."
    
    try {
        $wslStatus = wsl --status 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Log "WSL is already installed"
            return $true
        }
    } catch {
        # WSL not installed
    }
    
    Write-Log "WSL not found. Installing WSL..."
    
    # Enable WSL feature
    Write-Log "Enabling WSL feature..."
    dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
    
    # Enable Virtual Machine Platform
    Write-Log "Enabling Virtual Machine Platform..."
    dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
    
    # Install WSL
    Write-Log "Installing WSL..."
    wsl --install --no-distribution
    
    Write-Log "WSL installation initiated. Please restart your computer and run this script again."
    Write-Log "After restart, WSL will be ready to use."
    
    $restart = Read-Host "Would you like to restart now? (y/N)"
    if ($restart -match "^[Yy]$") {
        Restart-Computer -Force
    }
    
    return $false
}

# Switch to WSL and run Linux installer
function Switch-ToWSL {
    Write-Log "Switching to WSL environment..."
    
    # Convert Windows path to WSL path
    $wslPath = $FlashDir -replace '^([A-Z]):', '/mnt/$1' -replace '\\', '/'
    $wslPath = $wslPath.ToLower()
    
    Write-Log "Running Linux installer in WSL at: $wslPath"
    
    # Run the Linux installer in WSL
    wsl -e bash -c "cd '$wslPath' && chmod +x install.sh && ./install.sh"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Log "Installation completed successfully in WSL!"
        return $true
    } else {
        Write-LogError "Installation failed in WSL"
        return $false
    }
}

# Check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Install package manager
function Install-PackageManager {
    Write-Log "Installing package manager..."
    
    # Try chocolatey first
    try {
        $chocoVersion = choco --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Chocolatey already installed (version: $chocoVersion)"
            return "choco"
        }
    } catch {
        # Chocolatey not found, try to install it
    }
    
    # Install Chocolatey
    try {
        Write-Log "Installing Chocolatey..."
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        
        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        # Verify installation
        $chocoVersion = choco --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Chocolatey installed successfully (version: $chocoVersion)"
            return "choco"
        }
    } catch {
        Write-LogWarning "Chocolatey installation failed, trying winget..."
    }
    
    # Try winget
    try {
        $wingetVersion = winget --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Using winget (version: $wingetVersion)"
            return "winget"
        }
    } catch {
        # winget not available
    }
    
    Invoke-Fail "Neither Chocolatey nor winget available. Please install one manually."
}

# Install system packages
function Install-SystemPackages {
    param([string]$PackageManager)
    
    Write-Log "Installing system packages using $PackageManager..."
    
    $packages = @(
        "cmake",
        "git", 
        "python",
        "wget",
        "curl"
    )
    
    if ($PackageManager -eq "choco") {
        foreach ($package in $packages) {
            Write-Log "Installing $package..."
            choco install -y $package
            if ($LASTEXITCODE -ne 0) {
                Write-LogWarning "Failed to install $package via chocolatey"
            }
        }
        
        # Install OpenCV
        Write-Log "Installing OpenCV..."
        choco install -y opencv
    } elseif ($PackageManager -eq "winget") {
        $wingetPackages = @{
            "cmake" = "Kitware.CMake"
            "git" = "Git.Git"
            "python" = "Python.Python.3.9"
            "wget" = "GNU.Wget"
            "curl" = "cURL.cURL"
            "opencv" = "OpenCV.OpenCV"
        }
        
        foreach ($package in $packages) {
            $packageId = $wingetPackages[$package]
            if ($packageId) {
                Write-Log "Installing $package ($packageId)..."
                winget install --id $packageId --accept-package-agreements --accept-source-agreements
                if ($LASTEXITCODE -ne 0) {
                    Write-LogWarning "Failed to install $package via winget"
                }
            }
        }
        
        # Install OpenCV
        Write-Log "Installing OpenCV..."
        winget install --id "OpenCV.OpenCV" --accept-package-agreements --accept-source-agreements
    }
    
    # Verify Python installation
    try {
        $pythonVersion = python --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Python installed successfully: $pythonVersion"
        } else {
            Invoke-Fail "Python installation failed or not in PATH"
        }
    } catch {
        Invoke-Fail "Python installation failed or not in PATH"
    }
}

# Setup Python environment
function Setup-PythonEnvironment {
    Write-Log "Setting up Python environment..."
    
    # Create virtual environment
    if (-not (Test-Path "venv")) {
        Write-Log "Creating Python virtual environment..."
        python -m venv venv
        if ($LASTEXITCODE -ne 0) {
            Invoke-Fail "Failed to create virtual environment"
        }
    }
    
    # Activate virtual environment
    Write-Log "Activating virtual environment..."
    & ".\venv\Scripts\Activate.ps1"
    if ($LASTEXITCODE -ne 0) {
        Invoke-Fail "Failed to activate virtual environment"
    }
    
    # Upgrade pip
    Write-Log "Upgrading pip..."
    python -m pip install --upgrade pip
    if ($LASTEXITCODE -ne 0) {
        Write-LogWarning "Failed to upgrade pip"
    }
    
    # Install Python requirements
    if (Test-Path "base_requirements.txt") {
        Write-Log "Installing Python requirements..."
        pip install -r base_requirements.txt
        if ($LASTEXITCODE -ne 0) {
            Write-LogWarning "Some Python packages may have failed to install"
        }
    } else {
        Write-LogWarning "base_requirements.txt not found, skipping Python package installation"
    }
}

# Install OpenCV
function Install-OpenCV {
    Write-Log "Checking OpenCV installation..."
    
    try {
        $opencvVersion = python -c "import cv2; print(f'OpenCV version: {cv2.__version__}')" 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Log "OpenCV already installed: $opencvVersion"
            return
        }
    } catch {
        # OpenCV not installed
    }
    
    Write-Log "Installing OpenCV via pip..."
    pip install opencv-python opencv-contrib-python
    if ($LASTEXITCODE -ne 0) {
        Invoke-Fail "OpenCV installation failed"
    }
    
    # Verify installation
    try {
        $opencvVersion = python -c "import cv2; print(f'OpenCV version: {cv2.__version__}')" 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Log "OpenCV installed successfully: $opencvVersion"
        } else {
            Invoke-Fail "OpenCV installation verification failed"
        }
    } catch {
        Invoke-Fail "OpenCV installation verification failed"
    }
}

# Main installation function
function Main {
    Write-Log "Starting cross-platform flash installation..."
    
    # Check if running in WSL
    if (Test-WSL) {
        Write-Log "Running in WSL environment. Switching to Linux installer..."
        if (Switch-ToWSL) {
            return
        } else {
            Write-LogError "Failed to run Linux installer in WSL"
            exit 1
        }
    }
    
    # Check if WSL should be used
    if (-not $SkipWSL) {
        Write-Log "WSL is recommended for the best experience with elodin-db and other tools."
        $useWSL = Read-Host "Would you like to install and use WSL? (Y/n)"
        
        if ($useWSL -notmatch "^[Nn]$") {
            if (Install-WSL) {
                if (Switch-ToWSL) {
                    return
                } else {
                    Write-LogError "Failed to run Linux installer in WSL"
                    exit 1
                }
            } else {
                Write-Log "WSL installation requires restart. Please restart and run this script again."
                exit 0
            }
        }
    }
    
    # Fallback to native Windows installation
    Write-Log "Proceeding with native Windows installation (limited functionality)..."
    
    # Check if running as administrator
    if (Test-Administrator) {
        Write-LogWarning "Running as administrator. This is not recommended for most operations."
        if (-not $Force) {
            $continue = Read-Host "Continue anyway? (y/N)"
            if ($continue -notmatch "^[Yy]$") {
                exit 1
            }
        }
    } else {
        Write-LogInfo "Not running as administrator (good)"
    }
    
    # Install package manager
    $packageManager = Install-PackageManager
    
    # Install system packages
    Install-SystemPackages -PackageManager $packageManager
    
    # Setup Python environment
    Setup-PythonEnvironment
    
    # Install OpenCV
    Install-OpenCV
    
    Write-Log "Installation completed successfully!"
    Write-Log "Note: Some features like elodin-db are not available on native Windows."
    Write-Log "For full functionality, consider using WSL."
    Write-Log "You can now use the Python environment by activating it:"
    Write-Log "  .\venv\Scripts\Activate.ps1"
}

# Run main function
try {
    Main
} catch {
    Write-LogError "Installation failed with error: $($_.Exception.Message)"
    exit 1
}
