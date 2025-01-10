FROM --platform=$BUILDPLATFORM debian:stable-slim

# Set target architecture variable
ARG TARGETARCH

# Create a non-root user
ARG DEVUSER_NAME=dev
RUN useradd -ms /bin/bash ${DEVUSER_NAME}

#  Enable the arm64 architecture
RUN if [ "$TARGETARCH" = "arm64" ]; then \
  dpkg --add-architecture arm64; \
  fi

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install AstroNvim recommended dependencies
COPY install.sh /root/install.sh
RUN chmod +x /root/install.sh && \
  /root/install.sh --system-wide && \
  apt-get clean && rm -rf /var/lib/apt/lists/* && \
  rm /root/install.sh

# Copy the entrypoint script into the container
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Switch to non-root user
USER ${DEVUSER_NAME}
WORKDIR /home/${DEVUSER_NAME}

# Make sure lazygit config exists
RUN mkdir -p /home/${DEVUSER_NAME}/.config/lazygit && \
  touch /home/${DEVUSER_NAME}/.config/lazygit/config.yml

# Set shell for ToggleTerm and Deno installer
ENV SHELL="/bin/bash"

# Set up user utilities
COPY setup.sh /home/${DEVUSER_NAME}/setup.sh
RUN chmod +x /home/${DEVUSER_NAME}/setup.sh && \
  /home/${DEVUSER_NAME}/setup.sh && \
  rm /home/${DEVUSER_NAME}/setup.sh

# Set the SHELL to interactive bash
SHELL ["/bin/bash", "-i", "-c"]

# Pre-install Lazy and plugins
RUN nvim --headless -c "Lazy! sync" -c "qa!"

# Pre-install Mason tools
# Run Mason commands with explicit plugin loading
RUN nvim --headless +"\
  MasonInstall \
  css-lsp \
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
  json-lsp \
  js-debug-adapter \
  prettierd \
  vtsls \
  vue-language-server \
  " +q

# Start nvim
ENTRYPOINT ["/bin/bash", "-i", "/usr/local/bin/entrypoint.sh"]

