#!/usr/bin/env bash
###############################################
# questions.sh
#
# Generic interactive prompts shared by every distro installer
# (fedora.sh, debian.sh, ...).
#
# Usage (from a distro script, AFTER SCRIPT_DIR is defined):
#
#   source "$SCRIPT_DIR/questions.sh"
#   run_installer_questions
#
# Any prompt that is specific to a single distro (e.g. the
# hostname question in fedora.sh) stays in that distro's own
# script, right after the call to run_installer_questions.
#
# IMPORTANT: this file must be `source`d, never executed with
# `bash questions.sh`, otherwise the variables it sets (DESKTOP_CHOICE,
# BROWSERS, FLATPAK_BROWSER, OFFICE_CHOICE, INSTALL_VSCODE,
# RUN_FASTGATE, RUN_HARDENING, ...) would not survive in the
# calling script.
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

ask_flatpak_browser() {
    while :; do
        echo "Which Flatpak browser would you like to install?"
        echo "0) None"
        echo "1) LibreWolf (io.gitlab.librewolf-community)"
        echo "2) Brave (com.brave.Browser)"
        echo "3) Firefox (org.mozilla.firefox)"
        echo

        read -rp "Choice [0-3]: " FLATPAK_BROWSER

        [[ "$FLATPAK_BROWSER" =~ ^[0-3]$ ]] && break

        echo "Please enter a number between 0 and 3."
    done
    echo
}

ask_office() {
    while :; do
        echo "Which Office suite would you like to install?"
        echo "0) None"
        echo "1) ONLYOFFICE (org.onlyoffice.desktopeditors)"
        echo "2) LibreOffice (org.libreoffice.LibreOffice)"
        echo "3) Collabora Office (com.collaboraoffice.Office)"
        echo

        read -rp "Choice [0-3]: " OFFICE_CHOICE

        [[ "$OFFICE_CHOICE" =~ ^[0-3]$ ]] && break

        echo "Please enter a number between 0 and 3."
    done
    echo
}

ask_vscode() {
    while :; do
        read -rp "Do you want to install Visual Studio Code? (Y/n): " INSTALL_VSCODE
        INSTALL_VSCODE="${INSTALL_VSCODE:-Y}"
        [[ "$INSTALL_VSCODE" =~ ^([Yy]|[Nn])$ ]] && break
        echo "Please answer y or n."
    done
    echo
}

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

            if ! grep -qE "^username=.+" "$CRED_FILE" || ! grep -qE "^password=.+" "$CRED_FILE"; then
                echo "ERROR: failed to write valid Fastgate credentials to $CRED_FILE" >&2
                exit 1
            fi
        fi
    fi
    echo
}

ask_hardening() {
    while :; do
        read -rp "Do you want to apply system hardening at the end of installation? (Y/n): " RUN_HARDENING
        RUN_HARDENING="${RUN_HARDENING:-Y}"
        [[ "$RUN_HARDENING" =~ ^([Yy]|[Nn])$ ]] && break
        echo "Please answer y or n."
    done
}

###############################################
# Orchestrator
###############################################
run_installer_questions() {
    ask_desktop
    ask_browsers
    ask_flatpak_browser
    ask_office
    ask_vscode
    ask_fastgate
    ask_hardening
}
