#!/bin/bash
# Configuration file for cross-platform flash installer
# Modify these settings to customize your installation

# Python version to compile from source (Linux only)
PYTHON_VERSION="3.8.10"

# Repository branch for future FSW integration
REPO_BRANCH="main"

# Development tools
INSTALL_BASHDB=false          # Set to true to install bash debugger
INSTALL_ELODIN_EDITOR=true    # Set to false to skip elodin editor installation
INSTALL_ELODIN_DB=true        # Set to false to skip elodin-db installation

# Platform-specific settings
ENABLE_PYTHON_COMPILATION=true  # Set to false to skip Python compilation on Linux
ENABLE_STARTUP_INTEGRATION=true # Set to false to skip startup.sh integration
ENABLE_SUDO_SETUP=true         # Set to false to skip sudo permissions setup

# Logging
VERBOSE_LOGGING=false         # Set to true for more detailed output
