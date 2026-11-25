#!/usr/bin/env bash
set -euo pipefail

###############################################
# Root check
###############################################
if [[ "$EUID" -ne 0 ]]; then
    echo "Run as root (sudo)"
    exit 1
fi

###############################################
# Functions
###############################################
write_if_changed() {
    local file="$1"
    local content="$2"

    if [[ -f "$file" ]] && printf "%s" "$content" | cmp -s - "$file"; then
        return 0
    fi

    printf "%s" "$content" > "$file"
}

###############################################
# System update command
###############################################
UPDATE_SCRIPT="$(cat <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

###############################################
# Root check
###############################################
if [[ "$EUID" -ne 0 ]]; then
    echo "Please run: sudo update"
    exit 1
fi

###############################################
# Colors
###############################################
BLUE='\033[1;34m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
BOLD='\033[1m'
RESET='\033[0m'

###############################################
# Functions
###############################################
step() {
    echo
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}${CYAN}  $1${RESET}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

done_msg() {
    echo -e "${GREEN}✓ $1${RESET}"
}

###############################################
# Header
###############################################
clear

echo -e "${BOLD}"
echo "  System Update"
echo -e "${RESET}"
echo "  $(date '+%A, %d %B %Y - %H:%M')"

###############################################
# APT repositories
###############################################
step "Updating package repositories..."

apt-get update

done_msg "Repositories updated."

###############################################
# APT packages
###############################################
step "Checking available system upgrades..."

UPGRADES="$(apt list --upgradable 2>/dev/null | sed '1d')"

if [[ -n "$UPGRADES" ]]; then
    echo
    echo "$UPGRADES"
    echo
    echo -e "${YELLOW}Installing available system upgrades...${RESET}"
    echo

    apt-get upgrade -y

    done_msg "System packages updated."
else
    echo
    done_msg "System packages are already up to date."
fi

###############################################
# Snap
###############################################
if command -v snap >/dev/null 2>&1; then
    step "Updating Snap packages..."

    snap refresh

    done_msg "Snap packages updated."
fi

###############################################
# Flatpak
###############################################
if command -v flatpak >/dev/null 2>&1; then
    step "Updating Flatpak applications..."

    flatpak update -y

    done_msg "Flatpak applications updated."
fi

###############################################
# Reboot check
###############################################
if [[ -f /var/run/reboot-required ]]; then
    echo
    echo -e "${YELLOW}${BOLD}⚠ A system reboot is required.${RESET}"
fi

###############################################
# Finished
###############################################
echo
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}${GREEN}  ✓ System update completed${RESET}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo
EOF
)"

###############################################
# Install system command
###############################################
write_if_changed /usr/local/sbin/update "$UPDATE_SCRIPT"

chown root:root /usr/local/sbin/update
chmod 755 /usr/local/sbin/update
