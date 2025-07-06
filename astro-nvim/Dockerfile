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

# Make scripts executable
RUN chmod +x /opt/dev-setup/install.sh && \
  chmod +x /opt/dev-setup/wrapper.sh

# Install system-wide development environment
RUN cd /opt/dev-setup && \
  ./wrapper.sh base go editor --system-wide --debug && \
  apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy the entrypoint script into the container
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Switch to non-root user
USER ${DEVUSER_NAME}
ENV USER=${DEVUSER_NAME}
WORKDIR /home/${DEVUSER_NAME}

# Copy setup scripts for user-level configuration
COPY --chown=${DEVUSER_NAME} install.sh wrapper.sh setup.conf /home/${DEVUSER_NAME}/

# Make user scripts executable
RUN chmod +x /home/${DEVUSER_NAME}/install.sh && \
  chmod +x /home/${DEVUSER_NAME}/wrapper.sh

# Set up user-level development environment
RUN cd /home/${DEVUSER_NAME} && \
  ./wrapper.sh node config --debug && \
  rm -f /home/${DEVUSER_NAME}/setup.log

# Make sure lazygit config exists
RUN mkdir -p /home/${DEVUSER_NAME}/.config/lazygit && \
  touch /home/${DEVUSER_NAME}/.config/lazygit/config.yml

# Set shell for ToggleTerm and Deno installer
ENV SHELL="/bin/bash"

# Set the SHELL to interactive bash
SHELL ["/bin/bash", "-i", "-c"]

# Pre-install Lazy and plugins
RUN nvim --headless -c "Lazy! sync" -c "qa!"

# Pre-install Mason tools
# Run Mason commands with explicit plugin loading
RUN nvim --headless +"\
  MasonInstall \
  basedpyright \
  css-lsp \
  debugpy \
  delve \
  deno \
  eslint-lsp \
  goimports \
  gomodifytags \
  gopls \
  gotests \
  html-lsp \
  iferr \
  impl \
  isort \
  json-lsp \
  js-debug-adapter \
  prettierd \
  vtsls \
  vue-language-server \
  " +q

# Clean up setup scripts (optional - remove if you want to keep them for later use)
RUN rm -f /home/${DEVUSER_NAME}/install.sh \
  /home/${DEVUSER_NAME}/wrapper.sh \
  /home/${DEVUSER_NAME}/setup.conf

# Start nvim
ENTRYPOINT ["/bin/bash", "-i", "/usr/local/bin/entrypoint.sh"]
