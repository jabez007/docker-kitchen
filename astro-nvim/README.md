# AstroNvim Docker environment

A Debian image with Neovim, the [AstroNvim config](https://github.com/jabez007/AstroNvim-config), and the language tools it needs.
Plugins live in Docker volumes, so only the first run installs them.

The build-and-push workflow publishes `ghcr.io/jabez007/astro-nvim:latest` for amd64 and arm64.

## What's in the image

The repo's `install.sh` builds it (`base go editor` as root, then `node config` as the `dev` user):

| Tool                   | Notes                                        |
| ---------------------- | -------------------------------------------- |
| Neovim                 | Latest stable release                        |
| AstroNvim config       | From `ASTRONVIM_REPO` in `setup.conf`        |
| Go                     | Latest release                               |
| Node.js and npm        | Latest LTS through nvm                       |
| Deno                   | Latest release                               |
| LazyGit, Bottom        | Latest releases                              |
| git, curl, ripgrep, jq | Debian packages                              |
| python3, lua           | Debian packages                              |
| gcc, make              | For Treesitter parsers and native extensions |

Go, Node and Deno are on `PATH` for Neovim and `docker exec` shells, not only for login shells.

## Build arguments

| Argument     | Description                              | Default |
| ------------ | ---------------------------------------- | ------- |
| DEVUSER_NAME | Name of the non-root user in the image   | dev     |

## Usage

### Docker Compose

Add a `compose.yaml` to your project:

```yaml
services:
  nvim-dev:
    image: ghcr.io/jabez007/astro-nvim:latest
    volumes:
      # Persist plugins, state and cache
      - nvim-share:/home/dev/.local/share/nvim
      - nvim-state:/home/dev/.local/state/nvim
      - nvim-cache:/home/dev/.cache/nvim

      # Your project
      - ./:/home/dev/workspace

    working_dir: /home/dev/workspace
    stdin_open: true
    tty: true
    environment:
      - TERM=xterm-256color

volumes:
  nvim-share:
  nvim-state:
  nvim-cache:
```

Then run:

```bash
# The first run installs plugins and Mason tools
docker compose run --rm nvim-dev

# Or start it in the background and attach
docker compose up -d nvim-dev
docker compose exec nvim-dev nvim
```

### Docker run

```bash
docker run --rm -it \
  -v nvim-share:/home/dev/.local/share/nvim \
  -v nvim-state:/home/dev/.local/state/nvim \
  -v nvim-cache:/home/dev/.cache/nvim \
  -v "$(pwd)":/home/dev/workspace \
  -w /home/dev/workspace \
  ghcr.io/jabez007/astro-nvim:latest
```

### Building it yourself

The Dockerfile reads `install.sh` and `.install/` from the repo root through a build context named `setup`.
From this directory:

```bash
docker build --build-context setup=.. -t astro-nvim .

# or, with this directory's compose.yaml (mounts the repo root, or $WORKSPACE)
docker compose build
docker compose run --rm nvim-dev
```

Pass `--build-arg DEVUSER_NAME=me` for a different user, and change `/home/dev` in the volume paths to match.

## Startup modes

The entrypoint installs plugins on the first interactive run, then starts Neovim.

```bash
# Start Neovim
docker run --rm -it ghcr.io/jabez007/astro-nvim:latest

# Open a file
docker run --rm -it ghcr.io/jabez007/astro-nvim:latest myfile.txt

# Start bash instead
docker run --rm -it ghcr.io/jabez007/astro-nvim:latest bash

# Sync plugins and install Mason tools again
docker run --rm -it ghcr.io/jabez007/astro-nvim:latest setup

# Delete plugins, Mason tools, state and cache
docker run --rm -it ghcr.io/jabez007/astro-nvim:latest clean
```

`setup` runs `Lazy! sync`, then `MasonToolsInstallSync` if the config uses mason-tool-installer.
Add the volume flags from above to `setup` and `clean`, or they act on a throwaway container.

## Volumes

| Volume path           | Holds                          |
| --------------------- | ------------------------------ |
| `~/.local/share/nvim` | Plugins (lazy) and Mason tools |
| `~/.local/state/nvim` | Undo history, shada, logs      |
| `~/.cache/nvim`       | Caches                         |

`~/.config/nvim` isn't a volume.
The config comes from the image, so pulling or rebuilding the image updates it.
If a new config version adds plugins, Lazy installs them on the next start, or run `setup`.

Use separate volume names to keep plugins apart between projects, e.g. `-v nvim-share-project1:/home/dev/.local/share/nvim`.

### Clean up

```bash
# Remove the volumes for a fresh start
docker volume rm nvim-share nvim-state nvim-cache

# Or, with Compose
docker compose down -v
```

## Troubleshooting

If plugins are broken, run `clean` and then `setup` with your volumes attached.

```bash
# Check volume disk usage
docker system df -v
```

## Installing locally instead

To set up the same tools on your own machine, use the repo's `install.sh` with the same components as this image:

```bash
curl -fsSL https://raw.githubusercontent.com/jabez007/docker-kitchen/master/install.sh | bash -s -- base go node editor config
```

See the [root README](../README.md) for all components and options.

## License

MIT
