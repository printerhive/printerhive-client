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

with_deadline() {
    # with_deadline SECONDS COMMAND...: stops COMMAND after SECONDS. Plain bash, because macOS has no timeout(1).
    local seconds="$1"
    shift
    # A background job reads /dev/null unless stdin is given explicitly; request bodies come through stdin.
    "$@" <&0 &
    local pid=$!
    # The watchdog keeps no pipe open, so a command substitution around this returns as soon as COMMAND ends.
    { sleep "$seconds"; kill -TERM "$pid"; sleep 1; kill -KILL "$pid"; } </dev/null >/dev/null 2>&1 &
    local watchdog=$!
    local rc=0
    # 2>/dev/null: no "Terminated" job notice in the installer output when the deadline stops COMMAND.
    wait "$pid" 2>/dev/null || rc=$?
    kill "$watchdog" 2>/dev/null
    wait "$watchdog" 2>/dev/null
    return "$rc"
}

curl_json() {
    # curl_json METHOD URL SECONDS [extra curl args...]: the whole request, whatever ~/.curlrc adds, ends within SECONDS.
    # Sets: HTTP_BODY, HTTP_CODE
    local method="$1" url="$2" seconds="$3"
    shift 3
    local response
    # ~/.curlrc still supplies proxy and CA settings. --retry 0 overrides its retries, and the outer deadline also
    # covers extra transfers it may add (url/next), so nothing outlives the caller's budget; callers own retrying.
    # A transport error or timeout (even after a 200 status line) leaves no usable body: report it as HTTP 000.
    # OAuth errors arrive as HTTP 4xx with a JSON body, so CURL_NO_FAIL (set by authenticate_with_device) keeps
    # a fail/fail-with-body option in ~/.curlrc from turning them into transport errors.
    # A proxy password asked once up front (CURL_PROXY_AUTH) reaches curl as an extra config on a file descriptor,
    # never in its arguments: as a background job under with_deadline curl cannot prompt on the terminal itself.
    # The config is empty when no password was asked for.
    if ! response=$(with_deadline "$seconds" curl -sS --retry 0 "${CURL_NO_FAIL[@]}" -K <(printf '%s\n' "${CURL_PROXY_AUTH:-}") --max-time "$seconds" -w "\n__HTTP_CODE__%{http_code}" -X "$method" "$url" \
        -H "Content-Type: application/json" \
        -H "User-Agent: $USER_AGENT" \
        "$@"); then
        HTTP_CODE=000
        HTTP_BODY=""
        return 0
    fi
    HTTP_CODE="${response##*__HTTP_CODE__}"
    HTTP_BODY="${response%__HTTP_CODE__*}"
}

# ── Authentication (device sign-in, RFC 8628) ─────────────────────────────────
# The installer never sees a password: the user confirms a short code on the
# Printerhive website (any sign-in method works there) and we receive the API token.

