#!/bin/bash

# Set default values
CONTAINER_NAME="test"
IMAGE_NAME="ubuntu:latest"
NETWORK_MODE="bridge"

# Define port mappings as an array
declare -a PORT_MAPPINGS=(
    "10000:22"    # SSH
    "10001:80"    # HTTP
    "10002:443"   # HTTPS
    "10003:53"    # DNS
    "10004:68"    # DHCP
    "10005:69"    # TFTP
    "10006:3306"  # MySQL
    "10007:23"    # Telnet
)

# Help function
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Create a Docker container with SSH enabled in bridge network mode"
    echo ""
    echo "Options:"
    echo "  -n, --name         Container name (default: test)"
    echo "  -i, --image        Docker image (default: ubuntu:latest)"
    echo "  -h, --help         Show this help message"
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

# Pull the Docker image
echo "Pulling Docker image: $IMAGE_NAME"
if ! docker pull $IMAGE_NAME; then
    echo "Error: Failed to pull Docker image"
    exit 1
fi

# Create Dockerfile
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
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

EXPOSE 22 80 443 53 68 69 3306 23

CMD ["/usr/sbin/sshd", "-D"]
EOL

# Build Docker image
echo "Building custom SSH image..."
docker build -t "${CONTAINER_NAME}-ssh" . || {
    echo "Error: Failed to build Docker image"
    exit 1
}

# Construct port mapping arguments
PORT_ARGS=""
for PORT in "${PORT_MAPPINGS[@]}"; do
    PORT_ARGS="$PORT_ARGS -p $PORT"
done

# Run Docker container
echo "Starting container..."
docker run -d \
    --name "$CONTAINER_NAME" \
    --network "$NETWORK_MODE" \
    $PORT_ARGS \
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

echo "Container created successfully!"
echo -e "\nContainer status:"
docker ps --filter "name=$CONTAINER_NAME"
echo -e "\nSSH Access Information:"
echo "Host: localhost"
echo "Port: ${PORT_MAPPINGS[0]%:*}"  # Show SSH port
echo "Username: root"
echo "Password: root"
echo -e "\nConnect using: ssh -p ${PORT_MAPPINGS[0]%:*} root@localhost"

# Show all port mappings
echo -e "\nPort Mappings:"
for PORT in "${PORT_MAPPINGS[@]}"; do
    HOST_PORT="${PORT%:*}"
    CONTAINER_PORT="${PORT#*:}"
    echo "Host port $HOST_PORT -> Container port $CONTAINER_PORT"
done

# Show connection test command
echo -e "\nTo test SSH connection, use:"
echo "nc -zv localhost ${PORT_MAPPINGS[0]%:*}"