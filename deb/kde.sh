#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

###############################################
# Arguments and environment validation
###############################################
TARGET_USER="${1:?Missing TARGET_USER (first argument)}"
INSTALL_FLATPAK="${2:-n}"
DISTRO="${DISTRO:?DISTRO is not defined (the calling script must export it)}"

if [[ "$EUID" -ne 0 ]]; then
    echo "ERROR: This script must be run as root (sudo)." >&2
    exit 1
fi

TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"

if [[ -z "$TARGET_HOME" ]]; then
    echo "ERROR: User $TARGET_USER not found." >&2
    exit 1
fi

###############################################
# Functions
###############################################

# Execute commands as the target user with the
# correct HOME environment.
run_as_user() {
    runuser -u "$TARGET_USER" -- env HOME="$TARGET_HOME" "$@"
}

# Write a file only when its content changes.
write_if_changed() {
    local file="$1"
    local content="$2"

    if [[ -f "$file" ]] && printf '%s' "$content" | cmp -s - "$file"; then
        return 0
    fi

    printf '%s' "$content" > "$file"
}

###############################################
# KDE Plasma common packages
###############################################
KDE_PKGS=(
    plasma-desktop
    plasma-browser-integration-
    plasma-workspace

    # KDE applications
    dolphin
    kate
    kdialog
    kfind
    konsole
    ark

    # Storage / power
    udisks2
    upower

    # Graphics / documents
    isoimagewriter
    kolourpaint
    gwenview
    okular
    okular-extra-backends
    kcharselect
    kcolorchooser

    # System utilities
    filelight
    krecorder
    print-manager
    skanpage

    # KDE applications
    kclock
    kamoso
    qalculate-qt

    # Plasma assets
    plasma-workspace-wallpapers

    # Utilities
    inotify-tools
    libnotify-bin
    mpv
)

###############################################
# Distribution-specific packages
###############################################
case "$DISTRO" in
    debian)
        KDE_PKGS+=(
            sddm
        )
        ;;

    ubuntu)
        KDE_PKGS+=(
            # Display manager
            sddm
            sddm-theme-breeze

            # SDDM X11 greeter
            xserver-xorg

            # Ubuntu Plasma 6.7 timezone QML dependency
            qml6-module-qtlocation

            # Ubuntu boot splash
            plymouth
            plymouth-label
            plymouth-theme-spinner
            plymouth-theme-ubuntu-text
        )
        ;;

    *)
        echo "ERROR: Unsupported distribution: $DISTRO" >&2
        exit 1
        ;;
esac

###############################################
# Install KDE Plasma packages
###############################################
apt-get install -y "${KDE_PKGS[@]}"

###############################################
# Graphical target
###############################################
systemctl set-default graphical.target

###############################################
# Root GTK theme for privileged applications
###############################################
ROOT_GTK_DIR="/root/.config/gtk-3.0"
ROOT_GTK_SETTINGS="$ROOT_GTK_DIR/settings.ini"

ROOT_GTK_CONTENT="$(cat <<'EOF'
[Settings]
gtk-theme-name=Breeze-Dark
gtk-application-prefer-dark-theme=true
gtk-icon-theme-name=Papirus-Dark
gtk-cursor-theme-name=breeze_cursors
EOF
)"

install -d -m 0755 "$ROOT_GTK_DIR"

write_if_changed "$ROOT_GTK_SETTINGS" "$ROOT_GTK_CONTENT"

chown root:root "$ROOT_GTK_SETTINGS"
chmod 0644 "$ROOT_GTK_SETTINGS"

###############################################
# Ubuntu Plymouth configuration
###############################################
if [[ "$DISTRO" == "ubuntu" ]]; then
    BGRT_THEME="/usr/share/plymouth/themes/bgrt/bgrt.plymouth"

    if [[ -f "$BGRT_THEME" ]]; then
        CURRENT_PLYMOUTH="$(
            readlink -f /usr/share/plymouth/themes/default.plymouth \
                2>/dev/null || true
        )"

        if [[ "$CURRENT_PLYMOUTH" != "$BGRT_THEME" ]]; then
            update-alternatives --set default.plymouth "$BGRT_THEME"
            update-initramfs -u
        fi
    fi
fi

###############################################
# Optional Flatpak installation
###############################################
if [[ "$INSTALL_FLATPAK" =~ ^[Yy]$ ]]; then

    ###############################################
    # Flatpak and KDE integration
    ###############################################
    apt-get install -y \
        flatpak \
        plasma-discover-backend-flatpak \
        xdg-desktop-portal-kde \
        kde-config-flatpak

    ###############################################
    # Configure Flathub
    ###############################################
    flatpak remote-add \
        --if-not-exists \
        --system \
        flathub \
        https://dl.flathub.org/repo/flathub.flatpakrepo

    ###############################################
    # Flatpak application definitions
    ###############################################
    BROWSER_APP="io.gitlab.librewolf-community"
    TORRENT_APP="org.kde.ktorrent"

    FLATPAK_APPS=(
        org.gtk.Gtk3theme.Breeze
        "$TORRENT_APP"
        "$BROWSER_APP"
    )

    ###############################################
    # Install Flatpak applications
    ###############################################
    flatpak install \
        -y \
        --noninteractive \
        --system \
        flathub \
        "${FLATPAK_APPS[@]}"

    ###############################################
    # LibreWolf security overrides
    ###############################################
    run_as_user flatpak override \
        --user \
        "$BROWSER_APP" \
        --nofilesystem=host \
        --filesystem=xdg-download \
        --nodevice=all \
        --nosocket=x11 \
        --nosocket=pcsc \
        --nosocket=cups

    ###############################################
    # KTorrent security overrides
    ###############################################
    run_as_user flatpak override \
        --user \
        "$TORRENT_APP" \
        --nofilesystem=host \
        --nofilesystem=home \
        --filesystem=xdg-download \
        --nodevice=all \
        --nosocket=pulseaudio \
        --nosocket=cups \
        --nosocket=pcsc \
        --nosocket=ssh-auth \
        --nosocket=x11 \
        --nosocket=fallback-x11
fi

###############################################
# End of KDE Plasma installation
###############################################
