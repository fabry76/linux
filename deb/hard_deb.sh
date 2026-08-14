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
# Detect real network interfaces (excluding lo)
###############################################
IFACES=()
for path in /sys/class/net/*; do
  iface="$(basename "$path")"
  [ "$iface" = "lo" ] && continue
  IFACES+=("$iface")
done

IFACE_RP_FILTER_LINES=""
for iface in "${IFACES[@]}"; do
  IFACE_RP_FILTER_LINES+="net.ipv4.conf.${iface}.rp_filter = 1"$'\n'
done

###############################################
# Kernel Hardening
###############################################
HARDENING_CONTENT="$(cat << 'EOF'
kernel.kptr_restrict = 2
kernel.sysrq = 0
kernel.dmesg_restrict = 1
kernel.kexec_load_disabled = 1
kernel.yama.ptrace_scope = 1
kernel.unprivileged_bpf_disabled = 1

net.core.bpf_jit_harden = 2

net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.conf.all.rp_filter = 1
EOF
)"

HARDENING_CONTENT+=$'\n'"${IFACE_RP_FILTER_LINES}"

HARDENING_CONTENT+="$(cat << 'EOF'

net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0

fs.protected_fifos = 2
fs.protected_regular = 2
fs.protected_symlinks = 1
fs.protected_hardlinks = 1
fs.suid_dumpable = 0
EOF
)"

write_if_changed /etc/sysctl.d/99-hardening.conf "$HARDENING_CONTENT"

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

################################################
# Sudoers hardening
###############################################
chmod 750 /etc/sudoers.d
chown root:root /etc/sudoers.d

################################################
# Restrict Core Dumps
###############################################
write_if_changed /etc/security/limits.d/99-hardening.conf "$(cat << 'EOF'
* hard core 0
EOF
)"

###############################################
# Apply settings
###############################################
sysctl --system

echo
echo "Hardening completed."
