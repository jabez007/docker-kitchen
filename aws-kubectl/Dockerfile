FROM --platform=$BUILDPLATFORM debian:stable-slim

ARG AWS_REGION
ARG EKS_CLUSTER

# Set target architecture variable
ARG TARGETARCH

#  Enable the arm64 architecture
RUN if [ "$TARGETARCH" = "arm64" ]; then \
    dpkg --add-architecture arm64; \
  fi

# Install dependencies
RUN apt-get update && apt-get install -y \
  watch \
  unzip \
  bash \
  curl \
  jq \
  yq

# Install dependency for AWS CLI on arm64
RUN if [ "$TARGETARCH" = "arm64" ]; then \
    apt-get install -y \
      libc6:arm64 \
      zlib1g:arm64; \
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
  && unzip -q awscliv2.zip \
  && ./aws/install \
  && rm -rf awscliv2.zip aws
  
# Verify aws cli install
RUN aws --version

# Set environment variables for alias
ENV AWS_REGION=${AWS_REGION}
ENV EKS_CLUSTER=${EKS_CLUSTER}

# Copy Amazon's certificate into the container
# This can be used to also allow the container to work in corporate networks with outbound SSL inspection
COPY Amazon_Root_CA_1.pem /root/Amazon_Root_CA_1.pem

# Tell AWS CLI to use it
ENV AWS_CA_BUNDLE=/root/Amazon_Root_CA_1.pem

# Copy in helper script for JSON formatted log files
COPY json_ppc.sh /usr/local/bin/json_ppc.sh

# Make the helper script executable
RUN chmod +x /usr/local/bin/json_ppc.sh

# Add alias for help script
RUN echo "alias jsonppc='/usr/local/bin/json_ppc.sh'" >> /root/.bashrc

# Copy the entrypoint script into the container
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

# Make the entrypoint script executable
RUN chmod +x /usr/local/bin/entrypoint.sh

# Set the working directory
WORKDIR /home/root

# Run the  script and then start a shell
CMD ["/bin/bash", "-c", "/usr/local/bin/entrypoint.sh && exec /bin/bash"]
