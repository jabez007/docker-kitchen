FROM --platform=$BUILDPLATFORM debian:stable-slim

ARG DEVUSER_NAME=dev

# Set target architecture variable
ARG TARGETARCH

#  Enable the arm64 architecture
RUN if [ "$TARGETARCH" = "arm64" ]; then \
  dpkg --add-architecture arm64; \
  fi

# Install AstroNvim recommended dependencies
RUN apt-get update && \
  #apt-get upgrade -y && \
  apt-get install -y \
  bash \
  curl \
  git \
  lua5.1 \
  nodejs \ 
  npm \
  #lazygit \
  #bottom \
  python3 \
  golang \
  #neovim \
  ripgrep \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install LazyGit
RUN curl -L $(curl -s https://api.github.com/repos/jesseduffield/lazygit/releases/latest | \
  grep "browser_download_url.*lazygit.*$(uname -s).*$(uname -m).*tar.gz" | \
  cut -d : -f 2,3 | tr -d \" | tail -n 1) -o lazygit.tar.gz && \
  tar -xzf lazygit.tar.gz && \
  mv lazygit /usr/local/bin/ && \
  rm -rf lazygit* lazygit.tar.gz

# Install Bottom
RUN curl -L $(curl -s https://api.github.com/repos/ClementTsang/bottom/releases/latest | \
  grep "browser_download_url.*bottom.*$(dpkg --print-architecture).*deb" | \
  cut -d : -f 2,3 | tr -d \" | tail -n 1) -o bottom.deb && \
  dpkg -i bottom.deb && \
  rm bottom.deb

# Download and install the latest Neovim .tar.gz package
RUN curl -LO https://github.com/neovim/neovim/releases/download/stable/nvim-linux64.tar.gz && \
  rm -rf /opt/nvim && \
  tar -C /opt -xzf nvim-linux64.tar.gz && \
  rm nvim-linux64.tar.gz && \
  ln -s /opt/nvim-linux64/bin/nvim /usr/local/bin/nvim

# Create a non-root user
RUN useradd -ms /bin/bash ${DEVUSER_NAME}

# Switch to non-root user
USER ${DEVUSER_NAME}

# Set the working directory
WORKDIR /home/${DEVUSER_NAME}

# Clone AstroNvim config
RUN git clone --depth 1 https://github.com/jabez007/AstroNvim-config.git ~/.config/nvim && \
  rm -rf ~/.config/nvim/.git

# Install Lazy and plugins in a headless way
RUN nvim --headless -c "Lazy! sync" -c "qa!"

# Start nvim
ENTRYPOINT ["nvim"]

# Open present working directory
CMD ["."]
