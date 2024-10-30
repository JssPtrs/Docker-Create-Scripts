# Introduction

CreateCT.sh is a shell script designed to automate the creation of Docker containers with specific configurations. It sets up containers with SSH access and custom port mappings, ensuring that ports are available and not in use.
Currently only has port 22 and 80 mapped for SSH and apache HTTP. Could be extended in future.

The script includes functions to check if ports are in use and find available ports.
It creates a Dockerfile automatically to install and configure SSH on the Docker image.
The script ensures that the Docker container starts correctly and verifies SSH service within the container.

Runs Ubuntu image, can be changed to whatever.

.

**WARNING**

Default password NEEDS to be changed for security reasons. You can do this in the script or post install. Post install is more secure.

# Prerequisites

- Administrator privilges

- Docker Engine

**This is only tested with Docker Engine version 27.3.1, build ce12230. Try other versions at own risk.**

# Instructions
To use the CreateCT.sh script, run the following command in your terminal:

- Clone repo:
```
git clone https://github.com/PetersenJesse/Docker-Create-Scripts
```

- Make the script executable:
```
chmod +x CreateCT.sh
```

- Execute:
```
sudo bash CreateCT.sh
```
# Post-Install

- Remote access
```
ssh -p root@{YOUR_SERVER_IP}
```
- Default password
```
root
```

**WARNING** 

Default password NEEDS to be changed for security reasons. You can do this in the script or post install. Post install is more secure.

- Update the container
```
apt update
```

# From here it's up to you o7

