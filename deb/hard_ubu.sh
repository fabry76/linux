#!/usr/bin/env bash
set -euo pipefail

[ "$EUID" -eq 0 ] || { echo "Run as root (sudo)"; exit 1; }

# Sysctl
cat > /etc/sysctl.d/99-hardening.conf << 'EOF'
kernel.kptr_restrict = 2
kernel.sysrq = 0
kernel.dmesg_restrict = 1
kernel.yama.ptrace_scope = 1
kernel.unprivileged_bpf_disabled = 1
net.core.bpf_jit_harden = 2

# rp_filter: metti 2 se usi VPN/Docker/libvirt
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

# Protocolli legacy
cat > /etc/modprobe.d/disable-protocols.conf << 'EOF'
install dccp /bin/false
install sctp /bin/false
install rds /bin/false
install tipc /bin/false
EOF

# Sudoers
chmod 750 /etc/sudoers.d
chown root:root /etc/sudoers.d

# Umask più restrittivo (AUTH-9328)
if grep -q '^UMASK' /etc/login.defs; then
  sed -i 's/^UMASK.*/UMASK           027/' /etc/login.defs
else
  echo 'UMASK           027' >> /etc/login.defs
fi

# Permessi cron (FILE-7524)
chmod 600 /etc/crontab
chmod 700 /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.weekly /etc/cron.monthly

sysctl --system
echo "Done."