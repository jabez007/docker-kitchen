# AstroNvim Docker Environment

This repository contains a Dockerfile to set up a development environment with AstroNvim and other commonly used tools.
It includes essential tools for coding in various languages, and ensures that your Neovim configuration and environment are consistent across different machines.

## Features

- **Pre-installed tools** like Neovim, LazyGit, Bottom, and more.
- **Latest stable version of AstroNvim** configured out of the box.
- **Support for both** amd64 and arm64 architectures.
- **Non-root user** setup with bash as the default shell.

### Included Tools

The following tools and packages are installed:

| Tool    | Description                     |
| ------- | ------------------------------- |
| bash    | Default shell                   |
| curl    | Command-line file transfer tool |
| git     | Version control system          |
| lua     | Lua interpreter                 |
| nodejs  | JavaScript runtime              |
| npm     | Node.js package manager         |
| python3 | Python interpreter              |
| go      | Go programming language         |
| ripgrep | Fast search utility             |
| lazygit | Simple terminal UI for Git      |
| bottom  | System monitoring tool          |

## Build Arguments

The Dockerfile includes the following build arguments:

| Argument     | Description                                         | Default Value |
| ------------ | --------------------------------------------------- | ------------- |
| DEVUSER_NAME | Username for the non-root user inside the container | dev           |
| TARGETARCH   | Architecture of the Docker image (amd64 or arm64)   | Auto-detected |

These arguments can be passed during the build process using the --build-arg flag.

## Usage

### Bash scripts

If you wish to install this on your machine rather than run it as a Docker container
you just need to run the two bash scripts.

```bash
curl -fsSL https://raw.githubusercontent.com/jabez007/docker-kitchen/master/astro-nvim/install.sh | sudo bash
```

and

```bash
curl -fsSL https://raw.githubusercontent.com/jabez007/docker-kitchen/master/astro-nvim/setup.sh | bash
```

### Build the Docker image

with a specific non-root user

```bash
docker build --build-arg DEVUSER_NAME=mydevuser -t astronvim-env .
```

### Run the Docker container

mounting your local project directory to work on files

```bash
docker run --rm -v $(pwd):/home/mydevuser/workspace -it astronvim-env /home/mydevuser/workspace
```

## Contributing

Feel free to fork this repository and submit pull requests if you have improvements or suggestions.

## License

This project is licensed under the MIT License.
