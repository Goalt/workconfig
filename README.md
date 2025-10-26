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

- **System Utilities**
  - vim text editor
  - htop process monitor
  - jq JSON processor
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

With volume mounts for persistent data:

```bash
docker run -d \
  --name workenv \
  -v /path/to/data:/data/app \
  workconfig
```

### Accessing the Container

```bash
docker exec -it workenv bash
```

## Container Startup

The container uses a custom startup script (`start.sh`) that performs the following initialization tasks:

1. **D-Bus Setup** - Starts the D-Bus daemon if available (required for OpenVPN3)
2. **DNS Configuration** - Sets up DNS resolver to use Google DNS (8.8.8.8)
3. **VPN Aliases** - Adds convenient OpenVPN3 aliases to user's `.bashrc`:
   - `vpn-sessions` - List active VPN sessions
   - `vpn-start` - Start VPN connection using `/data/app/client.ovpn`
   - `vpn-disconnect` - Disconnect active VPN session
4. **Credential Management** - Copies `.netrc` from `/data/app/.netrc` to user home directories if available

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
