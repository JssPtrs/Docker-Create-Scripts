#!/bin/bash

# Set default values
CONTAINER_NAME="test"
IMAGE_NAME="ubuntu:latest"
NETWORK_MODE="bridge"
VOLUME_MAPPING="/host/path:/container/path"

# Function to check if a port is in use by Docker
is_port_used() {
    local port=$1
    docker ps --format '{{.Ports}}' | grep -q ":$port->"
    return $?
}

# Function to find the next available port
find_available_port() {
    for port in $(seq 10000 15000); do
        if ! is_port_used $port; then
            echo $port
            return 0
        fi
    done
    echo "No available ports found between 10000 and 15000"
    exit 1
}

# Help function
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Create a Docker container with SSH enabled in bridge network mode"
    echo ""
    echo "Options:"
    echo "  -n, --name         Container name (default: test)"
    echo "  -i, --image        Docker image (default: ubuntu:latest)"
    echo "  -v, --volume       Volume mapping (default: /host/path:/container/path)"
    echo "  -h, --help         Show this help message"
    echo ""
    echo "Note: The script will automatically find an available port between 10000 and 15000 for SSH access."
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -n|--name)
            CONTAINER_NAME="$2"
            shift
            shift
            ;;
        -i|--image)
            IMAGE_NAME="$2"
            shift
            shift
            ;;
        -v|--volume)
            VOLUME_MAPPING="$2"
            shift
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "Error: Docker is not running or you don't have permission to access it"
    exit 1
fi

# Check if container name already exists
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Error: Container with name ${CONTAINER_NAME} already exists"
    exit 1
fi

# Find an available port
AVAILABLE_PORT=$(find_available_port)
if [ $? -ne 0 ]; then
    echo "$AVAILABLE_PORT"
    exit 1
fi

PORT_MAPPING="${AVAILABLE_PORT}:22"

# Pull the Docker image
echo "Pulling Docker image: $IMAGE_NAME"
if ! docker pull $IMAGE_NAME; then
    echo "Error: Failed to pull Docker image"
    exit 1
fi

# Create Dockerfile to install and enable SSH
cat > Dockerfile <<EOL
FROM $IMAGE_NAME

# Install SSH and required packages
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    openssh-server \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Configure SSH
RUN mkdir /var/run/sshd && \
    echo 'root:root' | chpasswd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/UsePAM yes/UsePAM no/' /etc/ssh/sshd_config

# SSH login fix. Otherwise user is kicked off after login
RUN sed -i 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' /etc/pam.d/sshd

EXPOSE 22

# Start SSH service
ENTRYPOINT service ssh start && tail -f /dev/null
EOL

# Build Docker image
echo "Building custom SSH image..."
docker build -t "${CONTAINER_NAME}-ssh" . || {
    echo "Error: Failed to build Docker image"
    exit 1
}

# Run Docker container
echo "Starting container..."
docker run -d \
    --name "$CONTAINER_NAME" \
    --network "$NETWORK_MODE" \
    -p "$PORT_MAPPING" \
    -v "$VOLUME_MAPPING" \
    "${CONTAINER_NAME}-ssh"

# Clean up Dockerfile
rm Dockerfile

# Wait for container to start
echo "Waiting for container to start..."
sleep 5

# Check if container is running
if ! docker ps --filter "name=$CONTAINER_NAME" --format "{{.Status}}" | grep -q "Up"; then
    echo "Error: Container failed to start properly"
    echo "Container logs:"
    docker logs "$CONTAINER_NAME"
    exit 1
fi

# Test SSH connection
echo "Testing SSH service..."
docker exec "$CONTAINER_NAME" ps aux | grep sshd || {
    echo "Error: SSH service is not running in container"
    echo "Container logs:"
    docker logs "$CONTAINER_NAME"
    exit 1
}

echo "Container created successfully!"
echo -e "\nContainer status:"
docker ps --filter "name=$CONTAINER_NAME"
echo -e "\nSSH Access Information:"
echo "Host: localhost"
echo "Port: $AVAILABLE_PORT"
echo "Username: root"
echo "Password: root"
echo -e "\nConnect using: ssh -p $AVAILABLE_PORT root@localhost"

# Show connection test command
echo -e "\nTo test connection immediately, use:"
echo "nc -zv localhost $AVAILABLE_PORT"