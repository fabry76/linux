#!/usr/bin/env bash
set -euo pipefail

[ "$EUID" -eq 0 ] || { echo "Run as root (sudo)"; exit 1; }

###############################################
# Functions
###############################################
# Write the file only if the content differs. Always returns 0.
write_if_changed() {
  local file="$1"
  local content="$2"

  if [ -f "$file" ] && printf '%s\n' "$content" | cmp -s - "$file"; then
    return 0
  fi

  printf '%s\n' "$content" > "$file"
  echo "Updated: $file"
}

# Set "KEY   VALUE" in /etc/login.defs only if it is not already set.
# If the key exists it is replaced, otherwise it is appended.
set_login_defs() {
  local key="$1" value="$2" file=/etc/login.defs
  if grep -qE "^${key}[[:space:]]+${value}$" "$file"; then
    return 0
  fi
  if grep -q "^${key}[[:space:]]" "$file"; then
    sed -i "s/^${key}[[:space:]].*/${key}           ${value}/" "$file"
  else
    echo "${key}           ${value}" >> "$file"
  fi
  echo "Updated: $file ($key)"
}

###############################################
# Sysctl
###############################################
write_if_changed /etc/sysctl.d/99-hardening.conf "$(cat << 'EOF'
kernel.kptr_restrict = 2
kernel.sysrq = 0
kernel.dmesg_restrict = 1
kernel.yama.ptrace_scope = 1
kernel.unprivileged_bpf_disabled = 1
net.core.bpf_jit_harden = 2

# rp_filter: use 2 (loose) if you use VPN/Docker/libvirt
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

fs.protected_fifos = 2
fs.protected_regular = 2
fs.protected_symlinks = 1
fs.protected_hardlinks = 1
fs.suid_dumpable = 0
EOF
)"

###############################################
# Legacy network protocols
###############################################
write_if_changed /etc/modprobe.d/disable-protocols.conf "$(cat << 'EOF'
install dccp /bin/false
install sctp /bin/false
install rds /bin/false
install tipc /bin/false
EOF
)"

###############################################
# Sudoers (chmod/chown are already idempotent)
###############################################
chmod 750 /etc/sudoers.d
chown root:root /etc/sudoers.d

###############################################
# Restrictive umask (AUTH-9328)
###############################################
set_login_defs UMASK 027

###############################################
# Cron permissions (FILE-7524)
###############################################
chmod 600 /etc/crontab
chmod 700 /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.weekly /etc/cron.monthly

###############################################
# debsums via cron (PKGS-7370)
###############################################
if [ -f /etc/default/debsums ]; then
  if ! grep -q '^CRON_CHECK=weekly$' /etc/default/debsums; then
    if grep -q '^CRON_CHECK=' /etc/default/debsums; then
      sed -i 's/^CRON_CHECK=.*/CRON_CHECK=weekly/' /etc/default/debsums
    else
      echo 'CRON_CHECK=weekly' >> /etc/default/debsums
    fi
    echo "Updated: /etc/default/debsums"
  fi
fi

###############################################
# Apply settings
###############################################
sysctl --system >/dev/null
echo
echo "Hardening completed."