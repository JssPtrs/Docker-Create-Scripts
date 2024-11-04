# Introduction

CreateCT.sh is a shell script designed to automate the creation of Docker containers with specific configurations. It sets up containers with SSH access and custom port mappings, ensuring that ports are available and not in use.
Currently only has port 22 and 80 mapped for SSH and apache HTTP. Could be extended in future.

The script includes functions to check if ports are in use and find available ports.
It creates a Dockerfile automatically to install and configure SSH on the Docker image.
The script ensures that the Docker container starts correctly and verifies SSH service within the container.

Runs Ubuntu image, can be changed to whatever.



I created the CreateCT.sh script to simplify and automate the process of setting up Docker containers with specific configurations. The primary reasons for choosing to develop this product were:

- Ease of Use: To provide a straightforward solution for users to set up Docker containers with SSH access and custom port mappings without manual configuration.
- Automation: To automate repetitive tasks such as checking port availability, creating Dockerfiles, and ensuring container services run correctly.
- Flexibility: To allow users to extend and customize the script to suit their needs, including changing the base image and adding more port mappings.

This script aims to save time and reduce errors in container setup, making it a valuable tool for developers and system administrators.
    
.

**WARNING**

Default password NEEDS to be changed for security reasons. You can do this in the script or post install. Post install is more secure.

# Prerequisites

- Administrator privilges

- Docker Engine

**This is only tested with Docker Engine version 27.3.1, build ce12230. Try other versions at own risk.**

# Instructions
To use the ```CreateCT.sh``` script, run the following command in your terminal:

- Clone repo:
```
git clone https://github.com/PetersenJesse/Docker-Create-Scripts
```

(Or make own file and copy paste code!)

- Make the script executable:
```
chmod +x CreateCT.sh
```

- Execute:
```
./CreateCT.sh -n {CONTAINER NAME} -i {IMAGE}
```
or

```
sudo bash CreateCT.sh
```
# Post-Install

- Remote access
```
ssh -p {Port Assigned to SSH} root@{YOUR_SERVER_IP}
```
- Default password
```
root
```

**WARNING** 

Default password NEEDS to be changed for security reasons. You can do this in the script or post install. Post install is more secure. 

- You can change the password with the following command **IN** the docker container itself, then follow the instructions on screen:
```
passwd
```

- Update the container
```
apt update
```

# From here it's up to you o7

