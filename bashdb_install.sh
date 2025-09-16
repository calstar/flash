#!/bin/bash

#set -e
RESET='\033[0m'
COLOR='\033[1;32m'

function msg {
  echo -e "${COLOR}$(date): $1${RESET}"
}

function fail {
  msg "Error : $?"
  exit 1
}

# Detect directory of this script
FLASH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || fail
# Detect Bash Version
BASH_MAJOR_MINOR=$(bash --version | head -n1 | cut -d ' ' -f4 | cut -d '.' -f1,2) || fail
echo "Detected Bash version: $BASH_MAJOR_MINOR" || fail
# Install pre-requisites
sudo apt install -y autoconf automake m4 texinfo
cd $FLASH_DIR/resources || fail
git clone https://github.com/Trepan-Debuggers/bashdb.git || fail
cd bashdb || fail
git checkout bash-$BASH_MAJOR_MINOR || fail
# Make the source
echo "Installing the bash debugger"
./autogen.sh || fail
./configure || fail
make || fail
sudo make install || fail
# Check if it works 
bashdb --version || fail
echo "Cleaning up the source directory!"
cd .. || fail 
rm -rf bashdb || fail
echo "If this script doesnt error out, you're good to go! Meaning, if you got here, you should be set. Congrats, and goodbye!" || fail
