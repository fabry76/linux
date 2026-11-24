#!/usr/bin/env bash
set -euo pipefail

###############################################
# Args
###############################################

TARGET_USER="$1"
BROWSER_SELECTION="${2:-0}"

###############################################
# Snap installation helper
###############################################

install_snap_if_missing() {
    local package="$1"

    if ! snap list "$package" >/dev/null 2>&1; then
        snap install "$package"
    else
        echo "$package is already installed."
    fi
}

###############################################
# DEBIAN
###############################################

if [[ "$DISTRO" == "debian" ]]; then

    FLATPAK_BROWSER="$BROWSER_SELECTION"

    ###############################################
    # KDE Plasma base
    ###############################################

    apt-get install -y \
        plasma-desktop \
        plasma-browser-integration- \
        plasma-workspace \
        sddm \
        dolphin \
        kate \
        kdialog \
        kfind \
        konsole \
        ark \
        udisks2 \
        upower \
        isoimagewriter \
        kolourpaint \
        gwenview \
        okular \
        okular-extra-backends \
        kcharselect \
        kcolorchooser \
        filelight \
        krecorder \
        plasma-workspace-wallpapers \
        inotify-tools \
        libnotify-bin \
        mpv \
        print-manager \
        skanpage \
        kclock \
        kamoso \
        qalculate-qt

    systemctl set-default graphical.target

    ###############################################
    # KDE Flatpak base setup
    ###############################################

    apt-get install -y \
        flatpak \
        plasma-discover-backend-flatpak \
        xdg-desktop-portal-kde \
        kde-config-flatpak

    flatpak remote-add --if-not-exists \
        flathub \
        https://dl.flathub.org/repo/flathub.flatpakrepo

    ###############################################
    # Variables
    ###############################################

    BROWSER_APP=""
    TORRENT_APP="org.qbittorrent.qBittorrent"

    FLATPAK_APPS=(
        org.gtk.Gtk3theme.Breeze
        "$TORRENT_APP"
    )

    ###############################################
    # Browser selection
    ###############################################

    case "$FLATPAK_BROWSER" in
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
        0)
            ;;
    esac

    ###############################################
    # Install Flatpaks
    ###############################################

    flatpak install -y --system flathub "${FLATPAK_APPS[@]}"

    ###############################################
    # Browser override
    ###############################################

    if [ -n "$BROWSER_APP" ]; then
        runuser -u "$TARGET_USER" -- bash -c "
            flatpak override --user '$BROWSER_APP' \
            --nofilesystem=host \
            --filesystem=xdg-download \
            --nodevice=all \
            --nosocket=x11 \
            --nosocket=pcsc \
            --nosocket=cups
        "
    fi

    ###############################################
    # BitTorrent override
    ###############################################

    runuser -u "$TARGET_USER" -- bash -c "
        flatpak override --user '$TORRENT_APP' \
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
    "

###############################################
# UBUNTU
###############################################

elif [[ "$DISTRO" == "ubuntu" ]]; then

    SNAP_BROWSER="$BROWSER_SELECTION"

    ###############################################
    # KDE Plasma base
    ###############################################

    sudo apt install -y \
        plasma-desktop \
        plasma-workspace \
        kwin-wayland \
        sddm \
        sddm-theme-breeze \
        xserver-xorg \
        dolphin \
        konsole \
        kate \
        udisks2 \
        upower \
        kdialog \
        kfind \
        ark \
        isoimagewriter \
        kolourpaint \
        gwenview \
        okular \
        okular-extra-backends \
        kcharselect \
        kcolorchooser \
        filelight \
        krecorder \
        plasma-workspace-wallpapers \
        inotify-tools \
        libnotify-bin \
        mpv \
        print-manager \
        skanpage \
        kclock \
        kamoso \
        qalculate-qt

    systemctl set-default graphical.target

    ###############################################
    # Browser selection - Snap
    ###############################################

    case "$SNAP_BROWSER" in
        1)
            install_snap_if_missing firefox
            ;;
        2)
            install_snap_if_missing brave
            ;;
        0)
            ;;
        *)
            echo "ERROR: Invalid Snap browser selection: $SNAP_BROWSER" >&2
            exit 1
            ;;
    esac

    ###############################################
    # BitTorrent - Snap
    ###############################################

    install_snap_if_missing qbittorrent-arnatious

else
    echo "ERROR: Unsupported distribution: $DISTRO" >&2
    exit 1
fi
