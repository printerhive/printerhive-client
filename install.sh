#!/bin/bash

# ── Branding ──────────────────────────────────────────────────────────────────

print_banner() {
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
    echo ""
}

# ── Colors & helpers ──────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

API_HOST="https://app.printerhive.com"
USER_AGENT="Printerhive-CLI-Install/1.0"

info()    { echo -e "  ${CYAN}→${NC} $*"; }
success() { echo -e "  ${GREEN}✓${NC} $*"; }
warn()    { echo -e "  ${YELLOW}!${NC} $*"; }
fail()    { echo -e "  ${RED}✗${NC} $*" >&2; exit 1; }

divider() {
    echo -e "${DIM}────────────────────────────────────────────────────────${NC}"
}

section_header() {
    echo ""
    echo -e "${BOLD}── $* ──${NC}"
    divider
}

step_header() {
    local num="$1" total="$2" title="$3"
    section_header "Step ${num}/${total}: ${title}"
}

require_command() {
    local cmd="$1" hint="$2"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        fail "$cmd is required but not installed.${hint:+ $hint}"
    fi
}

json_get() {
    # Usage: echo "$json" | json_get '.access_token'
    local expr="$1"
    python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
except json.JSONDecodeError:
    sys.exit(2)
def resolve(obj, path):
    for part in path.strip('.').split('.'):
        if part.endswith(']'):
            key, idx = part[:-1].split('[')
            obj = obj[key][int(idx)]
        elif part:
            obj = obj[part]
    return obj
try:
    val = resolve(data, '$expr')
    if val is None:
        sys.exit(1)
    if isinstance(val, (dict, list)):
        print(json.dumps(val))
    else:
        print(val)
except (KeyError, IndexError, TypeError):
    sys.exit(1)
" 2>/dev/null
}

api_error_message() {
    local body="$1"
    local msg
    msg=$(printf '%s' "$body" | json_get 'message' 2>/dev/null || true)
    if [ -n "$msg" ]; then
        echo "$msg"
    else
        echo "Request failed."
    fi
}

curl_json() {
    # curl_json METHOD URL [extra curl args...]
    # Sets: HTTP_BODY, HTTP_CODE
    local method="$1" url="$2"
    shift 2
    local response
    response=$(curl -sS -w "\n__HTTP_CODE__%{http_code}" -X "$method" "$url" \
        -H "Content-Type: application/json" \
        -H "User-Agent: $USER_AGENT" \
        "$@")
    HTTP_CODE="${response##*__HTTP_CODE__}"
    HTTP_BODY="${response%__HTTP_CODE__*}"
}

# ── Authentication ────────────────────────────────────────────────────────────

