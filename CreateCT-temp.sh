#!/bin/bash

# Set default values
CONTAINER_NAME="test"
IMAGE_NAME="ubuntu:latest"
NETWORK_MODE="bridge"
PORT_MAPPING="8080:80"
VOLUME_MAPPING="/host/path:/container/path"

# Help function
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Create a Docker container in bridge network mode"
    echo ""
    echo "Options:"
    echo "  -n, --name         Container name (default: my-container)"
    echo "  -i, --image        Docker image (default: ubuntu:latest)"
    echo "  -p, --port         Port mapping (default: 8080:80)"
    echo "  -v, --volume       Volume mapping (default: /host/path:/container/path)"
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
        -p|--port)
            PORT_MAPPING="$2"
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

# Pull the Docker image
echo "Pulling Docker image: $IMAGE_NAME"
if ! docker pull $IMAGE_NAME; then
    echo "Error: Failed to pull Docker image"
    exit 1
fi

# Create and run the container
echo "Creating container: $CONTAINER_NAME"
docker run -d \
    --name $CONTAINER_NAME \
    --network $NETWORK_MODE \
    -p $PORT_MAPPING \
    -v $VOLUME_MAPPING \
    $IMAGE_NAME

# Check if container was created successfully
if [ $? -eq 0 ]; then
    echo "Container created successfully!"
    echo "Container details:"
    docker inspect $CONTAINER_NAME | grep -A 5 "NetworkSettings"
else
    echo "Error: Failed to create container"
    exit 1
fi