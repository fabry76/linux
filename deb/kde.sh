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
# Execute commands as the target user
###############################################

# Set the correct HOME environment variable when running commands
# as the target user. This prevents user configuration files from
# being created under /root.
run_as_user() {
    runuser -u "$TARGET_USER" -- env HOME="$TARGET_HOME" "$@"
}

###############################################
# KDE Plasma base packages
###############################################

KDE_PKGS=(
    plasma-desktop
    plasma-browser-integration-
    plasma-workspace
    dolphin
    kate
    kdialog
    kfind
    konsole
    ark
    udisks2
    upower
    isoimagewriter
    kolourpaint
    gwenview
    okular
    okular-extra-backends
    kcharselect
    kcolorchooser
    filelight
    krecorder
    plasma-workspace-wallpapers
    inotify-tools
    libnotify-bin
    mpv
    print-manager
    skanpage
    kclock
    kamoso
    qalculate-qt
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
            sddm
            sddm-theme-breeze
            xserver-xorg
            plymouth
            plymouth-label
            plymouth-theme-spinner
            plymouth-theme-ubuntu-text
            libqt6location6
            qml6-module-qtlocation
            qt6-location-plugins
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

# Set the graphical target as the default boot target.
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
# Optional Flatpak installation
# Supported on Debian and Ubuntu.
###############################################

if [[ "$INSTALL_FLATPAK" =~ ^[Yy]$ ]]; then

    ###############################################
    # Install Flatpak and KDE integration packages
    ###############################################

    apt-get install -y \
        flatpak \
        plasma-discover-backend-flatpak \
        xdg-desktop-portal-kde \
        kde-config-flatpak


    ###############################################
    # Configure Flathub repository
    ###############################################

    # Add Flathub system-wide if the repository does not exist.
    flatpak remote-add --if-not-exists --system \
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

    # Install the selected applications system-wide.
    flatpak install -y --noninteractive --system flathub "${FLATPAK_APPS[@]}"


    ###############################################
    # LibreWolf security overrides
    ###############################################

    run_as_user flatpak override --user "$BROWSER_APP" \
        --nofilesystem=host \
        --filesystem=xdg-download \
        --nodevice=all \
        --nosocket=x11 \
        --nosocket=pcsc \
        --nosocket=cups


    ###############################################
    # KTorrent security overrides
    ###############################################

    run_as_user flatpak override --user "$TORRENT_APP" \
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
