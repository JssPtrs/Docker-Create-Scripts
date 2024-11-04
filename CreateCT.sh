#!/bin/bash

# Configuration
# ------------
CONTAINER_NAME="test"
IMAGE_NAME="ubuntu:latest"
NETWORK_MODE="bridge"
VOLUME_MAPPING="/host/path:/container/path"
NUM_PORTS=1
IP_ADDRESS="YOUR_IP" # Change this to the IP address of your Docker host

# Port configuration
PORT_RANGE_START=10000
PORT_RANGE_END=15000

# Functions
# ---------
# Check if port is in use (Docker or system-wide)
is_port_used() {
    local port=$1
    # Check Docker ports
    docker ps --format '{{.Ports}}' | grep -q ":$port->" && return 0
    
    # Check system ports using available tools
    if command -v netstat > /dev/null; then
        netstat -tuln | grep -q ":$port " && return 0
    elif command -v ss > /dev/null; then
        ss -tuln | grep -q ":$port " && return 0
    elif command -v lsof > /dev/null; then
        lsof -i :$port > /dev/null 2>&1 && return 0
    fi
    return 1
}

# Find next available port
find_available_port() {
    local attempts=0
    local max_attempts=100    # Maximum number of random attempts before falling back to sequential search


    # Try random ports first loop (lt: less than)
    while [ $attempts -lt $max_attempts ]; do
        # 'local' variable named 'port' for use within this function
        # Generate a random port number within our range
        # shuf -i: generate random numbers in a range
        # -n 1: output only one number
        local port=$(shuf -i $PORT_RANGE_START-$PORT_RANGE_END -n 1)
        

# Check if this port is available
# is_port_used returns 0 if port is in use, 1 if available
    if ! is_port_used $port; then
        echo $port
        return 0
    fi

    # Attempt Counter
    ((attempts++))
done

    # Fall back to sequential search
    for port in $(seq $PORT_RANGE_START $PORT_RANGE_END); do
        if ! is_port_used $port; then
            echo $port
            return 0
        fi
    done

    echo "Error: No available ports in range $PORT_RANGE_START-$PORT_RANGE_END" >&2
    return 1
}

# Function to process command-line arguments
parse_arguments() {
    # While there are arguments left to process ($# is the number of arguments)
    # -gt 0 means "greater than 0"
    while [[ $# -gt 0 ]]; do
        # Look at the first argument ($1) and match it against known options
        case "$1" in
            # If argument is -n or --name
            -n|--name)  
                CONTAINER_NAME="$2"  # Set container name to the next argument
                shift 2              # Remove these 2 args (-n and the name) from processing
                ;;
            
            # If argument is -i or --image
            -i|--image) 
                IMAGE_NAME="$2"      # Set image name to the next argument
                shift 2              # Remove these 2 args (-i and the image) from processing
                ;;
            
            # If argument is -v or --volume
            -v|--volume) 
                VOLUME_MAPPING="$2"  # Set volume mapping to the next argument
                shift 2              # Remove these 2 args (-v and the volume) from processing
                ;;
            
            # If argument doesn't match any of the above
            *) 
                echo "Unknown option: $1"  # Show error message
                exit 1                     # Exit script with error
                ;;
        esac
    done
}


create_dockerfile() {
    cat > Dockerfile <<EOL
FROM $IMAGE_NAME

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y openssh-server && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir /var/run/sshd && \
    echo 'root:root' | chpasswd && \    # CHANGE THIS IF YOU WANT TO USE A DIFFERENT PASSWORD
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/UsePAM yes/UsePAM no/' /etc/ssh/sshd_config && \
    sed -i 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' /etc/pam.d/sshd

EXPOSE 22 80
ENTRYPOINT service ssh start && tail -f /dev/null
EOL
}

build_and_run_container() {
    echo "Building container..."
    docker build -t "${CONTAINER_NAME}-ssh" . || return 1


    # Build docker run command with all our port mappings
    echo "Starting container..."
    local port_args=""  # Empty string to store port mappings
    # Loop through each port mapping in the PORT_MAPPINGS array
    # ${PORT_MAPPINGS[@]} gets all values from the array
    # Example: PORT_MAPPINGS=("10000:22" "10001:80")
    for mapping in "${PORT_MAPPINGS[@]}"; do
        # Add each port mapping to port_args with -p flag
        # If port_args="" and mapping="10000:22":
        # First loop:  port_args="-p 10000:22"
        # Second loop: port_args="-p 10000:22 -p 10001:80"
        port_args="$port_args -p $mapping"
    done

    docker run -d \
        --name "$CONTAINER_NAME" \
        --network "$NETWORK_MODE" \
        $port_args \
        -v "$VOLUME_MAPPING" \
        "${CONTAINER_NAME}-ssh"
}

