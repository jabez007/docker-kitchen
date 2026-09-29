# syntax=docker/dockerfile:1

# install.sh and .install/ come from the repo root through a build context named
# "setup", which replaces this stage:
#   docker build --build-context setup=.. -t astro-nvim .
# compose.yaml and CI pass it. Without it, this stage fails with that hint.
FROM busybox:1 AS setup
RUN echo "Missing build context 'setup'. Build with: docker build --build-context setup=.. ." >&2 && exit 1

FROM debian:stable-slim

# Create a non-root user
ARG DEVUSER_NAME=dev
RUN useradd -ms /bin/bash ${DEVUSER_NAME}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# The setup scripts and setup.conf are bind-mounted rather than copied, so they
# never end up in an image layer.

# Install system-wide development environment
RUN --mount=type=bind,from=setup,target=/opt/dev-setup \
  --mount=type=bind,source=setup.conf,target=/opt/setup.conf \
  bash /opt/dev-setup/install.sh --config /opt/setup.conf --system-wide base go editor && \
  apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy the entrypoint script into the container
COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

# Switch to non-root user
USER ${DEVUSER_NAME}
ENV USER=${DEVUSER_NAME}
WORKDIR /home/${DEVUSER_NAME}

# Set shell for ToggleTerm and Deno installer
ENV SHELL="/bin/bash"

# Set up user-level development environment. ~/.nvm/current links to the
# default Node so PATH can point at it without loading nvm.
RUN --mount=type=bind,from=setup,target=/opt/dev-setup \
  --mount=type=bind,source=setup.conf,target=/opt/setup.conf \
  bash /opt/dev-setup/install.sh --config /opt/setup.conf node config && \
  source ~/.nvm/nvm.sh && \
  ln -sfn ~/.nvm/versions/node/"$(nvm version default)" ~/.nvm/current

# install.sh adds these to PATH in shell startup files, which the entrypoint,
# `docker exec` and Neovim's jobs never read
ENV PATH="/home/${DEVUSER_NAME}/.nvm/current/bin:/home/${DEVUSER_NAME}/.deno/bin:/usr/local/go/bin:/home/${DEVUSER_NAME}/go/bin:${PATH}"

# Create directories for volume mounts and a default lazygit config
RUN mkdir -p /home/${DEVUSER_NAME}/.local/share/nvim \
  /home/${DEVUSER_NAME}/.local/state/nvim \
  /home/${DEVUSER_NAME}/.cache/nvim \
  /home/${DEVUSER_NAME}/.config/lazygit && \
  touch /home/${DEVUSER_NAME}/.config/lazygit/config.yml

# Plugins, state and cache persist in volumes. The config in ~/.config/nvim
# stays in the image, so rebuilding the image updates it.
VOLUME ["/home/${DEVUSER_NAME}/.local/share/nvim", "/home/${DEVUSER_NAME}/.local/state/nvim", "/home/${DEVUSER_NAME}/.cache/nvim"]

# Start nvim
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
