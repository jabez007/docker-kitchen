#!/bin/bash

# Check if the 'eks' profile exists
aws configure list-profiles | grep -q '^eks$'
if [ $? -eq 0 ]; then
  echo "Profile 'eks' found. Running 'aws sso login --profile eks'."
  aws sso login --profile eks
else
  echo "Profile 'eks' not found. Running 'aws configure sso'."
  aws configure sso
fi