verify_container() {
    echo "Verifying container..."
    sleep 5 # Wait 5 seconds for container to start
    if ! docker ps --filter "name=$CONTAINER_NAME" --format "{{.Status}}" | grep -q "Up"; then  # ! is to reverse the command
        echo "Error: Container failed to start" 
        docker logs "$CONTAINER_NAME"   # Show logs of the container
        exit 1  # Exit script with error
    fi

    if ! docker exec "$CONTAINER_NAME" ps aux | grep -q sshd; then  # Check if SSH service is running. ! reverses it
        echo "Error: SSH service not running"
        docker logs "$CONTAINER_NAME"   # Show logs of the container
        exit 1  # Exit script with error
    fi
}

display_connection_info() {
    echo -e "\nContainer successfully created!" # -e is for special characters like ! or : \n is for newline
    echo -e "\nContainer status:"
    docker ps --filter "name=$CONTAINER_NAME"  # Show the status of the container
    
    echo -e "\nSSH Access Information:"
    for port_mapping in "${PORT_MAPPINGS[@]}"; do      # "${PORT_MAPPINGS[@]}" haalt alle waarden uit de array. Bijvoorbeeld: PORT_MAPPINGS=("10000:22" "10001:80")
        port=${port_mapping%%:*}    # Haal het host poortnummer uit de mapping
        if [[ $port_mapping == *":22" ]]; then
            echo "SSH Port: $port"
            echo "Command: ssh -p $port root@$IP_ADDRESS"
            echo "Password: root"
        fi
    done

    echo -e "\nHTTP Access Information:"
    echo "Port: $http_port"
    echo "URL: http://$IP_ADDRESS:$http_port"

    echo -e "\nTest connections with:"
    for port_mapping in "${PORT_MAPPINGS[@]}"; do   # "${PORT_MAPPINGS[@]}" haalt alle waarden uit de array. Bijvoorbeeld: PORT_MAPPINGS=("10000:22" "10001:80")
        port=${port_mapping%%:*}    # Haal het host poortnummer uit de mapping
        echo "nc -zv $IP_ADDRESS $port" # nc is netcat, -z is to scan, -v is verbose
    done
}

main() {
    # Process arguments
    parse_arguments "$@"    # "$@" is all arguments passed to the script

    # Check prerequisites
    if ! systemctl is-active --quiet docker; then  # Check if Docker service is running. ! is to reverse the command
        echo "Error: Docker service not running"
        exit 1
    fi

    # Controleer of een container met deze naam al bestaat
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo "Error: Container ${CONTAINER_NAME} already exists"
        exit 1  # Exit script with error
    fi

    # Setup ports
    echo "Finding available ports..."
    PORT_MAPPINGS=()    # Create an empty array to store port mappings
    for ((i=1; i<=NUM_PORTS; i++)); do      # Loop through the number of ports we want. i=1 is the start. i<=NUM_PORTS is NUM_PORTS, lower until its equal or lower to it. and then start adding 1 every time until a port is availible (i++). 
        port=$(find_available_port) || exit 1   # Find an available port. If it fails, exit the script with error
        PORT_MAPPINGS+=("${port}:22")   # += is to add to the array. Add the port to the array with the SSH port
    done
    
    http_port=$(find_available_port) || exit 1  # Find an available port for HTTP
    PORT_MAPPINGS+=("${http_port}:80")  # += is to add to the array. Add the port to the array with the HTTP port

    # Setup Docker
    echo "Setting up Docker environment..."
    docker pull "$IMAGE_NAME" || { echo "Failed to pull image: $IMAGE_NAME"; exit 1; } # Pull the image. If it fails, exit the script with error

    # Create and configure container
    create_dockerfile   # Create the Dockerfile
    build_and_run_container || exit 1   # Build and run the container. If it fails, exit the script with error
    rm Dockerfile

    # Verify and display results
    verify_container    # Verify the container
    display_connection_info # Display connection information
}

# makes it so that the script can be executed with -n and -i options
main "$@"