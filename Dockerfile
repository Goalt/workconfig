# Use the official Ubuntu base image
FROM debian:bookworm

# Set environment variables to prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Update package list and install basic utilities
RUN apt-get update && \
    apt-get install -y \
    curl \
    wget \
    vim \
    git \
    htop \
    net-tools \
    ca-certificates \
    unzip \
    jq \
    postgresql-client \
    openssh-server \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install AWS CLI v2
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"; \
    elif [ "$ARCH" = "aarch64" ]; then \
        curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"; \
    else \
        echo "Unsupported architecture: $ARCH" && exit 1; \
    fi && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf awscliv2.zip aws

# Install AWS Session Manager plugin
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
        curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"; \
    elif [ "$ARCH" = "aarch64" ]; then \
        curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_arm64/session-manager-plugin.deb" -o "session-manager-plugin.deb"; \
    else \
        echo "Unsupported architecture: $ARCH" && exit 1; \
    fi && \
    dpkg -x session-manager-plugin.deb /tmp/ssm && \
    cp /tmp/ssm/usr/local/sessionmanagerplugin/bin/session-manager-plugin /usr/local/bin/ && \
    rm -rf /tmp/ssm session-manager-plugin.deb

# Set the working directory
WORKDIR /app

# Create a non-root user
RUN useradd -m -s /bin/bash ubuntu && \
    chown -R ubuntu:ubuntu /app
RUN apt install apt-transport-https curl

# Install OpenVPN3
RUN curl -sSfL https://packages.openvpn.net/packages-repo.gpg >/etc/apt/keyrings/openvpn.asc
RUN echo "deb [signed-by=/etc/apt/keyrings/openvpn.asc] https://packages.openvpn.net/openvpn3/debian bookworm main" >>/etc/apt/sources.list.d/openvpn3.list
RUN apt update
RUN apt install openvpn3 -y

# Install golang
RUN ARCH=$(dpkg --print-architecture) && \
    GO_VERSION=1.25.3 && \
    wget https://go.dev/dl/go${GO_VERSION}.linux-${ARCH}.tar.gz && \
    tar -C /usr/local -xzf go${GO_VERSION}.linux-${ARCH}.tar.gz && \
    rm go${GO_VERSION}.linux-${ARCH}.tar.gz
ENV PATH="/usr/local/go/bin:${PATH}"

# Install go-swagger
RUN ARCH=$(uname -m) && \
    SWAGGER_VERSION=v0.31.0 && \
    if [ "$ARCH" = "x86_64" ]; then \
        SWAGGER_ARCH="amd64"; \
    elif [ "$ARCH" = "aarch64" ]; then \
        SWAGGER_ARCH="arm64"; \
    else \
        echo "Unsupported architecture: $ARCH" && exit 1; \
    fi && \
    wget -O /usr/local/bin/swagger "https://github.com/go-swagger/go-swagger/releases/download/${SWAGGER_VERSION}/swagger_linux_${SWAGGER_ARCH}" && \
    chmod +x /usr/local/bin/swagger

# Install VSCode CLI
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
        VSCODE_ARCH="x64"; \
    elif [ "$ARCH" = "aarch64" ]; then \
        VSCODE_ARCH="arm64"; \
    else \
        echo "Unsupported architecture: $ARCH" && exit 1; \
    fi && \
    curl -Lk "https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-${VSCODE_ARCH}" --output vscode_cli.tar.gz && \
    tar -xf vscode_cli.tar.gz -C /usr/local/bin && \
    rm vscode_cli.tar.gz && \
    chmod +x /usr/local/bin/code

# Install Docker (Todo)
# RUN apt-get update && \
#     apt-get install -y \
#     ca-certificates \
#     gnupg \
#     lsb-release
# RUN mkdir -p /etc/apt/keyrings
# RUN curl -fsSL https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
# RUN echo \
#   "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") \
#   $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
# RUN apt-get update && \
#     apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
#     && apt-get clean \
#     && rm -rf /var/lib/apt/lists/*

# Configure SSH server
RUN mkdir -p /var/run/sshd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Expose SSH port
EXPOSE 22

# Add start script into the image
COPY start.sh /usr/local/bin/container-start.sh
RUN chmod +x /usr/local/bin/container-start.sh

ENTRYPOINT ["/usr/local/bin/container-start.sh"]
CMD ["sleep", "infinity"]
