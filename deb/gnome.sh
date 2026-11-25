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
# GNOME common packages
###############################################
GNOME_PKGS=(
    gnome-core
    ptyxis
    papers
    showtime
    network-manager
    gnome-tweaks
    gnome-shell-extension-manager
    gnome-shell-extension-system-monitor
    gnome-themes-extra
    gnome-sound-recorder
)

###############################################
# Distribution-specific packages
###############################################
case "$DISTRO" in
    debian)
        GNOME_PKGS+=(
        gnome-shell-extension-dash-to-panel
        )
        ;;

    ubuntu)
        GNOME_PKGS+=(
        )
        ;;

    *)
        echo "ERROR: Unsupported distribution: $DISTRO" >&2
        exit 1
        ;;
esac

###############################################
# Install GNOME packages
###############################################
apt-get install -y --no-install-recommends "${GNOME_PKGS[@]}"

# Set the graphical target as the default boot target.
systemctl set-default graphical.target

###############################################
# Optional Flatpak installation
# Supported on Debian and Ubuntu.
###############################################
if [[ "$INSTALL_FLATPAK" =~ ^[Yy]$ ]]; then

    ###############################################
    # Install Flatpak and GNOME integration packages
    ###############################################
    apt-get install -y \
        flatpak \
        xdg-desktop-portal-gnome \
        gnome-software-plugin-flatpak

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
    BROWSER_APP=""
    TORRENT_APP="de.haeckerfelix.Fragments"

    FLATPAK_APPS=(
        com.github.tchx84.Flatseal
        com.github.PintaProject.Pinta
        "$TORRENT_APP"
    )

    ###############################################
    # Browser selection
    ###############################################
    case "$INSTALL_FLATPAK" in
        1)
            BROWSER_APP="io.gitlab.librewolf-community"
            FLATPAK_APPS+=(io.gitlab.librewolf-community)
            ;;
        2)
            BROWSER_APP="com.brave.Browser"
            FLATPAK_APPS+=(com.brave.Browser)
            ;;
        3)
            BROWSER_APP="org.mozilla.firefox"
            FLATPAK_APPS+=(org.mozilla.firefox)
            ;;
    esac

    ###############################################
    # Install Flatpak applications
    ###############################################
    flatpak install -y --noninteractive --system \
        flathub "${FLATPAK_APPS[@]}"

    ###############################################
    # Browser security overrides
    ###############################################
    if [[ -n "$BROWSER_APP" ]]; then
        run_as_user flatpak override --user "$BROWSER_APP" \
            --nofilesystem=host \
            --filesystem=xdg-download \
            --nodevice=all \
            --nosocket=x11 \
            --nosocket=pcsc \
            --nosocket=cups
    fi

    ###############################################
    # BitTorrent security overrides
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
# End of GNOME installation
###############################################
