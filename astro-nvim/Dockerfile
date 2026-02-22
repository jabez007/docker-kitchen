FROM debian:stable-slim

# Set target architecture variable
ARG TARGETARCH

# Create a non-root user
ARG DEVUSER_NAME=dev
RUN useradd -ms /bin/bash ${DEVUSER_NAME}

# Enable the arm64 architecture
RUN if [ "$TARGETARCH" = "arm64" ]; then \
  dpkg --add-architecture arm64; \
  fi

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Create setup directory and copy setup files
RUN mkdir -p /opt/dev-setup
COPY install.sh wrapper.sh setup.conf /opt/dev-setup/
COPY .install /opt/dev-setup/.install

# Set GitHub branch for script downloads if needed
ARG GITHUB_BRANCH=master
ENV GITHUB_BRANCH=${GITHUB_BRANCH}

# Make scripts executable
RUN chmod +x /opt/dev-setup/install.sh && \
  chmod +x /opt/dev-setup/wrapper.sh

# Install system-wide development environment
RUN cd /opt/dev-setup && \
  ./wrapper.sh base go editor --system-wide --debug && \
  apt-get clean && rm -rf /var/lib/apt/lists/*

# Clean up setup scripts
RUN rm -rf /opt/dev-setup/install.sh \
  /opt/dev-setup/wrapper.sh \
  /opt/dev-setup/setup.conf \
  /opt/dev-setup/.install

# Copy the entrypoint script into the container
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Switch to non-root user
USER ${DEVUSER_NAME}
ENV USER=${DEVUSER_NAME}
WORKDIR /home/${DEVUSER_NAME}

# Set shell for ToggleTerm and Deno installer
ENV SHELL="/bin/bash"

# Copy setup scripts for user-level configuration
COPY --chown=${DEVUSER_NAME} install.sh wrapper.sh setup.conf /home/${DEVUSER_NAME}/
COPY --chown=${DEVUSER_NAME} .install /home/${DEVUSER_NAME}/.install

# Make user scripts executable
RUN chmod +x /home/${DEVUSER_NAME}/install.sh && \
  chmod +x /home/${DEVUSER_NAME}/wrapper.sh

# Set up user-level development environment
RUN cd /home/${DEVUSER_NAME} && \
  ./wrapper.sh node config --debug && \
  rm -f /home/${DEVUSER_NAME}/setup.log

# Create directories for volume mounts
RUN mkdir -p /home/${DEVUSER_NAME}/.config/nvim \
  /home/${DEVUSER_NAME}/.local/share/nvim \
  /home/${DEVUSER_NAME}/.local/state/nvim \
  /home/${DEVUSER_NAME}/.cache/nvim \
  /home/${DEVUSER_NAME}/.config/lazygit

# Create a default lazygit config
RUN touch /home/${DEVUSER_NAME}/.config/lazygit/config.yml

# Clean up setup scripts
RUN rm -rf /home/${DEVUSER_NAME}/install.sh \
  /home/${DEVUSER_NAME}/wrapper.sh \
  /home/${DEVUSER_NAME}/setup.conf \
  /home/${DEVUSER_NAME}/.install

# Define volumes for persistent storage
VOLUME ["/home/${DEVUSER_NAME}/.config/nvim", "/home/${DEVUSER_NAME}/.local/share/nvim", "/home/${DEVUSER_NAME}/.local/state/nvim", "/home/${DEVUSER_NAME}/.cache/nvim"]

# Start nvim
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