ask_proxy_password() {
    # curl cannot prompt for a proxy password under with_deadline, and guessing from curl's config files is unreliable.
    # Every curl call in this installer adds the same -K, so the whole installation goes through the proxy.
    # A user whose proxy needs a password typed at run time names the proxy user explicitly; it is asked for once here
    # and then overrides the proxy user from ~/.curlrc. Without it, curl's own config is used unchanged.
    [ -n "${PRINTERHIVE_PROXY_USER:-}" ] || return 0
    { : </dev/tty; } 2>/dev/null || fail "PRINTERHIVE_PROXY_USER needs a terminal to ask for the proxy password."
    local password
    printf '  Proxy password for %s: ' "$PRINTERHIVE_PROXY_USER" >/dev/tty
    IFS= read -r -s password </dev/tty || password=""
    printf '\n' >/dev/tty
    # curl config syntax: a double-quoted value with backslash and quote escaped.
    password=${password//\\/\\\\}
    password=${password//\"/\\\"}
    local user=${PRINTERHIVE_PROXY_USER//\\/\\\\}
    user=${user//\"/\\\"}
    CURL_PROXY_AUTH="proxy-user = \"${user}:${password}\""
}

monotonic_ms() {
    # CLOCK_BOOTTIME keeps counting while the host is suspended and ignores wall-clock changes, like the code's lifetime.
    python3 -c 'import time; print(int(time.clock_gettime(getattr(time, "CLOCK_BOOTTIME", time.CLOCK_MONOTONIC)) * 1000))'
}

auth_device_start() {
    local payload
    payload=$(DEVICE_HOSTNAME="$(hostname 2>/dev/null || true)" python3 -c "
import json, os
print(json.dumps({'hostname': os.environ.get('DEVICE_HOSTNAME', ''), 'platform': 'linux_docker'}))
")
    # The code's lifetime starts no later than this request, so the deadline is counted from here.
    local started_ms
    started_ms=$(monotonic_ms)
    curl_json POST "${API_HOST}/api/auth/device" 30 --connect-timeout 10 -d "$payload"

    if [[ "$HTTP_CODE" != 2* ]]; then
        # A proxy that asks for a password (curl cannot prompt here) ends as HTTP 000 or 407.
        [[ "$HTTP_CODE" == 000 || "$HTTP_CODE" == 407 ]] && [ -z "${PRINTERHIVE_PROXY_USER:-}" ] &&
            warn "If your proxy asks for a password, run the installer again with PRINTERHIVE_PROXY_USER=<proxy user>."
        fail "$(api_error_message "$HTTP_BODY") (HTTP $HTTP_CODE)"
    fi

    DEVICE_CODE=$(printf '%s' "$HTTP_BODY" | json_get 'device_code') || fail "Invalid server response."
    USER_CODE=$(printf '%s' "$HTTP_BODY" | json_get 'user_code') || fail "Invalid server response."
    VERIFICATION_URI=$(printf '%s' "$HTTP_BODY" | json_get 'verification_uri') || fail "Invalid server response."
    DEVICE_EXPIRES_IN=$(printf '%s' "$HTTP_BODY" | json_get 'expires_in') || DEVICE_EXPIRES_IN=900
    DEVICE_INTERVAL=$(printf '%s' "$HTTP_BODY" | json_get 'interval') || DEVICE_INTERVAL=5
    [[ "$DEVICE_EXPIRES_IN" =~ ^[1-9][0-9]{0,5}$ && "$DEVICE_INTERVAL" =~ ^[1-9][0-9]{0,3}$ ]] || fail "Invalid server response."
    DEVICE_DEADLINE_MS=$(( started_ms + DEVICE_EXPIRES_IN * 1000 ))

    # The page is opened from a link or QR code, so only accept a secure web address with a host.
    VERIFICATION_URI="$VERIFICATION_URI" python3 -c "
import os, sys, urllib.parse
uri = os.environ['VERIFICATION_URI']
parts = urllib.parse.urlsplit(uri)
parts.port  # raises ValueError for an invalid port
ok = parts.scheme == 'https' and parts.hostname and not any(c.isspace() or ord(c) < 32 or ord(c) == 127 for c in uri)
sys.exit(0 if ok else 1)
" 2>/dev/null || fail "Invalid server response."

    # A code that arrives already expired is useless: do not show it.
    [ $(( DEVICE_DEADLINE_MS - $(monotonic_ms) )) -gt 0 ] || fail "The code has expired. Run the installer again to get a new code."
}

auth_device_wait() {
    local payload error remaining_ms pause_ms next_poll_ms seconds
    payload=$(DEVICE_CODE="$DEVICE_CODE" python3 -c "
import json, os
print(json.dumps({'device_code': os.environ['DEVICE_CODE']}))
")
    # Neither the pause nor a single request may run past the code's deadline, even if the server stalls.
    # A suspend-aware clock in milliseconds keeps this exact and immune to system clock changes.
    while :; do
        remaining_ms=$(( DEVICE_DEADLINE_MS - $(monotonic_ms) ))
        [ "$remaining_ms" -gt 0 ] || break
        # Wait in slices of at most 1 s against the suspend-aware clock, so a host that wakes up after the
        # deadline notices within a second instead of finishing a long (backed-off) pause first.
        next_poll_ms=$(( $(monotonic_ms) + (DEVICE_INTERVAL * 1000 < remaining_ms ? DEVICE_INTERVAL * 1000 : remaining_ms) ))
        while pause_ms=$(( next_poll_ms - $(monotonic_ms) )); [ "$pause_ms" -gt 0 ]; do
            [ "$pause_ms" -gt 1000 ] && pause_ms=1000
            sleep "$(( pause_ms / 1000 )).$(printf '%03d' $(( pause_ms % 1000 )))"
            [ $(( DEVICE_DEADLINE_MS - $(monotonic_ms) )) -gt 0 ] || break 2
        done

        remaining_ms=$(( DEVICE_DEADLINE_MS - $(monotonic_ms) ))
        [ "$remaining_ms" -gt 0 ] || break
        [ "$remaining_ms" -gt 30000 ] && remaining_ms=30000
        seconds="$(( remaining_ms / 1000 )).$(printf '%03d' $(( remaining_ms % 1000 )))"
        # The body goes through stdin, so the device code never appears in process arguments (ps, /proc).
        curl_json POST "${API_HOST}/api/auth/device/token" "$seconds" --connect-timeout 10 --data-binary @- <<<"$payload" 2>/dev/null
        # Network hiccup or server restart (deploy) while waiting: keep polling until the code expires.
        # A connection failure or timeout backs off (RFC 8628 section 3.5); the pause stays capped by the deadline.
        if [[ "$HTTP_CODE" == 000 ]]; then
            [ "$DEVICE_INTERVAL" -lt 86400 ] && DEVICE_INTERVAL=$((DEVICE_INTERVAL * 2))
            continue
        fi
        [[ "$HTTP_CODE" == 5* ]] && continue

        # A response that arrives after the deadline must not complete setup.
        [ $(( DEVICE_DEADLINE_MS - $(monotonic_ms) )) -gt 0 ] || break

        if [[ "$HTTP_CODE" == 2* ]]; then
            API_TOKEN=$(printf '%s' "$HTTP_BODY" | json_get 'api_token') || fail "Invalid server response."
            [[ "$API_TOKEN" =~ [^[:space:]] ]] || fail "Invalid server response."
            SELECTED_LOCATION_NAME=$(printf '%s' "$HTTP_BODY" | json_get 'location.name') || SELECTED_LOCATION_NAME=""
            USER_EMAIL=$(printf '%s' "$HTTP_BODY" | json_get 'user.email') || USER_EMAIL=""
            return
        fi

        error=$(printf '%s' "$HTTP_BODY" | json_get 'error' 2>/dev/null || true)
        case "$error" in
            authorization_pending) ;;
            slow_down) DEVICE_INTERVAL=$((DEVICE_INTERVAL + 5)) ;;
            access_denied) fail "The request was denied in the browser. Run the installer again to get a new code." ;;
            expired_token) fail "The code has expired. Run the installer again to get a new code." ;;
            *) fail "$(api_error_message "$HTTP_BODY") (HTTP $HTTP_CODE)" ;;
        esac
    done

    fail "The code has expired. Run the installer again to get a new code."
}

authenticate_with_device() {
    section_header "Connect this device to your Printerhive account"

    # Every request runs under with_deadline, so nothing ~/.curlrc adds can outlive the code.
    # --no-fail-with-body only exists since curl 7.76. Probe once, before the code exists, and without ~/.curlrc (-q).
    CURL_NO_FAIL=(--no-fail)
    curl -q --help all 2>/dev/null | grep -q -- '--fail-with-body' && CURL_NO_FAIL+=(--no-fail-with-body)
    ask_proxy_password
    auth_device_start

    echo ""
    # The address comes from the server, so print it literally (no echo -e escape processing).
    printf '  1. Open in a browser (computer or phone):  %b%s%b\n' "$BOLD" "$VERIFICATION_URI" "$NC"
    echo -e "  2. Sign in to Printerhive if asked."
    echo -e "  3. Enter this code:  ${BOLD}${CYAN}${USER_CODE}${NC}"
    echo -e "  4. Click ${BOLD}Connect device${NC}."
    echo ""
    if command -v qrencode >/dev/null 2>&1; then
        echo -e "  ${DIM}Or scan this QR code with your phone to open the page:${NC}"
        qrencode -t ANSIUTF8 -m 2 "$VERIFICATION_URI"
        echo ""
    fi
    # Printing the QR code takes time too: report expiry instead of "valid for 0 min".
    local remaining_ms
    remaining_ms=$(( DEVICE_DEADLINE_MS - $(monotonic_ms) ))
    [ "$remaining_ms" -gt 0 ] || fail "The code has expired. Run the installer again to get a new code."
    info "Waiting for confirmation in your browser… (the code is valid for $(( (remaining_ms + 59999) / 60000 )) min, keep this terminal open)"

    auth_device_wait
    success "Connected to location: ${SELECTED_LOCATION_NAME}${USER_EMAIL:+ (${USER_EMAIL})}"
}

resolve_api_token() {
    # Hidden fallback for support: bash install-printerhive.sh <API_TOKEN>
    if [ -n "$1" ]; then
        API_TOKEN="$1"
        info "Using API token from command line."
        return
    fi

    authenticate_with_device
}

# ── Install progress ──────────────────────────────────────────────────────────

log_step() {
    local step="$1"
    local status="$2"
    local message="$3"

    local response http_code body error_message
    response=$(curl -s -K <(printf '%s\n' "${CURL_PROXY_AUTH:-}") -w "%{http_code}" -X POST "${API_HOST}/api/install-progress" \
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
        curl -fsSL -K <(printf '%s\n' "${CURL_PROXY_AUTH:-}") https://get.docker.com -o get-docker.sh
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
        if ! curl -fsSL -K <(printf '%s\n' "${CURL_PROXY_AUTH:-}") https://raw.githubusercontent.com/printerhive/printerhive-client/main/docker-compose.yml -o docker-compose.yml; then
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
