#!/usr/bin/env bash
set -euo pipefail

###############################################
# Root check
###############################################
if [ "$EUID" -ne 0 ]; then
  echo "Run as root (sudo)"
  exit 1
fi

###############################################
# Disable SSH
###############################################
systemctl disable sshd

###############################################
# Function
###############################################
write_if_changed() {
  local file="$1"
  local content="$2"

  if [ -f "$file" ] && printf "%s" "$content" | cmp -s - "$file"; then
    return 0
  fi

  printf "%s" "$content" > "$file"
}

###############################################
# Kernel Hardening
###############################################
write_if_changed /etc/sysctl.d/99-hardening.conf "$(cat << 'EOF'
kernel.randomize_va_space = 2
net.ipv4.tcp_syncookies = 1
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
EOF
)"

###############################################
# Disable legacy network protocols
###############################################
write_if_changed /etc/modprobe.d/disable-protocols.conf "$(cat << 'EOF'
install dccp /bin/false
install sctp /bin/false
install rds /bin/false
install tipc /bin/false

blacklist dccp
blacklist sctp
blacklist rds
blacklist tipc
EOF
)"

###############################################
# Apply settings
###############################################
sysctl --system

echo
echo "Hardening completed."