auth_login() {
    local email="$1" password="$2"
    local payload
    payload=$(LOGIN_EMAIL="$email" LOGIN_PASSWORD="$password" python3 -c "
import json, os
print(json.dumps({
    'email': os.environ['LOGIN_EMAIL'],
    'password': os.environ['LOGIN_PASSWORD'],
}))
")
    curl_json POST "${API_HOST}/api/auth/login" -d "$payload"

    if [[ "$HTTP_CODE" != 2* ]]; then
        fail "$(api_error_message "$HTTP_BODY") (HTTP $HTTP_CODE)"
    fi

    ACCESS_TOKEN=$(printf '%s' "$HTTP_BODY" | json_get 'access_token') || fail "Invalid server response."
    USER_EMAIL=$(printf '%s' "$HTTP_BODY" | json_get 'user.email') || USER_EMAIL="$email"
}

auth_fetch_locations() {
    curl_json GET "${API_HOST}/api/auth/locations" \
        -H "Authorization: Bearer $ACCESS_TOKEN"

    if [[ "$HTTP_CODE" != 2* ]]; then
        fail "$(api_error_message "$HTTP_BODY") (HTTP $HTTP_CODE)"
    fi

    LOCATIONS_JSON=$(printf '%s' "$HTTP_BODY" | python3 -c "
import json, sys
data = json.load(sys.stdin)
usable = [
    loc for loc in data.get('locations', [])
    if loc.get('api_token') and loc.get('client_id') is not None
]
print(json.dumps(usable))
")
    LOCATION_COUNT=$(printf '%s' "$LOCATIONS_JSON" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")

    if [ "$LOCATION_COUNT" -eq 0 ]; then
        fail "Your account has no location with a configured client."
    fi
}

auth_select_location() {
    local location_id="$1"
    curl_json POST "${API_HOST}/api/auth/select-location" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -d "{\"location_id\": $location_id}"

    if [[ "$HTTP_CODE" != 2* ]]; then
        fail "$(api_error_message "$HTTP_BODY") (HTTP $HTTP_CODE)"
    fi

    API_TOKEN=$(printf '%s' "$HTTP_BODY" | json_get 'location.api_token') || fail "Invalid server response."
    SELECTED_LOCATION_NAME=$(printf '%s' "$HTTP_BODY" | json_get 'location.name') || SELECTED_LOCATION_NAME=""
}

prompt_location_selection() {
    echo ""
    echo -e "${BOLD}Select a location:${NC}"
    echo ""

    local i=1
    while IFS=$'\t' read -r id name slug; do
        printf "  ${CYAN}%d)${NC} %s ${DIM}(%s)${NC}\n" "$i" "$name" "$slug"
        i=$((i + 1))
    done < <(printf '%s' "$LOCATIONS_JSON" | python3 -c "
import json, sys
for loc in json.load(sys.stdin):
    print(f\"{loc['id']}\t{loc['name']}\t{loc.get('slug', '')}\")
")

    echo ""
    if [ "$LOCATION_COUNT" -eq 1 ]; then
        local only_id
        only_id=$(printf '%s' "$LOCATIONS_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin)[0]['id'])")
        info "Only one location available — selecting automatically."
        auth_select_location "$only_id"
        success "Location: ${SELECTED_LOCATION_NAME}"
        return
    fi

    while true; do
        read -r -p "  Enter number [1-${LOCATION_COUNT}]: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$LOCATION_COUNT" ]; then
            local selected_id
            selected_id=$(printf '%s' "$LOCATIONS_JSON" | python3 -c "
import json, sys
locs = json.load(sys.stdin)
print(locs[int(sys.argv[1]) - 1]['id'])
" "$choice")
            auth_select_location "$selected_id"
            success "Location: ${SELECTED_LOCATION_NAME}"
            return
        fi
        warn "Please enter a number between 1 and ${LOCATION_COUNT}."
    done
}

authenticate_with_login() {
    section_header "Sign in"

    local email password
    while [ -z "$email" ]; do
        read -r -p "  Email: " email
        email=$(echo "$email" | xargs)
        [ -n "$email" ] || warn "Email cannot be empty."
    done

    while [ -z "$password" ]; do
        read -r -s -p "  Password: " password
        echo ""
        [ -n "$password" ] || warn "Password cannot be empty."
    done

    info "Signing in…"
    auth_login "$email" "$password"
    success "Signed in as ${USER_EMAIL}"

    info "Loading locations…"
    auth_fetch_locations
    prompt_location_selection
}

resolve_api_token() {
    if [ -n "$1" ]; then
        API_TOKEN="$1"
        info "Using API token from command line."
        return
    fi

    authenticate_with_login
}

# ── Install progress ──────────────────────────────────────────────────────────

log_step() {
    local step="$1"
    local status="$2"
    local message="$3"

    local response http_code body error_message
    response=$(curl -s -w "%{http_code}" -X POST "${API_HOST}/api/install-progress" \
        -H "Content-Type: application/json" \
        -H "X-AUTH-TOKEN: $API_TOKEN" \
        -d "{\"step\": \"$step\", \"status\": \"$status\", \"message\": \"$message\"}")

    http_code="${response: -3}"
    body="${response:0:${#response}-3}"

    if [[ "$http_code" != 2* ]]; then
        error_message=$(echo "$body" | sed -n 's/.*"error":"\([^"]*\)".*/\1/p')
        fail "${error_message:-Install progress reporting failed (HTTP $http_code)}"
    fi
}

# ── Setup steps ───────────────────────────────────────────────────────────────

TOTAL_STEPS=5

check_docker() {
    step_header 1 "$TOTAL_STEPS" "Docker"
    if ! [ -x "$(command -v docker)" ]; then
        warn "Docker not found — installing…"
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        rm get-docker.sh
        sudo usermod -aG docker "$USER"
        success "Docker installed."
        warn "You may need to log out and back in for Docker group membership."
    else
        success "Docker is installed."
    fi

    if docker compose version >/dev/null 2>&1; then
        success "Docker Compose plugin is available."
    else
        warn "Docker Compose plugin not found — installing…"
        if [ -f /etc/os-release ]; then
            # shellcheck source=/dev/null
            . /etc/os-release
            DISTRO=$ID
        else
            fail "Cannot determine Linux distribution. Install docker-compose-plugin manually."
        fi

        case $DISTRO in
            ubuntu|debian|raspbian)
                info "Detected Debian/Ubuntu."
                sudo apt-get update
                sudo apt-get install -y docker-compose-plugin
                ;;
            centos|rhel|fedora)
                info "Detected RHEL/Fedora."
                if command -v dnf >/dev/null 2>&1; then
                    sudo dnf install -y docker-compose-plugin
                elif command -v yum >/dev/null 2>&1; then
                    sudo yum install -y docker-compose-plugin
                else
                    fail "Neither dnf nor yum found."
                fi
                ;;
            *)
                fail "Unsupported distribution '$DISTRO'. Install docker-compose-plugin manually."
                ;;
        esac

        if docker compose version >/dev/null 2>&1; then
            success "Docker Compose plugin installed."
        else
            fail "Failed to install Docker Compose plugin."
        fi
    fi
}

setup_environment() {
    step_header 3 "$TOTAL_STEPS" "Configuration"

    local env_file=".env"
    if [ -f "$env_file" ]; then
        warn ".env already exists — skipping."
    else
        cat > "$env_file" <<EOF
API_TOKEN=$API_TOKEN
API_DOMAIN=printerhive.com
API_HOST=${API_HOST}
EOF
        success "Created .env"
    fi

    log_step "3" "success" "Environment created"

    local printers_file="printers.json"
    if [ ! -f "$printers_file" ]; then
        cat > "$printers_file" <<'EOF'
{
  "printers": [
  ]
}
EOF
        success "Created printers.json"
    else
        warn "printers.json already exists — skipping."
    fi

    log_step "4" "success" "Space for printers created"
}

download_docker_compose() {
    step_header 4 "$TOTAL_STEPS" "Download"

    if [ ! -f "docker-compose.yml" ]; then
        info "Downloading docker-compose.yml…"
        if ! curl -fsSL https://raw.githubusercontent.com/printerhive/printerhive-client/main/docker-compose.yml -o docker-compose.yml; then
            log_step "6" "error" "Failed to download docker-compose.yml"
            fail "Could not download docker-compose.yml"
        fi
        success "docker-compose.yml downloaded."
    else
        warn "docker-compose.yml already exists — skipping."
    fi

    log_step "5" "success" "App downloaded"
}

start_app() {
    step_header 5 "$TOTAL_STEPS" "Start containers"

    info "Preparing Docker…"
    mkdir -p ~/.docker
    sudo chown -R "$(id -u):$(id -g)" ~/.docker

    for container in printerhive-client printerhive-camera-feed; do
        if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
            info "Removing existing container '${container}'…"
            docker stop "$container" >/dev/null 2>&1 || true
            docker rm "$container" >/dev/null 2>&1 || true
        fi
    done

    info "Pulling images and starting services…"
    sudo docker compose pull
    sudo docker compose up --build --force-recreate -d

    log_step "6" "success" "App built"
}

print_done() {
    echo ""
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}${BOLD}  Installation complete — Printerhive client is running.${NC}"
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${DIM}Status:${NC}       docker compose ps"
    echo -e "  ${DIM}Logs:${NC}         docker compose logs -f"
    echo ""
}

# ── Main ──────────────────────────────────────────────────────────────────────

print_banner

require_command curl "Install with: sudo apt install curl"
require_command python3 "Install with: sudo apt install python3"

echo "We may ask for a password for your admin account on this machine so we can download Printerhive, don't worry, your password is not stored anywhere."
echo -e "  ${DIM}Your Printerhive credentials are sent only to app.printerhive.com.${NC}"
echo ""

resolve_api_token "$1"

set -e

if [ "$(ls -A . 2>/dev/null | wc -l)" -gt 0 ] && [ ! -f "./printers.json" ]; then
    mkdir -p printerhive-client
    cd printerhive-client
fi

echo ""
divider
info "Starting installation…"
log_step "0" "success" "Started installation of Printerhive"

check_docker
log_step "1" "success" "Docker installed"
log_step "2" "success" "Docker Compose plugin checked/installed (using 'docker compose')"

step_header 2 "$TOTAL_STEPS" "Working directory"
success "Directory: $(pwd)"

setup_environment
download_docker_compose
start_app
print_done
