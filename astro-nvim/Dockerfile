# syntax=docker/dockerfile:1
FROM debian:stable-slim

# Create a non-root user
ARG DEVUSER_NAME=dev
RUN useradd -ms /bin/bash ${DEVUSER_NAME}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Branch install.sh downloads from if a module is missing from the build context
ARG GITHUB_BRANCH=master

# The build context (install.sh, .install/, setup.conf) is bind-mounted rather
# than copied, so the setup scripts never end up in an image layer.
# CI copies install.sh and .install/ from the repo root into this directory first.

# Install system-wide development environment
RUN --mount=type=bind,target=/opt/dev-setup \
  bash /opt/dev-setup/install.sh --system-wide base go editor && \
  apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy the entrypoint script into the container
COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

# Switch to non-root user
USER ${DEVUSER_NAME}
ENV USER=${DEVUSER_NAME}
WORKDIR /home/${DEVUSER_NAME}

# Set shell for ToggleTerm and Deno installer
ENV SHELL="/bin/bash"

# Set up user-level development environment
RUN --mount=type=bind,target=/opt/dev-setup \
  bash /opt/dev-setup/install.sh node config

# Create directories for volume mounts and a default lazygit config
RUN mkdir -p /home/${DEVUSER_NAME}/.config/nvim \
  /home/${DEVUSER_NAME}/.local/share/nvim \
  /home/${DEVUSER_NAME}/.local/state/nvim \
  /home/${DEVUSER_NAME}/.cache/nvim \
  /home/${DEVUSER_NAME}/.config/lazygit && \
  touch /home/${DEVUSER_NAME}/.config/lazygit/config.yml

# Define volumes for persistent storage
VOLUME ["/home/${DEVUSER_NAME}/.config/nvim", "/home/${DEVUSER_NAME}/.local/share/nvim", "/home/${DEVUSER_NAME}/.local/state/nvim", "/home/${DEVUSER_NAME}/.cache/nvim"]

# Start nvim
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
