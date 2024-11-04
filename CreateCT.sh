# This script creates a Docker container with SSH and HTTP access.
# It performs the following steps:
# 1. Sets default values for container name, image name, network mode, volume mapping, and number of ports.
# 2. Defines functions to check if a port is in use and to find the next available port.
# 3. Parses command line arguments to override default values.
# 4. Checks if Docker is running and if the specified container name already exists.
# 5. Finds available ports for SSH and HTTP access.
# 6. Pulls the specified Docker image.
# 7. Creates a Dockerfile to install and configure SSH in the container.
# 8. Builds a custom Docker image with SSH enabled.
# 9. Runs the Docker container with the specified settings.
# 10. Cleans up the Dockerfile.
# 11. Waits for the container to start and checks if it is running.
# 12. Tests the SSH service in the container.
# 13. Outputs the container status and SSH/HTTP access information.

#!/bin/bash

# Set default values
CONTAINER_NAME="test"
IMAGE_NAME="ubuntu:latest"
NETWORK_MODE="bridge"
VOLUME_MAPPING="/host/path:/container/path"
NUM_PORTS=1  # Number of ports needed

# Function to check if a port is in use by Docker
is_port_used() {
    local port=$1
    docker ps --format '{{.Ports}}' | grep -q ":$port->"
    return $?
}

# Function to find the next available port
is_port_used() {
    local port=$1
    # Check if port is used by Docker
    if docker ps --format '{{.Ports}}' | grep -q ":$port->"; then
        return 0
    fi
    # Check if port is used by the system
    if command -v netstat > /dev/null; then
        if netstat -tuln | grep -q ":$port "; then
            return 0
        fi
    elif command -v ss > /dev/null; then
        if ss -tuln | grep -q ":$port "; then
            return 0
        fi
    elif command -v lsof > /dev/null; then
        if lsof -i :$port > /dev/null 2>&1; then
            return 0
        fi
    fi
    # If none of the above commands found the port in use
    return 1
}

# Function to find the next available port with improved checking
find_available_port() {
    local start_port=10000
    local end_port=15000
    local attempts=0
    local max_attempts=100  # Prevent infinite loops
while [ $attempts -lt $max_attempts ]; do
        # Generate a random port number within the range
        local port=$(shuf -i $start_port-$end_port -n 1)
        if ! is_port_used $port; then
            echo $port
            return 0
        fi
        attempts=$((attempts + 1))
    done
  # If we couldn't find a random port, try sequentially
    for port in $(seq $start_port $end_port); do
        if ! is_port_used $port; then
            echo $port
            return 0
        fi
    done

    echo "No available ports found between $start_port and $end_port"
    exit 1
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

# Find available ports for SSH
PORT_MAPPINGS=()    
for i in $(seq 1 $NUM_PORTS); do
    AVAILABLE_PORT=$(find_available_port)   
    if [ $? -ne 0 ]; then
        echo "$AVAILABLE_PORT"
        exit 1
    fi
    PORT_MAPPINGS+=("${AVAILABLE_PORT}:22")
done

# Find an available port for port 80
AVAILABLE_PORT_80=$(find_available_port)
if [ $? -ne 0 ]; then
    echo "$AVAILABLE_PORT_80"
    exit 1
fi
PORT_MAPPINGS+=("${AVAILABLE_PORT_80}:80")

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

EXPOSE 22 80

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
    $(for port_mapping in "${PORT_MAPPINGS[@]}"; do echo -n "-p $port_mapping "; done) \
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
for port_mapping in "${PORT_MAPPINGS[@]}"; do
    port=${port_mapping%%:*}
    echo "Host: localhost"
    echo "Port: $port"
    echo "Username: root"
    echo "Password: root"
    echo -e "\nConnect using: ssh -p $port root@10.50.7.11" # Change IP address as needed
done

# Show connection test command
echo -e "\nTo test connection immediately, use:"
for port_mapping in "${PORT_MAPPINGS[@]}"; do
    port=${port_mapping%%:*}
    echo "nc -zv localhost $port"
done

# Show port 80 mapping
echo -e "\nHTTP Access Information:"
echo "Host: localhost"
echo "Port: $AVAILABLE_PORT_80"
echo -e "\nConnect using: http://localhost:$AVAILABLE_PORT_80"  # Change IP address as needed