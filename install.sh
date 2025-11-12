#!/bin/bash

echo "                                                                                                                                     "
echo "                                                                                                                                     "
echo "                                                                                                                                     "
echo "                                                                                                                                     "
echo "                     .--.                                                                                                             "
echo "                    --  --                                                                                                            "
echo "                    -    -                                                                                                            "
echo "           --:      -    -                                                                                                            "
echo "         .-----     -    -                                 @                                                                         "
echo "        ---   ---   ------   -:                           @@@                                     #@         @@                      "
echo "      ---       ---   --   -----                          @@@              ++                     #@         @@                      "
echo "    ---          .--:    :--:  ---                                         @@                     #@                                 "
echo "   --:             ---  ---      ---    @@@ @@@    %@@ #@ @@@  @@@ @@@     @@      =@@+    @@@ @@ #@  ##     -= -=      =.   +#      "
echo "   -                 -  -         --    @@@@@@@@%  %@@@@@ @@@  @@@@@@@@  @@@@@@   @@@@@@   @@@@@@ #@@@@@@@   @@  @.    -@  @@@@@@    "
echo "   -                 -  -         --    @@@@  @@@  %@@@@# @@@  @@@@:%@@@ ++@@++  @@@  @@@  @@@@@% #@@   #@   @@  @@    @@ #@    @@   "
echo "   -                 -  -         --    @@@    @@@ %@@    @@@  @@@   @@@   @@   .@@    @@  @@@    #@     @*  @@   @    @  @@     @   "
echo "   -                 -  -         --    @@@    @@@ %@@    @@@  @@@   :@@   @@   @@@@@@@@@# @@@    #@     @@  @@   @@  @@  @@@@@@@@   "
echo "   -                 -  -         --    @@@    @@@ %@@    @@@  @@@   :@@   @@   *@@        @@@    #@     @@  @@    @  @   @-         "
echo "   -                 -  --        --    @@@*  :@@: %@@    @@@  @@@   :@@   @@    @@@   @   @@@    #@     @@  @@    @@@@   @@         "
echo "   -                 -  ---     ---     @@@@@@@@@  %@@    @@@  @@@   :@@   @@@@+ @@@@@@@@  @@@    #@     @@  @@    +@@     @@   @@   "
echo "   -                 -    --- :--.      @@@@@@@@   %@@    @@@  @@@   :@@    @@@@  .@@@@@   @@@    #@     @@  @@     @@      @@@@@    "
echo "   -                 -      ----        @@@                                                                                          "
echo "   -                 -       .          @@@                                                                                          "
echo "   --              :--                  @@@                                                                                          "
echo "    ---           ---                                                                                                                "
echo "      ---       ---                                                                                                                  "
echo "       .--:   ---                                                                                                                    "
echo "         ---:--:                                                                                                                     "
echo "           ---                                                                                                                       "

echo "We may ask for a password for your admin account on this machine so we can download Printerhive, don't worry, your password is not stored anywhere."
sudo find / -type d -name "printerhive-node-client" -exec sudo rm -rf {} \;

if [ -z "$1" ]; then
    echo "Please enter the API token:
If you don't know your API token, you can find it here: https://app.printerhive.com/location"
    read -p "> " API_TOKEN
else
    API_TOKEN="$1"
fi

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

CURRENT_DIR="$(pwd)"

if [ "$(ls -A . 2>/dev/null | wc -l)" -gt 0 ]; then
    HAS_CONTENT=true
else
    HAS_CONTENT=false
fi

if [ "$HAS_CONTENT" = true ]; then
    if [ ! -f "./printers.json" ]; then
        mkdir -p printerhive-client
        cd printerhive-client
    fi
fi

log_step() {
    local step="$1"
    local status="$2"
    local message="$3"
    local token="$API_TOKEN"

    response=$(curl -s -w "%{http_code}" -X POST "https://app.printerhive.com/api/install-progress" \
        -H "Content-Type: application/json" \
        -H "X-AUTH-TOKEN: $token" \
        -d "{\"step\": \"$step\", \"status\": \"$status\", \"message\": \"$message\"}")

    http_code="${response: -3}"
    body="${response:0:${#response}-3}"

    if [[ "$http_code" != 2* ]]; then
        error_message=$(echo "$body" | sed -n 's/.*"error":"\([^"]*\)".*/\1/p')
        echo -e "${RED}$error_message${NC}"
        exit 1
    fi
}

