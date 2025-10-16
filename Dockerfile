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
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

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

# Run after login
# RUN /etc/init.d/dbus start

# Default command
CMD ["sleep", "infinity"]