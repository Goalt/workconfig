# workconfig

A Debian-based Docker development environment pre-configured with essential tools for cloud development, VPN connectivity, and software development workflows.

## Overview

This project provides a containerized development environment built on Debian Bookworm, equipped with a comprehensive set of tools commonly needed for modern software development, particularly for AWS-based projects and remote work scenarios.

## Features

### Pre-installed Tools

- **Cloud Tools**
  - AWS CLI v2 (with architecture-specific support for x86_64 and aarch64)
  - AWS Session Manager Plugin for secure remote access

- **VPN & Networking**
  - OpenVPN3 client with helper aliases for easy session management
  - Network utilities (net-tools, curl, wget)
  - Custom DNS configuration (defaults to Google DNS 8.8.8.8)

- **Development Tools**
  - Git version control
  - Go (version 1.25.3)
  - go-swagger (v0.31.0) for API development
  - Visual Studio Code CLI for remote development
  - PostgreSQL client (psql) for database management
  - VS Code Extensions (automatically installed):
    - GitLens (eamodio.gitlens)
    - GitHub Copilot (GitHub.copilot)
    - GitHub Copilot Workspace (github.copilot-workspace)
    - SQLTools (mtxr.sqltools)
    - SQLTools MySQL Driver (mtxr.sqltools-driver-mysql)
    - SQLTools PostgreSQL Driver (mtxr.sqltools-driver-pg)
    - PlantUML (well-ar.plantuml)
    - Kubernetes Tools (ms-kubernetes-tools.vscode-kubernetes-tools)
    - UUID Generator (netcorext.uuid-generator)
    - REST Client (humao.rest-client)
    - Tooltitude (tooltitudeteam.tooltitude)
    - Go Outliner (766b.go-outliner)

- **System Utilities**
  - vim text editor
  - htop process monitor
  - jq JSON processor
  - OpenSSH Server for remote access
  - Standard Unix utilities

### Architecture Support

The container image supports multiple architectures:
- x86_64 (amd64)
- aarch64 (arm64)

All tool installations automatically detect and install the appropriate architecture-specific binaries.

## Usage

### Building the Container

```bash
docker build -t workconfig .
```

### Running the Container

Basic usage with infinite sleep (keeps container running):

```bash
docker run -d --name workenv workconfig
```

With SSH port exposed:

```bash
docker run -d -p 2222:22 --name workenv workconfig
```

With volume mounts for persistent data:

```bash
docker run -d \
  --name workenv \
  -p 2222:22 \
  -v /path/to/data:/data/app \
  workconfig
```

### Accessing the Container

Via Docker exec:

```bash
docker exec -it workenv bash
```

Via SSH (if port is exposed):

```bash
# First, set a password for the ubuntu user
docker exec -it workenv passwd ubuntu

# Then connect via SSH
ssh -p 2222 ubuntu@localhost
```

## Container Startup

The container uses a custom startup script (`start.sh`) that performs the following initialization tasks:

1. **SSH Server** - Starts the OpenSSH server for remote access
2. **D-Bus Setup** - Starts the D-Bus daemon if available (required for OpenVPN3)
3. **DNS Configuration** - Sets up DNS resolver to use Google DNS (8.8.8.8)
4. **VPN Aliases** - Adds convenient OpenVPN3 aliases to user's `.bashrc`:
   - `vpn-sessions` - List active VPN sessions
   - `vpn-start` - Start VPN connection using `/data/app/client.ovpn`
   - `vpn-disconnect` - Disconnect active VPN session
5. **Credential Management** - Copies `.netrc` from `/data/app/.netrc` to user home directories if available
6. **VS Code Extensions** - Automatically installs a curated set of VS Code extensions for development

## OpenVPN3 Usage

After starting the container and opening a new shell session, you can use the following commands:

```bash
# List VPN sessions
vpn-sessions

# Start VPN connection (requires client.ovpn in /data/app/)
vpn-start

# Disconnect VPN
vpn-disconnect
```

**Note:** Place your OpenVPN configuration file at `/data/app/client.ovpn` before starting a VPN session.

## Volume Mounts

The container expects the following volume mount for full functionality:

- `/data/app` - Directory for configuration files:
  - `client.ovpn` - OpenVPN configuration file
  - `.netrc` - Authentication credentials (optional)

## SSH Access

The container includes an OpenSSH server that starts automatically. To use SSH access:

1. Expose port 22 when running the container (e.g., `-p 2222:22`)
2. Set a password for the user you want to connect as:
   ```bash
   docker exec -it workenv passwd ubuntu
   ```
3. Connect via SSH:
   ```bash
   ssh -p 2222 ubuntu@localhost
   ```

**Security Note:** By default, the SSH server is configured to allow password authentication for convenience in development environments. For production use, consider using SSH keys instead.

## User Configuration

The container creates a non-root user named `ubuntu` with the following properties:
- Home directory: `/home/ubuntu`
- Shell: `/bin/bash`
- Working directory: `/app` (owned by ubuntu:ubuntu)

## Requirements

- Docker or compatible container runtime
- (Optional) OpenVPN configuration file for VPN connectivity
- (Optional) AWS credentials for AWS CLI usage

## Future Enhancements

The Dockerfile includes commented-out Docker installation steps, indicating potential future support for Docker-in-Docker functionality.

## License

This project is provided as-is without a specific license. Please refer to the repository for any licensing information.

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests to improve this development environment.
