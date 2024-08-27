# aws-kubectl

This repository provides a Dockerfile to build an image with the AWS CLI and `kubectl` installed.
The image includes a startup script that ensures AWS Single Sign-On (SSO) is configured when the container starts.
Additionally, the image configures an alias in the `.bashrc` to update the kubeconfig with the specified AWS region and EKS cluster name.

## Features

- AWS CLI pre-installed
- `kubectl` pre-installed
- Automatic SSO configuration at startup
- Alias for updating kubeconfig with AWS region and EKS cluster

## Build Arguments

The Docker image build requires the following arguments:

- `AWS_REGION`: The AWS region where your EKS cluster is located.
- `EKS_CLUSTER`: The name of your EKS cluster.

### Build the Docker Image

To build the Docker image with the required arguments, run:

```bash
docker build --build-arg AWS_REGION=<your-region> --build-arg EKS_CLUSTER=<your-cluster-name> -t aws-kubectl .
```

### Running the Container

To run the container, ensure your local `.aws` directory is mounted to the container's `/root/.aws` directory. This allows the container to access your AWS configurations and credentials, including SSO profiles.

#### Example for Linux/macOS, Windows with WSL, or Git Bash

```bash
docker run -it --rm -v ~/.aws:/root/.aws aws-kubectl
```

#### Example for Windows with PowerShell

```powershell
docker run -it --rm -v ${env:USERPROFILE}\.aws:/root/.aws aws-kubectl
```

### Using the Kubeconfig Alias

Once the container is running, you can use the configured alias to update your kubeconfig:

```bash
update-kubeconfig
```

This command automatically updates the kubeconfig with the AWS region and EKS cluster name specified during the build.

### Notes

- The container must have access to your AWS credentials, so mounting your `.aws` directory is necessary.
- The startup script will check if SSO is configured and prompt you if additional steps are required.

## Contributing

Feel free to open issues or submit pull requests if you find any bugs or have suggestions for improvements.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
