
#!/usr/bin/env bash
###############################################
# questions.sh
#
# Generic interactive prompts shared by every distro installer
# (fedora.sh, debian.sh, ubuntu.sh, ...).
#
# Usage (from a distro script, AFTER SCRIPT_DIR is defined):
#
#   source "$SCRIPT_DIR/questions.sh"
#   run_installer_questions
#
# IMPORTANT: this file must be `source`d, never executed with
# `bash questions.sh`, otherwise the variables it sets will not
# survive in the calling script.
###############################################

###############################################
# Desktop environment
###############################################

ask_desktop() {
    while :; do
        echo "Which desktop environment would you like to install?"
        echo "1) KDE"
        echo "2) GNOME"
        echo
        echo "Please enter 1 for KDE or 2 for GNOME."
        echo
        read -rp "Selection: " DESKTOP_CHOICE

        [[ "$DESKTOP_CHOICE" =~ ^[12]$ ]] && break
    done
    echo
}

###############################################
# Main browsers
###############################################

ask_browsers() {
    while :; do
        echo "Which main browser would you like to install?"
        echo "1) Brave"
        echo "2) Chrome"
        echo "3) Firefox"
        echo
        echo "Please select one or more browsers using comma-separated values (e.g. 1,3)."
        echo
        read -rp "Selection: " BROWSER_SELECTION

        VALID=true
        IFS=',' read -ra BROWSERS <<< "$BROWSER_SELECTION"

        for browser in "${BROWSERS[@]}"; do
            browser="${browser// /}"
            [[ $browser =~ ^[123]$ ]] || {
                VALID=false
                break
            }
        done

        $VALID && break
    done
    echo
}

###############################################
# Flatpak support
###############################################

ask_flatpak() {
    while :; do
        read -rp "Do you want to install Flatpak support? (Y/n): " INSTALL_FLATPAK
        INSTALL_FLATPAK="${INSTALL_FLATPAK:-Y}"
        [[ "$INSTALL_FLATPAK" =~ ^([Yy]|[Nn])$ ]] && break
        echo "Please answer y or n."
    done
    echo
}

###############################################
# Nextcloud Office
###############################################

ask_office() {
    while :; do
        read -rp "Do you want to install Nextcloud Office? (Y/n): " INSTALL_OFFICE
        INSTALL_OFFICE="${INSTALL_OFFICE:-Y}"
        [[ "$INSTALL_OFFICE" =~ ^([Yy]|[Nn])$ ]] && break
        echo "Please answer y or n."
    done
    echo
}

###############################################
# Visual Studio Code
###############################################

ask_vscode() {
    while :; do
        read -rp "Do you want to install Visual Studio Code? (Y/n): " INSTALL_VSCODE
        INSTALL_VSCODE="${INSTALL_VSCODE:-Y}"
        [[ "$INSTALL_VSCODE" =~ ^([Yy]|[Nn])$ ]] && break
        echo "Please answer y or n."
    done
    echo
}

###############################################
# Fastgate SMB share
###############################################

ask_fastgate() {
    while :; do
        read -rp "Do you want to mount the Fastgate SMB share? (Y/n): " RUN_FASTGATE
        RUN_FASTGATE="${RUN_FASTGATE:-Y}"
        [[ "$RUN_FASTGATE" =~ ^([Yy]|[Nn])$ ]] && break
        echo "Please answer y or n."
    done

    if [[ "$RUN_FASTGATE" =~ ^[Yy]$ ]]; then
        CRED_FILE="/etc/samba/fastgate.creds"
        install -d -m 700 /etc/samba
        CRED_STATE="missing"

        if [ -f "$CRED_FILE" ]; then
            if grep -qE "^username=.+" "$CRED_FILE" &&
               grep -qE "^password=.+" "$CRED_FILE"; then
                CRED_STATE="valid"
            else
                CRED_STATE="invalid"
            fi
        fi

        if [ "$CRED_STATE" = "valid" ]; then
            echo
            while :; do
                read -rp "Fastgate credentials already exist. Update credentials? (y/N): " CONFIRM
                CONFIRM="${CONFIRM:-N}"
                [[ "$CONFIRM" =~ ^([Yy]|[Nn])$ ]] && break
                echo "Please answer y or n."
            done

            if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
                CRED_STATE="update"
            fi
        fi

        if [ "$CRED_STATE" = "missing" ] ||
           [ "$CRED_STATE" = "invalid" ] ||
           [ "$CRED_STATE" = "update" ]; then

            echo
            echo "=== Fastgate credentials ==="

            while :; do
                read -rp "Username: " NAS_USER
                [ -n "$NAS_USER" ] && break
                echo "Username cannot be empty."
            done

            while :; do
                read -rsp "Password: " NAS_PASS
                echo
                [ -n "$NAS_PASS" ] && break
                echo "Password cannot be empty."
            done

            OLD_UMASK="$(umask)"
            umask 077

            cat > "$CRED_FILE" <<EOF
username=$NAS_USER
password=$NAS_PASS
EOF

            umask "$OLD_UMASK"

            chown root:root "$CRED_FILE"
            chmod 600 "$CRED_FILE"

            if ! grep -qE "^username=.+" "$CRED_FILE" ||
               ! grep -qE "^password=.+" "$CRED_FILE"; then
                echo "ERROR: failed to write valid Fastgate credentials to $CRED_FILE" >&2
                exit 1
            fi
        fi
    fi

    echo
}

###############################################
# System hardening
###############################################

ask_hardening() {
    while :; do
        read -rp "Do you want to apply system hardening at the end of installation? (Y/n): " RUN_HARDENING
        RUN_HARDENING="${RUN_HARDENING:-Y}"
        [[ "$RUN_HARDENING" =~ ^([Yy]|[Nn])$ ]] && break
        echo "Please answer y or n."
    done
}

###############################################
# Hostname
###############################################

ask_hostname() {
    echo
    read -rp "Enter the hostname for this system: " NEW_HOSTNAME
    echo
}

###############################################
# Orchestrator
###############################################

run_installer_questions() {

    # Initialize distro-specific variables
    NEW_HOSTNAME=""

    # Hostname: Fedora only
    if [[ "$DISTRO" == "fedora" ]]; then
        ask_hostname
    fi

    ask_desktop
    ask_browsers

    # Ubuntu GNOME uses Snap applications instead of Flatpak
    if [[ "$DISTRO" == "ubuntu" && "$DESKTOP_CHOICE" == "2" ]]; then
        INSTALL_FLATPAK="n"
    else
        ask_flatpak
    fi

    ask_office
    ask_vscode
    ask_fastgate
    ask_hardening
}
