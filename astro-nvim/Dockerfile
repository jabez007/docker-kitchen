FROM --platform=$BUILDPLATFORM debian:stable-slim

# Set target architecture variable
ARG TARGETARCH

# Define a build argument to indicate the Docker build context
ARG DOCKER_BUILD=true

# Create a non-root user
ARG DEVUSER_NAME=dev
RUN useradd -ms /bin/bash ${DEVUSER_NAME}

#  Enable the arm64 architecture
RUN if [ "$TARGETARCH" = "arm64" ]; then \
  dpkg --add-architecture arm64; \
  fi

# Install AstroNvim recommended dependencies
RUN apt-get update && \
  # apt-get upgrade -y && \
  apt-get install -y --no-install-recommends \
  bash \
  curl \
  git \
  lua5.1 \
  #nodejs \ 
  #npm \
  #lazygit \
  #bottom \
  python3 \
  python-is-python3 \
  #golang \
  #neovim \
  ripgrep \
  unzip \
  build-essential \
  ca-certificates \
  libssl-dev \
  libffi-dev \
  openssh-client \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Set the SHELL to bash with pipefail option
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install the latest Go version
RUN curl -L "https://go.dev/dl/$(curl -fsSL "https://go.dev/VERSION?m=text" | grep "^go").linux-$(dpkg --print-architecture).tar.gz" -o go.tar.gz && \
  rm -rf /usr/local/go && \
  tar -C /usr/local -xzf go.tar.gz && \
  rm go.tar.gz
ENV PATH="$PATH:/usr/local/go/bin"

# Install LazyGit
RUN curl -L $(curl -s https://api.github.com/repos/jesseduffield/lazygit/releases/latest | \
  grep "browser_download_url.*lazygit.*$(uname -s).*$(uname -m).*tar.gz" | \
  cut -d : -f 2,3 | tr -d \" | tail -n 1) -o lazygit.tar.gz && \
  tar -C /usr/local/bin -xzf lazygit.tar.gz && \
  rm lazygit.tar.gz

# Install Bottom
RUN curl -L $(curl -s https://api.github.com/repos/ClementTsang/bottom/releases/latest | \
  grep "browser_download_url.*bottom.*$(dpkg --print-architecture).*deb" | \
  cut -d : -f 2,3 | tr -d \" | tail -n 1) -o bottom.deb && \
  dpkg -i bottom.deb && \
  rm bottom.deb

# Download and install the latest Neovim .tar.gz package
RUN curl -LO https://github.com/neovim/neovim/releases/download/stable/nvim-linux64.tar.gz && \
  rm -rf /opt/nvim* && \
  tar -C /opt -xzf nvim-linux64.tar.gz && \
  rm nvim-linux64.tar.gz && \
  ln -s /opt/nvim-linux64/bin/nvim /usr/local/bin/nvim

# Copy the entrypoint script into the container
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Switch to non-root user
USER ${DEVUSER_NAME}
WORKDIR /home/${DEVUSER_NAME}

# Set shell for ToggleTerm and Deno installer
ENV SHELL="/bin/bash"

# Install NVM
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

# Set the SHELL to interactive bash to use nvm
SHELL ["/bin/bash", "-i", "-c"]

# Install latest LTS version of Node.js
RUN nvm install --lts

# Install Deno
RUN curl -SL https://raw.githubusercontent.com/jabez007/deno_install/refs/heads/fix-docker/install.sh | sh -s -- -y

# Clone AstroNvim config
RUN git clone --depth 1 https://github.com/jabez007/AstroNvim-config.git ~/.config/nvim && \
  rm -rf ~/.config/nvim/.git

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
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

