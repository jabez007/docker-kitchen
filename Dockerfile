ARG AWS_REGION
ARG EKS_CLUSTER

FROM --platform=$BUILDPLATFORM debian:stable-slim

# Set target architecture variable
ARG TARGETARCH

# Install dependencies
RUN apt-get update && apt-get install -y \
  unzip \
  bash \
  curl \
  jq \
  yq

# Install dependency for AWS CLI on arm64
RUN if [ "$TARGETARCH" = "arm64" ]; then \
    apt-get install -y libc6:arm64; \
  fi

# Clean up apt-get afterwards
RUN rm -rf /var/lib/apt/lists/*

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${TARGETARCH}/kubectl" \
  && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  
# Verify kubectl install
RUN kubectl version --client

# Install aws cli
RUN if [ "$TARGETARCH" = "arm64" ]; then \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"; \
  else \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"; \
  fi \
  && unzip awscliv2.zip \
  && ./aws/install \
  && rm -rf awscliv2.zip aws
  
# Verify aws cli install
RUN aws --version

# Add aliases to .bashrc
RUN echo "alias update-kubeconfig='aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER}'" >> /root/.bashrc

# Copy the entrypoint script into the container
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

# Make the entrypoint script executable
RUN chmod +x /usr/local/bin/entrypoint.sh

# Set the entrypoint to the script
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Set the working directory
WORKDIR /home/root

# Set bash as the default shell
CMD ["/bin/bash"]