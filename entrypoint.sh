#!/bin/bash

# Get the list of AWS CLI profiles
profiles=$(aws configure list-profiles)

# Initialize a variable to track if the profile is found
profile_found=false

# Loop through each profile
for profile in $profiles; do
  # Check if the profile uses an SSO session named 'eks'
  sso_session=$(aws configure get sso_session --profile $profile)
  if [ "$sso_session" == "eks" ]; then
    profile_found=true
    profile_name=$profile
    break
  fi
done

# Execute the appropriate command based on whether the profile was found
if [ "$profile_found" == true ]; then
  echo "'eks' profile found. Running 'aws sso login --profile'."
  aws sso login --profile $profile_name
else
  echo "'eks' profile not found. Running 'aws configure sso'."
  export AWS_SSO_SESSION_NAME="eks"
  aws configure sso

  # Get the newly configured profile name
  profiles=$(aws configure list-profiles)
  for profile in $profiles; do
    sso_session=$(aws configure get sso_session --profile $profile)
    if [ "$sso_session" == "eks" ]; then
      profile_name=$profile
      break
    fi
  done
fi

# Update kubeconfig
echo "Updating kubeconfig."
aws eks update-kubeconfig --profile $profile_name --region $AWS_REGION --name $EKS_CLUSTER

# Add alias to .bashrc
echo "Adding alias to .bashrc."
echo "alias update-kubeconfig='aws eks update-kubeconfig --profile $profile_name --region \$AWS_REGION --name \$EKS_CLUSTER'" >> /root/.bashrc