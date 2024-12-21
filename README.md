# Docker Kitchen

Docker Kitchen is a collection of Dockerfiles and related resources to build and use various Docker images.

## Repository Structure

Each Docker image has its own sub-directory containing:

- A `Dockerfile` for building the image
- Supporting scripts and files as needed

## Installation and Usage Examples

### Run the `install.sh` Script

To use the provided `install.sh` script, you can execute it directly from the repository using `curl`:

```bash
curl -fsSL https://raw.githubusercontent.com/jabez007/docker-kitchen/master/install.sh | bash
```

This will download and execute the script.

### Install NerdFont for Astro-Nvim

You can download and install a NerdFont zip file from the repository using the following command:

```bash
curl -fsSL https://raw.githubusercontent.com/jabez007/docker-kitchen/master/astro-nvim/Mononoki.zip -o Mononoki.zip && \
unzip Mononoki.zip -d ~/.fonts && \
fc-cache -fv
```

## Contributing

Contributions are welcome! Please fork the repository and create a pull request with your changes.

## License

This repository is licensed under the MIT License. See the `LICENSE` file for more details.

