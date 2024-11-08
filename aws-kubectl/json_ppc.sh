#!/bin/bash

####
# attempts to pretty print and colorize JSON formatted log file
# usage:
#   ./json_ppc.sh your_file.json
#   cat your_file.json | ./json_ppc.sh
####

# Define color codes
RED='\033[0;31m'
YELLOW='\033[0;33m'
MAGENTA='\033[0;35m'
GREEN='\033[0;32m'
WHITE='\033[0;37m'
NC='\033[0m' # No Color

# Function to pretty print JSON with color based on the level attribute
pretty_print_json() {
  while IFS= read -r line; do
    level=$(echo "$line" | jq -r '.level')
    case "$level" in
      "error")
        echo -e "${RED}$(echo "$line" | jq .)${NC}"
        ;;
      "warn")
        echo -e "${YELLOW}$(echo "$line" | jq .)${NC}"
        ;;
      "http")
        echo -e "${MAGENTA}$(echo "$line" | jq .)${NC}"
        ;;
      "info")
        echo -e "${GREEN}$(echo "$line" | jq .)${NC}"
        ;;
      "debug")
        echo -e "${WHITE}$(echo "$line" | jq .)${NC}"
        ;;
      *)
        echo "$line" | jq .
        ;;
    esac
  done
}

# Check if input is from a pipe or a file
if [ -t 0 ]; then
  # No input from pipe, check if a file is provided as an argument
  if [ -z "$1" ]; then
    echo "Usage: $0 <file>"
    exit 1
  fi
  # Read from file
  pretty_print_json < "$1"
else
  # Read from pipe
  pretty_print_json
fi
