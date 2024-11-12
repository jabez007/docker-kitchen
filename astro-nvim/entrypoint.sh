#!/bin/bash
# Load nvm
source ~/.nvm/nvm.sh

# Run nvim with passed arguments or open the current directory by default
if [ "$#" -eq 0 ]; then
  nvim .
else
  nvim "$@"
fi