check_docker() {
    if ! [ -x "$(command -v docker)" ]; then
        echo -e "${RED}Docker is not installed. Installing Docker...${NC}"
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        rm get-docker.sh
        sudo usermod -aG docker $USER
        echo -e "${GREEN}Docker installed successfully.${NC}"
    else
        echo -e "${GREEN}Docker is already installed.${NC}"
    fi

    if docker compose version >/dev/null 2>&1; then
        echo -e "${GREEN}Docker Compose plugin is available.${NC}"
    else
        echo -e "${RED}Docker Compose plugin is not available. Attempting to install...${NC}"
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            DISTRO=$ID
        else
            echo -e "${RED}Cannot determine Linux distribution. Please install docker-compose-plugin manually.${NC}"
            exit 1
        fi

        case $DISTRO in
            ubuntu|debian|raspbian)
                echo -e "${GREEN}Detected Debian/Ubuntu. Installing docker-compose-plugin...${NC}"
                sudo apt-get update
                sudo apt-get install -y docker-compose-plugin
                ;;
            centos|rhel|fedora)
                echo -e "${GREEN}Detected RHEL/Fedora. Installing docker-compose-plugin...${NC}"
                if command -v dnf >/dev/null 2>&1; then
                    sudo dnf install -y docker-compose-plugin
                elif command -v yum >/dev/null 2>&1; then
                    sudo yum install -y docker-compose-plugin
                else
                    echo -e "${RED}Neither dnf nor yum found. Cannot install docker-compose-plugin.${NC}"
                    exit 1
                fi
                ;;
            *)
                echo -e "${RED}Unsupported distribution '$DISTRO'. Please install docker-compose-plugin manually.${NC}"
                exit 1
                ;;
        esac

        if docker compose version >/dev/null 2>&1; then
            echo -e "${GREEN}Docker Compose plugin installed successfully.${NC}"
        else
            echo -e "${RED}Failed to install Docker Compose plugin. Please install it manually and run the script again.${NC}"
            exit 1
        fi
    fi
}

setup_environment() {
ENV_FILE=".env"

if [ -f "$ENV_FILE" ]; then
    echo ".env file already exists. Skipping creation."
else
    echo "API_TOKEN=$API_TOKEN" > "$ENV_FILE"
    echo "API_DOMAIN=printerhive.com" >> "$ENV_FILE"
    echo "API_HOST=https://app.printerhive.com  " >> "$ENV_FILE"

    echo ".env file created successfully."
fi

log_step "3" "success" "Environment created"

PRINTERS_FILE="printers.json"

if [ ! -f "$PRINTERS_FILE" ]; then
    echo "Creating printers.json file with default content..."
    cat <<EOL > "$PRINTERS_FILE"
{
  "printers": [
  ]
}
EOL
    echo "printers.json file created successfully."
else
    echo "printers.json file already exists. Skipping creation."
fi

log_step "4" "success" "Space for printers created"
}

download_docker_compose() {
    if [ ! -f "docker-compose.yml" ]; then
        echo "Downloading docker-compose.yml..."
        curl -fsSL https://raw.githubusercontent.com/printerhive/printerhive-client/main/docker-compose.yml -o docker-compose.yml
        if [ $? -ne 0 ]; then
            echo -e "${RED}Error when downloading docker-compose.yml${NC}"
            log_step "6" "error" "Failed to download docker-compose.yml"
            exit 1
        fi
        echo -e "${GREEN}docker-compose.yml downloaded.${NC}"
    else
        echo "docker-compose.yml already exists, skipping download."
    fi
    log_step "5" "success" "App downloaded"
}

start_app() {
echo "Building and starting the Docker container..."
mkdir -p ~/.docker
sudo chown -R $(id -u):$(id -g) ~/.docker

if docker ps -a --format '{{.Names}}' | grep -q "^printerhive-client$"; then
    echo "Container 'printerhive-client' exists. Removing it..."
    docker stop printerhive-client
    docker rm printerhive-client
else
    echo "Container 'printerhive-client' does not exist. Skipping removal."
fi

if docker ps -a --format '{{.Names}}' | grep -q "^printerhive-camera-feed$"; then
    echo "Container 'printerhive-camera-feed' exists. Removing it..."
    docker stop printerhive-camera-feed
    docker rm printerhive-camera-feed
else
    echo "Container 'printerhive-camera-feed' does not exist. Skipping removal."
fi

sudo docker compose pull
sudo docker compose up --build --force-recreate -d

log_step "6" "success" "App built"
}

echo -e "${GREEN}Starting setup...${NC}"
log_step "0" "success" "Started installation of Printerhive"
check_docker
log_step "1" "success" "Docker installed"
log_step "2" "success" "Docker Compose plugin checked/installed (using 'docker compose')"
setup_environment
download_docker_compose_file
start_app
echo -e "${GREEN}Setup complete and client is running using 'docker compose'.${NC}"